# Proiecte

Proiecte elimină folderele de compilare și de dependențe din proiectele dvs. software, de exemplu `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` și încă 27 de tipuri.

## Locații de căutare
Implicit: ~/dev, ~/Proiecte, ~/GitHub, ~/Code și alte foldere obișnuite. Adăugați-vă propriile foldere cu **opțiunea „Adăugați folder…”** din partea de sus, inclusiv pe unitățile externe. Căutarea se efectuează pe 6 niveluri de adâncime (reglabil).

## Reguli de siguranță
- Doar folderele din interiorul unui proiect (cu fișiere precum `package.json`, `Cargo.toml`, `go.mod`, `Package.swift` și altele).
- Dosarele care conțin fișiere urmărite de Git sau fișiere cheie (`*-keypair.json`) rămân intacte.
- `bin`ul este prezent doar în proiectele .NET, iar `vendor`ul doar în cazul PHP/Composer.
- Dosarele utilizate în ultimele 7 zile sunt marcate și nu sunt preselectate (setare ajustabilă).

## După aceea
Fiecare rând indică modul de recuperare a folderului (de exemplu, `npm install`, `cargo build`). În mod implicit, acestea sunt șterse definitiv; este disponibilă opțiunea „Mutați în Coș”.
