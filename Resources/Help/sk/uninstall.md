# Odinštalovanie aplikácií

Presunutím aplikácie do koša zostanú jej údaje: vyrovnávacia pamäť, nastavenia, služby bežiace na pozadí a niekedy aj systémové súbory. Swabr tieto zvyšky nájde.

## Ako to funguje
- Aplikácie na ľavej strane vyberte pomocou **začiarkavacieho políčka** (možno vybrať viacero). Informácie a všetky nájdené súbory sa zobrazia na pravej strane.
- **Odinštalovať …** otvorí okno s prehľadom všetkých dôsledkov.
- Spustené aplikácie sa najskôr ukončia. Všetko sa presunie do **koša**.

## Čo sa odstraňuje?
| Skupina | Príklady | Predvolené |
|---|---|---|
| **Bude odstránené** | aplikácia, vyrovnávacia pamäť, protokoly, stav okien, spúšťacie agenty | áno |
| **Osobné údaje** | nastavenia, kontajnery, účty, knižnice | nie |
| **Citlivé** | profily prehliadača (heslá, história), údaje skupín aplikácií | nikdy automaticky |
| **Systémové súbory** | súbory v /Library, systémové služby, pomocné nástroje | nie, vyžaduje heslo |

Osobné údaje zostávajú štandardne zachované, takže nastavenia a účty sa obnovia, ak aplikáciu nainštalujete znovu. Voľba „Odstrániť aj všetko“ to vyberie. Zmenu predvoleného nastavenia nájdete v časti Nastavenia → Správanie.

## O aplikácii
V časti „Informácie“ sa zobrazuje vývojár (na základe podpisu), kategória, verzia, dátum posledného použitia a – ak sú k dispozícii online informácie – popis a odkazy na webovú stránku, App Store a vyhľadávanie na webe. To vám pomôže rozpoznať neznáme aplikácie pred ich odstránením.

## Symboly
- **Zámok:** chránené (súčasť systému, bezpečnostný softvér s vlastným odinštalátorom, samotná aplikácia Swabr).
- **Kľúč:** patrí inému používateľovi alebo systému; macOS pri odstraňovaní vyžaduje zadanie hesla.

## Homebrew
Aplikácie nainštalované prostredníctvom Homebrew sa odstraňujú pomocou príkazu `brew uninstall`, čím sa Homebrew udrží v synchronizácii.
