# SIS-STOCK multiempresa — estado local

Actualizado el 14 de octubre de 2026. La implementación está preparada en los dos
backends y el frontend. No se ha aplicado a Supabase ni publicado en Render.

## Decisiones implementadas

- Una base de datos y un sitio para COPA SPORT MOTOS y COPA SPORT BIKE.
- Todos los registros existentes se asignan a motos. Bicicletas comienza sin
  productos, proveedores, compras, ventas ni historial de negocio.
- La cuenta existente bekanbk1@gmail.com
  administra ambas. No se crea ni cambia su contraseña.
- Identidad de usuario global; membresías, roles y operaciones por empresa.
- Selector al iniciar sesión, empresa visible en cabecera y sesión por pestaña.
- Borradores, metas personales y notificaciones separados por empresa.
- Consultas del backend limitadas a la empresa autorizada; relaciones SQL impiden
  mezclar documentos, productos y lotes. Los clientes públicos no leen las tablas.
- Permisos vigentes comprobados en el servidor en cada petición. Las sesiones
  antiguas dejarán de funcionar después del despliegue; será necesario ingresar.

## Instalación

Seguir [MULTIEMPRESA_INSTALACION.md](MULTIEMPRESA_INSTALACION.md).
El instalador completo está en ../supabase/install/MULTIEMPRESA_INSTALAR.sql.
No ejecutar las migraciones individuales además del instalador.
La instalación requiere respaldo recuperable y una ventana sin operaciones.
No usar los antiguos scripts de vaciado de stock o reinicio de compras/ventas.

Las consultas de inventario y definiciones ya fueron recibidas. No es necesario
repetirlas salvo que la estructura desplegada haya cambiado desde entonces.
[MULTIEMPRESA_REVISION_ESQUEMA.md](MULTIEMPRESA_REVISION_ESQUEMA.md) conserva el
análisis previo del esquema, no el estado del despliegue.
