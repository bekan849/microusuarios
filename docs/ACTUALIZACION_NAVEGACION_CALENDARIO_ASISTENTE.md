# Actualización de navegación, calendario y asistente

Fecha: 9 de noviembre de 2026.

## Cambios implementados

- Dashboard como primer acceso. Productos contiene consulta, catálogos, categorías y marcas. Compras y ventas tienen iconos propios. Usuarios contiene perfil, calendario, gestión de usuarios e historial. Reportes y Asistente están en Análisis y asistencia.
- Se conservan las rutas y sus permisos. Historial sigue sujeto a `auditoria.ver`, asignado al administrador por la migración existente; no se conceden permisos nuevos ni se modifican roles.
- Eliminado el bloque de próximos eventos de ejemplo.
- Agenda personal guardada en el servidor por usuario y empresa: crear, consultar, editar, eliminar, mover y redimensionar eventos. Eventos de todo el día o con hora; vistas mes, semana y agenda. Sin eventos ficticios.
- Reportes: período inicial del mes actual, accesos a hoy/mes/año, rango validado, período aplicado visible, protección frente a respuestas antiguas y consultas auxiliares según permisos. Tablas, tarjetas y gráfico muestran operaciones completadas. La etiqueta margen bruto refleja ventas menos costo de mercadería, sin presentarlo como utilidad neta.
- Asistente: búsqueda real por nombre/código usando la API de productos; captura de instrucciones por texto o dictado; fotos adjuntas/cámara compatible; borrador de producto o venta según permisos. Los lectores que actúan como teclado pueden introducir códigos en el campo dedicado.

## Activación del calendario

El código está preparado localmente. No se aplicó SQL a producción ni se publicó esta actualización.

1. Aplicar `supabase/migrations/202611090001_calendario_personal.sql` en la base de datos que ya tiene las migraciones multiempresa.
2. Compilar y desplegar microusuarios (`npm run build`). Mantener sus variables de entorno actuales.
3. Compilar y desplegar el frontend `C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF` (`npm run build`). `VITE_API_USUARIOS` debe seguir apuntando a la base `/api` de microusuarios.
4. Comprobar con una cuenta real: crear evento, recargar, editar y eliminar. Comprobar con otra cuenta y empresa que la agenda está aislada.

No hace falta cambiar microproductos para esta entrega. Antes de la migración y el despliegue de la API, la agenda mostrará un error explícito y no simulará un guardado local.

La agenda usa `/api/calendario`: GET con `desde`/`hasta` ISO y rango máximo de 370 días; POST para crear; PUT/DELETE por ID con versión para evitar sobrescribir cambios concurrentes. El final es exclusivo. En la interfaz, el último día de un evento de día completo se presenta incluido. Las horas se muestran en la zona del dispositivo.

La identidad proviene de la sesión validada, nunca del cuerpo del pedido. Cada operación revalida la membresía y bloqueos existentes. La tabla no es accesible directamente por anon/authenticated. La auditoría registra la acción y el identificador, sin copiar el título ni la descripción personal al historial administrativo.

## Revisión de reportes: siguientes mejoras recomendadas

Se revisó `microproductos/src/services/reporte.service.ts`. Hay riesgos pendientes del cálculo servidor que requieren una entrega dedicada:

1. **Totales completos:** las consultas actuales de ventas, compras, detalles y lotes no recorren páginas ni agregan en SQL. El límite de filas configurado en Supabase puede truncar resultados. Antes de utilizar reportes con grandes volúmenes, implementar agregación por empresa en SQL o paginación exhaustiva y probar más registros que el límite configurado.
2. **Coherencia temporal:** los cuatro endpoints consultan por separado; una venta registrada durante la carga puede generar diferencias temporales. Un endpoint de resumen consistente reduciría también consultas repetidas.
3. **Detalle paginado y exportación:** mantener totales completos en el servidor y paginar los movimientos. Exportar con los filtros aplicados, sin confundir una página visible con el conjunto total.
4. **Cobertura del costo:** distinguir costo real conocido de lotes sin costo registrado, en lugar de permitir que un costo faltante parezca cero sin indicarlo.
5. **Indicadores útiles:** margen porcentual, comparación con período anterior, productos más vendidos y stock inmovilizado. Las cuentas por cobrar/pagar y utilidad neta requieren primero registrar pagos y gastos; no deben deducirse de las compras y ventas solamente.

Los puntos anteriores son propuestas y hallazgos; no se afirma que hayan sido implementados en esta entrega. Se conserva el contrato actual de las APIs de reportes.

## Asistente: alcance actual y siguiente etapa

La interfaz está disponible en `/asistente`. La búsqueda funciona mediante la API existente. La captura de instrucciones no llama todavía a un modelo de IA ni crea productos o ventas. El borrador y las imágenes son temporales en la pantalla y se pierden al salir.

- El dictado depende de SpeechRecognition del navegador; en algunos navegadores el audio se procesa en un servicio en línea. Hay alternativa por teclado y se muestra esta condición junto al botón.
- La cámara usa captura de archivos donde el dispositivo la admita. Las fotos todavía no se interpretan y no hay decodificación de barras/QR desde imágenes.
- El lector externo funciona si actúa como teclado y entrega un código que la búsqueda de productos reconozca. No se ha incorporado un catálogo adicional de EAN/UPC ni una equivalencia automática con QR de terceros.

Para conectar IA: elegir proveedor/modelo, servicio backend para voz/visión e interpretación estructurada, herramientas limitadas por permisos y empresa, resolución de productos existentes y pantalla de revisión. Antes de ejecutar una venta, mostrar productos, cantidades y precios y solicitar confirmación explícita; usar la operación atómica existente y una clave de idempotencia para impedir duplicados. Guardar claves del proveedor solo en el backend. No dar al modelo acceso directo a la base de datos.

## Validación

- Backend: `npm run typecheck`; `npm test` (25 pruebas); aislamiento de empresa mediante `node --test tests/multiempresa-api.test.cjs`.
- Calendario: pruebas HTTP con Supabase simulado y SQL con PGlite, incluyendo restricciones, usuarios ajenos, empresa ajena, sesiones revocadas y conflictos de versión.
- Frontend: TypeScript y compilación de producción; `node --test tests/workflow.test.cjs` para navegación/permisos y fechas.
- Navegador de prueba con respuestas simuladas: crear/recargar/editar/eliminar evento; búsqueda por código; preparar borrador de venta; filtros y estado COMPLETADA en reportes; escritorio y móvil.
- No se probaron físicamente un micrófono, una cámara o un lector. No se usaron datos de producción. La compilación conserva advertencias de CSS y de tamaño de un paquete de gráficos preexistentes.

Referencias de implementación: [FullCalendar: final exclusivo](https://fullcalendar.io/docs/event-object), [revertir un arrastre fallido](https://fullcalendar.io/docs/eventDrop), [dictado del navegador](https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition), [captura de cámara](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/capture).
