# Tárhely

A Tárhely megmutatja, hova kerül a tárhelyed – mintha röntgenfelvételt készítene a lemezről.

## Áttekintés
A kezdőlap a főbb helyeket méri: Főoldal (a Könyvtár nélkül), Könyvtár, Alkalmazások, rendszerkönyvtár, valamint a tipikus helyfoglalók, mint például az iOS-biztonsági mentések, a régi letöltések (90 napnál régebbiek), az Xcode- és a Docker-adatok.

## Használata
- **Kettős kattintással** megnyílik a mappa; a felső sávban lévő elérési út visszaugrik.
- **Lista vagy csempék:** a jobb felső sarokban válthat. A csempe nézet (treemap) a méreteket területekként jeleníti meg.
- **Legnagyobb fájlok:** az eszköztárban található dokumentum ikon a 20 legnagyobb fájlt jeleníti meg.
- **Gyorsnézet:** a szóköz billentyű lenyomásával előnézet jelenik meg.
- **A jelölőnégyzetek segítségével** választhatja ki a Lomtárba helyezendő elemeket.

## Jelölők
- **„removable”:** újra létrehozott build- vagy függőségi mappák (pl. node_modules).
- **„+” jelzéssel ellátott méret:** legalább ennyire nagy; egyes elemek olvashatatlanok voltak (Teljes lemezhozzáférés?), vagy a mérés túllépte az időkorlátot (30 másodperc, beállítható).

## Mi történik törléskor?
A kijelölt elemek a Lomtárba kerülnek, és visszaállíthatók. Az áttekintő ablak figyelmeztet az alkalmazásadatokra, az iCloud-mappákra és a médiakönyvtárakra. A rendszermappák, a saját mappa és a futó virtuális gépek adatai zárolva vannak.

## Megjegyzések
- Az iCloud helyőrzőket nem töltik le, és a helyi méretükkel számolnak (gyakran szinte 0).
- Az egyéb meghajtók nem kerülnek figyelembevételre.
