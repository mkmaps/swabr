# Optimize

Optimize runs maintenance tasks for macOS. Unnecessary steps are skipped with a reason.

## Using it
- Pick tasks with **check boxes**; "Select all/none" at the top right. Swabr remembers unticked tasks.
- Every task describes what it does and what changes afterwards. Orange: noticeable side effect.
- **Password:** tasks needing administrator rights run together; the password is asked only once. Cancelling skips only those tasks.

## The tasks
| Task | What happens | Password |
|---|---|---|
| QuickLook previews | reset QuickLook's thumbnail cache | no |
| Window states | remove saved windows older than 30 days, not for running apps | no |
| Broken preferences | move damaged third-party preference files to the Trash | no |
| DNS cache | flush name resolution (skipped with an active VPN or when offline) | yes |
| Network routes | flush the routing table and renew addresses via DHCP, only if every interface uses DHCP (short interruption) | yes |
| .DS_Store | no Finder files on network and USB drives | no |
| Old tuning switches | App Nap and image verification back to default | no |
| Permissions | reset permissions in your home folder, only if something is wrong (takes minutes) | yes |
| Spotlight index | check the status, rebuild only on errors or when indexing is off | yes |
| Spotlight exclusions | report exclusions whose place no longer exists; reads the settings with administrator rights, changes nothing | yes |
| Periodic maintenance | only periods that are due; no longer present since macOS 26 | yes |
| Sidebar and recents | move unreadable sidebar and recent-items lists to the Trash | no |
| Verify startup volume | check the file system, changes nothing | no |
| Login items | report entries whose program is missing | no |
| Download history | clear Gatekeeper's download history (privacy) | no |
| Background services | report services whose program is missing | no |
| Notifications | delete delivered notifications older than 30 days | no |
| Databases | compact Mail, Safari, Messages (only closed, intact, < 100 MB) | no |

## App Store edition
There, only the tasks that work in your home folder without administrator rights are available: window states, broken preferences, sidebar and recents, download history and background services.
