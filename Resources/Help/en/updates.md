# App updates

Swabr checks all installed apps for new versions. Requirement: **online info** is switched on (Settings → General).

## Sources
| Source | Detection | Direct edition | App Store edition |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | open website |
| App Store | comparison with the App Store | App Store opens its updates page | same |
| The app's update channel (Sparkle) | vendor's appcast | downloads and installs the new version | open website |
| Vendor (Homebrew catalogue) | version comparison | downloads from the vendor and installs | open website |

## Safety when installing (Direct)
A download only replaces an app if the **checksum** matches, the **developer signature** is the same as the installed app's and **Gatekeeper** agrees. The old version goes to the Trash. Running apps are quit after asking and reopened afterwards.

## Using it
- One at a time with **Update**, or several with **check boxes** and "Update selected".
- The ⋯ menu hides an update.
- "Up to date" and "Can't check" list the other apps; Safari web apps have no updates.

> Apps from .pkg installers open the macOS Installer; finish the installation there.
