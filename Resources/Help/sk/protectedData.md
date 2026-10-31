# Chránené údaje (whitelist)

Zoznam v časti Nastavenia → **Chránené údaje** definuje, čo Swabr počas Upratania **nikdy** neovplyvní – aj keby to inak pravidlo zahŕňalo. Iné nástroje to nazývajú „whitelist“.

## Ako čítať zoznam
- **Zapnuté = chránené.** Položka sa už nezobrazuje v sekcii Upratanie alebo sa zobrazuje so zeleným štítom.
- **Vypnuté = môže byť odstránené,** ak to zahŕňa pravidlo Upratania.
- **„Predvolené“** označuje položky, ktoré sú chránené už od začiatku (vyrovnávacia pamäť Gradle, prehliadače Playwright, modely Hugging Face).
- Každá položka zobrazuje, koľko miesta momentálne zaberá, takže vidíte, aké náklady so sebou ochrana danej položky prináša.

## Kedy chrániť
Chráňte dáta, ktoré sa znovu vytvárajú, ale trvá to dlho alebo spotrebúva veľký objem dát: Xcode DerivedData veľkého projektu, vyrovnávacia pamäť Gradle, stiahnuté modely umelej inteligencie, stiahnuté súbory Homebrew pri pomalom pripojení.

## Vaše vlastné položky
V časti „Vaše položky“ môžete chrániť akúkoľvek zložku alebo súbor:
- **Voľba „Vybrať zložku …“** otvorí dialógové okno; vybraná zložka je chránená.
- Alebo zadajte **vzor**. Pod ním hneď uvidíte, s koľkými položkami sa zhoduje.

| Vzor | Chráni |
|---|---|
| `~/Library/Caches/Foo` | presne tento priečinok |
| `~/Library/Caches/Foo/*` | všetko v tomto priečinku (a spolu s ním aj samotný priečinok) |
| `~/Library/Caches/Foo*` | každý priečinok začínajúci na „Foo“ |

„~“ je vaša domovská zložka, „*“ akékoľvek znaky.

## Bezpečnostné pravidlá
Niektoré položky sú vždy chránené a nemožno ich vypnúť: vyrovnávacia pamäť obsahujúca stav synchronizácie iCloud, prihlásenie do účtu Apple, aplikácia Wallet, aplikácia Home, písma, prebiehajúce vyhľadávanie v Spotlight alebo sťahovanie na pozadí a vlastná vyrovnávacia pamäť aplikácie Swabr. Okrem toho sú vždy mimo dosahu iCloud Drive, kľúčenka, Dokumenty, Plocha a všetko mimo vašej domovskej zložky.

## Umiestnenie a obnovenie
Zoznam je uložený v súbore `~/.config/swabr/whitelist` (jeden vzor na riadok). Hneď ako niečo zmeníte, tento súbor nahradí predvolený zoznam; voľba „Obnoviť predvolené nastavenia“ ho opäť vymaže.
