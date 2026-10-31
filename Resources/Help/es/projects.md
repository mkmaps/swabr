# Proyectos

La opción «Proyectos» elimina las carpetas de compilación y dependencias de tus proyectos de software, como por ejemplo: `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` y otros 27 tipos más.

## Buscar ubicaciones
Por defecto: ~/dev, ~/Projects, ~/GitHub, ~/Code y otras carpetas habituales. Añade las tuyas propias con **«Añadir carpeta…»** en la parte superior, incluso en discos externos. La búsqueda llega hasta 6 niveles de profundidad (ajustable).

## Normas de seguridad
- Solo carpetas que estén dentro de un proyecto (con `package.json`, `Cargo.toml`, `go.mod`, `Package.swift` y otros).
- Las carpetas con archivos controlados por Git o archivos de claves (`*-keypair.json`) no se tocan.
- `bin` solo en proyectos .NET, `vendor` solo con PHP/Composer.
- Las carpetas que se han usado en los últimos 7 días aparecen marcadas y no están preseleccionadas (se puede ajustar).

## Después
Cada fila indica cómo recuperar la carpeta (p. ej., `npm install`, `cargo build`). Por defecto, se eliminan de forma definitiva; también puedes elegir la opción «Trasladar a la Papelera».
