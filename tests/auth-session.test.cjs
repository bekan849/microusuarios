const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');

test('Sesión consolidada conserva roles, permisos y estado del usuario', async t => {
  const db = new PGlite();
  const id = n => `00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
  try {
    await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
      CREATE TABLE usuarios(idusuario uuid PRIMARY KEY, uidauth uuid UNIQUE, email text UNIQUE, nombre text, estado text, ultimo_acceso timestamptz);
      CREATE TABLE roles(idrol uuid PRIMARY KEY, nombre text, descripcion text, estado boolean);
      CREATE TABLE permisos(idpermiso uuid PRIMARY KEY, codigo text, nombre text, modulo text, descripcion text, estado boolean);
      CREATE TABLE usuario_rol(idusuario uuid, idrol uuid, estado boolean);
      CREATE TABLE rol_permiso(idrol uuid, idpermiso uuid);`);
    const migration=fs.readFileSync(path.join(__dirname,'../supabase/migrations/202609070001_optimize_auth_session.sql'),'utf8');
    await db.exec(migration);
    await db.exec(migration); // Aplicación repetida sin duplicar objetos.
    await db.query("INSERT INTO usuarios VALUES($1,NULL,'test@example.invalid','Prueba','ACTIVO',NULL)",[id(1)]);
    await db.query("INSERT INTO roles VALUES($1,'ADMINISTRADOR',NULL,true),($2,'VENTAS',NULL,true),($3,'INACTIVO',NULL,false)",[id(2),id(3),id(4)]);
    await db.query("INSERT INTO permisos VALUES($1,' Ventas.Ver ','Ver','ventas',NULL,true),($2,'ventas.crear','Crear','ventas',NULL,false)",[id(5),id(6)]);
    await db.query('INSERT INTO usuario_rol VALUES($1,$2,true),($1,$3,true),($1,$4,true)',[id(1),id(2),id(3),id(4)]);
    await db.query('INSERT INTO rol_permiso VALUES($1,$3),($2,$3),($2,$4)',[id(2),id(3),id(5),id(6)]);
    await t.test('Login vincula UID y devuelve último acceso actualizado',async()=>{
      const data=(await db.query('SELECT iniciar_sesion_usuario($1,$2) AS data',[id(10),'test@example.invalid'])).rows[0].data;
      assert.equal(data.usuario.uidauth,id(10));assert.ok(data.usuario.ultimo_acceso);
      assert.equal(data.roles.length,2);assert.equal(data.permisos.length,1);assert.equal(data.permisos[0].codigo,'ventas.ver');
    });
    await t.test('UID diferente no toma una cuenta existente por correo',async()=>{
      await assert.rejects(()=>db.query('SELECT iniciar_sesion_usuario($1,$2)',[id(11),'test@example.invalid']),/no coincide/);
    });
    await t.test('Los cambios de permisos se ven en la siguiente consulta',async()=>{
      await db.query('UPDATE usuario_rol SET estado=false WHERE idusuario=$1',[id(1)]);
      const data=(await db.query('SELECT obtener_accesos_usuario($1) AS data',[id(1)])).rows[0].data;
      assert.deepEqual(data.roles,[]);assert.deepEqual(data.permisos,[]);
    });
    await t.test('Usuario bloqueado no obtiene sesión ni modifica el último acceso',async()=>{
      await db.query("UPDATE usuarios SET estado='BLOQUEADO' WHERE idusuario=$1",[id(1)]);
      const before=(await db.query('SELECT * FROM usuarios')).rows;
      await assert.rejects(()=>db.query('SELECT iniciar_sesion_usuario($1,$2)',[id(10),'test@example.invalid']),/no activo/);
      await assert.rejects(()=>db.query('SELECT obtener_accesos_usuario($1)',[id(1)]),/no activo/);
      assert.deepEqual((await db.query('SELECT * FROM usuarios')).rows,before);
    });
    await t.test('Las funciones de sesión solo se conceden al backend',async()=>{
      for(const role of ['anon','authenticated']) assert.equal((await db.query("SELECT has_function_privilege($1,'obtener_accesos_usuario(text)','EXECUTE') AS ok",[role])).rows[0].ok,false);
    });
  } finally { await db.close(); }
});
