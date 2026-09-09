# Correcciones aplicadas a SIS-STOCK

Los cambios locales están aplicados en los dos microservicios y el frontend. No se ejecutaron migraciones en Supabase ni se desplegaron servicios.

## Resultado comprobado

- 31 pruebas aprobadas (28 escenarios y 3 pruebas contenedoras), sin fallos.
- TypeScript de ambos microservicios sin errores. Build del frontend correcto.
- JavaScript principal gzip: 804.22 KB antes y 81.99 KB después; reducción del 89.8%. Esta medida excluye CSS y chunks adicionales de cada pantalla.
- Dashboard y agrupación por día/mes verificados visualmente con datos ficticios.
- SQL probado en PostgreSQL embebido con un esquema mínimo; no contra la base real ni con múltiples conexiones simultáneas.
- El build conserva advertencias preexistentes de la plantilla: CSS, dependencia de mapas y tamaño del chunk de gráficos.

## Instalación pendiente

La dirección de Supabase configurada no se pudo resolver (ENOTFOUND). Primero revisar [estructura y triggers](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/checks/preflight.sql). Después instalar, en este orden:

1. [Sesión optimizada](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/supabase/migrations/202609070001_optimize_auth_session.sql).
2. [Dashboard e índices](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/migrations/202609070001_dashboard_performance.sql).
3. [Registro de venta atómico](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/migrations/202609070002_atomic_sale_registration.sql).

Instalar el SQL antes de desplegar/reiniciar el backend actualizado para ventas completas. Luego desplegar usuarios, productos y frontend. [Guía de instalación y límites](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/INSTALACION_CORRECCIONES.md).

La corrección transaccional cubre el registro completo de ventas. Las compras y los cambios de estado conservan sus caminos anteriores y necesitan una migración posterior a transacciones. El inventario histórico, incluidas las 10 unidades mencionadas en el chat compartido, no se modificó; hay un [diagnóstico de solo lectura](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/checks/inventario_diagnostico.sql).

## Archivos de usuarios

- [.gitignore](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/.gitignore)
- [src/app.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/src/app.ts)
- [src/services/auth.service.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/src/services/auth.service.ts)
- [src/services/user.service.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/src/services/user.service.ts)
- [src/utils/rpc.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/src/utils/rpc.ts)
- [supabase/migrations/202609070001_optimize_auth_session.sql](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/supabase/migrations/202609070001_optimize_auth_session.sql)
- [tests/auth-session.test.cjs](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/tests/auth-session.test.cjs)

## Archivos de microproductos

- [INSTALACION_CORRECCIONES.md](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/INSTALACION_CORRECCIONES.md) — nuevo
- [src/app.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/app.ts)
- [src/controllers/dashboard.controller.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/controllers/dashboard.controller.ts) — nuevo
- [src/controllers/venta.controller.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/controllers/venta.controller.ts)
- [src/middlewares/authorization.middleware.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/middlewares/authorization.middleware.ts)
- [src/routes/categoria.routes.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/routes/categoria.routes.ts)
- [src/routes/compra.routes.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/routes/compra.routes.ts)
- [src/routes/dashboard.routes.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/routes/dashboard.routes.ts) — nuevo
- [src/routes/marca.routes.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/routes/marca.routes.ts)
- [src/routes/producto.routes.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/routes/producto.routes.ts)
- [src/routes/proveedor.routes.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/routes/proveedor.routes.ts)
- [src/routes/venta.routes.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/routes/venta.routes.ts)
- [src/services/dashboard.service.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/services/dashboard.service.ts) — nuevo
- [src/services/detallecompra.service.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/services/detallecompra.service.ts)
- [src/services/reporte.service.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/services/reporte.service.ts)
- [src/services/venta.service.ts](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/src/services/venta.service.ts)
- [supabase/checks/inventario_diagnostico.sql](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/checks/inventario_diagnostico.sql) — nuevo
- [supabase/checks/preflight.sql](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/checks/preflight.sql) — nuevo
- [supabase/migrations/202609070001_dashboard_performance.sql](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/migrations/202609070001_dashboard_performance.sql) — nuevo
- [supabase/migrations/202609070002_atomic_sale_registration.sql](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/migrations/202609070002_atomic_sale_registration.sql) — nuevo
- [tests/api.test.cjs](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/tests/api.test.cjs) — nuevo
- [tests/atomic-sale.test.cjs](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/tests/atomic-sale.test.cjs) — nuevo
- [tests/fixture.sql](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/tests/fixture.sql) — nuevo

## Archivos de frontend

- [OPTIMIZACIONES.md](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/OPTIMIZACIONES.md) — nuevo
- [src/App.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/App.tsx)
- [src/components/ecommerce/EcommerceMetrics.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/components/ecommerce/EcommerceMetrics.tsx)
- [src/components/ecommerce/MonthlySalesChart.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/components/ecommerce/MonthlySalesChart.tsx)
- [src/components/ecommerce/MonthlyTarget.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/components/ecommerce/MonthlyTarget.tsx)
- [src/components/ecommerce/RecentOrders.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/components/ecommerce/RecentOrders.tsx)
- [src/context/AuthContext.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/context/AuthContext.tsx)
- [src/context/DashboardContext.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/context/DashboardContext.tsx) — nuevo
- [src/pages/Dashboard/Home.tsx](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/pages/Dashboard/Home.tsx)
- [src/services/api.ts](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/services/api.ts)
- [src/services/auth.service.ts](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/services/auth.service.ts)
- [src/services/dashboard-cache.ts](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/services/dashboard-cache.ts) — nuevo
- [src/services/dashboard.service.ts](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/services/dashboard.service.ts)
- [src/utils/session.ts](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/src/utils/session.ts) — nuevo
- [tests/session-cache.test.cjs](C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF/tests/session-cache.test.cjs) — nuevo

## Respaldo

Los originales modificados de productos y frontend están en [respaldo local](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/.codex-work/stock-corrections/backup-before-install). Las huellas antes/después se guardan en [registro de cambios](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/.codex-work/stock-corrections/changes.json). El área temporal está excluida de Git. Los cambios preexistentes en los ZIP se conservaron. No se tocaron credenciales ni archivos de configuración de despliegue.
