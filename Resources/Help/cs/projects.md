# Projekty

Projekty odstraňuje složky sestavení a závislostí z vašich softwarových projektů, např. `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` a dalších 27 typů.

## Místa pro vyhledávání
Ve výchozím nastavení: ~/dev, ~/Projekty, ~/GitHub, ~/Code a další běžné složky. Přidejte si vlastní pomocí **možnosti „Přidat složku …“** v horní části, a to i na externích discích. Vyhledávání probíhá do hloubky 6 úrovní (nastavitelné).

## Bezpečnostní pravidla
- Pouze složky uvnitř projektu (s soubory package.json, Cargo.toml, go.mod, Package.swift a dalšími).
- Složky obsahující soubory sledované systémem Git nebo soubory s klíči (`*-keypair.json`) zůstávají nedotčeny.
- `bin` pouze v projektech .NET, `vendor` pouze u PHP/Composer.
- Složky použité v posledních 7 dnech jsou označeny a nejsou předem vybrány (lze nastavit).

## Poté
Každý řádek uvádí, jak složku obnovit (např. `npm install`, `cargo build`). Ve výchozím nastavení jsou trvale odstraněny; k dispozici je možnost „Přesunout do Koše“.
