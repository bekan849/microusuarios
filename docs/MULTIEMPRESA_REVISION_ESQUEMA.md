# Revisión del inventario entregado el 14 de octubre de 2026

Nota de estado: este documento conserva el diagnóstico previo. La implementación
local posterior y el procedimiento de publicación están documentados en
[MULTIEMPRESA_INSTALACION.md](MULTIEMPRESA_INSTALACION.md). No se ha migrado producción.

Fuente: JSON entregado por el propietario, obtenido con la consulta de inventario.
No se accedió directamente a Supabase ni se modificaron datos de producción.
El archivo se pudo interpretar como JSON completo con sus nueve secciones.

## Alcance confirmado

15 tablas, 2 vistas, 135 columnas (incluidas las de vistas), 59 restricciones,
67 índices, 10 triggers y 19 firmas de funciones. No hay columna de empresa.
Los datos actuales se asignarán a COPA SPORT MOTOS; COPA SPORT BIKE comienza
vacía. La cuenta confirmada por el propietario administrará ambas.

| Grupo | Objetos | Adaptación prevista |
| --- | --- | --- |
| Catálogo | categorias, marcas, proveedor, productos | Empresa obligatoria, unicidad por empresa y relaciones de la misma empresa |
| Compras | compra, detalle_compra | Proveedor, producto, usuario y documento compatibles con la empresa |
| Ventas y lotes | venta, detalle_venta, detalle_venta_lote | Empresa coherente en documento, producto y lote; conservar PEPS |
| Accesos | usuarios, roles, usuario_rol, rol_permiso, permisos | Identidad compartida, membresía y roles por empresa; códigos de permisos globales |
| Auditoría | historial_acciones | Aislamiento conservando eventos y snapshots existentes |
| Vistas | productos_list_view, v_usuario_permisos | Incluir ámbito de empresa y revisar privilegios de la vista |

## Hallazgos que condicionan la migración

- RLS está desactivada en 14 de las 15 tablas; historial_acciones sí la tiene
  activada. No se reportan políticas en public.
- anon y authenticated tienen permisos amplios sobre esas 14 tablas y las dos
  vistas. Debe revisarse y cerrarse el acceso directo que no corresponda antes de
  habilitar una segunda empresa. El inventario no permite afirmar por sí solo
  qué endpoints están expuestos ni si se produjo acceso no autorizado.
- Hay dos sobrecargas de registrar_venta_completa_atomica: una con tres
  argumentos, SECURITY DEFINER y permisos para anon/authenticated; otra con
  p_payload jsonb, SECURITY INVOKER y permisos reportados solo para postgres y
  service_role. Cambiar únicamente la segunda dejaría sin revisar la primera.
- Los nombres de categorías, marcas y proveedores y los códigos de productos
  tienen unicidad global. Debe pasar a ser por empresa, conservando la regla de
  mayúsculas/minúsculas. productos tiene dos protecciones de unicidad del código.
- Los subtotales de detalle_compra y detalle_venta son columnas generadas. La
  migración y las operaciones no deben intentar escribir valores en ellas.
- Hay triggers que bloquean cambios en detalles de documentos completados y
  recalculan totales. Un UPDATE masivo de empresa necesita contemplar estos
  triggers; no puede tratarse como una actualización ordinaria del formulario.
- historial_acciones impide UPDATE, DELETE y TRUNCATE mediante un trigger por
  sentencia. Su asignación histórica requiere un procedimiento controlado sin
  perder ni modificar el contenido de los eventos.
- Las claves foráneas actuales verifican IDs, pero no empresa. En lotes también
  debe comprobarse que los detalles de compra y venta corresponden al producto.

## Información complementaria recibida

El propietario entregó el resultado de `multiempresa_definiciones.sql`:
19 definiciones de funciones, 2 vistas y 11 valores distribuidos en los cuatro
enums esperados. El JSON se pudo interpretar completo. No hace falta repetir
las consultas para comenzar la implementación.

### Decisiones derivadas de las definiciones

- La versión de venta con `p_payload jsonb` consume únicamente lotes de compras
  completadas y bloquea productos, lotes y compras. Es el contrato que invoca
  actualmente `microproductos/src/services/venta.service.ts`. La adaptación debe
  conservar estas garantías e incorporar empresa y actor verificados.
- La versión antigua con tres argumentos no filtra el estado de la compra al
  elegir lotes y usa SECURITY DEFINER. No debe quedar como una entrada global
  accesible después de la migración. Revisar dependencias antes de retirarla o
  revocar su ejecución.
- Las funciones cambiar_estado_compra y cambiar_estado_venta actualizan el stock
  general pero no sincronizan stockrestante y detalle_venta_lote. No reutilizarlas
  como si cubrieran por sí solas el flujo PEPS. El servicio de compras actual
  también modifica stockrestante; revisar el flujo completo antes de sustituirlo.
- El trigger activo de compras permite cambios de stockrestante en documentos
  completados, pero bloquea cambios de otros campos. El trigger de ventas bloquea
  cualquier UPDATE de detalles completados. Esto afecta la asignación histórica
  de empresa y requiere pruebas con documentos completados, no solo pendientes.
- Existe otra función de bloqueo de compras no pendientes, pero el inventario
  no muestra ningún trigger que la invoque. No confundir su existencia con una
  protección actualmente activa.
- Las dos vistas no incorporan empresa ni tienen opciones de seguridad
  configuradas. Deben revisarse junto con los permisos de acceso a tablas.
- Los estados son PENDIENTE/COMPLETADA/CANCELADA para compras y ventas,
  ACTIVO/INACTIVO para productos y ACTIVO/INACTIVO/BLOQUEADO para usuarios.
- Accesos, inicio de sesión y dashboard todavía consultan información global.
  Se conserva la validación de cuenta activa, pero los permisos deben calcularse
  por membresía y el dashboard por empresa autorizada.

Esta información permite reproducir la lógica desplegada en pruebas locales y preparar
una migración compatible. Aún no hay migración multiempresa aplicada ni cambios
de backend o frontend publicados. El inventario no sustituye un respaldo de los
datos antes del despliegue.
