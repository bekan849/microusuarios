-- Complemento del inventario recibido: solo lectura de definiciones, sin
-- ejecutar las funciones ni leer filas de negocio. Ejecutar en SQL Editor.
-- Revisar el resultado antes de compartirlo por si alguna funcion antigua
-- contiene credenciales escritas literalmente en su codigo.
SELECT jsonb_build_object(
  'funciones', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'nombre', p.proname,
      'argumentos', pg_get_function_identity_arguments(p.oid),
      'definicion', pg_get_functiondef(p.oid)
    ) ORDER BY p.proname, p.oid)
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f'
      AND p.proname IN (
        'cambiar_estado_compra', 'cambiar_estado_venta', 'dashboard_inicial',
        'iniciar_sesion_usuario', 'obtener_accesos_usuario',
        'proteger_historial_acciones', 'recalcular_total_compra',
        'recalcular_total_venta', 'registrar_venta_completa_atomica',
        'set_updated_at', 'trg_bloquear_detalle_compra_si_completada',
        'trg_bloquear_detalle_compra_si_compra_no_pendiente',
        'trg_bloquear_detalle_venta_si_completada',
        'trg_detalle_compra_recalcular_total',
        'trg_detalle_venta_recalcular_total', 'trg_normalizar_permiso',
        'trg_normalizar_rol', 'trg_normalizar_usuario'
      )
  ), '[]'::jsonb),
  'vistas', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'nombre', c.relname, 'definicion', pg_get_viewdef(c.oid, true),
      'opciones', c.reloptions
    ) ORDER BY c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'v'
      AND c.relname IN ('productos_list_view', 'v_usuario_permisos')
  ), '[]'::jsonb),
  'estados', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'tipo', t.typname, 'valor', e.enumlabel, 'orden', e.enumsortorder
    ) ORDER BY t.typname, e.enumsortorder)
    FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE n.nspname = 'public'
      AND t.typname IN ('compra_estado', 'venta_estado', 'producto_estado', 'usuario_estado')
  ), '[]'::jsonb)
) AS definiciones_multiempresa;
