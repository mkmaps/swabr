# Aufräumen

Aufräumen findet Daten, die Apps und macOS bei Bedarf neu erzeugen: Caches, Logs, temporäre Dateien, Browser- und Entwickler-Caches sowie Reste deinstallierter Apps. Swabr arbeitet mit zwei Arten von Regeln:
- **Gezielte Regeln** für Browser, Entwicklerwerkzeuge (Xcode, Homebrew, npm, pip, Cargo, Gradle …) und einige Apps, deren Daten tiefer liegen.
- **Allgemeine Regeln** nach den Ordnerregeln von macOS: alles unter `~/Library/Caches`, die Cache-Ordner von Chromium in jeder Electron-App (Slack, Discord, VS Code, Obsidian …), Caches, Logs und temporäre Dateien in App-Containern. So werden auch Apps erfasst, die keine Liste kennt.

Jede Regel trägt ihre Art (Cache, Protokolle, Pakete, Build …) und ihre Einstufung selbst. Gezielte Regeln haben Vorrang vor allgemeinen.

## Ablauf
- **Scan starten:** Swabr sucht nur, nichts wird verändert.
- **Liste prüfen:** Links stehen die Kategorien mit ihrer Größe, rechts die Einträge der gewählten Kategorie mit Einstufung, Größe und Auswirkung. Das Kästchen vor einer Kategorie wählt sie ganz aus, Aufklappen zeigt die einzelnen Pfade.
- **In den Papierkorb:** Knopf unten rechts, danach das Prüffenster bestätigen. Ist „Endgültig löschen“ eingeschaltet, heißt der Knopf „Bereinigen“ und löscht sofort.
- **Fertig:** Die Abschlussseite zeigt, wie viel frei wurde, aufgeteilt nach Kategorien, und den freien Speicher vorher und nachher.

## Sicher oder Prüfen
| Stufe | Bedeutung | Vorausgewählt |
|---|---|---|
| **Sicher** (grün) | Cache, Log oder temporäre Daten, die neu erzeugt werden | ja |
| **Prüfen** (orange) | Kann noch benötigte Daten enthalten oder dauert lange beim Neuladen: Papierkorb, Mail-Anhänge, Fensterzustände, Caches von macOS selbst, große Downloads wie Gradle oder Playwright | nein |

„Empfohlen“ wählt nur sichere Einträge, „Alle“ alles, „Keine“ nichts.

## Übersprungene Einträge
- **„läuft gerade“:** Caches einer geöffneten App werden nicht angefasst (z. B. Chrome, Slack, VS Code). Das gilt auch für die allgemeinen Regeln: Swabr erkennt die zugehörige App am Ordnernamen oder an der Bundle-ID. App beenden und erneut scannen.
- **Grünes Schild:** Der Eintrag ist geschützt (siehe „Geschützte Daten“) oder liegt in einem gesperrten Bereich.

## Besondere Kategorien
- **Reste entfernter Apps:** Caches, Logs und Fensterzustände von Apps, die nicht mehr installiert sind und seit 30 Tagen unverändert sind (einstellbar). Passwort-Manager, Schlüsselbund und SSH-Daten sind ausgenommen.
- **Große Datenbestände (nur Hinweis):** iOS-Backups, Mail, Simulatoren, Docker, KI-Modelle. Swabr löscht sie nie automatisch, sondern sagt, wo man sie richtig aufräumt.

## Nie mehr bereinigen
Rechtsklick auf einen Eintrag → **„Nie bereinigen“** schützt ihn dauerhaft. Rückgängig unter Einstellungen → Geschützte Daten.

Das gilt auch für alles, was dieselbe Regel später findet. In der aufgeklappten Liste schützt ein Rechtsklick auf einen Ort nur diesen Ort, alles einer App oder alle Ordner mit diesem Namen. Direkt danach lässt sich der Schutz in der Leiste über der Liste mit **„Rückgängig“** zurücknehmen.

## Was ändert sich danach?
Apps bauen Caches neu auf; der erste Start oder das erste Laden einer Webseite kann etwas länger dauern. Anmeldungen, Dokumente, Einstellungen und Lesezeichen bleiben erhalten.
