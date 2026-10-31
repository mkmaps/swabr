# Upratanie

Upratanie vyhľadáva údaje, ktoré aplikácie a macOS v prípade potreby znovu vytvoria: vyrovnávaciu pamäť, protokoly, dočasné súbory, vyrovnávaciu pamäť prehliadača a vývojárov, ako aj zvyšky odinštalovaných aplikácií. Swabr pracuje s dvoma druhmi pravidiel:
- **Špecifické pravidlá** pre prehliadače, vývojárske nástroje (Xcode, Homebrew, npm, pip, Cargo, Gradle …) a niektoré aplikácie, ktorých údaje sú uložené hlbšie.
- **Všeobecné pravidlá**, ktoré vychádzajú z konvencií priečinkov v macOS: všetko v priečinku `~/Library/Caches`, priečinky s vyrovnávacou pamäťou Chromium vo všetkých aplikáciách Electron (Slack, Discord, VS Code, Obsidian …), vyrovnávacie pamäte, protokoly a dočasné súbory v kontajneroch aplikácií. Týmto spôsobom sú pokryté aj aplikácie, o ktorých žiadny zoznam nevie.

Každé pravidlo má svoj typ (vyrovnávacia pamäť, protokoly, balíky, zostavenie…) a vlastné hodnotenie. Špecifické pravidlá majú prednosť pred všeobecnými.

## Ako to funguje
- **Spustiť skenovanie:** Swabr len prehliada, nič sa nemení.
- **Skontrolujte zoznam:** kategórie a ich veľkosti sú vľavo, položky vybranej kategórie vpravo spolu s ich hodnotením, veľkosťou a účinkom. Zaškrtnutím políčka pred kategóriou vyberiete všetko v nej; rozbaľte riadok, aby ste videli jeho cesty.
- **Do koša:** kliknite na tlačidlo v pravom dolnom rohu a potom potvrďte v okne s prehľadom. Ak je zapnutá možnosť „Trvalo odstrániť“, tlačidlo sa nazýva „Vyčistiť“ a súbory sa odstránia ihneď.
- **Hotovo:** na záverečnej stránke sa zobrazí, koľko miesta sa uvoľnilo, rozdelené podľa kategórií, a voľné miesto pred a po operácii.

## Bezpečné alebo Skontrolovať
| Úroveň | Význam | Predvolené |
|---|---|---|
| **Bezpečné** (zelené) | vyrovnávacia pamäť, protokoly alebo dočasné údaje, ktoré sa znovu vytvoria | áno |
| **Skontrolovať** (oranžové) | môžu obsahovať údaje, ktoré ešte chcete, alebo ktorých opätovné stiahnutie trvá dlho: koš, prílohy e-mailov, stavy okien, vlastné vyrovnávacie pamäte systému macOS, veľké súbory na stiahnutie, ako napríklad Gradle alebo Playwright | nie |

Možnosť „Odporúčané“ vyberá iba bezpečné položky, „Všetko“ vyberá všetko a „Žiadne“ nevyberá nič.

## Preskočené položky
- **„je spustená“:** vyrovnávacia pamäť otvorenej aplikácie zostane nedotknutá (napr. Chrome, Slack, VS Code). To platí aj pre všeobecné pravidlá: Swabr rozpoznáva aplikáciu podľa názvu zložky alebo identifikátora balíka. Ukončite aplikáciu a skontrolujte ju znovu.
- **Zelený štít:** položka je chránená (pozri „Chránené údaje“) alebo sa nachádza v uzamknutej oblasti.

## Špeciálne kategórie
- **Zvyšky odstránených aplikácií:** vyrovnávacia pamäť, protokoly a stavy okien aplikácií, ktoré už nie sú nainštalované a nezmenili sa 30 dní (nastaviteľné). Správcovia hesiel, kľúčenka a údaje SSH sú vylúčené.
- **Veľké súbory údajov (len tip):** zálohy iOS, Mail, simulátory, Docker, modely umelej inteligencie. Swabr ich nikdy automaticky nemazá, ale poradí vám, kde ich správne vyčistiť pri upratovaní.

## Už nikdy nemusíte čistiť
Kliknutím pravým tlačidlom na položku → **„Nikdy nečistiť“** ju natrvalo ochránite. Zrušiť môžete v Nastaveniach → Chránené údaje.

Toto sa vzťahuje aj na všetko, čo toto pravidlo nájde neskôr. V rozbalenom zozname kliknite pravým tlačidlom na umiestnenie, ak chcete chrániť len toto umiestnenie, všetko v jednej aplikácii alebo všetky zložky s týmto názvom. Hneď potom môžete ochranu zrušiť kliknutím na **„Vrátiť späť“** v lište nad zoznamom.

## Čo sa potom zmení?
Aplikácie obnovia svoje vyrovnávacie pamäte; prvé spustenie alebo prvé načítanie stránky môže trvať o niečo dlhšie. Prihlásenia, dokumenty, nastavenia a záložky zostanú zachované.
