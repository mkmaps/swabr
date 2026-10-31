# Sicherheit: Papierkorb, Löschen, Protokoll

## Nichts ohne deine Bestätigung
Jeder Bereich zeigt zuerst eine Liste. Vor dem Entfernen erscheint ein **Prüffenster** mit allen Einträgen und ihren Auswirkungen; erst „Löschen“ bzw. „In den Papierkorb legen“ ändert etwas.

## Papierkorb oder endgültig?
| | Papierkorb | Endgültig |
|---|---|---|
| Wiederherstellbar | ja, bis zum Leeren („Zurücklegen“ im Finder) | nein |
| Speicher frei | erst nach dem Leeren | sofort |
| Verwendet bei | Deinstallieren, Speicher, Installer, Verschlanken, wahlweise Aufräumen und Projekte | wahlweise Aufräumen und Projekte |

Aufräumen und Projekte löschen standardmäßig endgültig, weil Caches und Build-Ordner ohnehin neu erzeugt werden. Unter Einstellungen → Verhalten stellst du den Papierkorb als Standard ein.

## Mehrfach geprüft
- Gelöscht wird nur innerhalb deines Benutzerordners (und bei Apps in den Programme-Ordnern).
- Symbolische Links werden nie verfolgt; ein Link im Pfad stoppt die Löschung.
- Unmittelbar vor jeder Löschung prüft Swabr erneut: Gibt es den Eintrag noch? Ist er inzwischen geschützt?
- iCloud-Platzhalter werden nie heruntergeladen und nicht mitgezählt.

## Protokoll
Jede Aktion wird mit Zeit, Pfad und Größe protokolliert. Du findest sie im Bereich **Verlauf**.
