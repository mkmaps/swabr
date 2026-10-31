# Direct- und App-Store-Version

Swabr gibt es in zwei Varianten aus demselben Code. Die Variante steht unter Einstellungen → Allgemein und unter „Über“.

| | Direct | App Store |
|---|---|---|
| Vertrieb | GitHub (DMG) | Mac App Store |
| Zugriff | ganzer Benutzerordner mit Festplattenvollzugriff | nur Ordner, die du freigibst |
| Aufräumen, Deinstallieren | ja | ja, nach Freigabe |
| Apps, die dem System gehören | ja (Finder fragt nach dem Passwort) | ja (macOS fragt nach dem Passwort) |
| Systemdateien in /Library | ja | ja, nach Freigabe von /Library |
| Optimieren | alle 19 Aufgaben | 5 Aufgaben ohne Administratorrechte |
| Updates | installiert Updates selbst | zeigt Updates, öffnet App Store oder Hersteller-Website |
| Start | Anmeldeobjekte und Dienste verwalten | eigene Hintergrunddienste anzeigen und entfernen |
| Verschlanken | ja | nein |

## Warum die App-Store-Version weniger kann
Apple verlangt für den App Store eine **Sandbox**: Apps dürfen nur auf freigegebene Ordner zugreifen, keine Administratorrechte anfordern, keine anderen Apps installieren oder verändern und keine anderen Apps fernsteuern (App Store Review Guidelines 2.4.5 und 2.5.2). Swabr hält sich daran und bietet innerhalb dieser Regeln so viel wie möglich.

## Ordner freigeben (App-Store-Version)
Beim ersten Öffnen von Aufräumen, Optimieren oder Apps erscheint „Zugriff erlauben“. Klicke „Freigeben …“; der Dialog steht schon auf dem richtigen Ordner, du bestätigst nur. Freigaben bleiben gespeichert und lassen sich unter Einstellungen → Freigaben widerrufen.

## Direct-Version und Quellcode
Swabr ist freie Software unter der MIT-Lizenz. Die Direct-Version und den vollständigen Quellcode gibt es kostenlos auf GitHub; der Link steht unter Einstellungen → Über.
