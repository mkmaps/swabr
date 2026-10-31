# Optimalizovať

Optimalizovať spúšťa údržbové úlohy pre macOS. Nepotrebné kroky sa s odôvodnením preskakujú.

## Používanie
- Úlohy vyberajte pomocou **začiarkavacích políčok**; v pravom hornom rohu je tlačidlo „Vybrať všetko/nič“. Aplikácia Swabr si pamätá nezačiarknuté úlohy.
- Každá úloha popisuje, čo robí a aké zmeny po nej nastanú. Oranžová farba: badateľný vedľajší účinok.
- **Heslo:** úlohy vyžadujúce práva správcu sa spúšťajú naraz; heslo sa vyžaduje len raz. Zrušením sa preskočia len tieto úlohy.

## Úlohy
| Úloha | Čo sa stane | Heslo |
|---|---|---|
| Náhľady QuickLook | vynulovať vyrovnávaciu pamäť miniatúr v QuickLook | nie |
| Stavy okien | odstrániť uložené okná staršie ako 30 dní, neplatí pre spustené aplikácie | nie |
| Poškodené nastavenia | presun poškodených súborov nastavení tretích strán do Koša | nie |
| Cache DNS | vyprázdniť riešenie mien (preskočí sa pri aktívnej VPN alebo v režime offline) | áno |
| Sieťové trasy | vyprázdniť smerovaciu tabuľku a obnoviť adresy cez DHCP, iba ak každé rozhranie používa DHCP (krátke prerušenie) | áno |
| .DS_Store | žiadne súbory Finderu na sieťových a USB diskoch | nie |
| Staré prepínače na vyladenie | App Nap a overovanie obrázkov späť na predvolené nastavenia | nie |
| Oprávnenia | Obnovte oprávnenia vo vašom domovskom priečinku, len ak niečo nefunguje správne (trvá to niekoľko minút) | áno |
| Index Spotlight | skontrolujte stav, prebudujte iba v prípade chýb alebo ak je indexovanie vypnuté | áno |
| Vylúčenia zo Spotlightu | nahlási vylúčenia, ktorých umiestnenie už neexistuje; prečíta nastavenia s právami správcu, nič nemení | áno |
| Pravidelná údržba | len termíny, ktoré sú splatné; od verzie macOS 26 už nie sú k dispozícii | áno |
| Bočný panel a nedávne položky | presunúť nečitateľné zoznamy v bočnom paneli a zoznam nedávnych položiek do Koša | nie |
| Overiť spúšťací disk | skontrolujte súborový systém, nič sa nezmení | nie |
| Položky prihlásenia | nahlásiť položky, ktorých program chýba | nie |
| História stiahnutia | vymazať históriu sťahovania v Gatekeeperi (ochrana súkromia) | nie |
| Služby bežiace na pozadí | nahlásiť služby, ktorých program chýba | nie |
| Oznámenia | odstrániť doručené oznámenia staršie ako 30 dní | nie |
| Databázy | komprimovať Mail, Safari, Správy (len zatvorené, nepoškodené, < 100 MB) | nie |

## Verzia z App Store
K dispozícii sú tu len úlohy, ktoré fungujú vo vašom domovskom priečinku bez oprávnení správcu: stavy okien, poškodené nastavenia, bočný panel a nedávne položky, história sťahovania a služby bežiace na pozadí.
