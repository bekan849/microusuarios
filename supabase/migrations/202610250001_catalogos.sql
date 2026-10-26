-- Requiere las migraciones multiempresa. Ejecutar antes de desplegar el módulo.
BEGIN;
CREATE TABLE public.catalogos (
  idcatalogo uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempresa uuid NOT NULL REFERENCES public.empresas(idempresa) ON DELETE RESTRICT,
  nombre text NOT NULL CHECK (length(trim(nombre)) BETWEEN 1 AND 80),
  configuracion jsonb NOT NULL CHECK (jsonb_typeof(configuracion) = 'object'),
  actualizado_en timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX catalogos_empresa_fecha_idx ON public.catalogos(idempresa, actualizado_en DESC);
ALTER TABLE public.catalogos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.catalogos FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalogos TO service_role;
COMMIT;
