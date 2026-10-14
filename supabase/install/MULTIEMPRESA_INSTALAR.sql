-- INSTALADOR MULTIEMPRESA. Escritura real, NO ejecutado automáticamente.
-- Leer docs/MULTIEMPRESA_INSTALACION.md. Requiere respaldo y servicios detenidos.
-- Generado por scripts/build-multiempresa-install.cjs; no editar esta copia.
BEGIN;
SET LOCAL lock_timeout = '15s';
LOCK TABLE public.categorias, public.marcas, public.proveedor, public.productos, public.compra, public.detalle_compra, public.venta, public.detalle_venta, public.detalle_venta_lote, public.historial_acciones, public.usuarios, public.roles, public.usuario_rol, public.rol_permiso, public.permisos IN ACCESS EXCLUSIVE MODE;
CREATE TEMP TABLE multiempresa_recuentos(tabla text PRIMARY KEY, cantidad bigint) ON COMMIT DROP;
INSERT INTO multiempresa_recuentos SELECT 'categorias',count(*) FROM public.categorias;
INSERT INTO multiempresa_recuentos SELECT 'marcas',count(*) FROM public.marcas;
INSERT INTO multiempresa_recuentos SELECT 'proveedor',count(*) FROM public.proveedor;
INSERT INTO multiempresa_recuentos SELECT 'productos',count(*) FROM public.productos;
INSERT INTO multiempresa_recuentos SELECT 'compra',count(*) FROM public.compra;
INSERT INTO multiempresa_recuentos SELECT 'detalle_compra',count(*) FROM public.detalle_compra;
INSERT INTO multiempresa_recuentos SELECT 'venta',count(*) FROM public.venta;
INSERT INTO multiempresa_recuentos SELECT 'detalle_venta',count(*) FROM public.detalle_venta;
INSERT INTO multiempresa_recuentos SELECT 'detalle_venta_lote',count(*) FROM public.detalle_venta_lote;
INSERT INTO multiempresa_recuentos SELECT 'historial_acciones',count(*) FROM public.historial_acciones;

-- 202610140001_multiempresa_base.sql
-- Fase 1: estructura aditiva. No habilita todavía aislamiento del negocio.
-- Aplicar únicamente como parte del despliegue multiempresa coordinado.

CREATE TABLE public.empresas (
  idempresa uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo text NOT NULL UNIQUE CHECK (codigo ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  nombre text NOT NULL CHECK (length(trim(nombre)) > 0),
  activa boolean NOT NULL DEFAULT true,
  creado_en timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.empresa_usuario (
  idempresa uuid NOT NULL REFERENCES public.empresas(idempresa) ON DELETE RESTRICT,
  idusuario uuid NOT NULL REFERENCES public.usuarios(idusuario) ON DELETE RESTRICT,
  activa boolean NOT NULL DEFAULT true,
  es_administrador boolean NOT NULL DEFAULT false,
  creado_en timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (idempresa, idusuario)
);
CREATE INDEX empresa_usuario_usuario_idx ON public.empresa_usuario(idusuario, idempresa);

ALTER TABLE public.empresas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.empresa_usuario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.empresas, public.empresa_usuario FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.empresas, public.empresa_usuario TO service_role;

-- El backend debe pasar la identidad de su sesión verificada, nunca del body.
-- Invocación limitada al backend: no es una RPC pública de autenticación.
CREATE FUNCTION public.listar_empresas_usuario(p_idusuario uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.idusuario = p_idusuario AND u.estado = 'ACTIVO'
  ) THEN
    RAISE EXCEPTION 'Usuario no activo' USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'idempresa', e.idempresa, 'codigo', e.codigo, 'nombre', e.nombre,
      'esAdministrador', m.es_administrador
    ) ORDER BY e.nombre, e.idempresa), '[]'::jsonb)
    FROM public.empresas e JOIN public.empresa_usuario m USING (idempresa)
    WHERE m.idusuario = p_idusuario AND m.activa AND e.activa
  );
