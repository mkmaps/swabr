# Reducir

Muchas apps son «universales» y contienen código tanto para Macs con Intel como con Apple Silicon. Un Mac con chip de Apple solo necesita una parte de ese código. «Reducir» elimina la parte de Intel.

## ¿Qué aplicaciones?
Solo las apps firmadas con un ID de desarrollador que te pertenezca, que no sean de la App Store, que no sean de Apple, que no estén configuradas en «Abrir con Rosetta» y que no se estén ejecutando. Todas las demás aparecen en la lista «Omitidos» con el motivo correspondiente.

## ¿Es seguro?
- Cada aplicación se optimiza a partir de una **copia**.
- La copia sustituye al original solo si conserva su código para Apple Silicon, la firma del código es válida, la ha firmado el mismo desarrollador y Gatekeeper da su visto bueno.
- El original va a la **Papelera**.

## Efectos
A partir de ahí, la app solo funciona en Macs con Apple Silicon, ya no con Rosetta ni en Macs con Intel. Una actualización de la app vuelve a incluir el código de Intel. Solo en la edición directa.
