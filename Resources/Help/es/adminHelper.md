# Derechos de administrador (servicio auxiliar)

## ¿Qué es esto?
Algunos pasos necesitan derechos de administrador: eliminar apps que pertenecen al sistema, optimizaciones como vaciar la caché de DNS y leer los ítems de inicio que las propias apps han registrado. Sin el servicio auxiliar, macOS te pide la contraseña cada vez.

**El servicio auxiliar** de Swabr se encarga de estos pasos una vez que se lo hayas permitido. Solo acepta solicitudes de Swabr firmadas con el mismo certificado de desarrollador y se cierra tras cinco minutos de inactividad. Solo está disponible en la edición Direct.

## Cómo configurarlo
### 1. Configúralo en Swabr
Abre **Swabr → «Ajustes» → «Comportamiento»** y haz clic en **«Configurar…»** en la sección **«Derechos de administrador**».

![](images/helfer-1-einstellungen.png)

### 2. Permítelo en los Ajustes del Sistema
En macOS, abre «**Ajustes del Sistema**»** → «General» → «Ítems de inicio**». En **«Actividad en segundo plano de las apps**», activa **Swabr** y confirma con tu contraseña o Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Listo
De vuelta en Swabr, en la sección **de derechos de administrador** aparece «Configuración: ya no se necesita contraseña». A partir de ahora, estos pasos se ejecutarán sin pedirla.

> Si aparece «Esperando tu permiso en Ajustes del Sistema», aún falta el paso 2. El icono de **engranaje** que hay al lado te lleva directamente allí.

## ¿Qué cambia después?
- **En **Apps** → **Arranque**** también aparecen las apps que se registran solas (por ejemplo, con la opción «Abrir al iniciar sesión» en la app).
- **Desinstalar**, **Optimizar** y los pasos de root en **Limpiar**, **Proyectos**, **Instaladores** y **Reducir** ya no te piden la contraseña.
- Los controles de seguridad siguen siendo los mismos: todos los bloqueos fijos siguen vigentes, y cada paso se comprueba y se registra.

## Eliminar
Haz clic en **«Eliminar»** en «**Ajustes**»** → «Comportamiento» → «Derechos de administrador**». Swabr volverá a pedirte la contraseña en cada paso.
