# Actualizaciones de aplicaciones

Swabr comprueba si hay nuevas versiones de todas las apps instaladas. Requisito: la **información en línea** debe estar activada (Ajustes → General).

## Fuentes
| Fuente | Detección | Edición directa | Edición de la App Store |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | abrir página web |
| App Store | Comparación con la App Store | La App Store abre su página de actualizaciones | igual |
| El canal de actualizaciones de la app (Sparkle) | appcast del proveedor | descarga e instala la nueva versión | abrir página web |
| Proveedor (catálogo de Homebrew) | comparación de versiones | Descargas del proveedor e instalaciones | abrir página web |

## Seguridad al instalar (Directo)
Una descarga solo sustituye una app si la **suma de comprobación** coincide, la **firma del desarrollador** es la misma que la de la app instalada y **Gatekeeper** lo aprueba. La versión antigua va a la Papelera. Las apps que estén en ejecución se cierran tras preguntarte y se vuelven a abrir después.

## Cómo usarlo
- Una por una con «Actualizar», o varias con **las casillas de selección** y «**Actualizar** las seleccionadas».
- El menú ⋯ oculta una actualización.
- «Actualizadas» y «No se puede comprobar» muestran el resto de apps; las apps web de Safari no tienen actualizaciones.

> Las apps de instaladores .pkg abren el instalador de macOS; termina la instalación allí.
