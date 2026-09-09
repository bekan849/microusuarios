# Instalar las correcciones de SIS-STOCK paso a paso

Esta guía explica cómo preparar la base de datos y publicar los cambios que ya están guardados en tu computadora. No se ha instalado el SQL en Supabase ni se han desplegado los servicios desde esta tarea.

## 1. Entender dónde se hace cada cosa

| Lugar | Qué haces allí |
| --- | --- |
| Visual Studio Code, en tu computadora | Abres los archivos SQL y publicas los cambios del código en el repositorio conectado a tu alojamiento. |
| Panel web de Supabase | Ejecutas los archivos SQL para crear las funciones y los índices que necesita el código nuevo. |
| Panel del alojamiento, por ejemplo Render | Publicas la nueva versión de usuarios, productos y frontend. |

Instalar SQL significa ejecutar el contenido de unos archivos en la base de datos. No necesitas instalar SQL Server en Windows para este paso: tu sistema utiliza PostgreSQL en Supabase.

El orden es: revisar la base → instalar SQL → desplegar usuarios → desplegar productos → desplegar frontend → comprobar.

## 2. Abrir el proyecto correcto de Supabase

1. Entra en https://supabase.com/dashboard con tu cuenta.
2. Abre el proyecto que utiliza SIS-STOCK. Puedes comprobarlo comparando la dirección del proyecto con `SUPABASE_URL` de la configuración de cada backend. No compartas las claves del archivo `.env`.
3. Si usuarios y productos utilizan el mismo proyecto de Supabase, todos los SQL van allí. Si utilizan proyectos distintos, instala el SQL de usuarios en su proyecto y los dos SQL de productos en el proyecto de productos.
4. Busca **SQL Editor** en el menú y abre **New Query**.

En la revisión anterior no se pudo resolver el nombre del servidor configurado en Supabase (`ENOTFOUND`). Antes de publicar, comprueba que la dirección configurada corresponde al proyecto y que los servicios pueden conectarse. Ese error por sí solo no demuestra que la base haya sido eliminada.

## 3. Revisar la estructura antes de instalar

En Visual Studio Code abre este archivo:

`C:\Users\Usuario\Escritorio\SIS-STOCK\microproductos\supabase\checks\preflight.sql`

1. Copia todo su contenido con `Ctrl+A` y `Ctrl+C`.
2. En una consulta nueva del SQL Editor del proyecto de productos, pega con `Ctrl+V`.
3. Pulsa **Run**. Este archivo solo consulta información; no cambia el inventario.
4. Conserva los resultados de las consultas. Si el editor solo muestra el último resultado, puedes ejecutar cada consulta `SELECT` por separado.

Hay que revisar columnas, tipos, valores por defecto, índices y triggers. Que el archivo termine sin error no confirma por sí solo que todo sea compatible. En particular, un trigger existente que descuente inventario podría duplicar el descuento de la nueva función.

Si no sabes interpretar esos resultados, compártelos en esta conversación para revisarlos antes del paso siguiente. No necesitas compartir contraseñas ni claves. Esta comprobación sigue pendiente porque no se pudo consultar la base real.

## 4. Instalar los tres archivos SQL

Haz este paso después de revisar la compatibilidad. Elige un momento sin ventas ni compras activas, porque la creación de índices puede bloquear escrituras temporalmente.

Para cada archivo: ábrelo en VS Code, copia todo, crea una consulta nueva en Supabase, pega y pulsa **Run**. Espera a que termine antes de continuar. No pegues solo el nombre o la ruta del archivo.

### Primero: SQL de usuarios

`C:\Users\Usuario\Escritorio\SIS-STOCK\microusuarios\supabase\migrations\202609070001_optimize_auth_session.sql`

Prepara las funciones que aceleran el inicio de sesión y la consulta de accesos. Ejecútalo en la base que utiliza usuarios.

### Segundo: SQL del dashboard

`C:\Users\Usuario\Escritorio\SIS-STOCK\microproductos\supabase\migrations\202609070001_dashboard_performance.sql`

Prepara la consulta consolidada del panel y sus índices. Ejecútalo en la base que utiliza productos.

### Tercero: SQL de ventas completas

`C:\Users\Usuario\Escritorio\SIS-STOCK\microproductos\supabase\migrations\202609070002_atomic_sale_registration.sql`

Prepara la función que registra una venta completa dentro de una transacción. Si una parte falla, se revierten los cambios de esa operación. Ejecútalo en la base de productos, después del archivo anterior.

Un mensaje de éxito, a veces acompañado de “sin filas devueltas”, es normal para estos archivos. Si aparece un error, guarda el texto exacto y no continúes con el despliegue hasta resolverlo. No hace falta ejecutar estos archivos cada vez que se inicia el servidor.

No ejecutes `tests/fixture.sql` en tu base real: ese archivo es un esquema para pruebas aisladas. Estos cambios tampoco restauran las 10 unidades mencionadas anteriormente.

