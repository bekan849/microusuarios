const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {PGlite}=require('@electric-sql/pglite');
test('Catálogos: estructura, acceso solo backend y empresa obligatoria',async()=>{
  const db=new PGlite();
  try {
    await db.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS; CREATE TABLE empresas(idempresa uuid PRIMARY KEY);');
    await db.exec(fs.readFileSync(path.join(__dirname,'../supabase/migrations/202610250001_catalogos.sql'),'utf8'));
    await db.exec("INSERT INTO empresas VALUES ('00000000-0000-0000-0000-000000000001');");
    await db.exec('SET ROLE service_role');
    await db.exec("INSERT INTO catalogos(idempresa,nombre,configuracion) VALUES ('00000000-0000-0000-0000-000000000001','Cascos','{}');");
    assert.equal((await db.query('SELECT * FROM catalogos')).rows.length,1);
    await assert.rejects(()=>db.exec("INSERT INTO catalogos(nombre,configuracion) VALUES ('Sin empresa','{}')"),/null value/);
    await assert.rejects(()=>db.exec("INSERT INTO catalogos(idempresa,nombre,configuracion) VALUES ('00000000-0000-0000-0000-000000000099','Ajeno','{}')"),/foreign key/);
    await db.exec('RESET ROLE');
    for(const role of ['anon','authenticated']) {
      await db.exec('SET ROLE '+role);
      await assert.rejects(()=>db.query('SELECT * FROM catalogos'),/permission denied/);
      await assert.rejects(()=>db.exec('DELETE FROM catalogos'),/permission denied/);
      await db.exec('RESET ROLE');
    }
  } finally {await db.close();}
});
