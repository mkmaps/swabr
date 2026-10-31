# Közvetlen és App Store-kiadás

A Swabr két kiadásban érhető el, amelyek ugyanazon kódból készültek. A Beállítások → Általános menüpontban és a „Névjegy” alatt láthatja, melyik kiadással rendelkezik.

|  | Közvetlen | App Store |
|---|---|---|
| Terjesztés | GitHub (DMG) | Mac App Store |
| Hozzáférés | Teljes lemezhozzáférés a teljes otthoni mappához | csak azok a mappák, amelyekhez megosztással hozzáférést engedélyez |
| Tisztítás, eltávolítás | igen | igen, a hozzáférés megosztása után |
| A rendszer tulajdonában lévő alkalmazások | igen (a Finder kéri a jelszavad) | igen (a macOS kéri a jelszavad) |
| Rendszerfájlok a /Library mappában | igen | igen, a /Library hozzáférés megosztása után |
| Optimalizálás | mind a 19 feladat | 5 feladat rendszergazdai jogosultságok nélkül |
| Frissítések | magától telepíti a frissítéseket | frissítéseket jelenít meg, megnyitja az App Store-t vagy a gyártó weboldalát |
| Indítás | Bejelentkezési elemek és szolgáltatások kezelése | Saját háttérszolgáltatások megjelenítése és eltávolítása |
| Karcsúsítás | igen | nem |

## Miért kínál kevesebbet az App Store-kiadás?
Az Apple az App Store-hoz **sandboxot** ír elő: az alkalmazások csak a Megosztással rendelkező mappákhoz férhetnek hozzá, nem kérhetnek rendszergazdai jogokat, nem telepíthetnek vagy módosíthatnak más alkalmazásokat, és nem irányíthatnak más alkalmazásokat (App Store felülvizsgálati irányelvek 2.4.5 és 2.5.2). A Swabr betartja ezeket a szabályokat, és a megengedett mértékben nyújt szolgáltatásokat.

## Mappák megosztása (App Store-kiadás)
Amikor először megnyitja a Tisztítás, az Optimalizálás vagy az Apps alkalmazást, megjelenik a „Hozzáférés engedélyezése” felirat. Kattintson a „Megosztás …” gombra; a párbeszédablakban már a megfelelő mappa szerepel, csak meg kell erősítenie. A Megosztás engedélyek elmentésre kerülnek, és a Beállítások → Hozzáférés menüpont alatt visszavonhatók.

## Direct verzió és forráskód
A Swabr egy MIT-licenc alatt álló szabad szoftver. A Direct verzió és a teljes forráskód ingyenesen elérhető a GitHubon; a link a Beállítások → Névjegy menüpont alatt található.
