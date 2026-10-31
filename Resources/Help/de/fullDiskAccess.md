# Festplattenvollzugriff

## Was ist das?
macOS schützt bestimmte Daten besonders: Mail, Nachrichten, Safari, den Papierkorb, Time-Machine-Backups und die Daten mancher Apps. Programme sehen diese Ordner nur, wenn du ihnen den **Festplattenvollzugriff** erteilst. Das ist eine Sicherheitsfunktion von macOS, kein Swabr-Mechanismus.

## Wozu braucht Swabr ihn?
Ohne ihn fehlen Swabr Teile deines Mac:
- **Aufräumen:** Papierkorb, Mail-Anhänge, Caches in App-Containern und Nachrichten-Vorschauen bleiben unsichtbar.
- **Speicher:** Ordner wie Mail oder Safari werden zu klein oder gar nicht gemessen („+“ hinter der Größe).
- **Optimieren:** Datenbanken von Mail, Safari und Nachrichten sowie die Nutzungsdaten sind nicht erreichbar.

Swabr funktioniert auch ohne, findet dann aber weniger.

## Was darf Swabr damit?
Der Zugriff erlaubt Lesen und Schreiben. Swabr nutzt ihn ausschließlich für die Regeln, die du in der App siehst, und löscht nur nach deiner Bestätigung im Prüffenster. Feste Sperren gelten immer: iCloud Drive, Schlüsselbund, Dokumente, Schreibtisch und alles außerhalb deines Benutzerordners werden nie angefasst. Jede Löschung steht im Verlauf.

## So erteilst du ihn
### 1. Systemeinstellungen öffnen
Klicke im orangefarbenen Hinweis in Swabr (oder im Fenster beim ersten Start) auf das **Zahnrad**. Es öffnet sich **Systemeinstellungen → Datenschutz & Sicherheit → Festplattenvollzugriff**.

### 2. Swabr einschalten
Schalte den Schalter neben **Swabr OP.app** ein und bestätige mit deinem Passwort oder Touch ID. Fehlt der Eintrag, füge Swabr mit **+** hinzu oder ziehe die App aus dem Finder in die Liste.

![](images/festplattenvollzugriff-1-liste.png)

### 3. Swabr neu starten
macOS bittet meist darum. Danach verschwindet der orangefarbene Hinweis.

> Wenn du Swabr an einen anderen Ort verschiebst oder eine neu signierte Version installierst, kann macOS den Eintrag als neue App werten. Entferne dann den alten Eintrag mit **−** und füge Swabr erneut hinzu.

## Widerrufen
Schalter in derselben Liste ausschalten. Swabr zeigt dann wieder den Hinweis und arbeitet eingeschränkt.

## App-Store-Version
Die App-Store-Version nutzt keinen Festplattenvollzugriff, sondern Ordnerfreigaben (siehe „Direct- und App-Store-Version“).
