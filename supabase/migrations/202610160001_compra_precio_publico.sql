-- Ejecutar DESPUÉS de multiempresa y ANTES de publicar el backend de productos nuevo.
-- No volver a ejecutar MULTIEMPRESA_INSTALAR.sql.
BEGIN;
CREATE OR REPLACE FUNCTION public.registrar_compra_empresa(p_payload jsonb,p_idempresa uuid,p_idusuario uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE
  v_item jsonb; v_producto public.productos%ROWTYPE; v_compra public.compra%ROWTYPE;
  v_cantidad numeric; v_costo numeric; v_precio numeric(12,2); v_total numeric;
BEGIN
  PERFORM public.exigir_permiso_empresa(p_idusuario,p_idempresa,'compras.crear');
  IF jsonb_typeof(p_payload->'items') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'La compra debe tener productos';
  END IF;
  IF jsonb_array_length(p_payload->'items')=0 THEN RAISE EXCEPTION 'La compra debe tener productos'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_payload->'items') i GROUP BY (i->>'idproducto')::uuid HAVING count(*)>1) THEN
    RAISE EXCEPTION 'No se permiten productos repetidos';
  END IF;
  PERFORM 1 FROM public.proveedor WHERE idproveedor=(p_payload->>'idproveedor')::uuid AND idempresa=p_idempresa FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proveedor no disponible en esta empresa'; END IF;
  INSERT INTO public.compra(idempresa,idproveedor,idusuario,fechaingreso,estado,total)
  VALUES(p_idempresa,(p_payload->>'idproveedor')::uuid,p_idusuario,
    coalesce(nullif(p_payload->>'fechaingreso','')::timestamptz,now()),'PENDIENTE',0)
  RETURNING * INTO v_compra;

  -- Orden estable de bloqueo, compartido con las ventas por producto.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_payload->'items') ORDER BY value->>'idproducto' LOOP
    IF jsonb_typeof(v_item->'cantidad') IS DISTINCT FROM 'number' OR jsonb_typeof(v_item->'preciocosto') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'Completa cantidad y precio de compra';
    END IF;
    v_cantidad:=(v_item->>'cantidad')::numeric; v_costo:=(v_item->>'preciocosto')::numeric;
    IF v_cantidad<=0 OR v_cantidad<>trunc(v_cantidad) OR v_cantidad>2147483647 OR v_costo<0 THEN
      RAISE EXCEPTION 'Cantidad o precio de compra inválido';
    END IF;
    SELECT * INTO v_producto FROM public.productos WHERE idproducto=(v_item->>'idproducto')::uuid AND idempresa=p_idempresa FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Producto no disponible en esta empresa'; END IF;
    v_precio:=v_producto.precioventa;
    IF v_item ? 'precioventa' THEN
      PERFORM public.exigir_permiso_empresa(p_idusuario,p_idempresa,'productos.editar');
      IF jsonb_typeof(v_item->'precioventa') IS DISTINCT FROM 'number' OR (v_item->>'precioventa')::numeric<0 THEN
        RAISE EXCEPTION 'Precio al público inválido';
      END IF;
      IF jsonb_typeof(v_item->'precioventa_anterior') IS DISTINCT FROM 'number' THEN
        RAISE EXCEPTION 'Falta el precio anterior del producto; actualiza el catálogo';
      END IF;
      IF (v_item->>'precioventa_anterior')::numeric IS DISTINCT FROM v_producto.precioventa THEN
        RAISE EXCEPTION 'El precio al público cambió en otra operación. Actualiza el catálogo y revisa el precio';
      END IF;
      v_precio:=(v_item->>'precioventa')::numeric;
    END IF;
    INSERT INTO public.detalle_compra(idempresa,idcompra,idproducto,cantidad,preciocosto,stockrestante)
    VALUES(p_idempresa,v_compra.idcompra,v_producto.idproducto,v_cantidad::integer,v_costo,v_cantidad::integer);
    UPDATE public.productos SET stock=stock+v_cantidad::integer,estado='ACTIVO',precioventa=v_precio
    WHERE idempresa=p_idempresa AND idproducto=v_producto.idproducto;
    IF v_precio IS DISTINCT FROM v_producto.precioventa THEN
      INSERT INTO public.historial_acciones(id,idempresa,servicio,actor_id,actor_email,accion,recurso,registro_id,resultado,estado_http,antes,despues,detalles)
      SELECT gen_random_uuid(),p_idempresa,'productos',p_idusuario,u.email,'actualizar','productos',v_producto.idproducto::text,'exito',200,
        jsonb_build_object('precioventa',v_producto.precioventa),jsonb_build_object('precioventa',v_precio),
        jsonb_build_object('version_captura',2,'comparacion','registro','captura_antes',true,'captura_despues',true,
          'actor_nombre',concat_ws(' ',u.nombre,u.apellido),'idcompra',v_compra.idcompra,'origen','compra')
      FROM public.usuarios u WHERE u.idusuario=p_idusuario;
    END IF;
  END LOOP;
  SELECT sum(subtotal) INTO v_total FROM public.detalle_compra WHERE idempresa=p_idempresa AND idcompra=v_compra.idcompra;
  UPDATE public.compra SET total=v_total,estado='COMPLETADA' WHERE idempresa=p_idempresa AND idcompra=v_compra.idcompra RETURNING * INTO v_compra;
  RETURN to_jsonb(v_compra);
END;
$$;
REVOKE ALL ON FUNCTION public.registrar_compra_empresa(jsonb,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_compra_empresa(jsonb,uuid,uuid) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
