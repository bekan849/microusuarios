const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require('@electric-sql/pglite');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;

test('Migración sobre esquema real: historia conservada y relaciones aisladas', async t => {
  const db = new PGlite();
  try {
    await db.exec(read('tests/fixtures/multiempresa-baseline.sql'));
    await db.query("INSERT INTO usuarios(idusuario,nombre,apellido,email,uidauth) VALUES($1,'Admin','Prueba','admin@example.invalid','auth-ficticio')",[id(1)]);
    await db.exec("INSERT INTO permisos(codigo,nombre,modulo) VALUES('ventas.crear','Crear ventas','ventas'),('ventas.ver','Ver ventas','ventas'),('reportes.ver','Ver reportes','reportes'),('usuarios.crear','Crear usuarios','usuarios')");
    await db.query("INSERT INTO categorias(idcategoria,nombre) VALUES($1,'Accesorios');",[id(2)]);
    await db.query("INSERT INTO marcas(idmarca,nombre) VALUES($1,'Marca');",[id(3)]);
    await db.query("INSERT INTO proveedor(idproveedor,nombre) VALUES($1,'Proveedor');",[id(4)]);
    await db.query("INSERT INTO productos(idproducto,codigoprod,nombre,idcategoria,idmarca,stock,precioventa) VALUES($1,'P001','Casco',$2,$3,5,20)",[id(5),id(2),id(3)]);
    await db.query('INSERT INTO compra(idcompra,idproveedor,idusuario) VALUES($1,$2,$3)',[id(6),id(4),id(1)]);
    await db.query('INSERT INTO detalle_compra(iddetallecompra,idcompra,idproducto,cantidad,preciocosto,stockrestante) VALUES($1,$2,$3,5,10,5)',[id(7),id(6),id(5)]);
    await db.query("UPDATE compra SET estado='COMPLETADA' WHERE idcompra=$1",[id(6)]);
    await db.query('SELECT registrar_venta_completa_atomica(p_payload => $1::jsonb)',[JSON.stringify({idusuario:id(1),items:[{idproducto:id(5),cantidad:1,precioventa:20}]})]);
    await db.query("INSERT INTO historial_acciones(id,servicio,accion,recurso,resultado,estado_http,antes,despues) VALUES($1,'productos','crear','productos','exito',201,'{}','{\"nombre\":\"Casco\"}')",[id(8)]);
    const tables=['productos','compra','detalle_compra','venta','detalle_venta','detalle_venta_lote','historial_acciones'];
    const before={};
    for(const table of tables)before[table]=(await db.query(`SELECT to_jsonb(t) AS row FROM ${table} t ORDER BY to_jsonb(t)::text`)).rows.map(r=>r.row);
    await db.exec(read('supabase/install/MULTIEMPRESA_INSTALAR.sql').replace(/'[^']+@gmail\.com'/,"'admin@example.invalid'"));
    const companies=(await db.query('SELECT codigo,idempresa FROM empresas')).rows;
    const motos=companies.find(e=>e.codigo==='copa-sport-motos').idempresa;
    const bike=companies.find(e=>e.codigo==='copa-sport-bike').idempresa;
    await t.test('Documentos completados, lotes y auditoría conservan todos sus campos',async()=>{
      for(const table of tables){
        const after=(await db.query(`SELECT to_jsonb(t)-'idempresa' AS row FROM ${table} t ORDER BY (to_jsonb(t)-'idempresa')::text`)).rows.map(r=>r.row);
        assert.deepEqual(after,before[table],table);
        assert.equal((await db.query(`SELECT count(*)::int AS n FROM ${table} WHERE idempresa IS DISTINCT FROM $1`,[motos])).rows[0].n,0);
      }
      await assert.rejects(()=>db.query('UPDATE historial_acciones SET detalles=detalles'),/no se puede modificar/);
      await assert.rejects(()=>db.query('UPDATE detalle_venta SET cantidad=cantidad'),/COMPLETADA/);
    });
    await t.test('Bicicletas puede repetir códigos y nombres sin vincular catálogo de motos',async()=>{
      await db.query("INSERT INTO categorias(idcategoria,nombre,idempresa) VALUES($1,'Accesorios',$2)",[id(20),bike]);
      await db.query("INSERT INTO marcas(idmarca,nombre,idempresa) VALUES($1,'Marca',$2)",[id(21),bike]);
      await db.query("INSERT INTO productos(idproducto,codigoprod,nombre,idcategoria,idmarca,idempresa) VALUES($1,'P001','Casco',$2,$3,$4)",[id(22),id(20),id(21),bike]);
      await assert.rejects(()=>db.query('UPDATE productos SET idcategoria=$1 WHERE idproducto=$2',[id(2),id(22)]),/foreign key/);
      await assert.rejects(()=>db.query("INSERT INTO productos(codigoprod,nombre,idcategoria,idmarca) VALUES('P002','Nuevo',$1,$2)",[id(2),id(3)]),/null value/);
    });
    await t.test('Compra y detalle no admiten proveedor o documento de otra empresa',async()=>{
      await assert.rejects(()=>db.query('INSERT INTO compra(idempresa,idproveedor) VALUES($1,$2)',[bike,id(4)]),/foreign key/);
      await db.query("INSERT INTO proveedor(idproveedor,nombre,idempresa) VALUES($1,'Proveedor',$2)",[id(23),bike]);
      await db.query('INSERT INTO compra(idcompra,idempresa,idproveedor) VALUES($1,$2,$3)',[id(24),bike,id(23)]);
      await assert.rejects(()=>db.query('INSERT INTO detalle_compra(idempresa,idcompra,idproducto,cantidad,preciocosto) VALUES($1,$2,$3,1,10)',[motos,id(24),id(5)]),/foreign key/);
    });
    await t.test('Clientes públicos no tienen acceso SQL y RPC antiguas están revocadas',async()=>{
      for(const role of ['anon','authenticated']) {
        await db.exec(`SET ROLE ${role}`);
        try { await assert.rejects(()=>db.query('SELECT * FROM productos_list_view'),/permission denied/); }
        finally { await db.exec('RESET ROLE'); }
      }
      for(const signature of ['registrar_venta_completa_atomica(jsonb)','registrar_venta_completa_atomica(jsonb,timestamptz,uuid)','dashboard_inicial(boolean,boolean)'])
        assert.equal((await db.query("SELECT has_function_privilege('service_role',$1,'EXECUTE') AS allowed",[signature])).rows[0].allowed,false);
    });
    await t.test('Una venta en bicicletas rechaza productos de motos sin crear documentos',async()=>{
      await db.exec('SET ROLE service_role');
      try {
      const before=(await db.query('SELECT count(*)::int AS n FROM venta')).rows[0].n;
      const payload={idusuario:id(99),items:[{idproducto:id(5),cantidad:1,precioventa:20}]};
      await assert.rejects(()=>db.query('SELECT registrar_venta_empresa($1,$2,$3)',[payload,bike,id(1)]),/Producto no encontrado/);
      assert.equal((await db.query('SELECT count(*)::int AS n FROM venta')).rows[0].n,before);
      const sold=(await db.query('SELECT registrar_venta_empresa($1,$2,$3) AS data',[payload,motos,id(1)])).rows[0].data;
      assert.equal(sold.idusuario,id(1));
      assert.equal(Number(sold.total),20);
      assert.equal((await db.query('SELECT stock FROM productos WHERE idproducto=$1',[id(5)])).rows[0].stock,3);
      const dashboard=(await db.query('SELECT dashboard_empresa(true,true,$1,$2) AS data',[bike,id(1)])).rows[0].data;
      assert.equal(Number(dashboard.resumenDia.ventasTotales),0);
      assert.deepEqual(dashboard.productosVendidosHoy,[]);
      } finally { await db.exec('RESET ROLE'); }
    });
    await t.test('Crear un empleado lo incorpora solo a la empresa autorizada',async()=>{
      await db.exec('SET ROLE service_role');
      try {
        const result=await db.query('SELECT registrar_usuario_empresa($1,$2,$3) AS data',[bike,id(1),{nombre:'Empleado',apellido:'Prueba',email:'empleado@example.invalid',uidauth:'auth-empleado'}]);
        const employee=result.rows[0].data.idusuario;
        const memberships=(await db.query('SELECT idempresa FROM empresa_usuario WHERE idusuario=$1',[employee])).rows;
        assert.deepEqual(memberships,[{idempresa:bike}]);
        await assert.rejects(()=>db.query('SELECT obtener_accesos_empresa($1,$2)',[employee,motos]),/Sin acceso/);
      } finally { await db.exec('RESET ROLE'); }
    });
    await t.test('Permisos revocados y membresías suspendidas se aplican en la siguiente operación',async()=>{
      const roles=(await db.query('SELECT obtener_accesos_empresa($1,$2) AS data',[id(1),bike])).rows[0].data;
      assert.ok(roles.permisos.some(p=>p.codigo==='ventas.crear'));
      await db.query("DELETE FROM rol_permiso WHERE idempresa=$1 AND idpermiso=(SELECT idpermiso FROM permisos WHERE codigo='ventas.crear')",[bike]);
      await assert.rejects(()=>db.query('SELECT registrar_venta_empresa($1,$2,$3)',[{items:[]},bike,id(1)]),/Sin permiso/);
      await db.query('UPDATE empresa_usuario SET activa=false WHERE idempresa=$1',[bike]);
      await assert.rejects(()=>db.query('SELECT obtener_accesos_empresa($1,$2)',[id(1),bike]),/Sin acceso/);
      assert.ok((await db.query('SELECT obtener_accesos_empresa($1,$2) AS data',[id(1),motos])).rows[0].data.empresa);
    });
  } finally { await db.close(); }
});

