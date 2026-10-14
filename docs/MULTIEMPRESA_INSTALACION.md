# Instalación de COPA SPORT MOTOS y COPA SPORT BIKE

## Qué está hecho y qué falta

El código y SQL están preparados y probados localmente con datos ficticios.
**Tu Supabase y tu sitio publicado todavía no se han actualizado con estos cambios.**
La página local de prueba usa datos ficticios; no representa el inventario real.
No hace falta comprar otro dominio ni crear otra base de producción para BIKE.

Se actualizarán juntos:

| Componente | Carpeta en tu computadora |
| --- | --- |
| Usuarios | C:/Users/Usuario/Escritorio/SIS-STOCK/microusuarios |
| Productos | C:/Users/Usuario/Escritorio/SIS-STOCK/microproductos |
| Frontend | C:/Users/Usuario/Downloads/SIS-STOCKF/SIS-STOCKF |

## 1. Preparar respaldo antes de cerrar la tienda

En Supabase, selecciona el proyecto correcto y revisa **Database → Backups**.
Comprueba qué respaldo puedes restaurar, su fecha y el procedimiento de recuperación.
Si tu plan no dispone de respaldo recuperable, prepara un respaldo lógico con
Supabase CLI siguiendo la [guía oficial](https://supabase.com/docs/guides/platform/backups).
La [guía de restauración](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)
explica la exportación de roles, esquema y datos. Exportar solamente un CSV de
productos NO respalda compras, lotes, usuarios, funciones ni permisos.

Valida la restauración en una base de prueba antes del cambio. No pruebes la
restauración sobre la tienda activa. Conserva también las versiones anteriores
de los tres proyectos y su configuración de despliegue. No pegues claves ni
contraseñas en el chat, repositorio o SQL Editor.

## 2. Dejar los tres componentes listos para publicar

Los archivos locales no se publican automáticamente por estar en Visual Studio.
Revisa los cambios y súbelos a los repositorios que usa tu alojamiento. En Render,
pausa temporalmente el despliegue automático para no publicar un backend aislado.
Los nombres exactos de tus servicios de Render no se han verificado en esta tarea.

En cada backend, la compilación es npm ci y npm run build; el arranque es npm start.
En el frontend, npm ci y npm run build; la carpeta publicada es dist.
En esta computadora el lanzador npm presenta un problema de instalación; las
comprobaciones locales se hicieron ejecutando directamente TypeScript y Vite con
Node. Esto no cambia los comandos del alojamiento si allí npm funciona.

Comprueba la configuración sin compartir sus valores:

- Ambos backends: misma SUPABASE_URL, clave de servidor correspondiente y mismo
  JWT_SECRET. Usuarios también necesita SUPABASE_ANON_KEY.
- Ambos backends: CORS_ORIGIN debe permitir la dirección de tu frontend.
- Frontend: VITE_API_USUARIOS y VITE_API_PRODUCTOS apuntan a los backends reales,
  nunca a 127.0.0.1. Ninguna clave service_role o JWT_SECRET debe estar en el frontend.

## 3. Cerrar temporalmente las operaciones

Pide a quienes usan la tienda que terminen o guarden sus borradores. Detén o
suspende **ambos backends antiguos** y bloquea el uso del frontend durante la ventana.
Confirma que no quedan instancias antiguas atendiendo peticiones. Registra los
recuentos de productos/compras/ventas y el stock actual para compararlos después.
No basta con cerrar tu propia pestaña si hay otros empleados conectados.

El esquema nuevo exige empresa: los servicios antiguos no son compatibles con él.
No vuelvas a arrancarlos después de instalar SQL nuevo.

## 4. Ejecutar un solo instalador en Supabase

1. En Visual Studio Code abre la carpeta microusuarios.
2. Abre supabase/install/MULTIEMPRESA_INSTALAR.sql.
3. Copia TODO el contenido del archivo.
4. En el panel del proyecto de Supabase abre **SQL Editor → New query**.
5. Pega el contenido completo y verifica que corresponde al proyecto de la tienda.
6. Ejecuta la consulta completa una sola vez, sin seleccionar fragmentos.
7. Al terminar sin errores deben aparecer COPA SPORT MOTOS y COPA SPORT BIKE activas.

El instalador agrupa las cinco migraciones en una transacción. Bloquea las tablas
mientras realiza el cambio, conserva recuentos y asigna lo anterior a motos.
Comprueba que bekanbk1@gmail.com existe como usuario ACTIVO con identificador de
autenticación. Crea las dos membresías y roles administrativos; no cambia su clave.
Si encuentra un administrador inactivo o una estructura incompatible, falla para
que se revise el caso. Si no logra tomar los bloqueos en 15 segundos, falla también.

**Si aparece cualquier error, no ejecutes el resto por separado ni borres tablas.**
La transacción no debe confirmarse parcialmente; ejecuta ROLLBACK si el editor
mantiene la transacción abierta, conserva el error completo y revisa la causa.
Si no sabes si hubo confirmación, consulta primero si ya existen public.empresas
con las dos filas. No repitas el instalador a ciegas: no está diseñado para reinstalarse.

No ejecutar también los archivos 202610140001 a 202610140005: ya están incluidos.
Si se usa Supabase CLI para gestionar migraciones, el responsable técnico debe
reconciliar el registro de migraciones antes de un futuro db push; SQL Editor no
actualiza ese registro automáticamente.

## 5. Desplegar y reiniciar

Manteniendo cerrada la operación al público:

1. Publica el backend actualizado de usuarios; espera compilación y arranque correctos.
2. Publica el backend actualizado de productos; espera compilación y arranque correctos.
3. Publica el frontend actualizado.
4. Abre el sitio, recarga e inicia sesión de nuevo. Las sesiones anteriores se rechazan.
5. Tu cuenta debe mostrar el selector con las dos empresas.

Si alguno falla, mantén el mantenimiento y revisa sus registros. No intentes
resolverlo volviendo solo a un backend antiguo contra la base ya migrada.

## 6. Comprobar antes de volver a operar

- En MOTOS: compara productos, stock, compras, ventas y eventos anteriores con
  los recuentos que guardaste. Revisa también un documento antiguo y sus detalles.
- En BIKE: el catálogo y los documentos deben estar vacíos. Tu cuenta y el rol
  administrador sí estarán disponibles, porque son necesarios para administrarla.
- Desde la cabecera usa Cambiar empresa. Abre BIKE en otra pestaña y comprueba
  que MOTOS sigue seleccionada en la pestaña original. Si el navegador bloquea
  la ventana, guarda el borrador y usa el enlace alternativo que aparece.
- Crea una categoría y un producto propios de BIKE; comprueba que no aparecen
  en MOTOS. Puedes usar un código que ya exista en MOTOS.
- Revisa que el historial de BIKE muestre su acción y el nombre del responsable.
- Guarda un borrador en cada empresa y recarga: cada uno debe recuperar el suyo.
- Realiza una primera compra y venta real controlada solo cuando las comprobaciones
  anteriores sean correctas; revisa cantidades, lotes y reportes de esa empresa.
  No generes ventas ficticias en la tienda real para borrarlas después.

Reabre el acceso al personal cuando los tres componentes funcionen coordinados.

## Añadir después un administrador solo para BIKE

Entra a BIKE → Usuarios, crea su cuenta y asígnale el rol ADMINISTRADOR de BIKE.
La cuenta nueva queda asociada solo a esa empresa. Comprueba sus accesos al entrar.
El alta de una cuenta nueva no sirve para invitar un correo que ya existe en otra
empresa: esa incorporación requiere una operación de membresía administrativa,
que aún no tiene pantalla. No crees cuentas duplicadas ni cambies identificadores a mano.

## Comportamiento y límites que debes conocer

- La selección y sesión viven por pestaña. Recargar conserva la sesión; cerrar
  la pestaña puede terminarla. Cerrar sesión afecta esa pestaña. Los borradores
  permanecen en ese navegador, separados por usuario y empresa; no son un respaldo
  en el servidor. Los borradores antiguos se recuperan únicamente en MOTOS.
- Suspender o quitar un usuario deshabilita su membresía en la empresa actual,
  conserva su identidad e historial y no suspende su acceso a la otra tienda.
  Una cuenta bloqueada globalmente sigue bloqueada.
- La identidad personal de una cuenta compartida es global. Un administrador
  de tienda no puede cambiar la contraseña/datos de otra cuenta multiempresa;
  el propio titular puede cambiar sus datos por los flujos autorizados existentes.
- Los códigos de permisos son un catálogo común de solo lectura. Los roles y
  sus asignaciones son independientes por empresa.
- La auditoría de negocio y de selección de empresa se consulta por empresa.
  Los eventos de autenticación anteriores a seleccionar empresa no aparecen
  en esos listados de tienda.
- BIKE usa su nombre en interfaz/PDF; aún no tiene logo, dirección o teléfono
  propios configurables desde una pantalla. No se copian contactos de MOTOS.
- Las ventas completas conservan la operación SQL atómica y PEPS. Los flujos
  existentes de compra y cambios de estado no se han convertido a una única
  transacción SQL en esta adaptación; conservan sus limitaciones previas.
- La clave privilegiada del backend omite RLS: la separación depende también
  del cliente de consultas con contexto autorizado y de las relaciones SQL.
  No añadir accesos directos privilegiados de negocio fuera de ese cliente.
- Las pruebas SQL usan PGlite y un esquema generado del inventario entregado.
  No sustituyen una comprobación en Supabase/PostgREST con la configuración real.
  No se ha probado ni aplicado el despliegue de producción en esta tarea.

## Si hay que recuperar la versión anterior

Antes de confirmar SQL, un fallo se resuelve con la reversión de la transacción.
Después de confirmar, no existe un script inverso automático que borre BIKE con
seguridad. Mantén detenidas las operaciones; restaura el respaldo validado y
las tres versiones compatibles de aplicación. Si ya hubo operaciones nuevas,
exporta y reconcilia esas operaciones antes de restaurar para no perderlas.
No vacíes tablas ni suprimas columnas para intentar volver atrás.

## Validación local y mantenimiento técnico

Desde microusuarios:

- node node_modules/typescript/bin/tsc --noEmit
- node --test tests/auth-session.test.cjs tests/audit-sql.test.cjs tests/audit.test.cjs
- node --test tests/multiempresa-base.test.cjs tests/multiempresa-datos.test.cjs tests/multiempresa-api.test.cjs
- node scripts/build-multiempresa-install.cjs genera el SQL, no lo ejecuta.

Después de editar una migración, regenera el instalador y repite sus pruebas.
El test de datos ejecuta el instalador completo con identidad ficticia y verifica
que se conservan documentos históricos, que no se cruzan empresas y que los RPC
funcionan con el rol de servidor, además de rechazar clientes públicos.
