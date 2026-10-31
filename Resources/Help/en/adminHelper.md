# Administrator rights (helper service)

## What is it?
Some steps need administrator rights: removing apps that belong to the system, optimizations such as flushing the DNS cache, and reading the login items apps registered themselves. Without the helper service, macOS asks for your password every time.

Swabr's **helper service** takes over these steps once you have allowed it. It only accepts requests from Swabr signed with the same developer certificate and quits after five idle minutes. It exists in the Direct edition only.

## How to set it up
### 1. Set it up in Swabr
Open **Swabr → Settings → Behavior** and click **Set Up …** in the **Administrator rights** section.

![](images/helfer-1-einstellungen.png)

### 2. Allow it in System Settings
macOS opens **System Settings → General → Login Items**. Under **App Background Activity**, switch on **Swabr OP** and confirm with your password or Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Done
Back in Swabr, the **Administrator rights** section says "Set up: no password needed any more". From now on these steps run without asking.

> If it says "Waiting for your permission in System Settings", step 2 is still missing. The **gear** next to it takes you straight there.

## What changes afterwards?
- **Apps → Startup** also shows apps that register themselves (for example with "Open at Login" in the app).
- **Uninstall**, **Optimize** and the root steps in **Clean Up**, **Projects**, **Installers** and **Slim Down** no longer ask for the password.
- The safety checks stay the same: all fixed locks still apply, and every step is checked and logged.

## Remove
Click **Remove** in **Settings → Behavior → Administrator rights**. Swabr then asks for the password at every step again.
