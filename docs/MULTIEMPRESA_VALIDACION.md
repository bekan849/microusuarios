# Validación local — 14 de octubre de 2026

No se utilizaron datos ni credenciales reales para ejecutar las pruebas.

| Componente | Comprobación | Resultado |
| --- | --- | --- |
| Usuarios | TypeScript sin emisión | Correcto |
| Usuarios | auth-session, audit-sql, audit y tres suites multiempresa | 40 pruebas aprobadas |
| Productos | TypeScript sin emisión | Correcto |
| Productos | api y atomic-sale | 19 pruebas aprobadas |
| Frontend | Compilación TypeScript y Vite | Correcto; advertencias CSS de simplebar y tamaño de gráficos |
| Frontend | transaction-drafts, stock-events, session-cache y dashboard-view | 25 pruebas aprobadas |

El instalador completo se ejecutó sobre el esquema entregado, reconstruido en
PGlite con datos ficticios. Se conservaron campos históricos y se comprobaron
restricciones cruzadas, permisos públicos, creación de membresía individual,
ventas y dashboard con service_role y revocación de accesos.

La revisión visual local usó un servidor simulado: selector de dos empresas,
cabeceras distintas y dos pestañas independientes. No equivale a probar el
inicio de sesión contra Supabase/PostgREST desplegado.

Las pruebas HTTP locales requieren permiso para abrir conexiones al servidor de
prueba. La primera ejecución restringida falló con fetch failed; al ejecutarlas
con acceso local autorizado, la suite completa pasó.

Para atomic-sale se utilizó la dependencia PGlite instalada en microusuarios,
mediante NODE_PATH solo en el proceso de prueba. No se instalaron dependencias
ni se cambiaron claves en producción.

Pendientes fuera del entorno local: respaldo/restauración verificable, instalación
SQL, despliegue coordinado y comprobaciones del sitio real descritas en la guía.
