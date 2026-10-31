# Odinstalování aplikací

Přetažením aplikace do koše zůstanou její data: mezipaměti, nastavení, služby na pozadí a někdy i systémové soubory. Swabr tyto zbytky vyhledá.

## Jak to funguje
- Vlevo vyberte aplikace pomocí **zaškrtávacích políček** (lze vybrat více). Informace a všechny nalezené soubory se zobrazí vpravo.
- **Odinstalovat …** otevře okno s přehledem všech důsledků.
- Spuštěné aplikace se nejprve ukončí. Vše se přesune do **koše**.

## Co se odstraňuje?
| Skupina | Příklady | Předvolené |
|---|---|---|
| **Bude odstraněno** | aplikace, mezipaměti, protokoly, stav oken, spouštěcí agenti | ano |
| **Osobní údaje** | nastavení, kontejnery, účty, knihovny | ne |
| **Citlivé** | profily prohlížeče (hesla, historie), data skupin aplikací | nikdy automaticky |
| **Systémové soubory** | soubory v /Library, systémové služby, pomocné nástroje | ne, vyžaduje heslo |

Osobní data zůstávají ve výchozím nastavení zachována, takže při opětovné instalaci aplikace se obnoví nastavení a účty. Volba „Odstranit vše“ je vybere. Výchozí nastavení můžete změnit v části Nastavení → Chování.

## O aplikaci
Sekce „Informace“ zobrazuje vývojáře (podle podpisu), kategorii, verzi, datum posledního použití a – v případě dostupných online informací – popis a odkazy na webové stránky, App Store a vyhledávání na webu. To vám pomůže rozpoznat neznámé aplikace ještě před jejich odstraněním.

## Symboly
- **Zámek:** chráněno (systémová součást, bezpečnostní software s vlastním programem pro Odinstalování, samotná aplikace Swabr).
- **Klíč:** patří jinému uživateli nebo systému; při odstraňování vás macOS požádá o zadání hesla.

## Homebrew
Aplikace nainstalované pomocí Homebrew se odstraňují příkazem `brew uninstall`, takže Homebrew zůstává synchronizovaný.