END;
$$;
REVOKE ALL ON FUNCTION public.listar_empresas_usuario(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.listar_empresas_usuario(uuid) TO service_role;


-- 202610140002_multiempresa_inicial.sql
-- PREPARADO, NO APLICAR TODAVIA EN PRODUCCION.
-- Ejecutar después de la migración base, como parte del despliegue coordinado.
-- No asigna ni altera productos, compras, ventas, roles o historial.
DO $$
DECLARE
  v_usuario uuid;
  v_coincidencias integer;
BEGIN
  SELECT count(*), (array_agg(idusuario))[1] INTO v_coincidencias, v_usuario
  FROM public.usuarios
  WHERE lower(trim(email)) = 'bekanbk1@gmail.com'
    AND estado = 'ACTIVO' AND nullif(trim(uidauth::text), '') IS NOT NULL;
  IF v_coincidencias <> 1 THEN
    RAISE EXCEPTION 'Se requiere exactamente una cuenta administradora activa y vinculada';
  END IF;
  -- No sobrescribir instalaciones anteriores ni reactivar accesos revocados.
  INSERT INTO public.empresas(codigo, nombre) VALUES
    ('copa-sport-motos', 'COPA SPORT MOTOS'),
    ('copa-sport-bike', 'COPA SPORT BIKE');
  INSERT INTO public.empresa_usuario(idempresa, idusuario, es_administrador)
  SELECT idempresa, v_usuario, true FROM public.empresas
  WHERE codigo IN ('copa-sport-motos', 'copa-sport-bike');
END;
$$;


-- 202610140003_multiempresa_datos.sql
-- Pendiente de despliegue coordinado. Requiere base y preparación de empresas.
DO $$
DECLARE v_motos uuid; v_tabla text;
BEGIN
  SELECT idempresa INTO STRICT v_motos FROM public.empresas WHERE codigo = 'copa-sport-motos';
  -- El valor constante asigna los datos preexistentes sin UPDATE ni triggers
  -- de negocio. Se elimina el DEFAULT: nuevas operaciones deben indicar empresa.
  FOREACH v_tabla IN ARRAY ARRAY['categorias','marcas','proveedor','productos',
    'compra','detalle_compra','venta','detalle_venta','detalle_venta_lote',
    'roles','usuario_rol','rol_permiso','historial_acciones'] LOOP
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN idempresa uuid NOT NULL DEFAULT %L::uuid REFERENCES public.empresas(idempresa)', v_tabla, v_motos);
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN idempresa DROP DEFAULT', v_tabla);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', v_tabla);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated', v_tabla);
    EXECUTE format('CREATE INDEX %I ON public.%I (idempresa)', v_tabla || '_empresa_idx', v_tabla);
  END LOOP;
  -- Las cuentas conservan su identidad global y el acceso anterior a motos.
  INSERT INTO public.empresa_usuario(idempresa,idusuario)
  SELECT v_motos, idusuario FROM public.usuarios
  ON CONFLICT (idempresa,idusuario) DO NOTHING;
END;
$$;

-- Los eventos de autenticación anteriores a elegir empresa son globales y no
-- deben aparecer en la consulta del historial de otra empresa.
ALTER TABLE public.historial_acciones ALTER COLUMN idempresa DROP NOT NULL;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permisos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.usuarios, public.permisos FROM PUBLIC, anon, authenticated;

ALTER TABLE public.roles DROP CONSTRAINT roles_nombre_key;
CREATE UNIQUE INDEX roles_empresa_nombre_key ON public.roles(idempresa, upper(trim(nombre)));
ALTER TABLE public.productos DROP CONSTRAINT productos_codigoprod_key;
DROP INDEX public.ux_productos_codigoprod;
CREATE UNIQUE INDEX ux_productos_codigoprod ON public.productos(idempresa, upper(codigoprod));
DROP INDEX public.ux_productos_nombre_categoria_marca;
CREATE UNIQUE INDEX ux_productos_nombre_categoria_marca ON public.productos(idempresa, lower(nombre), idcategoria, idmarca);
DROP INDEX public.ux_categorias_nombre;
CREATE UNIQUE INDEX ux_categorias_nombre ON public.categorias(idempresa, lower(nombre));
DROP INDEX public.ux_marcas_nombre;
CREATE UNIQUE INDEX ux_marcas_nombre ON public.marcas(idempresa, lower(nombre));
DROP INDEX public.ux_proveedor_nombre;
CREATE UNIQUE INDEX ux_proveedor_nombre ON public.proveedor(idempresa, lower(nombre));

ALTER TABLE public.categorias ADD UNIQUE(idempresa,idcategoria);
ALTER TABLE public.marcas ADD UNIQUE(idempresa,idmarca);
ALTER TABLE public.proveedor ADD UNIQUE(idempresa,idproveedor);
ALTER TABLE public.productos ADD UNIQUE(idempresa,idproducto);
ALTER TABLE public.compra ADD UNIQUE(idempresa,idcompra);
ALTER TABLE public.venta ADD UNIQUE(idempresa,idventa);
ALTER TABLE public.detalle_compra ADD UNIQUE(idempresa,iddetallecompra,idproducto);
ALTER TABLE public.detalle_venta ADD UNIQUE(idempresa,iddetalleventa,idproducto);
ALTER TABLE public.roles ADD UNIQUE(idempresa,idrol);

