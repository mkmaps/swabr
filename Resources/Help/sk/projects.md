# Projekty

Projekty odstraňuje z vašich softvérových projektov zložky súvisiace so zostavovaním a závislosťami, napr. `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` a ďalších 27 typov.

## Miesta vyhľadávania
Predvolene: ~/dev, ~/Projekty, ~/GitHub, ~/Code a ďalšie bežné zložky. Vlastné zložky môžete pridať pomocou **možnosti Pridať zložku…** v hornej časti, a to aj na externých diskoch. Vyhľadávanie prebieha do hĺbky 6 úrovní (nastaviteľné).

## Bezpečnostné pravidlá
- Iba zložky vnútri projektu (s súbormi package.json, Cargo.toml, go.mod, Package.swift a ďalšími).
- Zložky so súbormi sledovanými systémom git alebo súbormi kľúčov (`*-keypair.json`) zostávajú nedotknuté.
- `bin` len v projektoch .NET, `vendor` len pri PHP/Composer.
- Zložky použité za posledných 7 dní sú označené a nie sú predvolené (možnosť nastavenia).

## Potom
V každom riadku je uvedené, ako zložku obnoviť (napr. `npm install`, `cargo build`). Predvolene sa zložky trvalo odstránia; k dispozícii je možnosť „Presunúť do Koša“.
