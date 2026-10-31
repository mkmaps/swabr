# Administratorrechte (Hilfsdienst)

## Was ist das?
Manche Schritte brauchen Administratorrechte: Apps entfernen, die dem System gehören, Optimierungen wie das Leeren des DNS-Cache und das Auslesen der Anmeldeobjekte, die Apps selbst eingetragen haben. Ohne Hilfsdienst fragt macOS dafür jedes Mal nach deinem Passwort.

Der **Hilfsdienst** von Swabr übernimmt diese Schritte, nachdem du ihn einmal erlaubt hast. Er nimmt nur Aufträge von Swabr an, die mit demselben Entwicklerzertifikat signiert sind, und beendet sich nach fünf Minuten ohne Arbeit. Das gibt es nur in der Direct-Version.

## So richtest du ihn ein
### 1. In Swabr einrichten
Öffne **Swabr → Einstellungen → Verhalten** und klicke im Abschnitt **Administratorrechte** auf **Einrichten …**.

![](images/helfer-1-einstellungen.png)

### 2. In den Systemeinstellungen erlauben
macOS öffnet **Systemeinstellungen → Allgemein → Anmeldeobjekte**. Schalte unter **App-Hintergrundaktivitäten** den Eintrag **Swabr OP** ein und bestätige mit deinem Passwort oder Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Fertig
Zurück in Swabr steht im Abschnitt **Administratorrechte**: „Eingerichtet: kein Passwort mehr nötig“. Ab jetzt laufen diese Schritte ohne Rückfrage.

> Steht dort „Wartet auf deine Erlaubnis in den Systemeinstellungen“, fehlt noch Schritt 2. Das **Zahnrad** daneben führt direkt dorthin.

## Was ändert sich danach?
- **Apps → Start** zeigt auch Apps, die sich selbst anmelden (z. B. über „Beim Anmelden öffnen“ in der App).
- **Deinstallieren**, **Optimieren** und die Root-Schritte in **Aufräumen**, **Projekte**, **Installer** und **Verschlanken** fragen nicht mehr nach dem Passwort.
- Die Sicherheitsprüfungen bleiben gleich: Auch mit Hilfsdienst gelten alle festen Sperren, und jeder Schritt wird geprüft und protokolliert.

## Entfernen
In **Einstellungen → Verhalten → Administratorrechte** auf **Entfernen** klicken. Swabr fragt danach wieder bei jedem Schritt nach dem Passwort.
