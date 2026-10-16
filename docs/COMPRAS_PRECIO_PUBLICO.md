# Actualización de compras y edición de texto — 16 de octubre de 2026

Preparada localmente; no aplicada a Supabase ni publicada.

- Formularios compartidos: conservar cursor y selección al convertir texto a mayúsculas.
- Nueva compra: agregar varios productos antes de completar cantidades y costos;
  editar valores en tabla o tarjetas móviles y conservar campos pendientes en borradores.
- Mostrar marca y precio al público; modificar el precio opcionalmente con permiso
  productos.editar. Los costos de compra y precios al público son independientes.
- Registro completo mediante una transacción SQL: compra, detalles, lotes, stock,
  precio y auditoría de cambios de precio. Si hay un error, se revierte todo.
- Si otro proceso cambia el precio al público, se exige revisar la referencia
  actualizada antes de volver a registrar. No se sobrescribe silenciosamente.

## Instalación sobre multiempresa ya instalada

1. Preparar respaldo recuperable y detener operaciones durante el despliegue.
2. Ejecutar completo SOLO `supabase/migrations/202610160001_compra_precio_publico.sql`
   en el SQL Editor del proyecto existente.
3. Publicar el backend de productos actualizado y después el frontend.
4. No volver a ejecutar el instalador inicial de multiempresa. Esta actualización
   no necesita publicar cambios de código en el backend de usuarios.

La nueva RPC debe existir antes de publicar productos. Si falta, el backend rechaza
la compra; no recurre al registro anterior por escrituras separadas.
El precio al público mostrado es el del catálogo, no un precio histórico de la compra.
Los cambios de estado de compras existentes mantienen su implementación anterior.

## Validación

- Frontend: 15 pruebas de edición y borradores aprobadas; TypeScript y Vite correctos.
- Backend productos: TypeScript correcto y 8 pruebas API aprobadas.
- SQL en PGlite con datos ficticios: 7 pruebas aprobadas, incluidos aislamiento,
  permisos, precio desactualizado, auditoría y reversión por fallo tardío.
- Vite conserva advertencias previas de CSS y tamaño del componente de gráficos.

La pantalla local de demostración no llama a Supabase. Registrar y guardar borrador
son simulaciones; no persisten al cerrar esa pantalla. No sustituye la validación
posterior al despliegue contra Supabase.
