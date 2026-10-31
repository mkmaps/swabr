# Troubleshooting

## "Full Disk Access missing" although granted
macOS binds the access to the app's signature. After an update or moving the app: remove the entry with **−**, add Swabr again, restart.

## An app can't be deleted
- **Key symbol:** the app belongs to the system. macOS asks for your password; after "Cancelled" just try again.
- **"Swabr isn't allowed to control the Finder":** System Settings → Privacy & Security → Automation → Swabr → switch on Finder.

## Entries are skipped
"is running": quit the app and scan again. Green shield: protected, see Protected data.

## DNS or network routes "skipped"
With an active VPN Swabr deliberately leaves both alone.

## Storage shows "+" after sizes
Some folders were unreadable or measuring took longer than the time limit. Check Full Disk Access or raise the time limit under Settings → Behavior.

## No updates shown
Switch on online info (Settings → General). Apps without a known source are listed under "Can't check".

## Something deleted by mistake
Items in the Trash can be put back in the Finder. What was deleted permanently was a cache or build folder and is recreated. History shows what was removed when.
