# Indítás: bejelentkezési elemek alatt és szolgáltatások

## Indítás bejelentkezéskor (Közvetlen)
Minden telepített alkalmazásnál található egy **„Indítás bejelentkezéskor”** kapcsoló. A macOS a bejelentkezés után megnyitja a bekapcsolt alkalmazásokat. A kisebb **„Rejtve”** kapcsoló ablak nélkül indítja el őket. Ez ugyanaz a lista, mint a Rendszerbeállítások → Általános → Bejelentkezési elemek alatt alatt; a Swabr a „System Events” segítségével vezérli (a macOS egyszer kéri az engedélyt).

## Háttérszolgáltatások
Az alábbiakban (kibontható listában) azok a frissítők és segédeszközök találhatók, amelyeket az alkalmazások maguk állítanak be (LaunchAgents/LaunchDaemons):
- **A saját szolgáltatásai** (a saját mappájában): engedélyezés/letiltás, eltávolítás (Kuka).
- **Rendszer-szintű szolgáltatások:** csak megjelenítés; módosításuk a Rendszerbeállításokban lehetséges. Kivétel: ha hiányzik a programjuk, **az „Eltávolítás …”** gomb megnyomásával törölhetők (a macOS jelszót kér).
- **„Hiányzó program”:** a szolgáltatás egy törölt alkalmazásra mutat, és már nem végez semmilyen műveletet – eltávolítható.

## Az árva bejegyzések eltávolítása
Azok a bejelentkezési elemek és szolgáltatások, amelyekhez már nincs telepítve az alkalmazás, narancssárga színnel és **a „Hiányzó program”** felirattal vannak jelölve.
- Bejelentkezési elemek alatt a **„Törlés a listából”** gomb törli a bejegyzést a bejelentkezési elemek közül.
- A jobb alsó sarokban található **„Árvák eltávolítása (szám) …”** gomb a nevek listájának megjelenése után egyszerre távolítja el az összeset.
- A szolgáltatásfájlok a Kuka kosárba kerülnek, ahonnan visszaállíthatók. A Swabr csak akkor távolítja el a rendszer szintű szolgáltatásokat, ha azok programja valóban eltűnt.

## App Store-kiadás
Az App Store-kiadás nem tudja irányítani a Rendszereseményeket, sem szolgáltatásokat indítani vagy leállítani. Megjeleníti a saját háttérszolgáltatásait, és eltávolíthatja azokat; a Bejelentkezési elemek alatt a Rendszerbeállítások gombbal kezelheti.
