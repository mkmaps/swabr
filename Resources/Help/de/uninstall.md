# Apps deinstallieren

Eine App in den Papierkorb zu ziehen, lässt ihre Daten zurück: Caches, Einstellungen, Hintergrunddienste und manchmal Systemdateien. Swabr findet diese Reste.

## Ablauf
- App links per **Kästchen** auswählen (mehrere möglich). Rechts erscheinen Informationen und alle gefundenen Dateien.
- **Deinstallieren …** öffnet das Prüffenster mit allen Auswirkungen.
- Laufende Apps werden vorher beendet. Alles landet im **Papierkorb**.

## Was wird entfernt?
| Gruppe | Beispiele | Vorausgewählt |
|---|---|---|
| **Wird entfernt** | Programm, Caches, Logs, Fensterzustand, Startagenten | ja |
| **Persönliche Daten** | Einstellungen, Container, Konten, Bibliotheken | nein |
| **Besonders heikel** | Browser-Profile (Passwörter, Verlauf), App-Gruppen-Daten | nie automatisch |
| **Systemdateien** | Dateien in /Library, Systemdienste, Hilfsprogramme | nein, braucht Passwort |

Persönliche Daten bleiben standardmäßig erhalten, damit Einstellungen und Konten bei einer Neuinstallation wieder da sind. „Alle mit entfernen“ wählt sie aus. Das Standardverhalten stellst du unter Einstellungen → Verhalten ein.

## Informationen zur App
Im Abschnitt „Informationen“ siehst du Entwickler (aus der Signatur), Kategorie, Version, letzte Nutzung und – bei eingeschalteten Online-Infos – eine Beschreibung sowie Links zu Website, App Store und Websuche. So erkennst du unbekannte Apps, bevor du sie löschst.

## Symbole
- **Schloss:** geschützt (Systemkomponente, Sicherheitssoftware mit eigenem Deinstallationsprogramm, Swabr selbst).
- **Schlüssel:** gehört einem anderen Benutzer oder dem System; beim Löschen fragt macOS nach deinem Passwort.

## Homebrew
Mit Homebrew installierte Apps entfernt Swabr über `brew uninstall`, damit Homebrew Bescheid weiß.
