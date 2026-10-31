# Adatvédelem

A Swabr nem gyűjt adatokat, nem tartalmaz elemzési vagy hirdetési funkciókat, és nincs felhasználói fiókja.

## Mi marad a Mac-en
Minden szkennelés, mérés, beállítás, védett adatok és a napló kizárólag helyileg kerül tárolásra.

## Mi kerül az internetre (csak „online információk” esetén)
| Hol | Mi | Miért |
|---|---|---|
| formulae.brew.sh | a nyilvános Homebrew-katalógus letöltése (kb. 10 MB, 7 napig tárolva a gyorsítótárban), az Ön adatai nem kerülnek rögzítésre | leírások és verziók |
| itunes.apple.com | az App Store-alkalmazások azonosítói (pl. com.bitwarden.desktop) | leírás, verzió, áruházi link |
| alkalmazások frissítési csatornái | a gyártó appcast-fájljának letöltése | verziók összehasonlítása |
| gyártói letöltések | csak frissítés indításakor (közvetlen) | Töltse le az új verziót |

Kapcsolja ki az „online info” funkciót a Beállítások → Általános menüpont alatt; a Swabr ezután teljesen offline módban fog működni. Az App Store-kiadásban ez alapértelmezés szerint ki van kapcsolva.

## Engedélyek
A Swabr kizárólag a látható funkciókhoz használja a Teljes lemezhozzáférés (közvetlen) vagy a mappahozzáférési jogosultságokat (App Store). Minden jogosultság visszavonható a Rendszerbeállításokban vagy a Beállítások → Hozzáférés menüpont alatt.

## Az adatok törlése
Távolítsa el a Swabr alkalmazást, majd törölje a `~/.config/swabr` és a `~/Library/Application Support/Swabr` mappákat (App Store-kiadás esetén: a `~/Library/Containers` mappában található konténerét).
