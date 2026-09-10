const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const {PGlite}=require(process.env.PGLITE_MODULE||'@electric-sql/pglite');
test('History SQL permissions, immutability and repeatable installation',async()=>{
  const db=new PGlite();
  try{
    await db.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;');
    const sql=fs.readFileSync(path.join(__dirname,'../supabase/migrations/202609100001_historial_acciones.sql'),'utf8');
    await db.exec(sql);await db.exec(sql);
    await db.exec("SET ROLE service_role; INSERT INTO historial_acciones(id,servicio,accion,recurso,resultado,estado_http) VALUES('00000000-0000-0000-0000-000000000001','usuarios','iniciar_sesion','auth','exito',200);");
    assert.equal((await db.query('SELECT * FROM historial_acciones')).rows.length,1);
    for(const sql of ['DELETE FROM historial_acciones',"UPDATE historial_acciones SET accion='fake'",'TRUNCATE historial_acciones'])await assert.rejects(()=>db.exec(sql));
    await db.exec('RESET ROLE;');
    await assert.rejects(()=>db.exec('DELETE FROM historial_acciones'),/no se puede/);
    await db.exec('SET ROLE anon;');await assert.rejects(()=>db.query('SELECT * FROM historial_acciones'));
    await db.exec('RESET ROLE; SET ROLE authenticated;');await assert.rejects(()=>db.query('SELECT * FROM historial_acciones'));
    await db.exec('RESET ROLE; CREATE TABLE permisos(idpermiso serial PRIMARY KEY,codigo text,nombre text,modulo text,descripcion text,estado boolean); CREATE TABLE roles(idrol serial PRIMARY KEY,nombre text,estado boolean); CREATE TABLE rol_permiso(idrolpermiso serial PRIMARY KEY,idrol integer,idpermiso integer);');
    await db.exec("INSERT INTO roles(nombre,estado) VALUES('ADMINISTRADOR',true),('VENDEDOR',true);");
    const permission=fs.readFileSync(path.join(__dirname,'../supabase/migrations/202609100002_permiso_auditoria.sql'),'utf8');
    await db.exec(permission);await db.exec(permission);
    assert.equal((await db.query('SELECT * FROM permisos')).rows.length,1);
    assert.equal((await db.query('SELECT * FROM rol_permiso')).rows.length,1);
  }finally{await db.close();}
});
