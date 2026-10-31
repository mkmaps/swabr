# Optimieren

Optimieren führt Wartungsaufgaben für macOS aus. Unnötige Schritte überspringt Swabr mit Begründung.

## Bedienung
- Aufgaben per **Kästchen** wählen; „Alle auswählen/abwählen“ oben rechts. Abgewählte Aufgaben merkt sich Swabr.
- Jede Aufgabe beschreibt, was sie tut und was sich danach ändert. Orange markiert: spürbare Nebenwirkung.
- **Passwort:** Aufgaben mit Administratorrechten laufen gesammelt; das Passwort wird nur einmal abgefragt. Abbrechen überspringt nur diese Aufgaben.

## Die Aufgaben
| Aufgabe | Was passiert | Passwort |
|---|---|---|
| QuickLook-Vorschauen | Vorschaubilder-Cache von QuickLook zurücksetzen | nein |
| Fensterzustände | Gespeicherte Fenster älter als 30 Tage entfernen, nicht bei laufenden Apps | nein |
| Defekte Einstellungen | Beschädigte Einstellungsdateien von Drittanbietern in den Papierkorb | nein |
| DNS-Cache | Namensauflösung leeren (übersprungen bei aktivem VPN oder ohne Netz) | ja |
| Netzwerk-Routen | Routing-Tabelle leeren und Adressen per DHCP neu holen, nur wenn alle Schnittstellen DHCP nutzen (kurze Unterbrechung) | ja |
| .DS_Store | Keine Finder-Dateien auf Netz- und USB-Laufwerken | nein |
| Alte Tuning-Schalter | App-Nap- und Image-Prüfung wieder auf Standard | nein |
| Zugriffsrechte | Rechte im Benutzerordner zurücksetzen, nur wenn etwas falsch ist (dauert Minuten) | ja |
| Spotlight-Index | Status prüfen, nur bei Fehler oder ausgeschaltetem Index neu aufbauen | ja |
| Spotlight-Ausschlüsse | Ausschlüsse melden, deren Ort nicht mehr existiert; liest die Einstellungen mit Administratorrechten, ändert nichts | ja |
| Periodische Wartung | nur fällige Durchläufe; seit macOS 26 nicht mehr vorhanden | ja |
| Seitenleiste und Verlauf | Unlesbare Seitenleisten- und Verlaufslisten in den Papierkorb | nein |
| Startvolume prüfen | Dateisystem prüfen, ändert nichts | nein |
| Anmeldeobjekte | Einträge mit fehlendem Programm melden | nein |
| Download-Verlauf | Gatekeeper-Download-Verlauf leeren (Datenschutz) | nein |
| Hintergrunddienste | Dienste mit fehlendem Programm melden | nein |
| Mitteilungen | Zugestellte Mitteilungen älter als 30 Tage löschen | nein |
| Datenbanken | Mail, Safari, Nachrichten komprimieren (nur geschlossen, intakt, < 100 MB) | nein |

## App-Store-Version
Dort stehen nur die Aufgaben zur Verfügung, die ohne Administratorrechte in deinem Benutzerordner arbeiten: Fensterzustände, defekte Einstellungen, Seitenleiste und Verlauf, Download-Verlauf und Hintergrunddienste.
