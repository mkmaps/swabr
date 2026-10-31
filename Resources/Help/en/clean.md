# Clean Up

Clean Up finds data that apps and macOS recreate when needed: caches, logs, temporary files, browser and developer caches and leftovers of uninstalled apps. Swabr works with two kinds of rules:
- **Specific rules** for browsers, developer tools (Xcode, Homebrew, npm, pip, Cargo, Gradle …) and some apps whose data lies deeper.
- **General rules** that follow macOS's folder conventions: everything under `~/Library/Caches`, Chromium's cache folders in every Electron app (Slack, Discord, VS Code, Obsidian …), caches, logs and temporary files in app containers. This way apps no list knows about are covered too.

Every rule carries its kind (cache, logs, packages, build …) and its rating itself. Specific rules take precedence over general ones.

## How it works
- **Start scan:** Swabr only looks, nothing changes.
- **Check the list:** the categories and their sizes are on the left, the entries of the chosen category on the right with their rating, size and effect. The box in front of a category selects all of it; expand a row to see its paths.
- **To the Trash:** the button at the bottom right, then confirm the review window. If "Delete permanently" is on, the button is called "Clean" and deletes right away.
- **Done:** the final page shows how much was freed, split by category, and the free space before and after.

## Safe or Review
| Level | Meaning | Preselected |
|---|---|---|
| **Safe** (green) | cache, log or temporary data that is recreated | yes |
| **Review** (orange) | may hold data you still want or takes long to download again: Trash, Mail attachments, window states, macOS's own caches, big downloads such as Gradle or Playwright | no |

"Recommended" selects safe entries only, "All" everything, "None" nothing.

## Skipped entries
- **"is running":** caches of an open app are left alone (e.g. Chrome, Slack, VS Code). This also applies to the general rules: Swabr recognises the app by its folder name or bundle ID. Quit the app and scan again.
- **Green shield:** the entry is protected (see "Protected data") or lies in a locked area.

## Special categories
- **Leftovers of removed apps:** caches, logs and window states of apps no longer installed and unchanged for 30 days (adjustable). Password managers, keychain and SSH data are excluded.
- **Large data sets (hint only):** iOS backups, Mail, simulators, Docker, AI models. Swabr never deletes them automatically but tells you where to clean them up properly.

## Never clean again
Right-click an entry → **"Never clean"** protects it permanently. Undo under Settings → Protected Data.

This also covers everything the same rule finds later. In the expanded list, right-click a location to protect just that location, everything of one app or all folders with that name. Right afterwards, **"Undo"** in the bar above the list takes the protection back.

## What changes afterwards?
Apps rebuild their caches; the first launch or the first page load may take a little longer. Logins, documents, settings and bookmarks stay.
