# Zaštićeni podaci (bijeli popis)

Popis pod Postavke → **Zaštićeni podaci** definira što Swabr **nikada ne** dira tijekom čišćenja – čak i ako bi ga pravilo inače uključilo. Drugi alati to nazivaju "whitelist".

## Kako pročitati popis
- **Uključeno = zaštićeno.** Unos se više ne pojavljuje u Čišćenje ili se pojavljuje sa zelenim štitom.
- **Isključeno = može biti izbrisano** ako ga uključuje pravilo čišćenja.
- **"Default"** označava unose koji su zaštićeni izravno iz kutije (Gradle kešovi, Playwright preglednici, Hugging Face modeli).
- Svaki unos prikazuje koliko prostora trenutno zauzima, tako da vidite koliko prostora zauzima njegova zaštita.

## Kada zaštititi
Zaštitite podatke koji se mogu ponovno stvoriti, ali za koje je potrebno puno vremena ili troše puno prometa: Xcode DerivedData velikog projekta, Gradle keševi, preuzeti AI modeli, preuzimanja s Homebrewa na sporoj vezi.

## Vaši vlastiti unosi
Pod "Vaši unosi" štitite bilo koju mapu ili datoteku:
- **Odabir mape …** otvara dijalog; odabrana mapa je zaštićena.
- Ili upišite **obrazac**. Ispod njega odmah vidite koliko stavki odgovara.

| Šablona | Štiti |
|---|---|
| `~/Library/Caches/Foo` | točno ovaj direktorij |
| `~/Library/Caches/Foo/*` | sve u ovoj mapi (a time i samu mapu) |
| `~/Library/Caches/Foo*` | svaka mapa koja počinje s "Foo" |

"~" je vaša početna mapa, a "*" bilo koji znak.

## Sigurnosna pravila
Neki su unosi uvijek zaštićeni i ne mogu se isključiti: predmemorije koje sadrže stanje sinkronizacije s iCloudom, prijava na Apple račun, Wallet, Home, fontovi, Spotlight ili pozadinske preuzimanja u tijeku te vlastita predmemorija aplikacije Swabr. Osim toga, iCloud Drive, keychain, Documents, Desktop i sve izvan vaše kućne mape uvijek su nedostupni.

## Lokacija i resetiranje
Popis se pohranjuje u `~/.config/swabr/whitelist` (po jedna uzorka po retku). Čim nešto promijenite, ta datoteka zamjenjuje zadani popis; "Reset to defaults" je ponovno briše.
