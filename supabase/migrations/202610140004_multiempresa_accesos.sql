BEGIN;
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
COMMIT;
