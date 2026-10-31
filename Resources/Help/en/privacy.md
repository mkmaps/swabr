# Privacy

Swabr collects no data, contains no analytics or advertising and has no user account.

## What stays on your Mac
All scans, measurements, settings, protected data and the log are stored locally only.

## What goes over the internet (only with "online info")
| Where | What | Why |
|---|---|---|
| formulae.brew.sh | download of the public Homebrew catalogue (about 10 MB, cached for 7 days), no data from you | descriptions and versions |
| itunes.apple.com | identifiers of your App Store apps (e.g. com.bitwarden.desktop) | description, version, store link |
| apps' update channels | fetching the vendor's appcast file | version comparison |
| vendor downloads | only when you start an update (Direct) | download the new version |

Switch "online info" off under Settings → General; Swabr then works completely offline. In the App Store edition it is off by default.

## Permissions
Swabr uses Full Disk Access (Direct) or folder grants (App Store) only for the visible features. All permissions can be revoked in System Settings or under Settings → Access.

## Deleting your data
Remove Swabr and delete `~/.config/swabr` and `~/Library/Application Support/Swabr` (App Store edition: its container in ~/Library/Containers).
