# Seguridad: Papelera, eliminación, registro

## Nada sin tu confirmación
Cada sección muestra primero una lista. Antes de eliminar nada, una **ventana de revisión** muestra todas las entradas y sus efectos; solo «Eliminar» o «Trasladar a la Papelera» cambia algo.

## ¿A la Papelera o eliminar definitivamente?
|  | Papelera | De forma permanente |
|---|---|---|
| Se puede restaurar | Sí, hasta que se vacíe («Recuperar» en el Finder) | no |
| Espacio liberado | tras vaciar | Inmediatamente |
| Utilizado por | Desinstalar, Almacenamiento, Instaladores, Reducir, opcionalmente Limpiar y Proyectos | Opcionalmente, «Limpiar» y «Proyectos» |

Las opciones «Limpiar» y «Proyectos» eliminan de forma permanente por defecto, ya que las cachés y las carpetas de compilación se vuelven a crear de todos modos. Elige la Papelera como opción predeterminada en Ajustes → Comportamiento.

## Comprobado varias veces
- La eliminación solo se lleva a cabo dentro de tu carpeta de inicio (y, en el caso de las apps, en la carpeta «Aplicaciones»).
- Nunca se siguen los enlaces simbólicos; si hay un enlace en la ruta, se detiene la eliminación.
- Justo antes de cada eliminación, Swabr vuelve a comprobar: ¿sigue existiendo el elemento? ¿Se ha protegido entretanto?
- Los marcadores de posición de iCloud nunca se descargan ni se cuentan.

## Registro
Cada acción se registra con la hora, la ruta y el tamaño. Lo encontrarás en **Historial**.