-- Sustituir las relaciones originales evita ambigüedad de embeds PostgREST.
ALTER TABLE public.productos DROP CONSTRAINT productos_idcategoria_fkey,
  ADD CONSTRAINT productos_idcategoria_fkey FOREIGN KEY(idempresa,idcategoria) REFERENCES public.categorias(idempresa,idcategoria) ON DELETE RESTRICT,
  DROP CONSTRAINT productos_idmarca_fkey,
  ADD CONSTRAINT productos_idmarca_fkey FOREIGN KEY(idempresa,idmarca) REFERENCES public.marcas(idempresa,idmarca) ON DELETE RESTRICT;
ALTER TABLE public.compra DROP CONSTRAINT compra_idproveedor_fkey,
  ADD CONSTRAINT compra_idproveedor_fkey FOREIGN KEY(idempresa,idproveedor) REFERENCES public.proveedor(idempresa,idproveedor) ON DELETE RESTRICT,
  ADD CONSTRAINT compra_membresia_fkey FOREIGN KEY(idempresa,idusuario) REFERENCES public.empresa_usuario(idempresa,idusuario);
ALTER TABLE public.venta ADD CONSTRAINT venta_membresia_fkey FOREIGN KEY(idempresa,idusuario) REFERENCES public.empresa_usuario(idempresa,idusuario);
ALTER TABLE public.detalle_compra DROP CONSTRAINT detalle_compra_idcompra_fkey,
  ADD CONSTRAINT detalle_compra_idcompra_fkey FOREIGN KEY(idempresa,idcompra) REFERENCES public.compra(idempresa,idcompra) ON DELETE CASCADE,
  DROP CONSTRAINT detalle_compra_idproducto_fkey,
  ADD CONSTRAINT detalle_compra_idproducto_fkey FOREIGN KEY(idempresa,idproducto) REFERENCES public.productos(idempresa,idproducto) ON DELETE RESTRICT;
ALTER TABLE public.detalle_venta DROP CONSTRAINT detalle_venta_idventa_fkey,
  ADD CONSTRAINT detalle_venta_idventa_fkey FOREIGN KEY(idempresa,idventa) REFERENCES public.venta(idempresa,idventa) ON DELETE CASCADE,
  DROP CONSTRAINT detalle_venta_idproducto_fkey,
  ADD CONSTRAINT detalle_venta_idproducto_fkey FOREIGN KEY(idempresa,idproducto) REFERENCES public.productos(idempresa,idproducto) ON DELETE RESTRICT;
ALTER TABLE public.detalle_venta_lote DROP CONSTRAINT detalle_venta_lote_iddetallecompra_fkey,
  ADD CONSTRAINT detalle_venta_lote_iddetallecompra_fkey FOREIGN KEY(idempresa,iddetallecompra,idproducto) REFERENCES public.detalle_compra(idempresa,iddetallecompra,idproducto),
  DROP CONSTRAINT detalle_venta_lote_iddetalleventa_fkey,
  ADD CONSTRAINT detalle_venta_lote_iddetalleventa_fkey FOREIGN KEY(idempresa,iddetalleventa,idproducto) REFERENCES public.detalle_venta(idempresa,iddetalleventa,idproducto) ON DELETE CASCADE,
  DROP CONSTRAINT detalle_venta_lote_idproducto_fkey,
  ADD CONSTRAINT detalle_venta_lote_idproducto_fkey FOREIGN KEY(idempresa,idproducto) REFERENCES public.productos(idempresa,idproducto);
ALTER TABLE public.usuario_rol DROP CONSTRAINT fk_usuario_rol_rol,
  ADD CONSTRAINT fk_usuario_rol_rol FOREIGN KEY(idempresa,idrol) REFERENCES public.roles(idempresa,idrol) ON DELETE RESTRICT,
  ADD CONSTRAINT usuario_rol_membresia_fkey FOREIGN KEY(idempresa,idusuario) REFERENCES public.empresa_usuario(idempresa,idusuario);
ALTER TABLE public.rol_permiso DROP CONSTRAINT fk_rol_permiso_rol,
  ADD CONSTRAINT fk_rol_permiso_rol FOREIGN KEY(idempresa,idrol) REFERENCES public.roles(idempresa,idrol) ON DELETE RESTRICT;

