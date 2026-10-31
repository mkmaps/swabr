# Protected data (whitelist)

The list under Settings → **Protected Data** defines what Swabr **never** touches during clean-up – even if a rule would otherwise include it. Other tools call this a "whitelist".

## How to read the list
- **Switch on = protected.** The entry no longer appears in Clean Up, or appears with a green shield.
- **Switch off = may be cleaned** if a clean-up rule includes it.
- **"Default"** marks entries protected out of the box (Gradle caches, Playwright browsers, Hugging Face models).
- Each entry shows how much space it uses right now, so you see what protecting it costs.

## When to protect
Protect data that is recreated but takes long or costs a lot of data volume: Xcode DerivedData of a big project, Gradle caches, downloaded AI models, Homebrew downloads on a slow connection.

## Your own entries
Under "Your entries" you protect any folder or file:
- **Choose folder …** opens a dialog; the chosen folder is protected.
- Or type a **pattern**. Below it you immediately see how many items it matches.

| Pattern | Protects |
|---|---|
| `~/Library/Caches/Foo` | exactly this folder |
| `~/Library/Caches/Foo/*` | everything in this folder (and with it the folder) |
| `~/Library/Caches/Foo*` | every folder starting with "Foo" |

"~" is your home folder, "*" any characters.

## Safety rules
Some entries are always protected and can't be switched off: caches that hold iCloud sync state, Apple Account sign-in, Wallet, Home, fonts, Spotlight or background downloads in progress, and Swabr's own cache. On top of that, iCloud Drive, the keychain, Documents, Desktop and everything outside your home folder are always off limits.

## Location and reset
The list is stored in `~/.config/swabr/whitelist` (one pattern per line). As soon as you change something, this file replaces the default list; "Reset to defaults" deletes it again.