Referencia del editor: [crear funciones en Supabase](https://supabase.com/docs/guides/database/functions).

## 5. Publicar el código nuevo

Los archivos modificados están en tu computadora. Si tu alojamiento despliega desde un repositorio Git, debe recibir esos cambios antes de poder publicarlos.

Para cada proyecto, en el orden usuarios → productos → frontend:

1. Abre su carpeta en VS Code.
2. Entra en **Control de código fuente**.
3. Revisa y prepara los archivos de las correcciones. El inventario está en `RESUMEN_CORRECCIONES.md`, dentro de microusuarios. Evita incluir `.env`, `node_modules`, `.codex-work` o cambios ajenos de archivos ZIP.
4. Crea un commit con un mensaje descriptivo.
5. Usa **Push** o **Sincronizar cambios** para enviarlo al repositorio y a la rama que utiliza el alojamiento. Si no hay repositorio remoto configurado, este paso requiere conectar primero el repositorio que realmente utiliza tu servicio; no inventes una dirección ni una rama.
6. Despliega ese proyecto y comprueba que arranca antes de seguir con el siguiente.

Carpetas:

- Usuarios: `C:\Users\Usuario\Escritorio\SIS-STOCK\microusuarios`
- Productos: `C:\Users\Usuario\Escritorio\SIS-STOCK\microproductos`
- Frontend: `C:\Users\Usuario\Downloads\SIS-STOCKF\SIS-STOCKF`

### Si tus servicios están en Render

No he verificado tu panel ni qué repositorio o rama tiene conectado cada servicio. Estas instrucciones aplican si utilizas Render:

1. Abre el servicio de usuarios en el panel de Render.
2. Comprueba que apunta al repositorio y a la rama donde subiste los cambios.
3. Si tiene despliegue automático, el push puede iniciar el despliegue. Espera a que termine.
4. Si debes iniciarlo manualmente, utiliza **Manual Deploy → Deploy latest commit**.
5. Revisa los logs y que el servicio quede activo. Después repite para productos y finalmente para frontend.

**Restart service** vuelve a iniciar la versión ya desplegada: no incorpora por sí solo los archivos que acabas de editar en tu computadora. [Documentación de despliegues de Render](https://render.com/docs/deploys).

Si ya tienes comandos de despliegue funcionales, conserva una configuración equivalente. En estos proyectos, los comandos son:

| Proyecto | Compilación desde su carpeta | Ejecución/publicación |
| --- | --- | --- |
| Usuarios | `npm ci --include=dev && npm run build` | `npm start` |
| Productos | `npm ci --include=dev && npm run build` | `npm start` |
| Frontend, si es un sitio estático | `npm ci --include=dev && npm run build` | Publicar la carpeta `dist` |

La ruta raíz del servicio debe corresponder a la ubicación del proyecto dentro de su repositorio. No tiene por qué ser la ruta de Windows de tu computadora.

## 6. Comprobar la configuración del alojamiento

Estos valores se configuran en el entorno de cada servicio. No basta con cambiarlos en el `.env` local para modificar la versión alojada.

- Ambos backends deben usar el mismo `JWT_SECRET` y `NODE_ENV=production`.
- Cada backend necesita su `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`. Usuarios también necesita `SUPABASE_ANON_KEY`.
- `CORS_ORIGIN` debe incluir la dirección real del frontend, por ejemplo `https://tu-frontend.onrender.com`, sin rutas como `/login`. Para varios orígenes, sepáralos con comas.
- El frontend necesita `VITE_API_USUARIOS` y `VITE_API_PRODUCTOS` apuntando a sus respectivas direcciones, con `/api` al final. Ejemplo ilustrativo: `https://tu-servicio-usuarios.onrender.com/api`.
- Las variables `VITE_` se incorporan al compilar el frontend: si las cambias, vuelve a desplegarlo. Nunca pongas la clave `service_role` ni `JWT_SECRET` en el frontend.

## 7. Comprobar que quedó funcionando

1. Abre la dirección de cada backend seguida de `/api/health`. Una respuesta correcta confirma que el proceso responde; no verifica por sí sola la base de datos.
2. Abre el frontend, inicia sesión y recarga la página. Comprueba que conserva una sesión válida.
3. Abre el dashboard y comprueba que carga la información permitida para ese usuario.
4. En una base y entorno de pruebas, registra una venta completa con stock suficiente y verifica venta, detalles, lotes y stock.
5. En ese entorno de pruebas, intenta una venta sin stock suficiente: debe rechazarse sin movimientos parciales. También debe comprobarse la reversión ante un error en un lote posterior.

No provoques ventas ficticias ni errores de precio en producción para hacer estas pruebas.

## Qué significa la limitación de ventas completas

La nueva transacción protege el registro mediante `/api/ventas/registrar-completa`. Las compras y otros cambios de estado todavía utilizan operaciones separadas. Esta instalación no garantiza que todos los movimientos concurrentes del inventario estén resueltos, ni repara diferencias históricas.

El primer paso que puedes hacer ahora es ejecutar `preflight.sql` en el proyecto correcto de Supabase y traer los resultados para revisar la compatibilidad.
