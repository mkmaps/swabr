# Alkalmazások eltávolítása

Ha egy alkalmazást a Kuka-ba húzol, az adatai – a gyorsítótárak, a beállítások, a háttérszolgáltatások és esetenként a rendszerfájlok – megmaradnak. A Swabr megtalálja ezeket a maradékokat.

## Hogyan működik
- A bal oldalon jelölőnégyzetekkel válassza ki az alkalmazásokat (többet is kiválaszthat). Az információk és az összes megtalált fájl a jobb oldalon jelenik meg.
- Az **Eltávolítás …** gomb megnyitja az áttekintő ablakot az összes hatással.
- A futó alkalmazásokat először bezárja a rendszer. Minden a **Kuka**-ba kerül.

## Mit távolít el?
| Csoport | Példák | Előre kiválasztott |
|---|---|---|
| **Eltávolításra kerül** | alkalmazás, gyorsítótárak, naplófájlok, ablakállapot, indítóügynökök | igen |
| **Személyes adatok** | beállítások, konténerek, fiókok, könyvtárak | nem |
| **Érzékeny** | böngészőprofilok (jelszavak, előzmények), alkalmazáscsoport-adatok | soha nem automatikusan |
| **Rendszerfájlok** | fájlok a /Library mappában, rendszerszolgáltatások, segédeszközök | nem, jelszó szükséges |

A személyes adatok alapértelmezés szerint megmaradnak, így a beállítások és fiókok visszaállnak, ha újratelepíted az alkalmazást. Az „Összes eltávolítása” opcióval válaszd ki ezt. Az alapértelmezést a Beállítások → Viselkedés menüpont alatt módosíthatod.

## Az alkalmazásról
Az „Információk” szakaszban megjelenik a fejlesztő (az aláírás alapján), a kategória, a verzió, az utolsó használat, valamint – amennyiben online információk állnak rendelkezésre – a leírás és a weboldalra, az App Store-ba és a webes keresőbe vezető linkek. Ez segít felismerni az ismeretlen alkalmazásokat, mielőtt törölnéd őket.

## Szimbólumok
- **Zár:** védett (rendszerkomponens, saját eltávolítóval rendelkező biztonsági szoftver, maga a Swabr).
- **Kulcs:** egy másik felhasználó vagy a rendszer tulajdonában van; a macOS a törléskor jelszót kér.

## Homebrew
A Homebrew-val telepített alkalmazások a `brew uninstall` paranccsal távolíthatók el, így a Homebrew szinkronban marad.