CREATE OR REPLACE VIEW public.productos_list_view WITH (security_invoker=true) AS
SELECT p.idproducto,p.codigoprod,p.nombre,p.descripcion,p.stock,p.urlimagen,
  p.precioventa,p.preciomayor,p.estado,p.creado_en,p.idcategoria,p.idmarca,
  c.nombre AS categoria_nombre,m.nombre AS marca_nombre,p.idempresa
FROM public.productos p LEFT JOIN public.categorias c ON c.idcategoria=p.idcategoria AND c.idempresa=p.idempresa
LEFT JOIN public.marcas m ON m.idmarca=p.idmarca AND m.idempresa=p.idempresa;
CREATE OR REPLACE VIEW public.v_usuario_permisos WITH (security_invoker=true) AS
SELECT u.idusuario,u.nombre,u.apellido,u.email,r.idrol,r.nombre AS rol,
  p.idpermiso,p.codigo AS permiso_codigo,p.nombre AS permiso_nombre,p.modulo,r.idempresa
FROM public.usuarios u
JOIN public.usuario_rol ur ON ur.idusuario=u.idusuario AND ur.estado
JOIN public.empresa_usuario eu ON eu.idempresa=ur.idempresa AND eu.idusuario=u.idusuario AND eu.activa
JOIN public.empresas e ON e.idempresa=eu.idempresa AND e.activa
JOIN public.roles r ON r.idrol=ur.idrol AND r.idempresa=ur.idempresa AND r.estado
JOIN public.rol_permiso rp ON rp.idrol=r.idrol AND rp.idempresa=r.idempresa
JOIN public.permisos p ON p.idpermiso=rp.idpermiso AND p.estado
WHERE u.estado='ACTIVO';
REVOKE ALL ON public.productos_list_view,public.v_usuario_permisos FROM PUBLIC,anon,authenticated;

-- Cerrar entradas antiguas antes de habilitar la segunda empresa. Los nuevos
-- servicios usarán RPC específicas; no debe haber respaldo a estas versiones.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.registrar_venta_completa_atomica(jsonb),
  public.registrar_venta_completa_atomica(jsonb,timestamptz,uuid),
  public.cambiar_estado_compra(uuid,public.compra_estado),
  public.cambiar_estado_venta(uuid,public.venta_estado),
  public.dashboard_inicial(boolean,boolean)
FROM service_role;


-- 202610140004_multiempresa_accesos.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.roles WHERE upper(trim(nombre))='ADMINISTRADOR' AND NOT estado) THEN
    RAISE EXCEPTION 'Existe un rol ADMINISTRADOR inactivo; revisar sus accesos antes de migrar';
  END IF;
END;
$$;
INSERT INTO public.roles(idempresa,nombre,descripcion)
SELECT e.idempresa,'ADMINISTRADOR','Administración de la empresa'
FROM public.empresas e WHERE NOT EXISTS (
  SELECT 1 FROM public.roles r WHERE r.idempresa=e.idempresa AND upper(trim(r.nombre))='ADMINISTRADOR'
);
INSERT INTO public.usuario_rol(idempresa,idusuario,idrol)
SELECT m.idempresa,m.idusuario,r.idrol FROM public.empresa_usuario m
JOIN public.roles r ON r.idempresa=m.idempresa AND upper(trim(r.nombre))='ADMINISTRADOR'
WHERE m.es_administrador
ON CONFLICT(idusuario,idrol) DO NOTHING;
INSERT INTO public.rol_permiso(idempresa,idrol,idpermiso)
SELECT r.idempresa,r.idrol,p.idpermiso FROM public.roles r CROSS JOIN public.permisos p
WHERE upper(trim(r.nombre))='ADMINISTRADOR' AND p.estado
ON CONFLICT(idrol,idpermiso) DO NOTHING;

