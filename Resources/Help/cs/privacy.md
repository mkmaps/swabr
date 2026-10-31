# Ochrana osobních údajů

Aplikace Swabr neshromažďuje žádná data, neobsahuje žádné analytické nástroje ani reklamy a nemá žádné uživatelské účty.

## Co zůstane na vašem Macu
Všechny skeny, měření, nastavení, Chráněná data a protokol jsou uloženy pouze lokálně.

## Co se přenáší přes internet (pouze u „online informací“)
| Kde | Co | Proč |
|---|---|---|
| formulae.brew.sh | stažení veřejného katalogu Homebrew (cca 10 MB, uchováváno v mezipaměti po dobu 7 dnů), žádná data od vás | popisy a verze |
| itunes.apple.com | identifikátory vašich aplikací z App Store (např. com.bitwarden.desktop) | popis, verze, odkaz na obchod |
| kanály aktualizací aplikací | načtení souboru appcast od výrobce | Porovnání verzí |
| stažení od dodavatele | pouze při spuštění aktualizace (přímý přístup) | Stáhněte si novou verzi |

Vypněte „online informace“ v části Nastavení → Obecné; Swabr pak bude fungovat zcela offline. Ve verzi z App Store je tato funkce ve výchozím nastavení vypnutá.

## Oprávnění
Swabr využívá Plný přístup k disku (přímý) nebo oprávnění ke složkám (App Store) pouze pro viditelné funkce. Všechna oprávnění lze zrušit v Nastavení systému nebo v části Nastavení → Přístup.

## Odstranění dat
Odstraňte aplikaci Swabr a smažte adresáře `~/.config/swabr` a `~/Library/Application Support/Swabr` (verze z App Store: její kontejner v adresáři ~/Library/Containers).
