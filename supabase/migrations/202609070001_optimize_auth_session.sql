BEGIN;

CREATE INDEX IF NOT EXISTS usuarios_uidauth_lookup_idx ON public.usuarios (uidauth);
CREATE INDEX IF NOT EXISTS usuario_rol_activo_lookup_idx ON public.usuario_rol (idusuario, idrol) WHERE estado = true;
CREATE INDEX IF NOT EXISTS rol_permiso_lookup_idx ON public.rol_permiso (idrol, idpermiso);

CREATE OR REPLACE FUNCTION public.obtener_accesos_usuario(p_idusuario text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.iniciar_sesion_usuario(p_uidauth text, p_email text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
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
$$;

REVOKE ALL ON FUNCTION public.obtener_accesos_usuario(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.iniciar_sesion_usuario(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_accesos_usuario(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.iniciar_sesion_usuario(text, text) TO service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
