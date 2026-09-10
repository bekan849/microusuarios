# Historial de acciones de SIS-STOCK

Implementado en los archivos locales. No se ha ejecutado este SQL en Supabase ni desplegado los servicios desde esta tarea.

## Instalación

1. Entra en el panel de Supabase y abre el proyecto que usa el backend de usuarios. En **SQL Editor**, crea una consulta nueva, pega todo el contenido de `supabase/migrations/202609100001_historial_acciones.sql` y ejecútalo. Crea una tabla nueva e índices; no cambia el inventario.
2. Si productos utiliza OTRO proyecto de Supabase, ejecuta también ese mismo archivo en el proyecto de productos. Hay una copia en `microproductos/supabase/migrations`. Si ambos utilizan la misma base, basta ejecutarlo una vez.
3. En la base de usuarios, ejecuta `supabase/migrations/202609100002_permiso_auditoria.sql`. Crea el permiso `auditoria.ver` y lo asigna a los roles activos llamados `ADMINISTRADOR`. Utiliza los valores por defecto de los identificadores que ya usa la aplicación. Si aparece un error, no continúes hasta revisarlo.
4. Publica los cambios de usuarios, después productos y finalmente frontend, siguiendo `GUIA_INSTALACION_PASO_A_PASO.md`. Reiniciar una versión antigua no publica los archivos nuevos.
5. Cierra sesión y vuelve a entrar como administrador para recibir el nuevo permiso. Aparecerá **Historial de acciones** en el menú. Si tu rol tiene otro nombre, asigna `auditoria.ver` desde la gestión de roles/permisos utilizando una cuenta autorizada y vuelve a iniciar sesión.

Archivos SQL, rutas completas:

- [Tabla del historial](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/supabase/migrations/202609100001_historial_acciones.sql)
- [Permiso de consulta](C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios/supabase/migrations/202609100002_permiso_auditoria.sql)
- [Copia para la base de productos, si es distinta](C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos/supabase/migrations/202609100001_historial_acciones.sql)

## Cómo usarlo

Abre **Historial de acciones**. El selector **Área** permite consultar inventario/compras/ventas o usuarios/sesiones, incluso cuando los microservicios tienen bases diferentes. Selecciona los filtros y pulsa **Filtrar**. Puedes buscar por correo del responsable, acción, módulo, fechas y resultado. Se muestran 25 registros por página, ordenados del más reciente al más antiguo. Las fechas utilizan horario de Bolivia.

Abre una fila para ver el registro afectado, el usuario y los valores anteriores y posteriores disponibles. **Actualizar** vuelve a consultar; la pantalla no se actualiza automáticamente. No hay botones ni API para editar o borrar el historial.

## Qué se registra

- Inicios de sesión exitosos y fallidos. En los fallidos no se atribuye el intento al correo escrito, porque no es una identidad verificada.
- Cierre explícito mediante el botón de salir. Se envía antes de borrar la sesión local.
- Creación, edición, eliminación y cambios de estado de usuarios, roles, permisos, asignaciones, categorías, marcas, proveedores, productos, compras, ventas y sus detalles.
- Cambios de contraseña como acción, sin guardar la contraseña.
- Registro completo de compras/ventas, con el identificador devuelto y un resumen limitado de los campos de negocio solicitados.
- Errores devueltos por los controladores que alcanzaron la auditoría. No se afirma éxito cuando la operación devolvió un error.

El responsable viene del token verificado o del resultado verificado del inicio de sesión. Nunca se toma del usuario responsable enviado en el cuerpo de una petición. Los datos solicitados de una compra/venta se muestran explícitamente como datos de la solicitud, no como prueba de todos los efectos internos.

## Protección y límites

- Consulta restringida por `auditoria.ver`. Usuarios comprueba permisos actuales en la base; productos conserva el control con permisos del JWT existente. Retirar un permiso no invalida instantáneamente un JWT ya emitido en productos.
- La tabla está protegida con RLS, sin acceso para `anon` ni `authenticated`. El backend tiene SELECT/INSERT; UPDATE/DELETE/TRUNCATE quedan denegados y también bloqueados por un trigger. Un administrador de la base puede modificar el esquema; esto no es un registro criptográfico a prueba de administradores.
- Se guardan solo campos de negocio permitidos. No se guardan encabezados, tokens, claves, contraseñas ni mensajes de error completos. Los textos se limitan a 250 caracteres y las listas a 200 elementos; el detalle no es una copia completa de cada operación.
- Las lecturas anteriores y posteriores y la escritura del historial son operaciones separadas de la operación de negocio. Ante concurrencia pueden observar otro cambio cercano; no constituyen una comparación transaccional exacta. En los flujos antiguos que permiten cambios parciales, una respuesta de error tampoco prueba que no se haya escrito nada.
- Si la conexión falla o el proceso se interrumpe, puede faltar un evento. Un fallo detectado se informa en el log del backend y mediante `X-Audit-Status: unavailable`; el frontend muestra un aviso. No se devuelve un falso error de venta ni se reintenta automáticamente una operación de negocio ya completada. Para garantías de auditoría sin pérdidas se necesita integrar un registro transaccional en todos los flujos de escritura.
- El cierre de sesión es un aviso al servidor. Cerrar la pestaña, perder conexión o expirar la sesión no garantiza un evento de cierre. Se conserva el comportamiento previo de JWT: este endpoint registra la salida, no agrega revocación de tokens.
- No registra lecturas habituales, cambios hechos directamente en Supabase ni acciones de otros programas. Las peticiones rechazadas por autenticación/permisos antes del controlador no entran al historial de cambios. Tampoco reconstruye acciones anteriores a la instalación.

## Comprobación después de instalar

En un entorno de pruebas, entra como administrador, crea y edita una categoría o producto y comprueba las filas del historial. Haz un cambio de precio y abre la fila para ver antes/después. Registra una venta de prueba válida y otra que sea rechazada; comprueba el resultado de cada una. Sal y vuelve a entrar para ver ambas sesiones. Con un usuario sin `auditoria.ver`, el menú debe ocultarse y la API debe rechazar la consulta.

## Pruebas locales

Verificación realizada: compilación de usuarios, productos y frontend correcta; 44 pruebas automatizadas aprobadas (incluyen las regresiones previas y los contenedores de subpruebas). En el navegador se verificaron, con datos ficticios, la carga del historial, el detalle de precio anterior/nuevo, el filtro por correo, el estado vacío y el cambio al área de sesiones. No se hicieron operaciones de prueba sobre Supabase real. El frontend conserva advertencias previas de sus dependencias de gráficos/mapas y tamaño de algunos paquetes.

Desde microusuarios:

```powershell
node --test tests/audit.test.cjs
```

Para probar las migraciones con PostgreSQL embebido, sin tocar Supabase, establece `PGLITE_MODULE` a la instalación local de PGlite y ejecuta `node --test tests/audit-sql.test.cjs`. La prueba crea su propio esquema temporal y verifica permisos, bloqueo de cambios y aplicación repetida de las migraciones.
