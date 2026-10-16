const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require('@electric-sql/pglite');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;

test('Compra atómica con precio al público, permisos y aislamiento', async t => {
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

    await db.exec(read('supabase/migrations/202610160001_compra_precio_publico.sql'));
    await db.exec("INSERT INTO permisos(codigo,nombre,modulo) VALUES('compras.crear','Crear compras','compras'),('productos.editar','Editar productos','productos')");
    await db.exec("INSERT INTO rol_permiso(idempresa,idrol,idpermiso) SELECT r.idempresa,r.idrol,p.idpermiso FROM roles r CROSS JOIN permisos p WHERE p.codigo IN ('compras.crear','productos.editar')");
    const motos=(await db.query("SELECT idempresa FROM empresas WHERE codigo='copa-sport-motos'")).rows[0].idempresa;
    const bike=(await db.query("SELECT idempresa FROM empresas WHERE codigo='copa-sport-bike'")).rows[0].idempresa;
    const payload={idproveedor:id(4),idusuario:id(99),items:[{idproducto:id(5),cantidad:3,preciocosto:10,precioventa:25,precioventa_anterior:20}]};
    const snapshot=async()=>({products:(await db.query('SELECT * FROM productos ORDER BY idproducto')).rows,compra:(await db.query('SELECT * FROM compra ORDER BY idcompra')).rows,details:(await db.query('SELECT * FROM detalle_compra ORDER BY iddetallecompra')).rows,audit:(await db.query('SELECT * FROM historial_acciones ORDER BY id')).rows});
    await t.test('Compra, stock, lotes y precio se guardan juntos y se audita el cambio',async()=>{
      await db.exec('SET ROLE service_role');
      try {
        const result=(await db.query('SELECT registrar_compra_empresa($1,$2,$3) AS data',[payload,motos,id(1)])).rows[0].data;
        assert.equal(result.idusuario,id(1));assert.equal(result.estado,'COMPLETADA');assert.equal(Number(result.total),30);
        const product=(await db.query('SELECT stock,precioventa FROM productos WHERE idproducto=$1',[id(5)])).rows[0];
        assert.equal(product.stock,7);assert.equal(Number(product.precioventa),25);
        const audit=(await db.query("SELECT antes,despues FROM historial_acciones WHERE recurso='productos' AND accion='actualizar'")).rows[0];
        assert.equal(audit.antes.precioventa,20);assert.equal(audit.despues.precioventa,25);
      } finally {await db.exec('RESET ROLE');}
    });
    await t.test('Un precio desactualizado revierte toda la nueva compra',async()=>{
      const before=await snapshot();
      await assert.rejects(()=>db.query('SELECT registrar_compra_empresa($1,$2,$3)',[payload,motos,id(1)]),/cambió en otra/);
      assert.deepEqual(await snapshot(),before);
    });
    await t.test('Proveedor ajeno, producto ajeno y duplicados no dejan registros',async()=>{
      const before=await snapshot();
      await assert.rejects(()=>db.query('SELECT registrar_compra_empresa($1,$2,$3)',[payload,bike,id(1)]),/Proveedor no disponible/);
      await assert.rejects(()=>db.query('SELECT registrar_compra_empresa($1,$2,$3)',[{...payload,items:[payload.items[0],payload.items[0]]},motos,id(1)]),/repetidos/);
      await db.query("INSERT INTO proveedor(idproveedor,nombre,idempresa) VALUES($1,'Bike proveedor',$2)",[id(23),bike]);
      await assert.rejects(()=>db.query('SELECT registrar_compra_empresa($1,$2,$3)',[{...payload,idproveedor:id(23)},bike,id(1)]),/Producto no disponible/);
      assert.deepEqual(await snapshot(),before);
    });
    await t.test('Sin permiso de editar se permite comprar, pero no cambiar precio',async()=>{
      await db.query("DELETE FROM rol_permiso WHERE idempresa=$1 AND idpermiso=(SELECT idpermiso FROM permisos WHERE codigo='productos.editar')",[motos]);
      const before=await snapshot();
      await assert.rejects(()=>db.query('SELECT registrar_compra_empresa($1,$2,$3)',[{...payload,items:[{...payload.items[0],precioventa_anterior:25}]},motos,id(1)]),/Sin permiso/);
      assert.deepEqual(await snapshot(),before);
      await db.query('SELECT registrar_compra_empresa($1,$2,$3)',[{...payload,items:[{idproducto:id(5),cantidad:1,preciocosto:8}]},motos,id(1)]);
      assert.equal(Number((await db.query('SELECT precioventa FROM productos WHERE idproducto=$1',[id(5)])).rows[0].precioventa),25);
    });
    await t.test('Error tardío en otro producto revierte compra y stock',async()=>{
      const before=await snapshot();
      await assert.rejects(()=>db.query('SELECT registrar_compra_empresa($1,$2,$3)',[{...payload,items:[{idproducto:id(5),cantidad:2,preciocosto:10},{idproducto:id(999),cantidad:2,preciocosto:8}]},motos,id(1)]),/Producto no disponible/);
      assert.deepEqual(await snapshot(),before);
    });
    await t.test('RPC no disponible a clientes públicos',async()=>{
      for(const role of ['anon','authenticated'])assert.equal((await db.query("SELECT has_function_privilege($1,'registrar_compra_empresa(jsonb,uuid,uuid)','EXECUTE') AS allowed",[role])).rows[0].allowed,false);
    });
  } finally {await db.close();}
});
