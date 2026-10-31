# Projekte

Projekte entfernt Build- und Abhängigkeitsordner aus deinen Softwareprojekten, z. B. `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` und 27 weitere Arten.

## Suchorte
Standardmäßig: ~/dev, ~/Projects, ~/GitHub, ~/Code und weitere übliche Ordner. Eigene Orte fügst du oben mit **Ordner hinzufügen …** hinzu, auch auf externen Laufwerken. Gesucht wird bis 6 Ebenen tief (einstellbar).

## Schutzregeln
- Nur Ordner in einem Projekt (mit package.json, Cargo.toml, go.mod, Package.swift u. a.).
- Ordner mit Git-verwalteten Dateien oder Schlüsseldateien (`*-keypair.json`) bleiben unberührt.
- `bin` nur bei .NET-Projekten, `vendor` nur bei PHP/Composer.
- In den letzten 7 Tagen benutzte Ordner sind markiert und nicht vorausgewählt (einstellbar).

## Danach
Jede Zeile sagt, wie man den Ordner zurückbekommt (z. B. `npm install`, `cargo build`). Standardmäßig wird endgültig gelöscht; „In den Papierkorb statt löschen“ ist wählbar.
