# Direct and App Store edition

Swabr comes in two editions built from the same code. You see which one you have under Settings → General and in "About".

| | Direct | App Store |
|---|---|---|
| Distribution | GitHub (DMG) | Mac App Store |
| Access | whole home folder with Full Disk Access | only folders you grant |
| Clean up, uninstall | yes | yes, after granting |
| Apps owned by the system | yes (Finder asks for your password) | yes (macOS asks for your password) |
| System files in /Library | yes | yes, after granting /Library |
| Optimize | all 19 tasks | 5 tasks without administrator rights |
| Updates | installs updates itself | shows updates, opens App Store or vendor website |
| Startup | manage login items and services | show and remove your own background services |
| Slim down | yes | no |

## Why the App Store edition does less
Apple requires a **sandbox** for the App Store: apps may only access granted folders, may not ask for administrator rights, may not install or change other apps and may not control other apps (App Store Review Guidelines 2.4.5 and 2.5.2). Swabr follows these rules and offers as much as they allow.

## Granting folders (App Store edition)
The first time you open Clean Up, Optimize or Apps, "Allow access" appears. Click "Grant …"; the dialog already shows the right folder, you just confirm. Grants are remembered and can be revoked under Settings → Access.

## Direct version and source code
Swabr is free software under the MIT license. The Direct version and the complete source code are available free of charge on GitHub; the link is under Settings → About.
