# Nachbesserung zur Abnahme Swabr 0.9.3 – 2026-10-31

Bezug: `2026-10-31-abnahme-0.9.3.md` (Urteil „abnahmefähig mit Auflagen“)

| ID | Stand | Umsetzung | Commit |
|---|---|---|---|
| A-01 | ✅ behoben | Helfer nimmt nur feste `RootOperation`s an (Papierkorb, Dienst stoppen, App ersetzen, 7 Wartungsbefehle), kein Shell-Skript mehr. Eigene Prüfung jedes Pfads im Helfer (`RootExecutor`: Wurzeln, Links, `realpath`, kein `com.apple.`, nur in den Papierkorb des anfragenden Benutzers, Benutzer aus der XPC-Verbindung). Verschieben per `renameatx_np` relativ zu `O_NOFOLLOW`-Ordnern mit `RENAME_EXCL`. Passwort-Weg startet denselben Helfer einmal (`--perform`). | 6abf295 |
| A-02 | ✅ behoben | Jeder Programmaufruf des Helfers mit Zeitlimit; danach `terminate`, dann `SIGKILL`. | 6abf295 |
| A-03 | ✅ behoben | Aufräumen und Projekte prüfen direkt vor dem Löschen erneut, ob der Ordner noch auf sich selbst auflöst bzw. das Ziel kein Link ist; Größe wird vorher gemessen. | f914312 |
| A-04 | ✅ behoben | Summenlogik in `CleanSelection` (SwabrCore), von Seite, Seitenleiste, Übersicht und Menüleiste gemeinsam genutzt; 4 Tests. | dcf388b |
| A-05 | ✅ behoben | VoiceOver-Beschriftungen für alle Knöpfe/Schalter mit reinem Symbol, Ansichtsumschalter und Status-Symbole; in 12 Sprachen. | 0c346e2 |
| A-06 | ✅ behoben | Appcast-Muster einmal erzeugt, ohne `try!`. | f914312 |
| A-07 | ✅ behoben | Geteilte Einstellungen (`ProjectPurge`, `DiskWalker`) per `Mutex`, kein `nonisolated(unsafe)` mehr. | f914312 |
| A-08 | ✅ erledigt | Release 0.9.3 committet (1f43c7c). | – |
| A-09 | ⏳ offen | Hilfe-Bilder mit „Swabr OP.app“ brauchen die Freigaben (Festplattenvollzugriff, Hilfsdienst) für Swabr OP. | – |

Messwerte nach der Nachbesserung: Tests 245/245 grün (8 neue für die Prüfregeln des Helfers, 4 für `CleanSelection`), Build Direct und Store ohne Fehler, kein `try!`/`nonisolated(unsafe)` im Code, kein Shell-Skript als root.

Noch zu prüfen am Gerät: Hilfsdienst neu einrichten (Protokollversion 2) und einen Root-Schritt auslösen (z. B. Apps → Start, das liest die Hintergrundobjekte über den Helfer).
