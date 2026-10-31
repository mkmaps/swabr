# Edición directa y de la App Store

Swabr está disponible en dos ediciones creadas a partir del mismo código. Puedes ver cuál tienes en Ajustes → General y en «Acerca de».

|  | Directo | App Store |
|---|---|---|
| Distribución | GitHub (DMG) | Mac App Store |
| Acceso | Toda la carpeta de inicio con «Acceso total al disco» | solo las carpetas que concedas |
| Limpiar, desinstalar | sí | Sí, después de concederlo |
| Aplicaciones del sistema | Sí (el Finder te pedirá tu contraseña) | Sí (macOS te pedirá tu contraseña) |
| Archivos del sistema en /Library | sí | Sí, después de conceder acceso a /Library |
| Optimizar | las 19 tareas | 5 tareas sin derechos de administrador |
| Actualizaciones | Se instala y actualiza sola | muestra actualizaciones, abre la App Store o la página web del desarrollador |
| Inicio | Gestionar ítems de inicio y servicios | Mostrar y eliminar tus propios servicios en segundo plano |
| Reducir | sí | no |

## ¿Por qué la versión de la App Store ofrece menos funciones?
Apple exige un **entorno aislado (sandbox)** para la App Store: las apps solo pueden acceder a las carpetas concedidas, no pueden solicitar derechos de administrador, no pueden instalar ni modificar otras apps y no pueden controlar otras apps (Directrices de revisión de la App Store 2.4.5 y 2.5.2). Swabr cumple estas normas y ofrece todo lo que permiten.

## Conceder permisos para carpetas (versión de la App Store)
La primera vez que abras «Limpiar», «Optimizar» o «Aplicaciones», aparecerá «Permitir acceso». Haz clic en «Conceder…»; el cuadro de diálogo ya muestra la carpeta correcta, solo tienes que confirmar. Los permisos se guardan y se pueden revocar en Ajustes → Acceso.

## Versión Direct y código fuente
Swabr es software libre bajo la licencia MIT. La versión Direct y el código fuente completo están disponibles de forma gratuita en GitHub; el enlace está en Ajustes → Acerca de.
