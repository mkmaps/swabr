# Solución de problemas

## «Falta el acceso total al disco», aunque está concedido
macOS vincula el acceso a la firma de la app. Después de una actualización o de mover la app: elimina la entrada con **−**, vuelve a añadir Swabr y reinicia.

## No se puede eliminar una app
- **Símbolo de llave:** la app pertenece al sistema. macOS te pedirá la contraseña; si aparece «Cancelado», simplemente vuelve a intentarlo.
- **«Swabr no tiene permiso para controlar el Finder»:** Ajustes del Sistema → Privacidad y seguridad → Automatización → Swabr → activa el Finder.

## Se omiten algunas entradas
«Se está ejecutando»: cierra la app y vuelve a escanear. Escudo verde: protegido; consulta «Datos protegidos».

## Rutas de DNS o de red «omitidas»
Con una VPN activa, Swabr deja ambas cosas tal cual a propósito.

## En «Almacenamiento» aparece un «+» junto a los tamaños
Algunas carpetas eran ilegibles o el análisis tardó más de lo permitido. Comprueba «Acceso total al disco» o aumenta el límite de tiempo en Ajustes → Comportamiento.

## No se muestran actualizaciones
Activa la información en línea (Ajustes → General). Las apps de origen desconocido aparecen en la lista «No se puede comprobar».

## Se ha borrado algo por error
Los elementos de la Papelera se pueden recuperar en el Finder. Lo que se ha eliminado de forma definitiva era una carpeta de caché o de compilación, y se vuelve a crear. El historial muestra qué se eliminó y cuándo.
