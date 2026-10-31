# App-Updates

Swabr prüft alle installierten Apps auf neue Versionen. Voraussetzung: **Online-Infos** sind eingeschaltet (Einstellungen → Allgemein).

## Quellen
| Quelle | Erkennung | Direct-Version | App-Store-Version |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | Website öffnen |
| App Store | Abgleich mit dem App Store | App Store öffnet die Update-Seite | dasselbe |
| Update-Kanal der App (Sparkle) | Appcast des Herstellers | lädt und installiert die neue Version | Website öffnen |
| Hersteller (Homebrew-Katalog) | Versionsvergleich | lädt vom Hersteller und installiert | Website öffnen |

## Sicherheit beim Installieren (Direct)
Ein Download ersetzt eine App nur, wenn die **Prüfsumme** stimmt, die **Entwickler-Signatur** dieselbe ist wie bei der installierten App und **Gatekeeper** zustimmt. Die alte Version landet im Papierkorb. Laufende Apps werden nach Rückfrage beendet und danach wieder geöffnet.

## Bedienung
- Einzeln mit **Aktualisieren** oder mehrere per **Kästchen** und „Ausgewählte aktualisieren“.
- Über ⋯ blendest du ein Update aus.
- „Aktuell“ und „Nicht prüfbar“ listen die übrigen Apps; Safari-Web-Apps haben keine Updates.

> Apps aus .pkg-Installern öffnen das macOS-Installationsprogramm; dort schließt du die Installation ab.
