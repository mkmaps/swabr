# Ažuriranja aplikacija

Swabr provjerava sve instalirane aplikacije na nove verzije. Preduvjet: uključene su **mrežne informacije** (Postavke → Općenito).

## Izvori
| Izvor | Otkrivanje | Izravno izdanje | Izdanje iz App Storea |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | otvori web-stranicu |
| App Store | usporedba s App Storeom | App Store otvara stranicu s ažuriranjima | isto |
| Kanala ažuriranja aplikacije (Sparkle) | appcast dobavljača | preuzima i instalira novu verziju | otvori web-stranicu |
| Proizvođač (Homebrew katalog) | usporedba verzija | preuzima s prodavača i instalira | otvori web-stranicu |

## Sigurnost pri instalaciji (izravno)
Preuzimanje zamjenjuje aplikaciju samo ako se **kontrolna suma** podudara, **potpis programera** je isti kao kod instalirane aplikacije i **Gatekeeper** to odobrava. Stara verzija odlazi u Kantu za smeće. Aplikacije koje su u tijeku rada zatvaraju se nakon što se to zatraži i potom se ponovno otvaraju.

## Upotreba
- Jednu po jednu pomoću **Ažuriraj**, ili više odjednom pomoću **potvrdnih okvira** i "Ažuriraj odabrano".
- Izbornik ⋯ skriva ažuriranje.
- "Ažurirano" i "Ne može se provjeriti" prikazuju ostale aplikacije; web-aplikacije Safarija nemaju ažuriranja.

> Aplikacije iz .pkg instalatera otvaraju macOS Instalater; dovršite instalaciju tamo.
