# Slim down

Many apps are "Universal" and contain code for Intel and Apple silicon Macs. A Mac with an Apple chip needs only part of it. Slim Down removes the Intel part.

## Which apps?
Only apps signed with a Developer ID, owned by you, not from the App Store, not by Apple, not set to "Open using Rosetta" and not running. All others are listed under "Skipped" with the reason.

## How safe is it?
- Every app is slimmed on a **copy**.
- The copy replaces the original only if it keeps its Apple silicon code, the code signature is valid, the same developer signed it and Gatekeeper agrees.
- The original goes to the **Trash**.

## Effects
The app then runs only on Apple silicon Macs, no longer with Rosetta or on Intel Macs. An app update brings the Intel code back. Direct edition only.
