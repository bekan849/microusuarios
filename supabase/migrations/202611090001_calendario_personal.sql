-- Agenda personal por usuario y empresa. Aplicar antes de desplegar la API.
BEGIN;
CREATE TABLE public.calendario_eventos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempresa uuid NOT NULL,
  idusuario uuid NOT NULL,
  titulo text NOT NULL CHECK (length(trim(titulo)) BETWEEN 1 AND 160),
  descripcion text NOT NULL DEFAULT '' CHECK (length(descripcion) <= 2000),
  inicio timestamptz NOT NULL,
  fin timestamptz NOT NULL CHECK (fin > inicio),
  todo_el_dia boolean NOT NULL DEFAULT false,
  tipo text NOT NULL CHECK (tipo IN ('General','Pendiente','Completado','Importante')),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  FOREIGN KEY (idempresa,idusuario) REFERENCES public.empresa_usuario(idempresa,idusuario) ON DELETE RESTRICT,
  CHECK (NOT todo_el_dia OR (
    (inicio AT TIME ZONE 'UTC')::time = time '00:00:00' AND
    (fin AT TIME ZONE 'UTC')::time = time '00:00:00'))
);
CREATE INDEX calendario_propietario_fecha ON public.calendario_eventos(idempresa,idusuario,inicio);
ALTER TABLE public.calendario_eventos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.calendario_eventos FROM PUBLIC, anon, authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.calendario_eventos TO service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
