# Limpiar

Limpiar encuentra los datos que las apps y macOS vuelven a crear cuando es necesario: cachés, registros, archivos temporales, cachés del navegador y de los desarrolladores, y restos de apps desinstaladas. Swabr funciona con dos tipos de reglas:
- **Hay reglas específicas** para navegadores, herramientas de desarrollo (Xcode, Homebrew, npm, pip, Cargo, Gradle…) y algunas apps cuyos datos están más ocultos.
- **Reglas generales** que siguen las convenciones de carpetas de macOS: todo lo que está en `~/Library/Caches`; las carpetas de caché de Chromium en todas las apps de Electron (Slack, Discord, VS Code, Obsidian…); cachés, registros y archivos temporales en los contenedores de las apps. De esta forma, también quedan cubiertas las apps que no aparecen en ninguna lista.

Cada regla tiene su propio tipo (caché, registros, paquetes, compilación…) y su propia clasificación. Las reglas específicas tienen prioridad sobre las generales.

## Cómo funciona
- **Inicia análisis:** Swabr solo echa un vistazo, no cambia nada.
- **Echa un vistazo a la lista:** a la izquierda están las categorías y sus tamaños; a la derecha, las entradas de la categoría elegida con su valoración, tamaño y efecto. La casilla situada delante de una categoría la selecciona por completo; expande una fila para ver sus rutas.
- **A la Papelera: pulsa** el botón de la esquina inferior derecha y, a continuación, confirma en la ventana de revisión. Si la opción «Eliminar definitivamente» está activada, el botón se llama «Limpiar» y elimina los datos al instante.
- **Listo:** la página final muestra cuánto espacio se ha liberado, desglosado por categorías, y el espacio libre antes y después.

## Seguro o Revisar
| Nivel | Es decir | Preseleccionado |
|---|---|---|
| **Seguro** (verde) | datos de caché, de registro o temporales que se vuelven a crear | sí |
| **Revisar** (naranja) | pueden contener datos que aún quieras conservar o que tarden mucho en volver a descargarse: la Papelera, los archivos adjuntos de Mail, los estados de las ventanas, las cachés propias de macOS, descargas grandes como Gradle o Playwright | no |

«Recomendados» selecciona solo las entradas seguras, «Todo» lo selecciona todo y «Ninguno» no selecciona nada.

## Entradas omitidas
- **«Se está ejecutando»:** las cachés de una aplicación abierta no se tocan (p. ej., Chrome, Slack, VS Code). Esto también se aplica a las reglas generales: Swabr reconoce la aplicación por el nombre de su carpeta o su ID de paquete. Cierra la aplicación y vuelve a escanear.
- **Escudo verde:** la entrada está protegida (véase «Datos protegidos») o se encuentra en una zona bloqueada.

## Categorías especiales
- **Restos de aplicaciones eliminadas:** cachés, registros y estados de ventanas de aplicaciones que ya no están instaladas y que no se han modificado en los últimos 30 días (ajustable). Se excluyen los gestores de contraseñas, el llavero y los datos SSH.
- **Conjuntos de datos grandes (solo como sugerencia):** copias de seguridad de iOS, Mail, simuladores, Docker, modelos de IA. Swabr nunca los borra automáticamente, pero te indica dónde limpiarlos correctamente.

## No tendrás que volver a limpiar nunca más
Haz clic con el botón derecho en una entrada → **«No limpiar nunca»** la protege de forma permanente. Deshazlo en Ajustes → Datos protegidos.

Esto también incluye todo lo que la misma regla detecte más adelante. En la lista desplegada, haz clic con el botón derecho en una ubicación para proteger solo esa ubicación, todo lo de una aplicación o todas las carpetas con ese nombre. Justo después, **la opción «Deshacer»** de la barra situada encima de la lista revoca la protección.

## ¿Qué cambia después?
Las apps reconstruyen sus cachés; el primer inicio o la primera carga de una página pueden tardar un poco más. Los datos de inicio de sesión, los documentos, la configuración y los marcadores se mantienen.
