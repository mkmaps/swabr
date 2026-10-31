# Datos protegidos (lista blanca)

La lista que aparece en Ajustes → **Datos protegidos** define lo que Swabr **nunca** toca durante la limpieza, incluso si una regla lo incluiría en otras circunstancias. Otras herramientas lo llaman «lista blanca».

## Cómo leer la lista
- **Si lo activas, queda protegido.** La entrada ya no aparecerá en «Limpiar» o aparecerá con un escudo verde.
- **Desactivado = puede eliminarse** si una regla de limpieza lo incluye.
- **«Predeterminado»** indica las entradas protegidas de serie (cachés de Gradle, navegadores de Playwright, modelos de Hugging Face).
- Cada entrada muestra cuánto espacio ocupa en este momento, para que veas lo que cuesta protegerla.

## Cuándo proteger
Protege los datos que se vuelven a crear pero que tardan mucho en generarse o consumen mucho volumen de datos: los DerivedData de Xcode de un proyecto grande, las cachés de Gradle, los modelos de IA descargados o las descargas de Homebrew con una conexión lenta.

## Tus propias entradas
En «Tus entradas» puedes proteger cualquier carpeta o archivo:
- **«Elegir carpeta…»** abre un cuadro de diálogo; la carpeta elegida queda protegida.
- O escribe un **patrón**. Justo debajo verás al instante con cuántos elementos coincide.

| Patrón | Protege |
|---|---|
| `~/Library/Caches/Foo` | exactamente esta carpeta |
| `~/Library/Caches/Foo/*` | todo lo que hay en esta carpeta (y con ello la carpeta) |
| `~/Library/Caches/Foo*` | todas las carpetas que empiecen por «Foo» |

«~» es tu carpeta de inicio, «*» representa cualquier carácter.

## Normas de seguridad
Algunas entradas están siempre protegidas y no se pueden desactivar: las cachés que contienen el estado de sincronización de iCloud, el inicio de sesión en la cuenta de Apple, Wallet, Home, las fuentes, las descargas de Spotlight o en segundo plano que estén en curso, y la propia caché de Swabr. Además, iCloud Drive, el llavero, Documentos, el Escritorio y todo lo que esté fuera de tu carpeta de inicio siempre están fuera de tu alcance.

## Ubicación y restablecimiento
La lista se guarda en `~/.config/swabr/whitelist` (un patrón por línea). En cuanto cambies algo, este archivo sustituye a la lista predeterminada; la opción «Restablecer valores predeterminados» lo borra de nuevo.
