# Deinstalacija aplikacija

Povlačenje aplikacije u Kantu za smeće ostavlja njezine podatke: keš, postavke, pozadinske usluge i ponekad sistemske datoteke. Swabr pronalazi te ostatke.

## Kako radi
- Odaberite aplikacije s lijeve strane pomoću **potvrdnog okvira** (moguće je odabrati više aplikacija). Informacije i sve pronađene datoteke pojavljuju se s desne strane.
- **Deinstaliraj …** otvara prozor za pregled sa svim posljedicama.
- Pokrenute aplikacije se prvo zatvaraju. Sve se premješta u Kantu **za smeće**.

## Što se uklanja?
| Grupa | Primjeri | Unaprijed odabrano |
|---|---|---|
| **Bit će uklonjen** | aplikacija, predmemorije, dnevnici, stanje prozora, agenti za pokretanje | da |
| **Osobni podaci** | postavke, kontejnere, račune, biblioteke | ne |
| **Osjetljivo** | profili preglednika (lozinke, povijest), podaci grupe aplikacija | nikada automatski |
| **Sistemski datoteke** | datoteke u /Library, sistemske usluge, pomoćni alati | ne, potrebna je lozinka |

Osobni podaci zadržavaju se prema zadanim postavkama, tako da se postavke i računi vraćaju ako ponovno instalirate aplikaciju. Opcija "Ukloni sve također" odabire tu radnju. Zadane postavke možete promijeniti u Postavke → Ponašanje.

## O aplikaciji
Odjeljak "Informacije" prikazuje programera (iz potpisa), kategoriju, verziju, zadnju upotrebu i – uz online informacije – opis i poveznice na web-stranicu, App Store i internetsku pretragu. To vam pomaže prepoznati nepoznate aplikacije prije njihova brisanja.

## Simboli
- **Zaključano:** zaštićeno (sistemski komponent, sigurnosni softver s vlastitim deinstalaterom, Swabr sam po sebi).
- **Ključ:** u vlasništvu drugog korisnika ili sustava; macOS traži vašu lozinku prilikom brisanja.

## Homebrew
Aplikacije instalirane pomoću Homebrewa uklanjaju se pomoću `brew uninstall`, tako da Homebrew ostaje sinkroniziran.
