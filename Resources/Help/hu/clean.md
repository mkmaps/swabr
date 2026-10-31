# Tisztítás

A Tisztítás olyan adatokat talál meg, amelyeket az alkalmazások és a macOS szükség szerint újra létrehoz: gyorsítótárak, naplófájlok, ideiglenes fájlok, böngésző- és fejlesztői gyorsítótárak, valamint az eltávolított alkalmazások maradványai. A Swabr kétféle szabályt használ:
- **Különleges szabályok** a böngészőkre, a fejlesztői eszközökre (Xcode, Homebrew, npm, pip, Cargo, Gradle …) és néhány olyan alkalmazásra, amelyek adatai mélyebben vannak elrejtve.
- **Általános szabályok**, amelyek a macOS mappakonvencióit követik: minden, ami a `~/Library/Caches` alatt található, a Chromium gyorsítótár-mappái minden Electron-alkalmazásban (Slack, Discord, VS Code, Obsidian …), valamint az alkalmazáskonténerekben található gyorsítótárak, naplófájlok és ideiglenes fájlok. Így azok az alkalmazások is védelem alá kerülnek, amelyekről a lista nem tud.

Minden szabály magában hordozza a típusát (gyorsítótár, naplófájlok, csomagok, build …) és a saját besorolását. A konkrét szabályok elsőbbséget élveznek az általános szabályokkal szemben.

## Hogyan működik?
- **Vizsgálat indítása:** a Swabr csak átnézi a rendszert, semmi sem változik.
- **Ellenőrizze a listát:** a kategóriák és méretük a bal oldalon, a kiválasztott kategória elemei pedig a jobb oldalon láthatók, besorolásukkal, méretükkel és hatásukkal együtt. A kategória előtti jelölőnégyzet bejelölésével az egész kategória kijelölhető; egy sor kibontásával megtekintheti az elérési útvonalakat.
- **A Kuka gomb:** a jobb alsó sarokban található gomb, majd erősítse meg az ellenőrző ablakban. Ha a „Véglegesen töröl” opció be van kapcsolva, a gomb neve „Tisztítás” lesz, és azonnal törli az adatokat.
- **Kész:** az utolsó oldalon látható, hogy mennyi helyet szabadított fel a rendszer, kategóriánkénti bontásban, valamint a szabad hely mennyisége a művelet előtt és után.

## Biztonságos vagy Felülvizsgálat
| Szint | Jelentése | Előre kiválasztott |
|---|---|---|
| **Biztonságos** (zöld) | A gyorsítótár, a napló vagy az ideiglenes adatok újra létrehozásra kerülnek | igen |
| **Ellenőrizendő** (narancssárga) | Lehet, hogy olyan adatokat tartalmaznak, amelyekre még szükséged van, vagy amelyek újratöltése sokáig tart: a Kuka, az e-mail mellékletek, az ablakállapotok, a macOS saját gyorsítótárai, valamint a nagy méretű letöltések, mint például a Gradle vagy a Playwright. | nem |

Az „Ajánlott” opció csak a biztonságos bejegyzéseket választja ki, az „All” (Minden) az összeset, a „None” (Nincs) pedig semmit.

## Kihagyott bejegyzések
- **„fut”:** a nyitott alkalmazások gyorsítótárai érintetlenek maradnak (pl. Chrome, Slack, VS Code). Ez az általános szabályokra is vonatkozik: a Swabr a mappa neve vagy a csomagazonosító alapján ismeri fel az alkalmazást. Zárja be az alkalmazást, majd futtassa újra a vizsgálatot.
- **Zöld pajzs:** a bejegyzés védett (lásd „Védett adatok”) vagy egy lezárt területen található.

## Különleges kategóriák
- **Az eltávolított alkalmazások maradványai:** a már nem telepített és 30 napja (beállítható) változatlan állapotú alkalmazások gyorsítótárai, naplói és ablakállapotai. A jelszókezelők, a kulcstartó és az SSH-adatok kivételt képeznek.
- **Nagy adathalmazok (csak tipp):** iOS-biztonsági mentések, Mail, szimulátorok, Docker, AI-modellek. A Swabr soha nem törli őket automatikusan, hanem megmutatja, hol lehet őket megfelelően tisztítani.

## Soha többé nem kell törölni
Kattintson jobb gombbal egy bejegyzésre → **a „Soha ne tisztítsa” (Soha ne tisztítsa) opcióval** véglegesen védheti azt. A visszavonás a Beállítások (Beállítások) → Védett adatok (Védett adatok) menüpont alatt érhető el.

Ez kiterjed mindenre, amit ugyanaz a szabály később megtalál. A kibontott listában kattintson a jobb gombbal egy helyre, hogy csak azt a helyet, egy alkalmazás összes elemét vagy az adott nevű összes mappát védje. Közvetlenül utána a lista feletti sávban található **„Visszavonás”** gombbal visszavonhatja a védelmet.

## Mi változik ezután?
Az alkalmazások újjáépítik a gyorsítótárukat; az első indítás vagy az első oldal betöltése kissé hosszabb ideig tarthat. A bejelentkezési adatok, dokumentumok, beállítások és könyvjelzők megmaradnak.
