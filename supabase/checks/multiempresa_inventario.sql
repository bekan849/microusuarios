-- SOLO LECTURA. Ejecutar completo en SQL Editor del proyecto actual.
-- Una fila JSON con metadatos; no consulta registros comerciales ni auth.users.
-- No contiene instrucciones para crear, actualizar ni borrar datos.
WITH relaciones AS (
  SELECT c.oid, n.nspname AS esquema, c.relname AS nombre,
         c.relkind, c.relrowsecurity AS rls, c.relforcerowsecurity AS rls_forzada
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm')
), columnas AS (
  SELECT r.nombre AS tabla, a.attname AS columna,
         format_type(a.atttypid, a.atttypmod) AS tipo,
         a.attnotnull AS no_nulo, a.attidentity AS identidad,
         a.attgenerated AS generada,
         pg_get_expr(d.adbin, d.adrelid) AS expresion_predeterminada
  FROM relaciones r JOIN pg_attribute a ON a.attrelid = r.oid
  LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  WHERE a.attnum > 0 AND NOT a.attisdropped
  ORDER BY r.nombre, a.attnum
), restricciones AS (
  SELECT r.nombre AS tabla, k.conname AS nombre, k.contype AS tipo,
         pg_get_constraintdef(k.oid) AS definicion,
         k.convalidated AS validada
  FROM relaciones r JOIN pg_constraint k ON k.conrelid = r.oid
  ORDER BY r.nombre, k.conname
), triggers AS (
  SELECT r.nombre AS tabla, t.tgname AS nombre,
         t.tgenabled AS estado, pg_get_triggerdef(t.oid) AS definicion
  FROM relaciones r JOIN pg_trigger t ON t.tgrelid = r.oid
  WHERE NOT t.tgisinternal
  ORDER BY r.nombre, t.tgname
), funciones AS (
  SELECT p.proname AS nombre,
         pg_get_function_identity_arguments(p.oid) AS argumentos,
         pg_get_function_result(p.oid) AS resultado,
         p.prosecdef AS security_definer,
         p.proconfig AS configuracion
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f'
  ORDER BY p.proname, p.oid
)
SELECT jsonb_build_object(
  'relaciones', COALESCE((SELECT jsonb_agg(to_jsonb(r) - 'oid') FROM relaciones r), '[]'::jsonb),
  'columnas', COALESCE((SELECT jsonb_agg(to_jsonb(c)) FROM columnas c), '[]'::jsonb),
  'restricciones', COALESCE((SELECT jsonb_agg(to_jsonb(c)) FROM restricciones c), '[]'::jsonb),
  'triggers', COALESCE((SELECT jsonb_agg(to_jsonb(t)) FROM triggers t), '[]'::jsonb),
  'funciones', COALESCE((SELECT jsonb_agg(to_jsonb(f)) FROM funciones f), '[]'::jsonb),
  'indices', COALESCE((SELECT jsonb_agg(to_jsonb(i)) FROM pg_indexes i WHERE schemaname = 'public'), '[]'::jsonb),
  'politicas', COALESCE((SELECT jsonb_agg(to_jsonb(p)) FROM pg_policies p WHERE schemaname = 'public'), '[]'::jsonb),
  'permisos_tablas', COALESCE((SELECT jsonb_agg(to_jsonb(g)) FROM information_schema.role_table_grants g WHERE table_schema = 'public'), '[]'::jsonb),
  'permisos_funciones', COALESCE((SELECT jsonb_agg(to_jsonb(g)) FROM information_schema.role_routine_grants g WHERE routine_schema = 'public'), '[]'::jsonb)
) AS inventario_multiempresa;
