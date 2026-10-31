# Optimiziraj

Optimiziraj izvršava zadatke održavanja za macOS. Nepotrebni koraci se s razlogom preskaču.

## Korištenje
- Odaberite zadatke pomoću **potvrdnih okvira**; "Odaberi sve/ništa" nalazi se u gornjem desnom kutu. Swabr pamti neoznačene zadatke.
- Svaki zadatak opisuje što radi i koje promjene donosi. Narančasta boja: primjetan sporedni učinak.
- **Lozenka:** zadaci kojima su potrebna administratorska prava izvršavaju se zajedno; lozenka se traži samo jednom. Otkazivanje preskače samo te zadatke.

## Zadaci
| Zadatak | Što se događa | Loзинka |
|---|---|---|
| QuickLook pregled | resetiranje predmemorije minijatura QuickLooka | ne |
| Stanja prozora | ukloniti spremljene prozore starije od 30 dana, ne za aktivne aplikacije | ne |
| Neispravne postavke | premjestiti oštećene datoteke preferencija trećih strana u Kantu za smeće | ne |
| DNS predmemorija | osvježi rješavanje imena (preskače se s aktivnim VPN-om ili kada ste izvan mreže) | da |
| Mrežne rute | isprazni tablicu usmjeravanja i obnovi adrese putem DHCP-a, samo ako svaki sučelje koristi DHCP (kratki prekid) | da |
| .DS_Store | nema datoteka iz Findera na mrežnim i USB pogonima | ne |
| Stari prekidači za podešavanje | App Nap i provjera slika vraćeni na zadano | ne |
| Dozvole | resetiranje dozvola u vašem korisničkom mapu, samo ako nešto nije u redu (traje nekoliko minuta) | da |
| Spotlight indeks | provjeri status, ponovno izgradi samo kod pogrešaka ili kada je indeksiranje isključeno | da |
| Isključenja iz Spotlighta | prijavljuje isključenja čije mjesto više ne postoji; čita postavke s administratorskim pravima, ništa ne mijenja | da |
| Periodično održavanje | samo razdoblja koja su dospjela; više nisu prisutna od macOS-a 26 | da |
| Bočna traka i nedavno korišteno | premjesti nečitljive popise bočne trake i nedavnih stavki u Kantu za smeće | ne |
| Provjeri pokretni volumen | provjeri datotečni sustav, ne mijenja ništa | ne |
| Stavke za prijavu | prijaviti unose za koje nedostaje program | ne |
| Povijest preuzimanja | poništiti povijest preuzimanja Gatekeepera (privatnost) | ne |
| Pozadinske usluge | prijaviti usluge čiji program nedostaje | ne |
| Obavijesti | izbriši isporučene obavijesti starije od 30 dana | ne |
| Baze podataka | komprimirajte Poštu, Safari, Poruke (samo zatvorene, netaknute, < 100 MB) | ne |

## Izdanje za App Store
Tamo su dostupni samo zadaci koji rade u vašem korisničkom mapu bez administratorskih prava: stanja prozora, neispravne postavke, bočna traka i nedavni elementi, povijest preuzimanja i pozadinske usluge.
