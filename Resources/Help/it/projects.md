# Progetti

La funzione "Progetti" rimuove le cartelle di build e delle dipendenze dai tuoi progetti software, ad esempio `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` e altri 27 tipi.

## Cerca nelle posizioni
Di default: ~/dev, ~/Projects, ~/GitHub, ~/Code e altre cartelle comuni. Aggiungi le tue con **“Aggiungi cartella…”** in alto, anche su unità esterne. La ricerca va fino a 6 livelli di profondità (regolabile).

## Regole di sicurezza
- Solo cartelle all’interno di un progetto (con package.json, Cargo.toml, go.mod, Package.swift e altri).
- Le cartelle con file tracciati da Git o file di chiavi (`*-keypair.json`) rimangono intatte.
- `bin` solo nei progetti .NET, `vendor` solo con PHP/Composer.
- Le cartelle usate negli ultimi 7 giorni sono contrassegnate e non preselezionate (impostazione personalizzabile).

## In seguito
Ogni riga indica come ripristinare la cartella (ad es. `npm install`, `cargo build`). Per impostazione predefinita vengono eliminate definitivamente; è disponibile l’opzione “Sposta nel Cestino”.
