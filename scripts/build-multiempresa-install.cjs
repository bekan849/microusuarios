// Genera un instalador revisable; NO conecta ni ejecuta SQL en Supabase.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const names = [
  '202610140001_multiempresa_base.sql',
  '202610140002_multiempresa_inicial.sql',
  '202610140003_multiempresa_datos.sql',
  '202610140004_multiempresa_accesos.sql',
  '202610140005_multiempresa_operaciones.sql',
];
const business = ['categorias','marcas','proveedor','productos','compra','detalle_compra','venta','detalle_venta','detalle_venta_lote','historial_acciones'];
const all = [...business,'usuarios','roles','usuario_rol','rol_permiso','permisos'];
const sql = `-- INSTALADOR MULTIEMPRESA. Escritura real, NO ejecutado automáticamente.
-- Leer docs/MULTIEMPRESA_INSTALACION.md. Requiere respaldo y servicios detenidos.
-- Generado por scripts/build-multiempresa-install.cjs; no editar esta copia.
BEGIN;
SET LOCAL lock_timeout = '15s';
LOCK TABLE ${all.map(t=>'public.'+t).join(', ')} IN ACCESS EXCLUSIVE MODE;
CREATE TEMP TABLE multiempresa_recuentos(tabla text PRIMARY KEY, cantidad bigint) ON COMMIT DROP;
${business.map(t=>`INSERT INTO multiempresa_recuentos SELECT '${t}',count(*) FROM public.${t};`).join('\n')}

${names.map(name => `-- ${name}\n` + fs.readFileSync(path.join(root,'supabase/migrations',name),'utf8').replace(/^BEGIN;\r?\n/m,'').replace(/^COMMIT;\s*$/m,'')).join('\n\n')}

DO $$
DECLARE r record; n bigint; ajenos bigint; motos uuid;
BEGIN
  SELECT idempresa INTO STRICT motos FROM public.empresas WHERE codigo='copa-sport-motos';
  FOR r IN SELECT * FROM multiempresa_recuentos LOOP
    EXECUTE format('SELECT count(*), count(*) FILTER (WHERE idempresa IS DISTINCT FROM $1) FROM public.%I',r.tabla) INTO n,ajenos USING motos;
    IF n <> r.cantidad OR ajenos <> 0 THEN
      RAISE EXCEPTION 'No se conservaron los datos originales de %',r.tabla;
    END IF;
  END LOOP;
END;
$$;
NOTIFY pgrst, 'reload schema';
COMMIT;
-- Si llegó aquí sin errores, el cambio está confirmado.
SELECT codigo,nombre,activa FROM public.empresas ORDER BY codigo;
`;
const dest=path.join(root,'supabase/install');
fs.mkdirSync(dest,{recursive:true});
fs.writeFileSync(path.join(dest,'MULTIEMPRESA_INSTALAR.sql'),sql);
console.log('Instalador generado; no se ha ejecutado SQL.');
