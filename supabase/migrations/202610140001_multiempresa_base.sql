-- Fase 1: estructura aditiva. No habilita todavía aislamiento del negocio.
-- Aplicar únicamente como parte del despliegue multiempresa coordinado.
BEGIN;

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
COMMIT;
