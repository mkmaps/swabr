# Safety: Trash, deletion, log

## Nothing without your confirmation
Every section shows a list first. Before anything is removed, a **review window** lists all entries and their effects; only "Delete" or "Move to Trash" changes anything.

## Trash or delete permanently?
| | Trash | Permanently |
|---|---|---|
| Can be restored | yes, until emptied ("Put Back" in the Finder) | no |
| Space freed | after emptying | immediately |
| Used by | Uninstall, Storage, Installers, Slim Down, optionally Clean Up and Projects | optionally Clean Up and Projects |

Clean Up and Projects delete permanently by default, because caches and build folders are recreated anyway. Choose the Trash as default under Settings → Behavior.

## Checked several times
- Deletion happens only inside your home folder (and, for apps, in the Applications folders).
- Symbolic links are never followed; a link in the path stops the deletion.
- Right before every deletion Swabr checks again: does the item still exist? Has it been protected meanwhile?
- iCloud placeholders are never downloaded and not counted.

## Log
Every action is logged with time, path and size. You find it in **History**.
