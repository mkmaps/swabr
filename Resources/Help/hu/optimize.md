# Optimalizálás

Az Optimalizálás a macOS karbantartási feladatait futtatja. A felesleges lépéseket indoklással kihagyja.

## Használata
- A feladatokat **jelölőnégyzetek**kel válassza ki; a jobb felső sarokban található „Összes kijelölése/semmi kijelölése” gombot használja. A Swabr megjegyzi a bejelölés nélküli feladatokat.
- Minden feladat leírja, mit csinál, és mi változik utána. Narancssárga: észrevehető mellékhatás.
- **Jelszó:** a rendszergazdai jogosultságot igénylő feladatok együtt futnak; a jelszót csak egyszer kell megadni. A lemondás csak ezeket a feladatokat hagyja ki.

## A feladatok
| Feladat | Mi történik | Jelszó |
|---|---|---|
| QuickLook-előnézetek | a QuickLook miniatűr-gyorsítótárának visszaállítása | nem |
| Ablakállapotok | a 30 napnál régebbi mentett ablakok eltávolítása, nem futó alkalmazások esetében | nem |
| Meghibásodott beállítások | a sérült, harmadik féltől származó beállítási fájlok Áthelyezés a Kukába | nem |
| DNS-gyorsítótár | névfeloldás ürítése (aktív VPN-kapcsolat vagy offline állapot esetén kihagyásra kerül) | igen |
| Hálózati útvonalak | az útválasztási táblázat ürítése és a címek frissítése DHCP-n keresztül, csak akkor, ha minden interfész DHCP-t használ (rövid megszakítás) | igen |
| .DS_Store | nincsenek Finder-fájlok a hálózati és USB-meghajtókon | nem |
| Régi optimalizálási beállítások | Az App Nap és a képellenőrzés visszaáll az alapértelmezett beállításokra | nem |
| Jogosultságok | Állítsd vissza a jogosultságokat a saját mappádban, de csak akkor, ha valami nem stimmel (pár percet vesz igénybe) | igen |
| Spotlight-index | ellenőrizze az állapotot, csak hiba esetén vagy kikapcsolt indexelés mellett végezzen újjáépítést | igen |
| Spotlight-kizárások | jelenti azokat a kizárásokat, amelyek helye már nem létezik; rendszergazdai jogosultsággal olvassa be a beállításokat, de semmit sem módosít | igen |
| Rendszeres karbantartás | csak az esedékes időszakok; a macOS 26 óta már nem elérhető | igen |
| Oldalsáv és legutóbbi elemek | az olvashatatlan oldalsáv- és legutóbbi elemek listák áthelyezése a Kukába | nem |
| Indítási kötet ellenőrzése | ellenőrizze a fájlrendszert, nem változtat semmit | nem |
| Bejelentkezési elemek alatt | a hiányzó programhoz tartozó bejegyzések jelentése | nem |
| Letöltési előzmények | a Gatekeeper letöltési előzményeinek törlése (adatvédelem) | nem |
| Háttérszolgáltatások | jelentse azokat a szolgáltatásokat, amelyeknek hiányzik a programja | nem |
| Értesítések | a 30 napnál régebbi kézbesített értesítések törlése | nem |
| Adatbázisok | Mail, Safari, Üzenetek tömörítése (csak bezárt, sértetlen, < 100 MB) | nem |

## App Store-kiadás
Itt csak azok a feladatok érhetők el, amelyek rendszergazdai jogosultságok nélkül is működnek a saját mappában: ablakállapotok, sérült beállítások, oldalsáv és legutóbbi elemek, letöltési előzmények és háttérszolgáltatások.
