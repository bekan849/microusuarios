BEGIN;
-- Uses the existing defaults for permission and assignment primary keys.
INSERT INTO public.permisos(codigo, nombre, modulo, descripcion, estado)
SELECT 'auditoria.ver', 'Ver historial de acciones', 'auditoria', 'Consultar sesiones y cambios del sistema', true
WHERE NOT EXISTS (SELECT 1 FROM public.permisos WHERE lower(codigo) = 'auditoria.ver');
INSERT INTO public.rol_permiso(idrol, idpermiso)
SELECT r.idrol, p.idpermiso FROM public.roles r CROSS JOIN public.permisos p
WHERE upper(r.nombre) = 'ADMINISTRADOR' AND r.estado = true AND lower(p.codigo) = 'auditoria.ver'
AND NOT EXISTS (SELECT 1 FROM public.rol_permiso rp WHERE rp.idrol = r.idrol AND rp.idpermiso = p.idpermiso);
NOTIFY pgrst, 'reload schema';
COMMIT;
