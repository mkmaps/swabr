# Probleme lösen

## „Festplattenvollzugriff fehlt“, obwohl erteilt
macOS bindet den Zugriff an die Signatur der App. Nach einem Update oder Verschieben: Eintrag in der Liste mit **−** entfernen, Swabr neu hinzufügen, neu starten.

## Eine App lässt sich nicht löschen
- **Schlüssel-Symbol:** Die App gehört dem System. macOS fragt nach deinem Passwort; bei „Abgebrochen“ einfach erneut versuchen.
- **„Swabr darf den Finder nicht steuern“:** Systemeinstellungen → Datenschutz & Sicherheit → Automation → Swabr → Finder einschalten.

## Einträge werden übersprungen
„läuft gerade“: App beenden und neu scannen. Grünes Schild: geschützt, siehe Geschützte Daten.

## DNS oder Netzwerk-Routen „übersprungen“
Bei aktivem VPN lässt Swabr beides absichtlich in Ruhe.

## Speicher zeigt „+“ hinter Größen
Einige Ordner waren nicht lesbar oder die Messung brauchte länger als das Zeitlimit. Festplattenvollzugriff prüfen oder das Zeitlimit unter Einstellungen → Verhalten erhöhen.

## Updates werden nicht angezeigt
Online-Infos einschalten (Einstellungen → Allgemein). Apps ohne bekannte Quelle stehen unter „Nicht prüfbar“.

## Etwas versehentlich gelöscht
Was im Papierkorb liegt, lässt sich im Finder „Zurücklegen“. Was endgültig gelöscht wurde, war ein Cache oder Build-Ordner und wird neu erzeugt. Der Verlauf zeigt, was wann entfernt wurde.
