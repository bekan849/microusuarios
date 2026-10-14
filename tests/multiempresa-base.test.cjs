const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require('@electric-sql/pglite');

test('Base multiempresa: membresías, suspensión y acceso SQL', async t => {
  const db = new PGlite();
  const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
  const list = async n => (await db.query('SELECT public.listar_empresas_usuario($1) AS data', [id(n)])).rows[0].data;
  try {
    await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
      CREATE TABLE public.usuarios(idusuario uuid PRIMARY KEY, estado text NOT NULL);
      GRANT SELECT ON public.usuarios TO service_role;`);
    await db.exec(fs.readFileSync(path.join(__dirname, '../supabase/migrations/202610140001_multiempresa_base.sql'), 'utf8'));
    await db.query("INSERT INTO usuarios VALUES ($1,'ACTIVO'),($2,'ACTIVO'),($3,'BLOQUEADO')", [id(1),id(2),id(3)]);
    await db.query("INSERT INTO empresas(idempresa,codigo,nombre) VALUES ($1,'motos','Motos'),($2,'bike','Bicicletas')", [id(10),id(20)]);
    await db.query('INSERT INTO empresa_usuario(idempresa,idusuario,es_administrador) VALUES ($1,$3,true),($2,$3,true),($2,$4,false),($1,$5,true)', [id(10),id(20),id(1),id(2),id(3)]);
    await t.test('La cuenta compartida ve ambas; el empleado solo su empresa', async () => {
      assert.equal((await list(1)).length, 2);
      assert.deepEqual((await list(2)).map(e => e.codigo), ['bike']);
      assert.equal((await list(2))[0].esAdministrador, false);
    });
    await t.test('Suspender una membresía conserva el acceso a la otra empresa', async () => {
      await db.query('UPDATE empresa_usuario SET activa=false WHERE idempresa=$1 AND idusuario=$2', [id(20),id(1)]);
      assert.deepEqual((await list(1)).map(e => e.codigo), ['motos']);
      assert.equal((await list(2)).length, 1);
    });
    await t.test('Suspender empresa oculta sus accesos; bloquear usuario rechaza la consulta', async () => {
      await db.query('UPDATE empresas SET activa=false WHERE idempresa=$1', [id(20)]);
      assert.deepEqual(await list(2), []);
      await assert.rejects(() => list(3), /Usuario no activo/);
      await assert.rejects(() => list(99), /Usuario no activo/);
    });
    await t.test('No admite membresías duplicadas ni referencias inexistentes', async () => {
      await assert.rejects(() => db.query('INSERT INTO empresa_usuario VALUES($1,$2)',[id(10),id(1)]), /duplicate key/);
      await assert.rejects(() => db.query('INSERT INTO empresa_usuario VALUES($1,$2)',[id(10),id(99)]), /foreign key/);
    });
    await t.test('anon y authenticated no consultan membresías ni llaman la RPC', async () => {
      for (const role of ['anon', 'authenticated']) {
        await db.exec(`SET ROLE ${role}`);
        try {
          await assert.rejects(() => db.query('SELECT * FROM public.empresa_usuario'), /permission denied/);
          await assert.rejects(() => list(1), /permission denied/);
        } finally { await db.exec('RESET ROLE'); }
      }
      await db.exec('SET ROLE service_role');
      try { assert.equal((await list(1)).length, 1); }
      finally { await db.exec('RESET ROLE'); }
    });
  } finally { await db.close(); }
});

test('Preparación inicial: cuenta obligatoria, dos empresas y reversión completa', async () => {
  const db = new PGlite();
  const admin = '00000000-0000-0000-0000-000000000001';
  // Sustituir solo el correo de instalación por un dato ficticio en la prueba.
  const seed = fs.readFileSync(path.join(__dirname, '../supabase/migrations/202610140002_multiempresa_inicial.sql'), 'utf8')
    .replace(/'[^']+@gmail\.com'/, "'admin@example.invalid'");
  try {
    await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
      CREATE TABLE public.usuarios(idusuario uuid PRIMARY KEY, email text, estado text, uidauth text);`);
    await db.exec(fs.readFileSync(path.join(__dirname, '../supabase/migrations/202610140001_multiempresa_base.sql'), 'utf8'));
    await assert.rejects(() => db.exec(seed), /cuenta administradora activa/);
    await db.exec('ROLLBACK');
    assert.equal((await db.query('SELECT count(*)::int AS n FROM empresas')).rows[0].n, 0);
    await db.query("INSERT INTO usuarios VALUES($1,'admin@example.invalid','ACTIVO','auth-ficticio')", [admin]);
    await db.exec(seed);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM empresas')).rows[0].n, 2);
    const members = (await db.query('SELECT idusuario, es_administrador FROM empresa_usuario')).rows;
    assert.equal(members.length, 2);
    assert.ok(members.every(m => m.idusuario === admin && m.es_administrador));
    // Una segunda ejecución no debe reactivar membresías ni crear duplicados.
    await db.exec('UPDATE empresa_usuario SET activa=false');
    await assert.rejects(() => db.exec(seed), /duplicate key/);
    await db.exec('ROLLBACK');
    assert.equal((await db.query('SELECT count(*)::int AS n FROM empresas')).rows[0].n, 2);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM empresa_usuario WHERE activa')).rows[0].n, 0);
  } finally { await db.close(); }
});
