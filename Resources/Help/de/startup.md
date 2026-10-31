# Start: Anmeldeobjekte und Dienste

## Beim Anmelden starten (Direct)
Jede installierte App hat einen Schalter **„Beim Anmelden starten“**. Eingeschaltete Apps öffnet macOS nach der Anmeldung. Der kleinere Schalter **„Versteckt“** startet sie ohne Fenster. Das ist dieselbe Liste wie in Systemeinstellungen → Allgemein → Anmeldeobjekte; Swabr steuert sie über „System Events“ (macOS fragt einmal nach der Erlaubnis).

## Hintergrunddienste
Darunter (aufklappbar) stehen Updater und Hilfsprogramme, die Apps selbst einrichten (LaunchAgents/LaunchDaemons):
- **Deine Dienste** (im Benutzerordner): Start erlauben/blockieren, entfernen (Papierkorb).
- **Systemweite Dienste:** nur Anzeige; ändern in den Systemeinstellungen. Ausnahme: Fehlt ihr Programm, lassen sie sich mit **„Entfernen …“** löschen (macOS fragt nach dem Passwort).
- **„Programm fehlt“:** Der Dienst zeigt auf eine gelöschte App und tut nichts mehr – kann weg.

## Verwaiste Einträge entfernen
Anmeldeobjekte und Dienste, deren App nicht mehr installiert ist, sind orange mit **„Programm fehlt“** markiert.
- Bei einem Anmeldeobjekt löscht **„Aus der Liste entfernen“** den Eintrag aus den Anmeldeobjekten.
- Unten rechts entfernt **„Verwaiste entfernen (Anzahl) …“** alle auf einmal, nach einer Rückfrage mit der Liste der Namen.
- Dienst-Dateien landen im Papierkorb und lassen sich von dort wiederherstellen. Swabr entfernt systemweite Dienste nur, wenn ihr Programm wirklich fehlt.

## App-Store-Version
Die App-Store-Version darf weder System Events steuern noch Dienste starten oder stoppen. Sie zeigt deine eigenen Hintergrunddienste und kann sie entfernen; Anmeldeobjekte verwaltest du über den Knopf zu den Systemeinstellungen.
