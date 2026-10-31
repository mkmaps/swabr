# Startup: login items and services

## Open at login (Direct)
Every installed app has a switch **"Open at login"**. macOS opens switched-on apps after you log in. The smaller switch **"Hidden"** starts them without a window. It's the same list as System Settings → General → Login Items; Swabr controls it through "System Events" (macOS asks once for permission).

## Background services
Below (expandable) are updaters and helper tools that apps set up themselves (LaunchAgents/LaunchDaemons):
- **Your services** (in your home folder): allow/block starting, remove (Trash).
- **System-wide services:** display only; change them in System Settings. Exception: if their program is missing, **"Remove …"** deletes them (macOS asks for your password).
- **"Program missing":** the service points to a deleted app and does nothing anymore – can go.

## Removing orphaned entries
Login items and services whose app is no longer installed are marked orange with **"Program missing"**.
- For a login item, **"Remove from list"** deletes the entry from the login items.
- At the bottom right, **"Remove orphans (count) …"** removes all of them at once, after asking with the list of names.
- Service files go to the Trash and can be restored from there. Swabr removes system-wide services only if their program is really gone.

## App Store edition
The App Store edition may neither control System Events nor start or stop services. It shows your own background services and can remove them; manage login items with the button to System Settings.
