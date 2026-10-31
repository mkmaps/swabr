# Projektek

A Projektek eltávolítja a szoftverprojektekből a build- és függőségi mappákat, pl. a `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` és további 27 típust.

## Keresési helyek
Alapértelmezés szerint: ~/dev, ~/Projektek, ~/GitHub, ~/Code és egyéb szokásos mappák. A tetején található **„Mappa hozzáadása…”** gombbal saját mappákat is hozzáadhat, akár külső meghajtókról is. A keresés 6 szint mélységig terjed (beállítható).

## Biztonsági szabályok
- Csak a projekten belüli mappák (amelyek tartalmaznak `package.json`, `Cargo.toml`, `go.mod`, `Package.swift` és egyéb fájlokat).
- A git által nyomon követett fájlokat vagy kulcsfájlokat (`*-keypair.json`) tartalmazó mappák érintetlenek maradnak.
- A `bin` csak .NET-projektekben, a `vendor` pedig csak PHP/Composer esetén jelenik meg.
- Az elmúlt 7 napban használt mappák meg vannak jelölve, de nincsenek előre kijelölve (beállítható).

## Utána
Minden sorban szerepel, hogyan lehet a mappát visszaállítani (pl. `npm install`, `cargo build`). Alapértelmezés szerint véglegesen törlődnek; választható a „Áthelyezés a Kukába” opció.
