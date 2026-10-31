# Desinstalar aplicaciones

Al arrastrar una app a la Papelera, quedan restos de sus datos: cachés, ajustes, servicios en segundo plano y, a veces, archivos del sistema. Swabr encuentra estos restos.

## Cómo funciona
- Selecciona las apps de la izquierda con la **casilla de verificación** (puedes seleccionar varias). La información y todos los archivos encontrados aparecen a la derecha.
- Al hacer clic en **Desinstalar…** se abre la ventana de resumen con todas las consecuencias.
- Las apps que estén en ejecución se cierran primero. Todo va a la **Papelera**.

## ¿Qué se elimina?
| Grupo | Ejemplos | Preseleccionadas |
|---|---|---|
| **Se eliminará** | aplicación, cachés, registros, estado de la ventana, agentes de inicio | sí |
| **Datos personales** | ajustes, contenedores, cuentas, bibliotecas | no |
| **Información confidencial** | perfiles del navegador (contraseñas, historial), datos de grupos de aplicaciones | Nunca automáticamente |
| **Archivos del sistema** | archivos en /Library, servicios del sistema, herramientas auxiliares | no, necesita contraseña |

Los datos personales se conservan por defecto, así que la configuración y las cuentas volverán si reinstalas la app. «Eliminar también el resto» lo selecciona. Cambia la opción por defecto en Ajustes → Comportamiento.

## Acerca de la app
La sección «Información» muestra el desarrollador (según la firma), la categoría, la versión, la última vez que se usó y —si hay información en línea— una descripción y enlaces a la página web, la App Store y búsquedas en Internet. Esto te ayuda a reconocer las apps que no conoces antes de borrarlas.

## Símbolos
- **Candado:** protegido (componente del sistema, software de seguridad con su propio desinstalador, la propia Swabr).
- **Llave:** pertenece a otro usuario o al sistema; macOS te pide la contraseña al eliminarla.

## Homebrew
Las apps instaladas con Homebrew se eliminan con `brew uninstall`, para que Homebrew se mantenga sincronizado.
