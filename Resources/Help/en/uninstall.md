# Uninstalling apps

Dragging an app to the Trash leaves its data behind: caches, settings, background services and sometimes system files. Swabr finds these leftovers.

## How it works
- Select apps on the left with the **check box** (several possible). Information and all files found appear on the right.
- **Uninstall …** opens the review window with all effects.
- Running apps are quit first. Everything goes to the **Trash**.

## What is removed?
| Group | Examples | Preselected |
|---|---|---|
| **Will be removed** | app, caches, logs, window state, launch agents | yes |
| **Personal data** | settings, containers, accounts, libraries | no |
| **Sensitive** | browser profiles (passwords, history), app group data | never automatically |
| **System files** | files in /Library, system services, helper tools | no, needs password |

Personal data stays by default, so settings and accounts are back if you reinstall the app. "Remove all too" selects it. Change the default under Settings → Behavior.

## About the app
The "Information" section shows the developer (from the signature), category, version, last use and – with online info on – a description and links to website, App Store and web search. This helps you recognise unknown apps before deleting them.

## Symbols
- **Lock:** protected (system component, security software with its own uninstaller, Swabr itself).
- **Key:** owned by another user or the system; macOS asks for your password when deleting.

## Homebrew
Apps installed with Homebrew are removed with `brew uninstall`, so Homebrew stays in sync.
