# Guía de trabajo para microusuarios

## Alcance y arquitectura

- Backend de usuarios de SIS-STOCK: TypeScript estricto, Express 5, Supabase y JWT.
- `src/server.ts` carga el entorno y arranca el servidor; `src/app.ts` monta rutas y middlewares.
- `src/routes`, `src/controllers` y `src/services` contienen rutas, controladores y acceso a datos. Sigue los patrones del módulo que estés modificando.
- `src/middlewares` contiene autenticación, autorización, auditoría y manejo de errores.
- `src/config/env.ts` centraliza la configuración; `src/lib/supabase.ts` crea los clientes de Supabase.
- `supabase/migrations` contiene las migraciones SQL; `tests` contiene pruebas con `node:test`.
- `src` es el código activo. `dist` es salida generada y `.codex-work` contiene material auxiliar, copias y trabajo previo: no los uses como fuente principal ni los edites como implementación.
- `../microproductos` es otro servicio. Comprueba los contratos compartidos cuando una tarea afecte a ambos; limita las modificaciones al alcance pedido.

## Comandos y validación

- Desarrollo: `npm run dev`.
- Compilación: `npm run build`.
- Arranque del compilado: `npm start`.
- Comprobación de tipos sin generar archivos: `npx tsc --noEmit`.
- Pruebas de auditoría del backend: `node --test tests/audit.test.cjs`.
- Instalación reproducible: `npm ci` (incluye dependencias de desarrollo).
- Suite del backend: `npm test`; usa PGlite en memoria y Supabase simulado, sin otro repositorio ni credenciales reales.
- Pruebas SQL y de sesiones: `node --test tests/auth-session.test.cjs tests/audit-sql.test.cjs`; PGlite está declarado como dependencia de desarrollo.
- Comprobación de tipos: `npm run typecheck`.
- Prueba opcional del frontend: `npm run test:presentation`, con `FRONTEND_ROOT` apuntando a su checkout. Consulta `tests/README.md`. No forma parte de la suite del backend.
- Ejecuta las pruebas pertinentes al cambio y comunica comandos, resultados y cualquier comprobación pendiente.
- Para cambios de TypeScript, comprueba tipos y comportamiento afectado. Para cambios SQL, revisa las pruebas de permisos y sesiones correspondientes. Los cambios solo de documentación no necesitan ejecutar toda la suite.

## Contratos que deben preservarse

- Conserva rutas públicas, formatos de respuesta y códigos de estado, salvo que la tarea pida cambiarlos.
- En rutas privadas, valida identidad y permisos en el servidor mediante los middlewares existentes; no confíes en roles o identidades enviados en el cuerpo de la petición.
- Mantén las restricciones de usuarios bloqueados y la actualización de permisos al consultar accesos.
- La auditoría debe excluir contraseñas, tokens y claves. Conserva la lista explícita de campos admitidos y la inmutabilidad del historial.
- Si una operación de negocio ya se confirmó y falla guardar su auditoría, no la repitas ni la presentes como una operación de negocio fallida.
- El respaldo de RPC en `src/utils/rpc.ts` se limita a `PGRST202`; no lo amplíes para ocultar errores distintos.
- Prepara cambios de esquema en migraciones y comprueba su compatibilidad. Diferencia archivos SQL preparados de migraciones realmente aplicadas y de despliegues realizados.
- No expongas valores de `.env`, JWT ni claves de Supabase en respuestas, registros, pruebas o archivos versionados. Usa valores ficticios en pruebas y ejemplos.

## Forma de trabajar

- Las instrucciones del usuario tienen prioridad sobre esta guía. Resuelve decisiones rutinarias dentro del alcance autorizado sin pedir confirmación repetida.
- Antes de editar, revisa el estado de Git y el código relacionado; conserva cambios existentes del usuario.
- Haz cambios concretos y revisables. Evita refactorizaciones ajenas a la tarea.
- Usa casos representativos de sesión, permisos y auditoría para evaluar cambios en esas áreas.
- Responde en español indicando el resultado, la validación y las limitaciones reales. No afirmes que una prueba, migración o publicación se realizó sin evidencia.
- El modelo se selecciona en Codex. Esta guía no cambia el modelo de una tarea ni requiere integrar una API de IA en el backend.
