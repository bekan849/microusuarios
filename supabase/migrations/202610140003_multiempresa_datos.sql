-- Pendiente de despliegue coordinado. Requiere base y preparación de empresas.
BEGIN;
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
COMMIT;
