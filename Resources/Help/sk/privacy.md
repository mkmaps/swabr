# Ochrana súkromia

Aplikácia Swabr nezhromažďuje žiadne údaje, neobsahuje žiadne analytické nástroje ani reklamy a nemá žiadne používateľské konto.

## Čo zostane na vašom Macu
Všetky skenovania, merania, nastavenia, chránené údaje a protokol sa ukladajú výlučne lokálne.

## Čo sa odosiela cez internet (len pri „online informáciách“)
| Kde | Čo | Prečo |
|---|---|---|
| formulae.brew.sh | stiahnutie verejného katalógu Homebrew (cca 10 MB, uchovávané v cache 7 dní), žiadne vaše údaje | popisy a verzie |
| itunes.apple.com | identifikátory vašich aplikácií z App Store (napr. com.bitwarden.desktop) | popis, verzia, odkaz na obchod |
| kanály aktualizácií aplikácií | načítanie súboru appcast od výrobcu | Porovnanie verzií |
| sťahovanie od dodávateľov | len pri spustení aktualizácie (priamy prístup) | stiahnite si novú verziu |

Vypnite „online informácie“ v časti Nastavenia → Všeobecné; aplikácia Swabr potom funguje úplne offline. V verzii z App Store je táto funkcia štandardne vypnutá.

## Oprávnenia
Swabr využíva Úplný prístup k disku (priamy) alebo oprávnenia pre zložky (App Store) iba pre viditeľné funkcie. Všetky oprávnenia je možné zrušiť v Nastaveniach systému alebo v časti Nastavenia → Prístup.

## Vymazanie vašich údajov
Odstráňte aplikáciu Swabr a vymažte adresáre `~/.config/swabr` a `~/Library/Application Support/Swabr` (verzia z App Store: jej kontajner v adresári `~/Library/Containers`).
