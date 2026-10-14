-- SOLO PRUEBAS LOCALES: estructura recibida el 2026-10-14, sin filas reales.

-- No ejecutar como migracion de produccion.

CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;

CREATE TYPE public."compra_estado" AS ENUM ('PENDIENTE','COMPLETADA','CANCELADA');

CREATE TYPE public."producto_estado" AS ENUM ('ACTIVO','INACTIVO');

CREATE TYPE public."usuario_estado" AS ENUM ('ACTIVO','INACTIVO','BLOQUEADO');

CREATE TYPE public."venta_estado" AS ENUM ('PENDIENTE','COMPLETADA','CANCELADA');

CREATE TABLE public."usuario_rol" ("idusuariorol" uuid DEFAULT gen_random_uuid() NOT NULL,
"idusuario" uuid NOT NULL,
"idrol" uuid NOT NULL,
"estado" boolean DEFAULT true NOT NULL,
"asignado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."detalle_venta_lote" ("iddetalleventalote" uuid DEFAULT gen_random_uuid() NOT NULL,
"iddetalleventa" uuid NOT NULL,
"iddetallecompra" uuid NOT NULL,
"idproducto" uuid NOT NULL,
"cantidad" integer NOT NULL,
"preciocosto" numeric NOT NULL,
"subtotalcosto" numeric NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."rol_permiso" ("idrolpermiso" uuid DEFAULT gen_random_uuid() NOT NULL,
"idrol" uuid NOT NULL,
"idpermiso" uuid NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."permisos" ("idpermiso" uuid DEFAULT gen_random_uuid() NOT NULL,
"codigo" text NOT NULL,
"nombre" text NOT NULL,
"modulo" text NOT NULL,
"descripcion" text,
"estado" boolean DEFAULT true NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."historial_acciones" ("id" uuid NOT NULL,
"fecha" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
"servicio" text NOT NULL,
"actor_id" text,
"actor_email" text,
"accion" text NOT NULL,
"recurso" text NOT NULL,
"registro_id" text,
"resultado" text NOT NULL,
"estado_http" integer NOT NULL,
"antes" jsonb,
"despues" jsonb,
"detalles" jsonb DEFAULT '{}'::jsonb NOT NULL);

CREATE TABLE public."productos" ("idproducto" uuid DEFAULT gen_random_uuid() NOT NULL,
"codigoprod" text NOT NULL,
"nombre" text NOT NULL,
"descripcion" text,
"idcategoria" uuid NOT NULL,
"idmarca" uuid NOT NULL,
"stock" integer DEFAULT 0 NOT NULL,
"urlimagen" text,
"precioventa" numeric(12,2) DEFAULT 0 NOT NULL,
"estado" producto_estado DEFAULT 'ACTIVO'::producto_estado NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL,
"preciomayor" numeric(12,2) DEFAULT 0 NOT NULL);

CREATE TABLE public."categorias" ("idcategoria" uuid DEFAULT gen_random_uuid() NOT NULL,
"nombre" text NOT NULL,
"descripcion" text,
"estado" boolean DEFAULT true NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."marcas" ("idmarca" uuid DEFAULT gen_random_uuid() NOT NULL,
"nombre" text NOT NULL,
"descripcion" text,
"estado" boolean DEFAULT true NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."proveedor" ("idproveedor" uuid DEFAULT gen_random_uuid() NOT NULL,
"nombre" text NOT NULL,
"email" text,
"telefono" text,
"direccion" text,
"estado" boolean DEFAULT true NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."usuarios" ("idusuario" uuid DEFAULT gen_random_uuid() NOT NULL,
"uidauth" text,
"nombre" text NOT NULL,
"apellido" text NOT NULL,
"email" text NOT NULL,
"telefono" text,
"direccion" text,
"estado" usuario_estado DEFAULT 'ACTIVO'::usuario_estado NOT NULL,
"ultimo_acceso" timestamp with time zone,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL,
"actualizado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."detalle_venta" ("iddetalleventa" uuid DEFAULT gen_random_uuid() NOT NULL,
"idventa" uuid NOT NULL,
"idproducto" uuid NOT NULL,
"cantidad" integer NOT NULL,
"precioventa" numeric(12,2) NOT NULL,
"subtotal" numeric(12,2) GENERATED ALWAYS AS (((cantidad)::numeric * precioventa)) STORED,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."roles" ("idrol" uuid DEFAULT gen_random_uuid() NOT NULL,
"nombre" text NOT NULL,
"descripcion" text,
"estado" boolean DEFAULT true NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL,
"actualizado_en" timestamp with time zone DEFAULT now() NOT NULL);

CREATE TABLE public."venta" ("idventa" uuid DEFAULT gen_random_uuid() NOT NULL,
"fechaventa" timestamp with time zone DEFAULT now() NOT NULL,
"estado" venta_estado DEFAULT 'PENDIENTE'::venta_estado NOT NULL,
"total" numeric(12,2) DEFAULT 0 NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL,
"idusuario" uuid);

CREATE TABLE public."detalle_compra" ("iddetallecompra" uuid DEFAULT gen_random_uuid() NOT NULL,
"idcompra" uuid NOT NULL,
"idproducto" uuid NOT NULL,
"cantidad" integer NOT NULL,
"preciocosto" numeric(12,2) NOT NULL,
"subtotal" numeric(12,2) GENERATED ALWAYS AS (((cantidad)::numeric * preciocosto)) STORED,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL,
"stockrestante" numeric DEFAULT 0 NOT NULL);

CREATE TABLE public."compra" ("idcompra" uuid DEFAULT gen_random_uuid() NOT NULL,
"fechaingreso" timestamp with time zone DEFAULT now() NOT NULL,
"idproveedor" uuid NOT NULL,
"estado" compra_estado DEFAULT 'PENDIENTE'::compra_estado NOT NULL,
"total" numeric(12,2) DEFAULT 0 NOT NULL,
"creado_en" timestamp with time zone DEFAULT now() NOT NULL,
"idusuario" uuid);

ALTER TABLE public."categorias" ADD CONSTRAINT "categorias_pkey" PRIMARY KEY (idcategoria);

ALTER TABLE public."compra" ADD CONSTRAINT "compra_pkey" PRIMARY KEY (idcompra);

ALTER TABLE public."compra" ADD CONSTRAINT "compra_total_check" CHECK ((total >= (0)::numeric));

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "chk_detalle_compra_cantidad_positive" CHECK ((cantidad > 0));

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "chk_detalle_compra_preciocosto_nonnegative" CHECK ((preciocosto >= (0)::numeric));

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "chk_detalle_compra_stockrestante_nonnegative" CHECK ((stockrestante >= (0)::numeric));

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "chk_detalle_compra_subtotal_nonnegative" CHECK ((subtotal >= (0)::numeric));

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "detalle_compra_cantidad_check" CHECK ((cantidad > 0));

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "detalle_compra_pkey" PRIMARY KEY (iddetallecompra);

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "detalle_compra_preciocosto_check" CHECK ((preciocosto >= (0)::numeric));

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "chk_detalle_venta_cantidad_positive" CHECK ((cantidad > 0));

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "chk_detalle_venta_precioventa_nonnegative" CHECK ((precioventa >= (0)::numeric));

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "chk_detalle_venta_subtotal_nonnegative" CHECK ((subtotal >= (0)::numeric));

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "detalle_venta_cantidad_check" CHECK ((cantidad > 0));

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "detalle_venta_pkey" PRIMARY KEY (iddetalleventa);

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "detalle_venta_precioventa_check" CHECK ((precioventa >= (0)::numeric));

ALTER TABLE public."detalle_venta_lote" ADD CONSTRAINT "detalle_venta_lote_cantidad_check" CHECK ((cantidad > 0));

ALTER TABLE public."detalle_venta_lote" ADD CONSTRAINT "detalle_venta_lote_pkey" PRIMARY KEY (iddetalleventalote);

ALTER TABLE public."detalle_venta_lote" ADD CONSTRAINT "detalle_venta_lote_preciocosto_check" CHECK ((preciocosto >= (0)::numeric));

ALTER TABLE public."detalle_venta_lote" ADD CONSTRAINT "detalle_venta_lote_subtotalcosto_check" CHECK ((subtotalcosto >= (0)::numeric));

ALTER TABLE public."historial_acciones" ADD CONSTRAINT "historial_acciones_estado_http_check" CHECK (((estado_http >= 100) AND (estado_http <= 599)));

ALTER TABLE public."historial_acciones" ADD CONSTRAINT "historial_acciones_pkey" PRIMARY KEY (id);

ALTER TABLE public."historial_acciones" ADD CONSTRAINT "historial_acciones_resultado_check" CHECK ((resultado = ANY (ARRAY['exito'::text, 'error'::text])));

ALTER TABLE public."historial_acciones" ADD CONSTRAINT "historial_acciones_servicio_check" CHECK ((servicio = ANY (ARRAY['usuarios'::text, 'productos'::text])));

ALTER TABLE public."marcas" ADD CONSTRAINT "marcas_pkey" PRIMARY KEY (idmarca);

ALTER TABLE public."permisos" ADD CONSTRAINT "permisos_codigo_key" UNIQUE (codigo);

ALTER TABLE public."permisos" ADD CONSTRAINT "permisos_pkey" PRIMARY KEY (idpermiso);

ALTER TABLE public."productos" ADD CONSTRAINT "productos_codigoprod_key" UNIQUE (codigoprod);

ALTER TABLE public."productos" ADD CONSTRAINT "productos_pkey" PRIMARY KEY (idproducto);

ALTER TABLE public."productos" ADD CONSTRAINT "productos_precioventa_check" CHECK ((precioventa >= (0)::numeric));

ALTER TABLE public."productos" ADD CONSTRAINT "productos_stock_check" CHECK ((stock >= 0));

ALTER TABLE public."proveedor" ADD CONSTRAINT "proveedor_pkey" PRIMARY KEY (idproveedor);

ALTER TABLE public."rol_permiso" ADD CONSTRAINT "rol_permiso_pkey" PRIMARY KEY (idrolpermiso);

ALTER TABLE public."rol_permiso" ADD CONSTRAINT "uq_rol_permiso" UNIQUE (idrol, idpermiso);

ALTER TABLE public."roles" ADD CONSTRAINT "roles_nombre_key" UNIQUE (nombre);

ALTER TABLE public."roles" ADD CONSTRAINT "roles_pkey" PRIMARY KEY (idrol);

ALTER TABLE public."usuario_rol" ADD CONSTRAINT "uq_usuario_rol" UNIQUE (idusuario, idrol);

ALTER TABLE public."usuario_rol" ADD CONSTRAINT "usuario_rol_pkey" PRIMARY KEY (idusuariorol);

ALTER TABLE public."usuarios" ADD CONSTRAINT "usuarios_email_key" UNIQUE (email);

ALTER TABLE public."usuarios" ADD CONSTRAINT "usuarios_pkey" PRIMARY KEY (idusuario);

ALTER TABLE public."usuarios" ADD CONSTRAINT "usuarios_uidauth_key" UNIQUE (uidauth);

ALTER TABLE public."venta" ADD CONSTRAINT "venta_pkey" PRIMARY KEY (idventa);

ALTER TABLE public."venta" ADD CONSTRAINT "venta_total_check" CHECK ((total >= (0)::numeric));

ALTER TABLE public."compra" ADD CONSTRAINT "compra_idproveedor_fkey" FOREIGN KEY (idproveedor) REFERENCES proveedor(idproveedor) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."compra" ADD CONSTRAINT "fk_compra_usuario" FOREIGN KEY (idusuario) REFERENCES usuarios(idusuario) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "detalle_compra_idcompra_fkey" FOREIGN KEY (idcompra) REFERENCES compra(idcompra) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public."detalle_compra" ADD CONSTRAINT "detalle_compra_idproducto_fkey" FOREIGN KEY (idproducto) REFERENCES productos(idproducto) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "detalle_venta_idproducto_fkey" FOREIGN KEY (idproducto) REFERENCES productos(idproducto) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."detalle_venta" ADD CONSTRAINT "detalle_venta_idventa_fkey" FOREIGN KEY (idventa) REFERENCES venta(idventa) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public."detalle_venta_lote" ADD CONSTRAINT "detalle_venta_lote_iddetallecompra_fkey" FOREIGN KEY (iddetallecompra) REFERENCES detalle_compra(iddetallecompra);

ALTER TABLE public."detalle_venta_lote" ADD CONSTRAINT "detalle_venta_lote_iddetalleventa_fkey" FOREIGN KEY (iddetalleventa) REFERENCES detalle_venta(iddetalleventa) ON DELETE CASCADE;

ALTER TABLE public."detalle_venta_lote" ADD CONSTRAINT "detalle_venta_lote_idproducto_fkey" FOREIGN KEY (idproducto) REFERENCES productos(idproducto);

ALTER TABLE public."productos" ADD CONSTRAINT "productos_idcategoria_fkey" FOREIGN KEY (idcategoria) REFERENCES categorias(idcategoria) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."productos" ADD CONSTRAINT "productos_idmarca_fkey" FOREIGN KEY (idmarca) REFERENCES marcas(idmarca) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."rol_permiso" ADD CONSTRAINT "fk_rol_permiso_permiso" FOREIGN KEY (idpermiso) REFERENCES permisos(idpermiso) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."rol_permiso" ADD CONSTRAINT "fk_rol_permiso_rol" FOREIGN KEY (idrol) REFERENCES roles(idrol) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."usuario_rol" ADD CONSTRAINT "fk_usuario_rol_rol" FOREIGN KEY (idrol) REFERENCES roles(idrol) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."usuario_rol" ADD CONSTRAINT "fk_usuario_rol_usuario" FOREIGN KEY (idusuario) REFERENCES usuarios(idusuario) ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE public."venta" ADD CONSTRAINT "fk_venta_usuario" FOREIGN KEY (idusuario) REFERENCES usuarios(idusuario) ON UPDATE CASCADE ON DELETE RESTRICT;

CREATE INDEX idx_usuario_rol_idusuario ON public.usuario_rol USING btree (idusuario);

CREATE INDEX idx_usuario_rol_idrol ON public.usuario_rol USING btree (idrol);

CREATE INDEX idx_usuario_rol_estado ON public.usuario_rol USING btree (estado);

CREATE INDEX usuario_rol_activo_lookup_idx ON public.usuario_rol USING btree (idusuario, idrol) WHERE (estado = true);

CREATE INDEX idx_detalle_venta_lote_iddetalleventa ON public.detalle_venta_lote USING btree (iddetalleventa);

CREATE INDEX idx_detalle_venta_lote_iddetallecompra ON public.detalle_venta_lote USING btree (iddetallecompra);

CREATE INDEX idx_detalle_venta_lote_idproducto ON public.detalle_venta_lote USING btree (idproducto);

CREATE INDEX detalle_venta_lote_detalle_idx ON public.detalle_venta_lote USING btree (iddetalleventa);

CREATE INDEX idx_rol_permiso_idrol ON public.rol_permiso USING btree (idrol);

CREATE INDEX idx_rol_permiso_idpermiso ON public.rol_permiso USING btree (idpermiso);

CREATE INDEX rol_permiso_lookup_idx ON public.rol_permiso USING btree (idrol, idpermiso);

CREATE INDEX idx_permisos_codigo ON public.permisos USING btree (codigo);

CREATE INDEX idx_permisos_modulo ON public.permisos USING btree (modulo);

CREATE INDEX idx_permisos_estado ON public.permisos USING btree (estado);

CREATE INDEX historial_servicio_fecha_idx ON public.historial_acciones USING btree (servicio, fecha DESC, id DESC);

CREATE INDEX historial_actor_fecha_idx ON public.historial_acciones USING btree (actor_id, fecha DESC);

CREATE INDEX historial_accion_fecha_idx ON public.historial_acciones USING btree (servicio, accion, fecha DESC);

CREATE UNIQUE INDEX ux_productos_codigoprod ON public.productos USING btree (upper(codigoprod));

CREATE UNIQUE INDEX ux_productos_nombre_categoria_marca ON public.productos USING btree (lower(nombre), idcategoria, idmarca);

CREATE INDEX ix_productos_categoria ON public.productos USING btree (idcategoria);

CREATE INDEX ix_productos_marca ON public.productos USING btree (idmarca);

CREATE INDEX ix_productos_estado ON public.productos USING btree (estado);

CREATE UNIQUE INDEX ux_categorias_nombre ON public.categorias USING btree (lower(nombre));

CREATE UNIQUE INDEX ux_marcas_nombre ON public.marcas USING btree (lower(nombre));

CREATE UNIQUE INDEX ux_proveedor_nombre ON public.proveedor USING btree (lower(nombre));

CREATE INDEX idx_usuarios_email ON public.usuarios USING btree (email);

CREATE INDEX idx_usuarios_estado ON public.usuarios USING btree (estado);

CREATE INDEX idx_usuarios_nombre ON public.usuarios USING btree (nombre, apellido);

CREATE INDEX usuarios_uidauth_lookup_idx ON public.usuarios USING btree (uidauth);

CREATE INDEX ix_detalle_venta_venta ON public.detalle_venta USING btree (idventa);

CREATE INDEX ix_detalle_venta_producto ON public.detalle_venta USING btree (idproducto);

CREATE INDEX detalle_venta_venta_idx ON public.detalle_venta USING btree (idventa);

CREATE INDEX idx_roles_nombre ON public.roles USING btree (nombre);

CREATE INDEX idx_roles_estado ON public.roles USING btree (estado);

CREATE INDEX ix_venta_estado ON public.venta USING btree (estado);

CREATE INDEX ix_venta_fecha ON public.venta USING btree (fechaventa);

CREATE INDEX venta_estado_fecha_idx ON public.venta USING btree (estado, fechaventa);

CREATE INDEX ix_detalle_compra_compra ON public.detalle_compra USING btree (idcompra);

CREATE INDEX ix_detalle_compra_producto ON public.detalle_compra USING btree (idproducto);

CREATE INDEX detalle_compra_peps_idx ON public.detalle_compra USING btree (idproducto, creado_en, iddetallecompra) WHERE (stockrestante > (0)::numeric);

CREATE INDEX detalle_compra_compra_idx ON public.detalle_compra USING btree (idcompra);

CREATE INDEX ix_compra_proveedor ON public.compra USING btree (idproveedor);

CREATE INDEX ix_compra_estado ON public.compra USING btree (estado);

CREATE INDEX ix_compra_fecha ON public.compra USING btree (fechaingreso);

CREATE INDEX compra_estado_fecha_idx ON public.compra USING btree (estado, fechaingreso);

CREATE OR REPLACE FUNCTION public.cambiar_estado_compra(p_idcompra uuid, p_estado compra_estado)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  v_estado_actual public.compra_estado;
begin
  select estado into v_estado_actual
  from public.compra
  where idcompra = p_idcompra
  for update;

  if not found then
    raise exception 'Compra no encontrada';
  end if;

  if v_estado_actual = p_estado then
    return;
  end if;

  -- Si estaba COMPLETADA y va a otro estado: revertir stock (restar)
  if v_estado_actual = 'COMPLETADA' and p_estado <> 'COMPLETADA' then
    update public.productos p
    set stock = p.stock - dc.cantidad
    from public.detalle_compra dc
    where dc.idcompra = p_idcompra
      and dc.idproducto = p.idproducto;

    -- Validación: que no quede negativo (por seguridad)
    if exists (select 1 from public.productos where stock < 0) then
      raise exception 'Reversión inválida: stock negativo detectado';
    end if;
  end if;

  -- Si NO estaba COMPLETADA y pasa a COMPLETADA: aplicar stock (sumar)
  if v_estado_actual <> 'COMPLETADA' and p_estado = 'COMPLETADA' then
    update public.productos p
    set stock = p.stock + dc.cantidad
    from public.detalle_compra dc
    where dc.idcompra = p_idcompra
      and dc.idproducto = p.idproducto;
  end if;

  update public.compra
  set estado = p_estado
  where idcompra = p_idcompra;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cambiar_estado_venta(p_idventa uuid, p_estado venta_estado)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  v_estado_actual public.venta_estado;
begin
  select estado into v_estado_actual
  from public.venta
  where idventa = p_idventa
  for update;

  if not found then
    raise exception 'Venta no encontrada';
  end if;

  if v_estado_actual = p_estado then
    return;
  end if;

  -- Si NO estaba COMPLETADA y pasa a COMPLETADA: validar stock y descontar
  if v_estado_actual <> 'COMPLETADA' and p_estado = 'COMPLETADA' then

    -- Validar stock suficiente por cada producto
    if exists (
      select 1
      from public.detalle_venta dv
      join public.productos p on p.idproducto = dv.idproducto
      where dv.idventa = p_idventa
        and p.stock < dv.cantidad
    ) then
      raise exception 'Stock insuficiente para completar la venta';
    end if;

    update public.productos p
    set stock = p.stock - dv.cantidad
    from public.detalle_venta dv
    where dv.idventa = p_idventa
      and dv.idproducto = p.idproducto;
  end if;

  -- Si estaba COMPLETADA y cambia a otro estado: revertir (sumar)
  if v_estado_actual = 'COMPLETADA' and p_estado <> 'COMPLETADA' then
    update public.productos p
    set stock = p.stock + dv.cantidad
    from public.detalle_venta dv
    where dv.idventa = p_idventa
      and dv.idproducto = p.idproducto;
  end if;

  update public.venta
  set estado = p_estado
  where idventa = p_idventa;
end;
$function$;

CREATE OR REPLACE FUNCTION public.dashboard_inicial(p_reportes boolean, p_ventas boolean)
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
BEGIN
  v_dia := v_hoy::timestamp AT TIME ZONE 'America/La_Paz';
  v_mes := date_trunc('month', v_hoy::timestamp) AT TIME ZONE 'America/La_Paz';
  v_anio := date_trunc('year', v_hoy::timestamp) AT TIME ZONE 'America/La_Paz';
  v_fin := (v_hoy + 1)::timestamp AT TIME ZONE 'America/La_Paz';
  IF p_reportes THEN
    WITH ventas AS MATERIALIZED (
      SELECT v.idventa, v.fechaventa, v.total, COALESCE(sum(l.subtotalcosto),0) AS costo
      FROM public.venta v LEFT JOIN public.detalle_venta d ON d.idventa = v.idventa
      LEFT JOIN public.detalle_venta_lote l ON l.iddetalleventa = d.iddetalleventa
      WHERE v.estado = 'COMPLETADA' AND v.fechaventa >= v_anio AND v.fechaventa < v_fin
      GROUP BY v.idventa, v.fechaventa, v.total
    ), compras AS MATERIALIZED (
      SELECT fechaingreso, total FROM public.compra
      WHERE estado = 'COMPLETADA' AND fechaingreso >= v_anio AND fechaingreso < v_fin
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
      WHERE v.estado = 'COMPLETADA' AND v.fechaventa >= v_anio AND v.fechaventa < v_fin
      GROUP BY v.idventa, v.fechaventa, v.total
    ), movimientos AS (
      SELECT periodo, total AS ventas, costo, 0::numeric AS compras, 1 AS nv, 0 AS nc FROM ventas
      UNION ALL
      SELECT to_char(fechaingreso AT TIME ZONE 'America/La_Paz','YYYY-MM'), 0, 0, total, 0, 1
      FROM public.compra WHERE estado = 'COMPLETADA' AND fechaingreso >= v_anio AND fechaingreso < v_fin
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
      WHERE v.estado = 'COMPLETADA' AND v.fechaventa >= v_dia AND v.fechaventa < v_fin
      ORDER BY d.creado_en DESC, d.iddetalleventa LIMIT 20
    ) r;
    v_datos := v_datos || jsonb_build_object('productosVendidosHoy',v_recientes);
  END IF;
  RETURN jsonb_build_object('fecha',v_hoy) || v_datos;
END;
$function$;

CREATE OR REPLACE FUNCTION public.iniciar_sesion_usuario(p_uidauth text, p_email text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_input public.usuarios%ROWTYPE;
  v_usuario public.usuarios%ROWTYPE;
BEGIN
  IF NULLIF(trim(p_uidauth), '') IS NULL OR NULLIF(trim(p_email), '') IS NULL THEN
    RAISE EXCEPTION 'Faltan los datos de autenticación';
  END IF;
  v_input := jsonb_populate_record(NULL::public.usuarios, jsonb_build_object('uidauth', p_uidauth));
  SELECT * INTO v_usuario FROM public.usuarios WHERE uidauth = v_input.uidauth FOR UPDATE;
  IF NOT FOUND THEN
    SELECT * INTO v_usuario FROM public.usuarios WHERE email = lower(trim(p_email)) FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El usuario autenticado no existe en la tabla usuarios'; END IF;
    IF v_usuario.uidauth IS NOT NULL AND v_usuario.uidauth <> v_input.uidauth THEN
      RAISE EXCEPTION 'La cuenta de autenticación no coincide con el usuario';
    END IF;
  END IF;
  IF v_usuario.estado IS DISTINCT FROM 'ACTIVO' THEN RAISE EXCEPTION 'Usuario no activo'; END IF;
  UPDATE public.usuarios SET uidauth = v_input.uidauth, ultimo_acceso = now()
  WHERE idusuario = v_usuario.idusuario;
  RETURN public.obtener_accesos_usuario(v_usuario.idusuario::text);
END;
$function$;

CREATE OR REPLACE FUNCTION public.obtener_accesos_usuario(p_idusuario text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_input public.usuarios%ROWTYPE;
  v_usuario public.usuarios%ROWTYPE;
  v_roles jsonb;
  v_permisos jsonb;
BEGIN
  v_input := jsonb_populate_record(NULL::public.usuarios, jsonb_build_object('idusuario', p_idusuario));
  SELECT * INTO v_usuario FROM public.usuarios WHERE idusuario = v_input.idusuario;
  IF NOT FOUND THEN RAISE EXCEPTION 'Usuario no encontrado'; END IF;
  IF v_usuario.estado IS DISTINCT FROM 'ACTIVO' THEN RAISE EXCEPTION 'Usuario no activo'; END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r.nombre, r.idrol), '[]'::jsonb)
  INTO v_roles FROM (
    SELECT DISTINCT r.idrol, trim(r.nombre) AS nombre, r.descripcion
    FROM public.roles r JOIN public.usuario_rol ur ON ur.idrol = r.idrol
    WHERE ur.idusuario = v_usuario.idusuario AND ur.estado = true AND r.estado = true
  ) r;

  SELECT COALESCE(jsonb_agg(to_jsonb(p) ORDER BY p.codigo, p.idpermiso), '[]'::jsonb)
  INTO v_permisos FROM (
    SELECT DISTINCT p.idpermiso, lower(trim(p.codigo)) AS codigo, p.nombre, p.modulo, p.descripcion
    FROM public.permisos p
    JOIN public.rol_permiso rp ON rp.idpermiso = p.idpermiso
    JOIN public.roles r ON r.idrol = rp.idrol AND r.estado = true
    JOIN public.usuario_rol ur ON ur.idrol = r.idrol AND ur.estado = true
    WHERE ur.idusuario = v_usuario.idusuario AND p.estado = true
  ) p;
  RETURN jsonb_build_object('usuario', to_jsonb(v_usuario), 'roles', v_roles, 'permisos', v_permisos);
END;
$function$;

CREATE OR REPLACE FUNCTION public.proteger_historial_acciones()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'El historial de acciones no se puede modificar ni borrar';
END;
$function$;

CREATE OR REPLACE FUNCTION public.recalcular_total_compra(p_idcompra uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
  update public.compra c
  set total = coalesce((
    select sum(dc.subtotal)
    from public.detalle_compra dc
    where dc.idcompra = c.idcompra
  ), 0)
  where c.idcompra = p_idcompra;
end;
$function$;

CREATE OR REPLACE FUNCTION public.recalcular_total_venta(p_idventa uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
  update public.venta v
  set total = coalesce((
    select sum(dv.subtotal)
    from public.detalle_venta dv
    where dv.idventa = v.idventa
  ), 0)
  where v.idventa = p_idventa;
end;
$function$;

CREATE OR REPLACE FUNCTION public.registrar_venta_completa_atomica(p_items jsonb, p_fechaventa timestamp with time zone DEFAULT NULL::timestamp with time zone, p_idusuario uuid DEFAULT NULL::uuid)
 RETURNS SETOF venta
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_venta public.venta%rowtype;
  v_item record;
  v_lote record;
  v_iddetalleventa uuid;
  v_cantidad integer;
  v_cantidad_consumida integer;
  v_restante integer;
  v_precioventa numeric;
  v_preciocosto numeric;
  v_stock_producto integer;
  v_stock_lotes integer;
  v_estado_producto text;
  v_total numeric := 0;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Los items de la venta deben ser un arreglo';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'La venta debe tener al menos un item';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as item(
      idproducto uuid,
      cantidad numeric,
      precioventa numeric
    )
    group by item.idproducto
    having count(*) > 1
  ) then
    raise exception 'No se permite repetir un producto en la misma venta';
  end if;

  insert into public.venta (
    fechaventa,
    idusuario,
    estado,
    total
  )
  values (
    coalesce(p_fechaventa, now()),
    p_idusuario,
    'PENDIENTE',
    0
  )
  returning * into v_venta;

  -- El orden fijo de bloqueo evita que dos ventas concurrentes de varios
  -- productos se bloqueen mutuamente en un orden diferente.
  for v_item in
    select
      item.idproducto,
      item.cantidad,
      item.precioventa
    from jsonb_to_recordset(p_items) as item(
      idproducto uuid,
      cantidad numeric,
      precioventa numeric
    )
    order by item.idproducto
  loop
    if v_item.idproducto is null then
      raise exception 'idproducto es obligatorio';
    end if;

    if v_item.cantidad is null
      or v_item.cantidad <= 0
      or v_item.cantidad <> trunc(v_item.cantidad)
    then
      raise exception 'cantidad inválida para el producto %', v_item.idproducto;
    end if;

    if v_item.precioventa is null or v_item.precioventa < 0 then
      raise exception 'precioventa inválido para el producto %', v_item.idproducto;
    end if;

    v_cantidad := v_item.cantidad::integer;
    v_precioventa := v_item.precioventa;

    select
      coalesce(producto.stock, 0)::integer,
      producto.estado::text
    into
      v_stock_producto,
      v_estado_producto
    from public.productos as producto
    where producto.idproducto = v_item.idproducto
    for update;

    if not found then
      raise exception 'No se encontró el producto %', v_item.idproducto;
    end if;

    if v_estado_producto <> 'ACTIVO' then
      raise exception 'Solo se pueden vender productos activos. Producto: %',
        v_item.idproducto;
    end if;

    -- Bloquea los lotes PEPS antes de validar o descontar existencias.
    perform lote.iddetallecompra
    from public.detalle_compra as lote
    where lote.idproducto = v_item.idproducto
      and lote.stockrestante > 0
    order by lote.creado_en, lote.iddetallecompra
    for update;

    select coalesce(sum(lote.stockrestante), 0)::integer
    into v_stock_lotes
    from public.detalle_compra as lote
    where lote.idproducto = v_item.idproducto
      and lote.stockrestante > 0;

    if v_stock_producto < v_cantidad or v_stock_lotes < v_cantidad then
      raise exception
        'Stock insuficiente para el producto %. Stock general: %, stock PEPS: %, requerido: %',
        v_item.idproducto,
        v_stock_producto,
        v_stock_lotes,
        v_cantidad;
    end if;

    insert into public.detalle_venta (
      idventa,
      idproducto,
      cantidad,
      precioventa
    )
    values (
      v_venta.idventa,
      v_item.idproducto,
      v_cantidad,
      v_precioventa
    )
    returning iddetalleventa into v_iddetalleventa;

    v_restante := v_cantidad;

    for v_lote in
      select
        lote.iddetallecompra,
        lote.stockrestante,
        lote.preciocosto
      from public.detalle_compra as lote
      where lote.idproducto = v_item.idproducto
        and lote.stockrestante > 0
      order by lote.creado_en, lote.iddetallecompra
      for update
    loop
      exit when v_restante = 0;

      v_cantidad_consumida := least(
        v_lote.stockrestante::integer,
        v_restante
      );
      v_preciocosto := coalesce(v_lote.preciocosto, 0);

      if v_precioventa < v_preciocosto then
        raise exception
          'El precio de venta no puede ser menor al precio de compra. Producto: %. Precio venta: %, precio costo: %',
          v_item.idproducto,
          v_precioventa,
          v_preciocosto;
      end if;

      update public.detalle_compra
      set stockrestante = stockrestante - v_cantidad_consumida
      where iddetallecompra = v_lote.iddetallecompra
        and stockrestante >= v_cantidad_consumida;

      if not found then
        raise exception 'El stock PEPS cambió mientras se registraba la venta';
      end if;

      insert into public.detalle_venta_lote (
        iddetalleventa,
        iddetallecompra,
        idproducto,
        cantidad,
        preciocosto,
        subtotalcosto
      )
      values (
        v_iddetalleventa,
        v_lote.iddetallecompra,
        v_item.idproducto,
        v_cantidad_consumida,
        v_preciocosto,
        v_cantidad_consumida * v_preciocosto
      );

      v_restante := v_restante - v_cantidad_consumida;
    end loop;

    if v_restante <> 0 then
      raise exception 'No se pudo consumir completamente el stock del producto %',
        v_item.idproducto;
    end if;

    update public.productos
    set
      stock = stock - v_cantidad,
      estado = case
        when stock - v_cantidad > 0 then 'ACTIVO'::public.producto_estado
        else 'INACTIVO'::public.producto_estado
      end
    where idproducto = v_item.idproducto
      and stock >= v_cantidad;

    if not found then
      raise exception 'El stock general cambió mientras se registraba la venta';
    end if;

    v_total := v_total + (v_cantidad * v_precioventa);
  end loop;

  update public.venta
  set
    total = v_total,
    estado = 'COMPLETADA'
  where idventa = v_venta.idventa
  returning * into v_venta;

  return next v_venta;
end;
$function$;

CREATE OR REPLACE FUNCTION public.registrar_venta_completa_atomica(p_payload jsonb)
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
    SELECT * INTO v_producto FROM public.productos WHERE idproducto = v_input.idproducto FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Producto no encontrado'; END IF;
    IF v_producto.estado IS DISTINCT FROM 'ACTIVO' THEN RAISE EXCEPTION 'Solo se pueden vender productos activos'; END IF;
    IF v_producto.stock IS NULL OR v_producto.stock < v_input.cantidad THEN RAISE EXCEPTION 'Stock insuficiente del producto %', v_producto.idproducto; END IF;
  END LOOP;

  v_venta := jsonb_populate_record(NULL::public.venta, p_payload - 'items');
  INSERT INTO public.venta (fechaventa, idusuario, estado, total)
  VALUES (COALESCE(v_venta.fechaventa, now()), v_venta.idusuario, 'PENDIENTE', 0)
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
      WHERE dc.idproducto = v_input.idproducto AND dc.stockrestante > 0 AND c.estado = 'COMPLETADA'
      ORDER BY dc.creado_en, dc.iddetallecompra FOR UPDATE OF dc, c
    LOOP
      v_disponible := v_disponible + v_lote.stockrestante;
    END LOOP;
    IF v_disponible < v_restante THEN RAISE EXCEPTION 'Stock insuficiente en los lotes del producto %', v_input.idproducto; END IF;

    INSERT INTO public.detalle_venta (idventa, idproducto, cantidad, precioventa)
    VALUES (v_venta.idventa, v_input.idproducto, v_input.cantidad, v_precio)
    RETURNING * INTO v_detalle;

    FOR v_lote IN
      SELECT dc.* FROM public.detalle_compra dc JOIN public.compra c ON c.idcompra = dc.idcompra
      WHERE dc.idproducto = v_input.idproducto AND dc.stockrestante > 0 AND c.estado = 'COMPLETADA'
      ORDER BY dc.creado_en, dc.iddetallecompra
    LOOP
      EXIT WHEN v_restante <= 0;
      v_consumir := least(v_restante, v_lote.stockrestante);
      IF v_lote.preciocosto IS NULL OR v_precio < v_lote.preciocosto THEN
        RAISE EXCEPTION 'El precio de venta no puede ser menor al precio de compra';
      END IF;
      UPDATE public.detalle_compra SET stockrestante = stockrestante - v_consumir WHERE iddetallecompra = v_lote.iddetallecompra;
      INSERT INTO public.detalle_venta_lote (iddetalleventa, iddetallecompra, idproducto, cantidad, preciocosto, subtotalcosto)
      VALUES (v_detalle.iddetalleventa, v_lote.iddetallecompra, v_input.idproducto, v_consumir, v_lote.preciocosto, v_consumir * v_lote.preciocosto);
      v_restante := v_restante - v_consumir;
    END LOOP;
    IF v_restante <> 0 THEN RAISE EXCEPTION 'No se pudo consumir completamente el stock'; END IF;
    UPDATE public.productos SET stock = stock - v_input.cantidad,
      estado = (jsonb_populate_record(NULL::public.productos, jsonb_build_object(
        'estado', CASE WHEN stock - v_input.cantidad > 0 THEN 'ACTIVO' ELSE 'INACTIVO' END))).estado
    WHERE idproducto = v_input.idproducto;
    v_total := v_total + COALESCE(v_detalle.subtotal, v_input.cantidad * v_precio);
  END LOOP;
  UPDATE public.venta SET total = v_total, estado = 'COMPLETADA' WHERE idventa = v_venta.idventa RETURNING * INTO v_venta;
  RETURN jsonb_build_object('idventa', v_venta.idventa, 'fechaventa', v_venta.fechaventa,
    'estado', v_venta.estado, 'total', v_venta.total, 'creado_en', v_venta.creado_en, 'idusuario', v_venta.idusuario);
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.actualizado_en = now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_bloquear_detalle_compra_si_completada()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_estado text;
  v_old jsonb;
  v_new jsonb;
begin
  if tg_op = 'INSERT' then
    select estado
      into v_estado
    from public.compra
    where idcompra = new.idcompra;

    if v_estado = 'COMPLETADA' then
      raise exception 'No se puede insertar detalle_compra: la compra está COMPLETADA';
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    select estado
      into v_estado
    from public.compra
    where idcompra = old.idcompra;

    if v_estado = 'COMPLETADA' then
      raise exception 'No se puede eliminar detalle_compra: la compra está COMPLETADA';
    end if;

    return old;
  end if;

  if tg_op = 'UPDATE' then
    select estado
      into v_estado
    from public.compra
    where idcompra = old.idcompra;

    if v_estado = 'COMPLETADA' then
      -- ignorar stockrestante y subtotal
      v_old := to_jsonb(old) - 'stockrestante' - 'subtotal';
      v_new := to_jsonb(new) - 'stockrestante' - 'subtotal';

      if v_old <> v_new then
        raise exception 'No se puede modificar detalle_compra: la compra está COMPLETADA';
      end if;
    end if;

    return new;
  end if;

  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_bloquear_detalle_compra_si_compra_no_pendiente()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  estado_compra text;
begin
  select c.estado::text
  into estado_compra
  from public.compra c
  where c.idcompra = coalesce(new.idcompra, old.idcompra);

  -- INSERT
  if tg_op = 'INSERT' then
    if estado_compra is distinct from 'PENDIENTE' then
      raise exception 'No se puede insertar detalle_compra: la compra no está PENDIENTE';
    end if;
    return new;
  end if;

  -- DELETE
  if tg_op = 'DELETE' then
    if estado_compra is distinct from 'PENDIENTE' then
      raise exception 'No se puede eliminar detalle_compra: la compra está %', estado_compra;
    end if;
    return old;
  end if;

  -- UPDATE
  if tg_op = 'UPDATE' then
    -- Si está PENDIENTE, permitir todo
    if estado_compra = 'PENDIENTE' then
      return new;
    end if;

    -- Si NO está pendiente, solo permitir cambiar stockrestante
    if estado_compra in ('COMPLETADA', 'CANCELADA') then
      if
        old.idcompra is distinct from new.idcompra or
        old.idproducto is distinct from new.idproducto or
        old.cantidad is distinct from new.cantidad or
        old.preciocosto is distinct from new.preciocosto or
        old.subtotal is distinct from new.subtotal
      then
        raise exception 'No se puede modificar detalle_compra: la compra está %', estado_compra;
      end if;

      -- Solo cambió stockrestante, permitido
      return new;
    end if;
  end if;

  return coalesce(new, old);
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_bloquear_detalle_venta_si_completada()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_estado text;
begin
  if tg_op = 'INSERT' then
    select estado
      into v_estado
    from public.venta
    where idventa = new.idventa;

    if v_estado = 'COMPLETADA' then
      raise exception 'No se puede insertar detalle_venta: la venta está COMPLETADA';
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    select estado
      into v_estado
    from public.venta
    where idventa = old.idventa;

    if v_estado = 'COMPLETADA' then
      raise exception 'No se puede eliminar detalle_venta: la venta está COMPLETADA';
    end if;

    return old;
  end if;

  if tg_op = 'UPDATE' then
    select estado
      into v_estado
    from public.venta
    where idventa = old.idventa;

    if v_estado = 'COMPLETADA' then
      raise exception 'No se puede modificar detalle_venta: la venta está COMPLETADA';
    end if;

    return new;
  end if;

  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_detalle_compra_recalcular_total()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_idcompra uuid;
begin
  v_idcompra := coalesce(new.idcompra, old.idcompra);
  perform public.recalcular_total_compra(v_idcompra);
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_detalle_venta_recalcular_total()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_idventa uuid;
begin
  v_idventa := coalesce(new.idventa, old.idventa);
  perform public.recalcular_total_venta(v_idventa);
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_normalizar_permiso()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.codigo := lower(trim(new.codigo));
  new.nombre := trim(new.nombre);
  new.modulo := lower(trim(new.modulo));

  if new.descripcion is not null then
    new.descripcion := trim(new.descripcion);
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_normalizar_rol()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.nombre := upper(trim(new.nombre));

  if new.descripcion is not null then
    new.descripcion := trim(new.descripcion);
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_normalizar_usuario()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.nombre := upper(trim(new.nombre));
  new.apellido := upper(trim(new.apellido));
  new.email := lower(trim(new.email));

  if new.telefono is not null then
    new.telefono := trim(new.telefono);
  end if;

  if new.direccion is not null then
    new.direccion := upper(trim(new.direccion));
  end if;

  return new;
end;
$function$;

CREATE VIEW public."productos_list_view" AS  SELECT p.idproducto,
    p.codigoprod,
    p.nombre,
    p.descripcion,
    p.stock,
    p.urlimagen,
    p.precioventa,
    p.preciomayor,
    p.estado,
    p.creado_en,
    p.idcategoria,
    p.idmarca,
    c.nombre AS categoria_nombre,
    m.nombre AS marca_nombre
   FROM productos p
     LEFT JOIN categorias c ON c.idcategoria = p.idcategoria
     LEFT JOIN marcas m ON m.idmarca = p.idmarca;

CREATE VIEW public."v_usuario_permisos" AS  SELECT u.idusuario,
    u.nombre,
    u.apellido,
    u.email,
    r.idrol,
    r.nombre AS rol,
    p.idpermiso,
    p.codigo AS permiso_codigo,
    p.nombre AS permiso_nombre,
    p.modulo
   FROM usuarios u
     JOIN usuario_rol ur ON ur.idusuario = u.idusuario AND ur.estado = true
     JOIN roles r ON r.idrol = ur.idrol AND r.estado = true
     JOIN rol_permiso rp ON rp.idrol = r.idrol
     JOIN permisos p ON p.idpermiso = rp.idpermiso AND p.estado = true;

CREATE TRIGGER bloquear_detalle_compra_si_completada BEFORE INSERT OR DELETE OR UPDATE ON public.detalle_compra FOR EACH ROW EXECUTE FUNCTION trg_bloquear_detalle_compra_si_completada();

CREATE TRIGGER t_detalle_compra_recalcular_total AFTER INSERT OR DELETE OR UPDATE ON public.detalle_compra FOR EACH ROW EXECUTE FUNCTION trg_detalle_compra_recalcular_total();

CREATE TRIGGER bloquear_detalle_venta_si_completada BEFORE INSERT OR DELETE OR UPDATE ON public.detalle_venta FOR EACH ROW EXECUTE FUNCTION trg_bloquear_detalle_venta_si_completada();

CREATE TRIGGER t_detalle_venta_recalcular_total AFTER INSERT OR DELETE OR UPDATE ON public.detalle_venta FOR EACH ROW EXECUTE FUNCTION trg_detalle_venta_recalcular_total();

CREATE TRIGGER historial_solo_lectura BEFORE DELETE OR UPDATE OR TRUNCATE ON public.historial_acciones FOR EACH STATEMENT EXECUTE FUNCTION proteger_historial_acciones();

CREATE TRIGGER t_normalizar_permiso BEFORE INSERT OR UPDATE ON public.permisos FOR EACH ROW EXECUTE FUNCTION trg_normalizar_permiso();

CREATE TRIGGER t_normalizar_rol BEFORE INSERT OR UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION trg_normalizar_rol();

CREATE TRIGGER t_roles_set_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER t_normalizar_usuario BEFORE INSERT OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION trg_normalizar_usuario();

CREATE TRIGGER t_usuarios_set_updated_at BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE public."historial_acciones" ENABLE ROW LEVEL SECURITY;

GRANT INSERT ON public."usuario_rol" TO "anon";

GRANT SELECT ON public."usuario_rol" TO "anon";

GRANT UPDATE ON public."usuario_rol" TO "anon";

GRANT DELETE ON public."usuario_rol" TO "anon";

GRANT TRUNCATE ON public."usuario_rol" TO "anon";

GRANT REFERENCES ON public."usuario_rol" TO "anon";

GRANT TRIGGER ON public."usuario_rol" TO "anon";

GRANT INSERT ON public."usuario_rol" TO "authenticated";

GRANT SELECT ON public."usuario_rol" TO "authenticated";

GRANT UPDATE ON public."usuario_rol" TO "authenticated";

GRANT DELETE ON public."usuario_rol" TO "authenticated";

GRANT TRUNCATE ON public."usuario_rol" TO "authenticated";

GRANT REFERENCES ON public."usuario_rol" TO "authenticated";

GRANT TRIGGER ON public."usuario_rol" TO "authenticated";

GRANT INSERT ON public."usuario_rol" TO "service_role";

GRANT SELECT ON public."usuario_rol" TO "service_role";

GRANT UPDATE ON public."usuario_rol" TO "service_role";

GRANT DELETE ON public."usuario_rol" TO "service_role";

GRANT TRUNCATE ON public."usuario_rol" TO "service_role";

GRANT REFERENCES ON public."usuario_rol" TO "service_role";

GRANT TRIGGER ON public."usuario_rol" TO "service_role";

GRANT INSERT ON public."detalle_venta_lote" TO "anon";

GRANT SELECT ON public."detalle_venta_lote" TO "anon";

GRANT UPDATE ON public."detalle_venta_lote" TO "anon";

GRANT DELETE ON public."detalle_venta_lote" TO "anon";

GRANT TRUNCATE ON public."detalle_venta_lote" TO "anon";

GRANT REFERENCES ON public."detalle_venta_lote" TO "anon";

GRANT TRIGGER ON public."detalle_venta_lote" TO "anon";

GRANT INSERT ON public."detalle_venta_lote" TO "authenticated";

GRANT SELECT ON public."detalle_venta_lote" TO "authenticated";

GRANT UPDATE ON public."detalle_venta_lote" TO "authenticated";

GRANT DELETE ON public."detalle_venta_lote" TO "authenticated";

GRANT TRUNCATE ON public."detalle_venta_lote" TO "authenticated";

GRANT REFERENCES ON public."detalle_venta_lote" TO "authenticated";

GRANT TRIGGER ON public."detalle_venta_lote" TO "authenticated";

GRANT INSERT ON public."detalle_venta_lote" TO "service_role";

GRANT SELECT ON public."detalle_venta_lote" TO "service_role";

GRANT UPDATE ON public."detalle_venta_lote" TO "service_role";

GRANT DELETE ON public."detalle_venta_lote" TO "service_role";

GRANT TRUNCATE ON public."detalle_venta_lote" TO "service_role";

GRANT REFERENCES ON public."detalle_venta_lote" TO "service_role";

GRANT TRIGGER ON public."detalle_venta_lote" TO "service_role";

GRANT INSERT ON public."rol_permiso" TO "anon";

GRANT SELECT ON public."rol_permiso" TO "anon";

GRANT UPDATE ON public."rol_permiso" TO "anon";

GRANT DELETE ON public."rol_permiso" TO "anon";

GRANT TRUNCATE ON public."rol_permiso" TO "anon";

GRANT REFERENCES ON public."rol_permiso" TO "anon";

GRANT TRIGGER ON public."rol_permiso" TO "anon";

GRANT INSERT ON public."rol_permiso" TO "authenticated";

GRANT SELECT ON public."rol_permiso" TO "authenticated";

GRANT UPDATE ON public."rol_permiso" TO "authenticated";

GRANT DELETE ON public."rol_permiso" TO "authenticated";

GRANT TRUNCATE ON public."rol_permiso" TO "authenticated";

GRANT REFERENCES ON public."rol_permiso" TO "authenticated";

GRANT TRIGGER ON public."rol_permiso" TO "authenticated";

GRANT INSERT ON public."rol_permiso" TO "service_role";

GRANT SELECT ON public."rol_permiso" TO "service_role";

GRANT UPDATE ON public."rol_permiso" TO "service_role";

GRANT DELETE ON public."rol_permiso" TO "service_role";

GRANT TRUNCATE ON public."rol_permiso" TO "service_role";

GRANT REFERENCES ON public."rol_permiso" TO "service_role";

GRANT TRIGGER ON public."rol_permiso" TO "service_role";

GRANT INSERT ON public."permisos" TO "anon";

GRANT SELECT ON public."permisos" TO "anon";

GRANT UPDATE ON public."permisos" TO "anon";

GRANT DELETE ON public."permisos" TO "anon";

GRANT TRUNCATE ON public."permisos" TO "anon";

GRANT REFERENCES ON public."permisos" TO "anon";

GRANT TRIGGER ON public."permisos" TO "anon";

GRANT INSERT ON public."permisos" TO "authenticated";

GRANT SELECT ON public."permisos" TO "authenticated";

GRANT UPDATE ON public."permisos" TO "authenticated";

GRANT DELETE ON public."permisos" TO "authenticated";

GRANT TRUNCATE ON public."permisos" TO "authenticated";

GRANT REFERENCES ON public."permisos" TO "authenticated";

GRANT TRIGGER ON public."permisos" TO "authenticated";

GRANT INSERT ON public."permisos" TO "service_role";

GRANT SELECT ON public."permisos" TO "service_role";

GRANT UPDATE ON public."permisos" TO "service_role";

GRANT DELETE ON public."permisos" TO "service_role";

GRANT TRUNCATE ON public."permisos" TO "service_role";

GRANT REFERENCES ON public."permisos" TO "service_role";

GRANT TRIGGER ON public."permisos" TO "service_role";

GRANT INSERT ON public."historial_acciones" TO "service_role";

GRANT SELECT ON public."historial_acciones" TO "service_role";

GRANT INSERT ON public."v_usuario_permisos" TO "anon";

GRANT SELECT ON public."v_usuario_permisos" TO "anon";

GRANT UPDATE ON public."v_usuario_permisos" TO "anon";

GRANT DELETE ON public."v_usuario_permisos" TO "anon";

GRANT TRUNCATE ON public."v_usuario_permisos" TO "anon";

GRANT REFERENCES ON public."v_usuario_permisos" TO "anon";

GRANT TRIGGER ON public."v_usuario_permisos" TO "anon";

GRANT INSERT ON public."v_usuario_permisos" TO "authenticated";

GRANT SELECT ON public."v_usuario_permisos" TO "authenticated";

GRANT UPDATE ON public."v_usuario_permisos" TO "authenticated";

GRANT DELETE ON public."v_usuario_permisos" TO "authenticated";

GRANT TRUNCATE ON public."v_usuario_permisos" TO "authenticated";

GRANT REFERENCES ON public."v_usuario_permisos" TO "authenticated";

GRANT TRIGGER ON public."v_usuario_permisos" TO "authenticated";

GRANT INSERT ON public."v_usuario_permisos" TO "service_role";

GRANT SELECT ON public."v_usuario_permisos" TO "service_role";

GRANT UPDATE ON public."v_usuario_permisos" TO "service_role";

GRANT DELETE ON public."v_usuario_permisos" TO "service_role";

GRANT TRUNCATE ON public."v_usuario_permisos" TO "service_role";

GRANT REFERENCES ON public."v_usuario_permisos" TO "service_role";

GRANT TRIGGER ON public."v_usuario_permisos" TO "service_role";

GRANT INSERT ON public."productos" TO "anon";

GRANT SELECT ON public."productos" TO "anon";

GRANT UPDATE ON public."productos" TO "anon";

GRANT DELETE ON public."productos" TO "anon";

GRANT TRUNCATE ON public."productos" TO "anon";

GRANT REFERENCES ON public."productos" TO "anon";

GRANT TRIGGER ON public."productos" TO "anon";

GRANT INSERT ON public."productos" TO "authenticated";

GRANT SELECT ON public."productos" TO "authenticated";

GRANT UPDATE ON public."productos" TO "authenticated";

GRANT DELETE ON public."productos" TO "authenticated";

GRANT TRUNCATE ON public."productos" TO "authenticated";

GRANT REFERENCES ON public."productos" TO "authenticated";

GRANT TRIGGER ON public."productos" TO "authenticated";

GRANT INSERT ON public."productos" TO "service_role";

GRANT SELECT ON public."productos" TO "service_role";

GRANT UPDATE ON public."productos" TO "service_role";

GRANT DELETE ON public."productos" TO "service_role";

GRANT TRUNCATE ON public."productos" TO "service_role";

GRANT REFERENCES ON public."productos" TO "service_role";

GRANT TRIGGER ON public."productos" TO "service_role";

GRANT INSERT ON public."categorias" TO "anon";

GRANT SELECT ON public."categorias" TO "anon";

GRANT UPDATE ON public."categorias" TO "anon";

GRANT DELETE ON public."categorias" TO "anon";

GRANT TRUNCATE ON public."categorias" TO "anon";

GRANT REFERENCES ON public."categorias" TO "anon";

GRANT TRIGGER ON public."categorias" TO "anon";

GRANT INSERT ON public."categorias" TO "authenticated";

GRANT SELECT ON public."categorias" TO "authenticated";

GRANT UPDATE ON public."categorias" TO "authenticated";

GRANT DELETE ON public."categorias" TO "authenticated";

GRANT TRUNCATE ON public."categorias" TO "authenticated";

GRANT REFERENCES ON public."categorias" TO "authenticated";

GRANT TRIGGER ON public."categorias" TO "authenticated";

GRANT INSERT ON public."categorias" TO "service_role";

GRANT SELECT ON public."categorias" TO "service_role";

GRANT UPDATE ON public."categorias" TO "service_role";

GRANT DELETE ON public."categorias" TO "service_role";

GRANT TRUNCATE ON public."categorias" TO "service_role";

GRANT REFERENCES ON public."categorias" TO "service_role";

GRANT TRIGGER ON public."categorias" TO "service_role";

GRANT INSERT ON public."marcas" TO "anon";

GRANT SELECT ON public."marcas" TO "anon";

GRANT UPDATE ON public."marcas" TO "anon";

GRANT DELETE ON public."marcas" TO "anon";

GRANT TRUNCATE ON public."marcas" TO "anon";

GRANT REFERENCES ON public."marcas" TO "anon";

GRANT TRIGGER ON public."marcas" TO "anon";

GRANT INSERT ON public."marcas" TO "authenticated";

GRANT SELECT ON public."marcas" TO "authenticated";

GRANT UPDATE ON public."marcas" TO "authenticated";

GRANT DELETE ON public."marcas" TO "authenticated";

GRANT TRUNCATE ON public."marcas" TO "authenticated";

GRANT REFERENCES ON public."marcas" TO "authenticated";

GRANT TRIGGER ON public."marcas" TO "authenticated";

GRANT INSERT ON public."marcas" TO "service_role";

GRANT SELECT ON public."marcas" TO "service_role";

GRANT UPDATE ON public."marcas" TO "service_role";

GRANT DELETE ON public."marcas" TO "service_role";

GRANT TRUNCATE ON public."marcas" TO "service_role";

GRANT REFERENCES ON public."marcas" TO "service_role";

GRANT TRIGGER ON public."marcas" TO "service_role";

GRANT INSERT ON public."proveedor" TO "anon";

GRANT SELECT ON public."proveedor" TO "anon";

GRANT UPDATE ON public."proveedor" TO "anon";

GRANT DELETE ON public."proveedor" TO "anon";

GRANT TRUNCATE ON public."proveedor" TO "anon";

GRANT REFERENCES ON public."proveedor" TO "anon";

GRANT TRIGGER ON public."proveedor" TO "anon";

GRANT INSERT ON public."proveedor" TO "authenticated";

GRANT SELECT ON public."proveedor" TO "authenticated";

GRANT UPDATE ON public."proveedor" TO "authenticated";

GRANT DELETE ON public."proveedor" TO "authenticated";

GRANT TRUNCATE ON public."proveedor" TO "authenticated";

GRANT REFERENCES ON public."proveedor" TO "authenticated";

GRANT TRIGGER ON public."proveedor" TO "authenticated";

GRANT INSERT ON public."proveedor" TO "service_role";

GRANT SELECT ON public."proveedor" TO "service_role";

GRANT UPDATE ON public."proveedor" TO "service_role";

GRANT DELETE ON public."proveedor" TO "service_role";

GRANT TRUNCATE ON public."proveedor" TO "service_role";

GRANT REFERENCES ON public."proveedor" TO "service_role";

GRANT TRIGGER ON public."proveedor" TO "service_role";

GRANT INSERT ON public."productos_list_view" TO "anon";

GRANT SELECT ON public."productos_list_view" TO "anon";

GRANT UPDATE ON public."productos_list_view" TO "anon";

GRANT DELETE ON public."productos_list_view" TO "anon";

GRANT TRUNCATE ON public."productos_list_view" TO "anon";

GRANT REFERENCES ON public."productos_list_view" TO "anon";

GRANT TRIGGER ON public."productos_list_view" TO "anon";

GRANT INSERT ON public."productos_list_view" TO "authenticated";

GRANT SELECT ON public."productos_list_view" TO "authenticated";

GRANT UPDATE ON public."productos_list_view" TO "authenticated";

GRANT DELETE ON public."productos_list_view" TO "authenticated";

GRANT TRUNCATE ON public."productos_list_view" TO "authenticated";

GRANT REFERENCES ON public."productos_list_view" TO "authenticated";

GRANT TRIGGER ON public."productos_list_view" TO "authenticated";

GRANT INSERT ON public."productos_list_view" TO "service_role";

GRANT SELECT ON public."productos_list_view" TO "service_role";

GRANT UPDATE ON public."productos_list_view" TO "service_role";

GRANT DELETE ON public."productos_list_view" TO "service_role";

GRANT TRUNCATE ON public."productos_list_view" TO "service_role";

GRANT REFERENCES ON public."productos_list_view" TO "service_role";

GRANT TRIGGER ON public."productos_list_view" TO "service_role";

GRANT INSERT ON public."usuarios" TO "anon";

GRANT SELECT ON public."usuarios" TO "anon";

GRANT UPDATE ON public."usuarios" TO "anon";

GRANT DELETE ON public."usuarios" TO "anon";

GRANT TRUNCATE ON public."usuarios" TO "anon";

GRANT REFERENCES ON public."usuarios" TO "anon";

GRANT TRIGGER ON public."usuarios" TO "anon";

GRANT INSERT ON public."usuarios" TO "authenticated";

GRANT SELECT ON public."usuarios" TO "authenticated";

GRANT UPDATE ON public."usuarios" TO "authenticated";

GRANT DELETE ON public."usuarios" TO "authenticated";

GRANT TRUNCATE ON public."usuarios" TO "authenticated";

GRANT REFERENCES ON public."usuarios" TO "authenticated";

GRANT TRIGGER ON public."usuarios" TO "authenticated";

GRANT INSERT ON public."usuarios" TO "service_role";

GRANT SELECT ON public."usuarios" TO "service_role";

GRANT UPDATE ON public."usuarios" TO "service_role";

GRANT DELETE ON public."usuarios" TO "service_role";

GRANT TRUNCATE ON public."usuarios" TO "service_role";

GRANT REFERENCES ON public."usuarios" TO "service_role";

GRANT TRIGGER ON public."usuarios" TO "service_role";

GRANT INSERT ON public."detalle_venta" TO "anon";

GRANT SELECT ON public."detalle_venta" TO "anon";

GRANT UPDATE ON public."detalle_venta" TO "anon";

GRANT DELETE ON public."detalle_venta" TO "anon";

GRANT TRUNCATE ON public."detalle_venta" TO "anon";

GRANT REFERENCES ON public."detalle_venta" TO "anon";

GRANT TRIGGER ON public."detalle_venta" TO "anon";

GRANT INSERT ON public."detalle_venta" TO "authenticated";

GRANT SELECT ON public."detalle_venta" TO "authenticated";

GRANT UPDATE ON public."detalle_venta" TO "authenticated";

GRANT DELETE ON public."detalle_venta" TO "authenticated";

GRANT TRUNCATE ON public."detalle_venta" TO "authenticated";

GRANT REFERENCES ON public."detalle_venta" TO "authenticated";

GRANT TRIGGER ON public."detalle_venta" TO "authenticated";

GRANT INSERT ON public."detalle_venta" TO "service_role";

GRANT SELECT ON public."detalle_venta" TO "service_role";

GRANT UPDATE ON public."detalle_venta" TO "service_role";

GRANT DELETE ON public."detalle_venta" TO "service_role";

GRANT TRUNCATE ON public."detalle_venta" TO "service_role";

GRANT REFERENCES ON public."detalle_venta" TO "service_role";

GRANT TRIGGER ON public."detalle_venta" TO "service_role";

GRANT INSERT ON public."roles" TO "anon";

GRANT SELECT ON public."roles" TO "anon";

GRANT UPDATE ON public."roles" TO "anon";

GRANT DELETE ON public."roles" TO "anon";

GRANT TRUNCATE ON public."roles" TO "anon";

GRANT REFERENCES ON public."roles" TO "anon";

GRANT TRIGGER ON public."roles" TO "anon";

GRANT INSERT ON public."roles" TO "authenticated";

GRANT SELECT ON public."roles" TO "authenticated";

GRANT UPDATE ON public."roles" TO "authenticated";

GRANT DELETE ON public."roles" TO "authenticated";

GRANT TRUNCATE ON public."roles" TO "authenticated";

GRANT REFERENCES ON public."roles" TO "authenticated";

GRANT TRIGGER ON public."roles" TO "authenticated";

GRANT INSERT ON public."roles" TO "service_role";

GRANT SELECT ON public."roles" TO "service_role";

GRANT UPDATE ON public."roles" TO "service_role";

GRANT DELETE ON public."roles" TO "service_role";

GRANT TRUNCATE ON public."roles" TO "service_role";

GRANT REFERENCES ON public."roles" TO "service_role";

GRANT TRIGGER ON public."roles" TO "service_role";

GRANT INSERT ON public."venta" TO "anon";

GRANT SELECT ON public."venta" TO "anon";

GRANT UPDATE ON public."venta" TO "anon";

GRANT DELETE ON public."venta" TO "anon";

GRANT TRUNCATE ON public."venta" TO "anon";

GRANT REFERENCES ON public."venta" TO "anon";

GRANT TRIGGER ON public."venta" TO "anon";

GRANT INSERT ON public."venta" TO "authenticated";

GRANT SELECT ON public."venta" TO "authenticated";

GRANT UPDATE ON public."venta" TO "authenticated";

GRANT DELETE ON public."venta" TO "authenticated";

GRANT TRUNCATE ON public."venta" TO "authenticated";

GRANT REFERENCES ON public."venta" TO "authenticated";

GRANT TRIGGER ON public."venta" TO "authenticated";

GRANT INSERT ON public."venta" TO "service_role";

GRANT SELECT ON public."venta" TO "service_role";

GRANT UPDATE ON public."venta" TO "service_role";

GRANT DELETE ON public."venta" TO "service_role";

GRANT TRUNCATE ON public."venta" TO "service_role";

GRANT REFERENCES ON public."venta" TO "service_role";

GRANT TRIGGER ON public."venta" TO "service_role";

GRANT INSERT ON public."detalle_compra" TO "anon";

GRANT SELECT ON public."detalle_compra" TO "anon";

GRANT UPDATE ON public."detalle_compra" TO "anon";

GRANT DELETE ON public."detalle_compra" TO "anon";

GRANT TRUNCATE ON public."detalle_compra" TO "anon";

GRANT REFERENCES ON public."detalle_compra" TO "anon";

GRANT TRIGGER ON public."detalle_compra" TO "anon";

GRANT INSERT ON public."detalle_compra" TO "authenticated";

GRANT SELECT ON public."detalle_compra" TO "authenticated";

GRANT UPDATE ON public."detalle_compra" TO "authenticated";

GRANT DELETE ON public."detalle_compra" TO "authenticated";

GRANT TRUNCATE ON public."detalle_compra" TO "authenticated";

GRANT REFERENCES ON public."detalle_compra" TO "authenticated";

GRANT TRIGGER ON public."detalle_compra" TO "authenticated";

GRANT INSERT ON public."detalle_compra" TO "service_role";

GRANT SELECT ON public."detalle_compra" TO "service_role";

GRANT UPDATE ON public."detalle_compra" TO "service_role";

GRANT DELETE ON public."detalle_compra" TO "service_role";

GRANT TRUNCATE ON public."detalle_compra" TO "service_role";

GRANT REFERENCES ON public."detalle_compra" TO "service_role";

GRANT TRIGGER ON public."detalle_compra" TO "service_role";

GRANT INSERT ON public."compra" TO "anon";

GRANT SELECT ON public."compra" TO "anon";

GRANT UPDATE ON public."compra" TO "anon";

GRANT DELETE ON public."compra" TO "anon";

GRANT TRUNCATE ON public."compra" TO "anon";

GRANT REFERENCES ON public."compra" TO "anon";

GRANT TRIGGER ON public."compra" TO "anon";

GRANT INSERT ON public."compra" TO "authenticated";

GRANT SELECT ON public."compra" TO "authenticated";

GRANT UPDATE ON public."compra" TO "authenticated";

GRANT DELETE ON public."compra" TO "authenticated";

GRANT TRUNCATE ON public."compra" TO "authenticated";

GRANT REFERENCES ON public."compra" TO "authenticated";

GRANT TRIGGER ON public."compra" TO "authenticated";

GRANT INSERT ON public."compra" TO "service_role";

GRANT SELECT ON public."compra" TO "service_role";

GRANT UPDATE ON public."compra" TO "service_role";

GRANT DELETE ON public."compra" TO "service_role";

GRANT TRUNCATE ON public."compra" TO "service_role";

GRANT REFERENCES ON public."compra" TO "service_role";

GRANT TRIGGER ON public."compra" TO "service_role";

-- Permisos explícitos de service_role reportados por el inventario.
GRANT EXECUTE ON FUNCTION public.cambiar_estado_compra(p_idcompra uuid, p_estado compra_estado) TO service_role;
GRANT EXECUTE ON FUNCTION public.cambiar_estado_venta(p_idventa uuid, p_estado venta_estado) TO service_role;
GRANT EXECUTE ON FUNCTION public.dashboard_inicial(p_reportes boolean, p_ventas boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.iniciar_sesion_usuario(p_uidauth text, p_email text) TO service_role;
GRANT EXECUTE ON FUNCTION public.obtener_accesos_usuario(p_idusuario text) TO service_role;
GRANT EXECUTE ON FUNCTION public.recalcular_total_compra(p_idcompra uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.recalcular_total_venta(p_idventa uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.registrar_venta_completa_atomica(p_items jsonb, p_fechaventa timestamp with time zone, p_idusuario uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.registrar_venta_completa_atomica(p_payload jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.set_updated_at() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_bloquear_detalle_compra_si_completada() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_bloquear_detalle_compra_si_compra_no_pendiente() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_bloquear_detalle_venta_si_completada() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_detalle_compra_recalcular_total() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_detalle_venta_recalcular_total() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_normalizar_permiso() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_normalizar_rol() TO service_role;
GRANT EXECUTE ON FUNCTION public.trg_normalizar_usuario() TO service_role;