CREATE FUNCTION public.obtener_accesos_empresa(p_idusuario uuid,p_idempresa uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE v_usuario public.usuarios%ROWTYPE; v_empresa public.empresas%ROWTYPE;
  v_roles jsonb; v_permisos jsonb;
BEGIN
  SELECT * INTO v_usuario FROM public.usuarios WHERE idusuario=p_idusuario AND estado='ACTIVO';
  IF NOT FOUND THEN RAISE EXCEPTION 'Usuario no activo' USING ERRCODE='42501'; END IF;
  SELECT e.* INTO v_empresa FROM public.empresas e JOIN public.empresa_usuario m USING(idempresa)
  WHERE e.idempresa=p_idempresa AND e.activa AND m.idusuario=p_idusuario AND m.activa;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sin acceso a la empresa' USING ERRCODE='42501'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.nombre,r.idrol),'[]'::jsonb) INTO v_roles FROM (
    SELECT DISTINCT r.idrol,r.nombre,r.descripcion FROM public.roles r
    JOIN public.usuario_rol ur ON ur.idempresa=r.idempresa AND ur.idrol=r.idrol
    WHERE r.idempresa=p_idempresa AND ur.idusuario=p_idusuario AND ur.estado AND r.estado
  ) r;
  SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.codigo,p.idpermiso),'[]'::jsonb) INTO v_permisos FROM (
    SELECT DISTINCT p.idpermiso,p.codigo,p.nombre,p.modulo,p.descripcion FROM public.permisos p
    JOIN public.rol_permiso rp ON rp.idpermiso=p.idpermiso
    JOIN public.roles r ON r.idrol=rp.idrol AND r.idempresa=rp.idempresa AND r.estado
    JOIN public.usuario_rol ur ON ur.idrol=r.idrol AND ur.idempresa=r.idempresa AND ur.estado
    WHERE r.idempresa=p_idempresa AND ur.idusuario=p_idusuario AND p.estado
      AND p.codigo NOT IN ('permisos.crear','permisos.editar','permisos.eliminar')
  ) p;
  RETURN jsonb_build_object('usuario',to_jsonb(v_usuario),'empresa',to_jsonb(v_empresa),'roles',v_roles,'permisos',v_permisos);
