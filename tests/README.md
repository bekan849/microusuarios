# Ejecutar las pruebas

Usa Node.js 22 o posterior y npm. Desde la raíz de microusuarios:

```sh
npm ci
npm test
npm run typecheck
```

En PowerShell puedes usar `npm.cmd` en lugar de `npm` si el lanzador npm.ps1 falla. Por ejemplo, `npm.cmd test` y `npm.cmd run typecheck`. Este problema del lanzador se detectó en la computadora actual; npm.cmd está disponible y devuelve la versión correctamente.

`npm ci` instala las versiones del archivo package-lock.json, incluidas las dependencias de desarrollo. `npm test` ejecuta las pruebas de sesiones, migraciones SQL y auditoría de este backend. No necesita otro repositorio ni variables de entorno de producción.

Las pruebas SQL utilizan PostgreSQL en memoria con PGlite y las migraciones de este repositorio. Las pruebas HTTP levantan servidores temporales en 127.0.0.1 y usan clientes de Supabase simulados y credenciales ficticias. No requieren conexión a Supabase ni modifican una base real. El entorno debe permitir conexiones locales para las pruebas HTTP.

También puedes ejecutar un archivo concreto, por ejemplo:

```sh
node --test tests/audit.test.cjs
```

## Comprobación opcional de presentación del frontend

La función auditComparison pertenece al frontend, no a este backend. Sus seis pruebas se conservan en tests/integration/audit-presentation.cjs y se ejecutan por separado contra el código real del frontend, sin copiar su implementación como fixture.

Define FRONTEND_ROOT con la raíz de un checkout del frontend que contenga src/utils/audit-presentation.ts. Puede ser una ruta relativa a la carpeta desde la que ejecutas npm. Ejemplo en PowerShell, si ese checkout está en ../frontend:

```powershell
$env:FRONTEND_ROOT = '../frontend'
npm run test:presentation
```

Ejemplo en un shell POSIX:

```sh
FRONTEND_ROOT=../frontend npm run test:presentation
```

La comprobación opcional falla con un mensaje explícito si no está configurado el frontend. No se omiten pruebas silenciosamente. `npm test` cubre microusuarios y no certifica rutas de microproductos ni código del frontend.
