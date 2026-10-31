# Čišćenje

Čišćenje pronalazi podatke koje aplikacije i macOS ponovno stvaraju po potrebi: predmemorije, dnevnike, privremene datoteke, predmemorije preglednika i programera te ostatke deinstaliranih aplikacija. Swabr radi s dvije vrste pravila:
- **Posebna pravila** za preglednike, alate za programere (Xcode, Homebrew, npm, pip, Cargo, Gradle …) i neke aplikacije čiji se podaci nalaze dublje.
- **Opća pravila** koja slijede konvencije mapa macOS-a: sve u mapi `~/Library/Caches`, mape predmemorije Chromiuma u svakoj Electron aplikaciji (Slack, Discord, VS Code, Obsidian …), predmemorije, dnevnici i privremene datoteke u spremnicima aplikacija. Na taj način su obuhvaćene i aplikacije za koje popis ne zna.

Svako pravilo ima svoju vrstu (keš, dnevnici, paketi, izrada …) i vlastitu ocjenu. Specifična pravila imaju prednost nad općim.

## Kako radi
- **Pokretanje skeniranja:** Swabr samo pregledava, ništa se ne mijenja.
- **Provjerite popis:** kategorije i njihove veličine nalaze se s lijeve strane, a stavke odabrane kategorije s desne strane s njihovom ocjenom, veličinom i učinkom. Okvir ispred kategorije odabire sve njezine stavke; proširite redak da biste vidjeli njegove putanje.
- **U kantu za smeće:** kliknite gumb u donjem desnom kutu, a zatim potvrdite prozor za potvrdu. Ako je uključena opcija "Trajno ukloni", gumb se zove "Očisti" i brisanje se odvija odmah.
- **Završeno:** posljednja stranica prikazuje koliko je prostora oslobođeno, razvrstano po kategorijama, te slobodan prostor prije i poslije.

## Sigurno ili Pregled
| Razina | Što znači | Unaprijed odabrano |
|---|---|---|
| **Sigurno** (zelena) | keš, zapisnik ili privremene podatke koji se ponovno stvaraju | da |
| **Provjerite** (narančasta) | mogu sadržavati podatke koje još uvijek želite ili se dugo preuzimaju: Kanta za smeće, privitci e-pošte, stanja prozora, vlastite predmemorije sustava macOS, velika preuzimanja kao što su Gradle ili Playwright | ne |

"Preporučeno" odabire samo sigurne stavke, "Sve" sve, "Ništa" ništa.

## Preskočene stavke
- **"radi":** predmemorije otvorene aplikacije ostaju netaknute (npr. Chrome, Slack, VS Code). Ovo se također odnosi na opća pravila: Swabr prepoznaje aplikaciju po nazivu njezine mape ili ID-u paketa. Zatvorite aplikaciju i ponovno skenirajte.
- **Zelena štit:** unos je zaštićen (vidi "Zaštićeni podaci") ili se nalazi u zaključanom području.

## Posebne kategorije
- **Ostatci uklonjenih aplikacija:** predmemorije, dnevnici i stanja prozora aplikacija koje više nisu instalirane i koje su nepromijenjene 30 dana (podesivo). Upravitelji lozinki, keychain i SSH podaci su izuzeti.
- **Velike skupine podataka (samo prijedlog):** iOS sigurnosne kopije, Mail, simulatori, Docker, AI modeli. Swabr ih nikada ne briše automatski, već vam govori gdje ih možete pravilno očistiti.

## Nikad više ne čistite
Desni klik na unos → **"Nikad ne čisti"** trajno ga štiti. Povratak pod Postavke → Zaštićeni podaci.

Ovo se također odnosi na sve što ista pravila pronađu kasnije. U proširenom popisu desnom tipkom miša kliknite na lokaciju da biste zaštitili samo tu lokaciju, sve od jedne aplikacije ili sve mape s tim imenom. Odmah nakon toga, **"Poništi"** u traci iznad popisa uklanja zaštitu.

## Što se mijenja nakon toga?
Aplikacije ponovno izgrađuju svoje predmemorije; prvo pokretanje ili učitavanje prve stranice može potrajati malo duže. Prijave, dokumenti, postavke i oznake ostaju.
