# Arranque: ítems de inicio y servicios

## Abrir al iniciar sesión (Directo)
Cada app instalada tiene un interruptor **«Abrir al iniciar sesión**». macOS abre las apps activadas tras iniciar sesión. El interruptor más pequeño **«Oculta»** las inicia sin ventana. Es la misma lista que en Ajustes del Sistemas → General → Ítems de inicio; Swabr la controla a través de «Eventos del sistema» (macOS te pide permiso una vez).

## Servicios en segundo plano
A continuación (expandible) aparecen los actualizadores y las herramientas auxiliares que las propias apps configuran (LaunchAgents/LaunchDaemons):
- **Tus servicios** (en tu carpeta de inicio): permitir/bloquear el inicio, eliminar (Papelera).
- **Servicios de todo el sistema:** solo visualización; modifícalos en los Ajustes del Sistema. Excepción: si falta el programa, **«Eliminar…»** los borra (macOS te pedirá la contraseña).
- **«Falta el programa»:** el servicio apunta a una app eliminada y ya no hace nada; puedes eliminarlo.

## Eliminar entradas huérfanas
Los ítems de inicio y los servicios cuya aplicación ya no está instalada aparecen marcados en naranja con **el mensaje «Falta el programa**».
- En el caso de un elemento de inicio, **«Eliminar de la lista»** borra la entrada de los ítems de inicio.
- En la esquina inferior derecha, **«Eliminar huérfanos (número) …»** los elimina todos de una vez, tras mostrarte la lista de nombres.
- Los archivos de servicio van a la Papelera y se pueden recuperar desde allí. Swabr solo elimina los servicios de todo el sistema si el programa correspondiente ya no está.

## Edición de la App Store
La versión de la App Store no puede controlar los eventos del sistema ni iniciar o detener servicios. Muestra tus propios servicios en segundo plano y puedes eliminarlos; gestiona los Ítems de inicio con el botón de «Ajustes del Sistema».
