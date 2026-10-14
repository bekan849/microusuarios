-- PREPARADO, NO APLICAR TODAVIA EN PRODUCCION.
-- Ejecutar después de la migración base, como parte del despliegue coordinado.
-- No asigna ni altera productos, compras, ventas, roles o historial.
BEGIN;
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
COMMIT;
