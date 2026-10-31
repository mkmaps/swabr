# Projekti

Projekti uklanja mape za izgradnju i ovisnosti iz vaših softverskih projekata, npr. `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` i još 27 vrsta.

## Lokacije pretraživanja
Po zadanome: ~/dev, ~/Projekti, ~/GitHub, ~/Code i druge uobičajene mape. Dodajte vlastite mapu pomoću **opcije Dodaj mapu …** na vrhu, također na vanjske pogone. Pretraživanje seže 6 razina duboko (podesivo).

## Sigurnosna pravila
- Samo mape unutar projekta (s paketom.json, Cargo.toml, go.mod, Package.swift i drugima).
- Mape s praćenim git datotekama ili ključnim datotekama (`*-keypair.json`) ostaju netaknute.
- `bin` samo u .NET projektima, `vendor` samo s PHP/Composerom.
- Mapama korištenima u posljednjih 7 dana postavljena je oznaka i nisu odabrane (može se promijeniti).

## Nakon toga
Svaki redak navodi kako vratiti mapu (npr. `npm install`, `cargo build`). Zadano se trajno brišu; dostupna je opcija "Umjesto toga premjesti u smeće".
