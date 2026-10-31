# Optimizar

Optimizar ejecuta tareas de mantenimiento para macOS. Los pasos innecesarios se omiten y se explica el motivo.

## Cómo usarla
- Elige las tareas con **las casillas de selección**; «Seleccionar todo/nada» en la esquina superior derecha. Swabr recuerda las tareas que no has marcado.
- Cada tarea describe lo que hace y qué cambia después. Naranja: efecto secundario perceptible.
- **Contraseña:** las tareas que necesitan derechos de administrador se ejecutan juntas; solo te piden la contraseña una vez. Si las cancelas, solo se saltan esas tareas.

## Las tareas
| Tarea | ¿Qué pasa? | Contraseña |
|---|---|---|
| Vistas previas de QuickLook | Restablecer la caché de miniaturas de QuickLook | no |
| Estados de las ventanas | eliminar ventanas guardadas con más de 30 días de antigüedad, no para aplicaciones en ejecución | no |
| Preferencias dañadas | Mueve los archivos de preferencias de terceros dañados a la Papelera | no |
| Caché de DNS | vacíala resolución de nombres (se omite si tienes una VPN activa o cuando estás sin conexión) | sí |
| Rutas de red | vací la tabla de enrutamiento y renueva las direcciones a través de DHCP, solo si todas las interfaces usan DHCP (breve interrupción) | sí |
| .DS_Store | No hay archivos del Finder en unidades de red ni USB | no |
| Opciones de ajuste antiguas | App Nap y la verificación de imágenes vuelven a los valores predeterminados | no |
| Permisos | Restablece los permisos de tu carpeta de inicio, solo si hay algún problema (tarda unos minutos) | sí |
| Índice de Spotlight | Comprueba el estado y vuelve a generar solo si hay errores o cuando la indexación esté desactivada | sí |
| Exclusiones de Spotlight | informa de las exclusiones cuya ubicación ya no existe; lee la configuración con derechos de administrador, pero no cambia nada | sí |
| Mantenimiento periódico | solo los periodos que están pendientes; ya no están presentes desde macOS 26 | sí |
| Barra lateral y elementos recientes | Mueve a la Papelera las listas ilegibles de la barra lateral y de elementos recientes | no |
| Comprueba el volumen de arranque | Comprueba el sistema de archivos, no cambia nada | no |
| Ítems de inicio | informar de entradas cuya falta del programa | no |
| Historial de descargas | borrar el historial de descargas de Gatekeeper (privacidad) | no |
| Servicios en segundo plano | informar de servicios cuyo programa no se encuentra | no |
| Notificaciones | Eliminar notificaciones entregadas con más de 30 días de antigüedad | no |
| Bases de datos | Compactar Mail, Safari y Mensajes (solo si están cerrados, intactos y ocupan menos de 100 MB) | no |

## Edición de la App Store
Allí solo están disponibles las tareas que funcionan en tu carpeta de inicio sin derechos de administrador: estados de ventana, preferencias dañadas, barra lateral y elementos recientes, historial de descargas y servicios en segundo plano.
