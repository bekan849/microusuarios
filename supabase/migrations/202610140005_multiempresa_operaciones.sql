-- RPC aisladas derivadas de las definiciones verificadas en Supabase.
BEGIN;
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
COMMIT;