END;
$$;
REVOKE ALL ON FUNCTION public.obtener_accesos_empresa(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_accesos_empresa(uuid,uuid) TO service_role;

CREATE FUNCTION public.iniciar_sesion_multiempresa(p_uidauth text,p_email text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE v_sesion jsonb; v_empresas jsonb;
BEGIN
  v_sesion := public.iniciar_sesion_usuario(p_uidauth,p_email);
  v_empresas := public.listar_empresas_usuario((v_sesion->'usuario'->>'idusuario')::uuid);
  IF jsonb_array_length(v_empresas)=0 THEN RAISE EXCEPTION 'No tienes empresas habilitadas' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('usuario',v_sesion->'usuario','roles','[]'::jsonb,'permisos','[]'::jsonb,'empresas',v_empresas);
END;
$$;
REVOKE ALL ON FUNCTION public.iniciar_sesion_multiempresa(text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.iniciar_sesion_multiempresa(text,text) TO service_role;

CREATE FUNCTION public.registrar_usuario_empresa(p_idempresa uuid,p_actor uuid,p_usuario jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE v_accesos jsonb; v_usuario public.usuarios%ROWTYPE;
BEGIN
  v_accesos:=public.obtener_accesos_empresa(p_actor,p_idempresa);
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_accesos->'permisos') p WHERE p->>'codigo'='usuarios.crear') THEN
    RAISE EXCEPTION 'Sin permiso para crear usuarios' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.usuarios(uidauth,nombre,apellido,email,telefono,direccion)
  VALUES(p_usuario->>'uidauth',p_usuario->>'nombre',p_usuario->>'apellido',p_usuario->>'email',p_usuario->>'telefono',p_usuario->>'direccion')
  RETURNING * INTO v_usuario;
  INSERT INTO public.empresa_usuario(idempresa,idusuario) VALUES(p_idempresa,v_usuario.idusuario);
  RETURN to_jsonb(v_usuario);
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_usuario_empresa(uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_usuario_empresa(uuid,uuid,jsonb) TO service_role;


-- 202610140005_multiempresa_operaciones.sql
-- RPC aisladas derivadas de las definiciones verificadas en Supabase.
CREATE FUNCTION public.exigir_permiso_empresa(p_idusuario uuid,p_idempresa uuid,p_permiso text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE v_accesos jsonb;
BEGIN
 v_accesos := public.obtener_accesos_empresa(p_idusuario,p_idempresa);
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_accesos->'permisos') p WHERE p->>'codigo'=p_permiso) THEN
  RAISE EXCEPTION 'Sin permiso para la operación' USING ERRCODE='42501';
 END IF;
END;
$$;
CREATE OR REPLACE FUNCTION public.registrar_venta_empresa(p_payload jsonb, p_idempresa uuid, p_idusuario uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_item jsonb;
  v_items jsonb;
  v_input public.detalle_venta%ROWTYPE;
  v_producto public.productos%ROWTYPE;
  v_venta public.venta%ROWTYPE;
  v_detalle public.detalle_venta%ROWTYPE;
  v_lote public.detalle_compra%ROWTYPE;
  v_restante numeric;
  v_consumir numeric;
  v_disponible numeric;
  v_precio numeric;
  v_cantidad numeric;
  v_total numeric := 0;
  v_ids text[] := ARRAY[]::text[];
BEGIN
  PERFORM public.exigir_permiso_empresa(p_idusuario,p_idempresa,'ventas.crear');
  IF jsonb_typeof(p_payload) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Venta inválida'; END IF;
  v_items := p_payload->'items';
  IF jsonb_typeof(v_items) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'La venta debe tener al menos un item'; END IF;
  IF jsonb_array_length(v_items) = 0 THEN RAISE EXCEPTION 'La venta debe tener al menos un item'; END IF;

  -- Validar números ANTES de convertir al tipo de columna (un integer redondearía).
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' OR NULLIF(trim(v_item->>'idproducto'), '') IS NULL THEN
      RAISE EXCEPTION 'idproducto es obligatorio';
    END IF;
    IF jsonb_typeof(v_item->'cantidad') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'cantidad inválida'; END IF;
    v_cantidad := (v_item->>'cantidad')::numeric;
    IF v_cantidad <= 0 OR v_cantidad <> trunc(v_cantidad) OR v_cantidad > 9007199254740991 THEN
      RAISE EXCEPTION 'cantidad debe ser un entero positivo';
    END IF;
    IF jsonb_typeof(v_item->'precioventa') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'precioventa inválido'; END IF;
    IF (v_item->>'precioventa')::numeric < 0 THEN RAISE EXCEPTION 'precioventa inválido'; END IF;
    v_input := jsonb_populate_record(NULL::public.detalle_venta, v_item);
    IF v_input.idproducto::text = ANY(v_ids) THEN RAISE EXCEPTION 'No se permiten productos repetidos'; END IF;
    v_ids := array_append(v_ids, v_input.idproducto::text);
  END LOOP;

  -- Orden estable: dos ventas con los mismos productos adquieren los bloqueos
  -- en el mismo orden, aunque los artículos lleguen ordenados de forma diferente.
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) ORDER BY lower(value->>'idproducto') LOOP
    v_input := jsonb_populate_record(NULL::public.detalle_venta, v_item);
    SELECT * INTO v_producto FROM public.productos WHERE idempresa = p_idempresa AND idproducto = v_input.idproducto FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Producto no encontrado'; END IF;
    IF v_producto.estado IS DISTINCT FROM 'ACTIVO' THEN RAISE EXCEPTION 'Solo se pueden vender productos activos'; END IF;
    IF v_producto.stock IS NULL OR v_producto.stock < v_input.cantidad THEN RAISE EXCEPTION 'Stock insuficiente del producto %', v_producto.idproducto; END IF;
  END LOOP;

  v_venta := jsonb_populate_record(NULL::public.venta, p_payload - 'items');
  INSERT INTO public.venta (idempresa, fechaventa, idusuario, estado, total)
  VALUES (p_idempresa, COALESCE(v_venta.fechaventa, now()), p_idusuario, 'PENDIENTE', 0)
  RETURNING * INTO v_venta;

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_items) ORDER BY lower(value->>'idproducto') LOOP
    v_input := jsonb_populate_record(NULL::public.detalle_venta, v_item);
    v_restante := v_input.cantidad;
    v_precio := v_input.precioventa;
    v_disponible := 0;

    -- Nunca consumir lotes pendientes o cancelados. Se bloquean también sus
    -- compras para que el estado no cambie mientras se procesa esta operación.
    FOR v_lote IN
      SELECT dc.* FROM public.detalle_compra dc JOIN public.compra c ON c.idcompra = dc.idcompra
      WHERE dc.idempresa = p_idempresa AND c.idempresa = p_idempresa AND dc.idproducto = v_input.idproducto AND dc.stockrestante > 0 AND c.estado = 'COMPLETADA'
      ORDER BY dc.creado_en, dc.iddetallecompra FOR UPDATE OF dc, c
    LOOP
      v_disponible := v_disponible + v_lote.stockrestante;
    END LOOP;
    IF v_disponible < v_restante THEN RAISE EXCEPTION 'Stock insuficiente en los lotes del producto %', v_input.idproducto; END IF;

    INSERT INTO public.detalle_venta (idempresa, idventa, idproducto, cantidad, precioventa)
    VALUES (p_idempresa, v_venta.idventa, v_input.idproducto, v_input.cantidad, v_precio)
    RETURNING * INTO v_detalle;

    FOR v_lote IN
      SELECT dc.* FROM public.detalle_compra dc JOIN public.compra c ON c.idcompra = dc.idcompra
      WHERE dc.idempresa = p_idempresa AND c.idempresa = p_idempresa AND dc.idproducto = v_input.idproducto AND dc.stockrestante > 0 AND c.estado = 'COMPLETADA'
      ORDER BY dc.creado_en, dc.iddetallecompra
    LOOP
      EXIT WHEN v_restante <= 0;
      v_consumir := least(v_restante, v_lote.stockrestante);
      IF v_lote.preciocosto IS NULL OR v_precio < v_lote.preciocosto THEN
        RAISE EXCEPTION 'El precio de venta no puede ser menor al precio de compra';
      END IF;
      UPDATE public.detalle_compra SET stockrestante = stockrestante - v_consumir WHERE idempresa = p_idempresa AND iddetallecompra = v_lote.iddetallecompra;
      INSERT INTO public.detalle_venta_lote (idempresa, iddetalleventa, iddetallecompra, idproducto, cantidad, preciocosto, subtotalcosto)
      VALUES (p_idempresa, v_detalle.iddetalleventa, v_lote.iddetallecompra, v_input.idproducto, v_consumir, v_lote.preciocosto, v_consumir * v_lote.preciocosto);
      v_restante := v_restante - v_consumir;
    END LOOP;
    IF v_restante <> 0 THEN RAISE EXCEPTION 'No se pudo consumir completamente el stock'; END IF;
    UPDATE public.productos SET stock = stock - v_input.cantidad,
      estado = (jsonb_populate_record(NULL::public.productos, jsonb_build_object(
        'estado', CASE WHEN stock - v_input.cantidad > 0 THEN 'ACTIVO' ELSE 'INACTIVO' END))).estado
    WHERE idempresa = p_idempresa AND idproducto = v_input.idproducto;
    v_total := v_total + COALESCE(v_detalle.subtotal, v_input.cantidad * v_precio);
  END LOOP;
  UPDATE public.venta SET total = v_total, estado = 'COMPLETADA' WHERE idempresa = p_idempresa AND idventa = v_venta.idventa RETURNING * INTO v_venta;
  RETURN jsonb_build_object('idventa', v_venta.idventa, 'fechaventa', v_venta.fechaventa,
    'estado', v_venta.estado, 'total', v_venta.total, 'creado_en', v_venta.creado_en, 'idusuario', v_venta.idusuario);
END;
$function$
;
CREATE OR REPLACE FUNCTION public.dashboard_empresa(p_reportes boolean, p_ventas boolean, p_idempresa uuid, p_idusuario uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_hoy date := (now() AT TIME ZONE 'America/La_Paz')::date;
  v_dia timestamptz;
  v_mes timestamptz;
  v_anio timestamptz;
  v_fin timestamptz;
  v_datos jsonb := '{}'::jsonb;
  v_resumen jsonb;
  v_series jsonb;
  v_recientes jsonb;
  v_accesos jsonb;
BEGIN
  v_accesos := public.obtener_accesos_empresa(p_idusuario,p_idempresa);
  p_reportes := p_reportes AND EXISTS(SELECT 1 FROM jsonb_array_elements(v_accesos->'permisos') p WHERE p->>'codigo'='reportes.ver');
  p_ventas := p_ventas AND EXISTS(SELECT 1 FROM jsonb_array_elements(v_accesos->'permisos') p WHERE p->>'codigo'='ventas.ver');
  v_dia := v_hoy::timestamp AT TIME ZONE 'America/La_Paz';
  v_mes := date_trunc('month', v_hoy::timestamp) AT TIME ZONE 'America/La_Paz';
  v_anio := date_trunc('year', v_hoy::timestamp) AT TIME ZONE 'America/La_Paz';
  v_fin := (v_hoy + 1)::timestamp AT TIME ZONE 'America/La_Paz';
  IF p_reportes THEN
    WITH ventas AS MATERIALIZED (
      SELECT v.idventa, v.fechaventa, v.total, COALESCE(sum(l.subtotalcosto),0) AS costo
      FROM public.venta v LEFT JOIN public.detalle_venta d ON d.idventa = v.idventa
      LEFT JOIN public.detalle_venta_lote l ON l.iddetalleventa = d.iddetalleventa
      WHERE v.idempresa = p_idempresa AND v.estado = 'COMPLETADA' AND v.fechaventa >= v_anio AND v.fechaventa < v_fin
      GROUP BY v.idventa, v.fechaventa, v.total
    ), compras AS MATERIALIZED (
      SELECT fechaingreso, total FROM public.compra
      WHERE idempresa = p_idempresa AND estado = 'COMPLETADA' AND fechaingreso >= v_anio AND fechaingreso < v_fin
    ), periodos AS (
      SELECT 'resumenDia' AS nombre, v_dia AS inicio UNION ALL SELECT 'resumenMes', v_mes
    )
    SELECT jsonb_object_agg(p.nombre, jsonb_build_object(
      'desde', (p.inicio AT TIME ZONE 'America/La_Paz')::date, 'hasta', v_hoy,
      'ventasTotales', COALESCE(v.total,0), 'comprasTotales', COALESCE(c.total,0),
      'costoRealVentas', COALESCE(v.costo,0), 'gananciaReal', COALESCE(v.total,0)-COALESCE(v.costo,0),
      'cantidadVentas', v.cantidad, 'cantidadCompras', c.cantidad))
    INTO v_resumen FROM periodos p
    CROSS JOIN LATERAL (SELECT sum(total) AS total, sum(costo) AS costo, count(*) AS cantidad FROM ventas WHERE fechaventa >= p.inicio) v
    CROSS JOIN LATERAL (SELECT sum(total) AS total, count(*) AS cantidad FROM compras WHERE fechaingreso >= p.inicio) c;

    WITH ventas AS (
      SELECT to_char(v.fechaventa AT TIME ZONE 'America/La_Paz','YYYY-MM') AS periodo,
        v.idventa, v.total, COALESCE(sum(l.subtotalcosto),0) AS costo
      FROM public.venta v LEFT JOIN public.detalle_venta d ON d.idventa = v.idventa
      LEFT JOIN public.detalle_venta_lote l ON l.iddetalleventa = d.iddetalleventa
      WHERE v.idempresa = p_idempresa AND v.estado = 'COMPLETADA' AND v.fechaventa >= v_anio AND v.fechaventa < v_fin
      GROUP BY v.idventa, v.fechaventa, v.total
    ), movimientos AS (
      SELECT periodo, total AS ventas, costo, 0::numeric AS compras, 1 AS nv, 0 AS nc FROM ventas
      UNION ALL
      SELECT to_char(fechaingreso AT TIME ZONE 'America/La_Paz','YYYY-MM'), 0, 0, total, 0, 1
      FROM public.compra WHERE idempresa = p_idempresa AND estado = 'COMPLETADA' AND fechaingreso >= v_anio AND fechaingreso < v_fin
    ), agrupados AS (
      SELECT periodo, sum(ventas) AS ventas, sum(compras) AS compras,
        sum(costo) AS "costoRealVentas", sum(ventas)-sum(costo) AS "gananciaReal",
        sum(nv) AS "cantidadVentas", sum(nc) AS "cantidadCompras"
      FROM movimientos GROUP BY periodo
    ) SELECT COALESCE(jsonb_agg(to_jsonb(a) ORDER BY a.periodo),'[]'::jsonb) INTO v_series FROM agrupados a;
    v_datos := v_resumen || jsonb_build_object('gananciasMensuales',v_series);
  END IF;
  IF p_ventas THEN
    SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r."creadoEn" DESC, r.id),'[]'::jsonb) INTO v_recientes FROM (
      SELECT d.iddetalleventa AS id, d.idventa, upper(left(d.idventa::text,8)) AS "ventaCodigo",
        d.cantidad, d.precioventa AS "precioUnitario", d.subtotal,
        COALESCE(p.nombre,'Producto sin nombre') AS producto, p.codigoprod AS codigo,
        COALESCE(m.nombre,'Sin marca') AS marca, p.urlimagen AS imagen, d.creado_en AS "creadoEn"
      FROM public.detalle_venta d JOIN public.venta v ON v.idventa = d.idventa
      LEFT JOIN public.productos p ON p.idproducto = d.idproducto LEFT JOIN public.marcas m ON m.idmarca = p.idmarca
      WHERE v.idempresa = p_idempresa AND v.estado = 'COMPLETADA' AND v.fechaventa >= v_dia AND v.fechaventa < v_fin
      ORDER BY d.creado_en DESC, d.iddetalleventa LIMIT 20
    ) r;
    v_datos := v_datos || jsonb_build_object('productosVendidosHoy',v_recientes);
  END IF;
  RETURN jsonb_build_object('fecha',v_hoy) || v_datos;
END;
$function$
;
REVOKE ALL ON FUNCTION public.exigir_permiso_empresa(uuid,uuid,text),public.registrar_venta_empresa(jsonb,uuid,uuid),public.dashboard_empresa(boolean,boolean,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.exigir_permiso_empresa(uuid,uuid,text),public.registrar_venta_empresa(jsonb,uuid,uuid),public.dashboard_empresa(boolean,boolean,uuid,uuid) TO service_role;


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
