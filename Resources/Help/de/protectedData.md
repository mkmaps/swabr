# Geschützte Daten (Whitelist)

Die Liste unter Einstellungen → **Geschützte Daten** legt fest, was Swabr beim Aufräumen **nie** anfasst – auch wenn eine Regel es sonst erfassen würde. Andere Werkzeuge nennen das „Whitelist“.

## Wie lese ich die Liste?
- **Schalter an = geschützt.** Der Eintrag erscheint beim Aufräumen nicht mehr bzw. wird mit grünem Schild als geschützt angezeigt.
- **Schalter aus = darf aufgeräumt werden**, sofern eine Aufräum-Regel ihn erfasst.
- **„Standard“** markiert Einträge, die schon ab Werk geschützt sind (Gradle-Caches, Playwright-Browser, Hugging-Face-Modelle).
- Hinter jedem Eintrag steht, wie viel Platz er gerade belegt. So siehst du, was der Schutz kostet.

## Wann schützen?
Schütze Daten, die zwar neu erzeugt werden, aber lange dauern oder viel Datenvolumen kosten: Xcode DerivedData eines großen Projekts, Gradle-Caches, heruntergeladene KI-Modelle, Homebrew-Downloads bei langsamer Verbindung.

## Eigene Einträge
Unter „Eigene Einträge“ schützt du beliebige Ordner oder Dateien:
- **Ordner wählen …** öffnet einen Dialog; der gewählte Ordner wird geschützt.
- Oder ein **Muster** eintippen. Darunter siehst du sofort, wie viele Einträge es trifft.

| Muster | Schützt |
|---|---|
| `~/Library/Caches/Foo` | genau diesen Ordner |
| `~/Library/Caches/Foo/*` | alles in diesem Ordner (und damit den Ordner) |
| `~/Library/Caches/Foo*` | alle Ordner, die mit „Foo“ beginnen |

„~“ ist dein Benutzerordner, „*“ beliebige Zeichen.

## Sicherheitsregeln
Einige Einträge sind fest geschützt und nicht abschaltbar: Caches, die iCloud-Synchronisation, Anmeldung beim Apple-Account, Wallet, Home, Schriften, Spotlight oder laufende Hintergrund-Downloads enthalten, sowie der Cache von Swabr selbst. Außerdem sind iCloud Drive, Schlüsselbund, Dokumente, Schreibtisch und alles außerhalb deines Benutzerordners grundsätzlich tabu.

## Speicherort und Zurücksetzen
Die Liste liegt in `~/.config/swabr/whitelist` (eine Zeile pro Muster). Sobald du etwas änderst, ersetzt diese Datei die Standardliste; „Auf Standard zurücksetzen“ löscht sie wieder.
