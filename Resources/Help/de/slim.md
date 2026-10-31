# Verschlanken

Viele Apps sind „Universal“ und enthalten Code für Intel- und Apple-Silicon-Macs. Ein Mac mit Apple-Chip braucht nur einen Teil davon. Verschlanken entfernt den Intel-Teil.

## Welche Apps?
Nur Apps, die mit einer Developer ID signiert sind, dir gehören, nicht aus dem App Store stammen, keine Apple-Apps sind, nicht auf „Mit Rosetta öffnen“ stehen und nicht laufen. Alle anderen stehen mit Grund unter „Übersprungen“.

## Wie sicher ist das?
- Jede App wird an einer **Kopie** verschlankt.
- Die Kopie ersetzt das Original nur, wenn sie den Apple-Silicon-Code behält, die Code-Signatur gültig ist, derselbe Entwickler signiert hat und Gatekeeper zustimmt.
- Das Original landet im **Papierkorb**.

## Auswirkungen
Die App läuft danach nur noch auf Apple-Silicon-Macs, nicht mehr mit Rosetta oder auf Intel-Macs. Ein App-Update bringt den Intel-Code zurück. Nur in der Direct-Version verfügbar.
