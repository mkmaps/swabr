# Full Disk Access

## What is it?
macOS protects some data specially: Mail, Messages, Safari, the Trash, Time Machine backups and the data of some apps. Programs only see these folders if you give them **Full Disk Access**. This is a macOS security feature, not something Swabr invented.

## Why does Swabr need it?
Without it, parts of your Mac stay hidden:
- **Clean Up:** Trash, Mail attachments, caches in app containers and Messages previews are invisible.
- **Storage:** folders such as Mail or Safari are measured too small or not at all ("+" after the size).
- **Optimize:** the Mail, Safari and Messages databases and usage data are out of reach.

Swabr works without it but finds less.

## What may Swabr do with it?
The access allows reading and writing. Swabr uses it only for the rules you see in the app and deletes only after you confirm the review window. Fixed locks always apply: iCloud Drive, the keychain, Documents, Desktop and everything outside your home folder are never touched. Every deletion is listed in History.

## How to grant it
### 1. Open System Settings
Click the **gear** in Swabr's orange notice (or in the window at the first start). **System Settings → Privacy & Security → Full Disk Access** opens.

### 2. Switch Swabr on
Switch on **Swabr OP.app** and confirm with your password or Touch ID. If the entry is missing, add Swabr with **+** or drag the app from the Finder into the list.

![](images/festplattenvollzugriff-1-liste.png)

### 3. Restart Swabr
macOS usually asks you to. The orange notice then disappears.

> If you move Swabr or install a newly signed version, macOS may treat it as a new app. Remove the old entry with **−** and add Swabr again.

## Revoking
Switch it off in the same list. Swabr shows the notice again and works with less access.

## App Store edition
The App Store edition does not use Full Disk Access but folder grants (see "Direct and App Store edition").
