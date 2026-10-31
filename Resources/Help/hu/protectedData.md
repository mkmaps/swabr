# Védett adatok (fehér lista)

A Beállítások → **Védett adatok** menüpont alatt található lista határozza meg, hogy a Swabr mit **nem** érint a Tisztítás során – még akkor sem, ha egy szabály egyébként magában foglalná azokat. Más eszközök ezt „fehérlistának” nevezik.

## Hogyan olvassuk el a listát
- **Bekapcsolva = védett.** A bejegyzés már nem jelenik meg a Tisztítás menüpontban, vagy zöld pajzs jelöléssel jelenik meg.
- **Kikapcsolva = törölhető,** ha egy Tisztítás szabály magában foglalja.
- **Az „Alapértelmezett”** jelöléssel ellátott bejegyzések eleve védettek (Gradle-gyorsítótárak, Playwright-böngészők, Hugging Face-modellek).
- Minden bejegyzés megmutatja, hogy jelenleg mennyi helyet foglal, így láthatod, mennyibe kerül a védelme.

## Mikor érdemes védelmet alkalmazni
Védje azokat az adatokat, amelyek újra létrehozhatók, de ez hosszú időt vesz igénybe vagy nagy adatforgalmat igényel: egy nagy projekt Xcode DerivedData-ja, Gradle-gyorsítótárak, letöltött AI-modellek, lassú kapcsolaton történő Homebrew-letöltések.

## Saját bejegyzések
A „Saját bejegyzések” alatt bármely mappát vagy fájlt védhet:
- **A „Mappa kiválasztása…” gomb megnyomásával** egy párbeszédablak nyílik meg; a kiválasztott mappa védetté válik.
- Vagy írj be egy **mintát**. Alatta azonnal láthatod, hány elemre illik.

| Minta | Védi |
|---|---|
| `~/Library/Caches/Foo` | pontosan ez a mappa |
| `~/Library/Caches/Foo/*` | minden ebben a mappában (és vele együtt a mappa is) |
| `~/Library/Caches/Foo*` | minden „Foo”-val kezdődő mappa |

A „~” a saját mappádat jelöli, a „*” pedig bármilyen karaktert.

## Biztonsági szabályok
Egyes bejegyzések mindig védettek, és nem lehet őket kikapcsolni: az iCloud szinkronizálási állapotát tároló gyorsítótárak, az Apple-fiók bejelentkezési adatai, a Wallet, a Home, a betűtípusok, a Spotlight vagy a háttérben folyó letöltések, valamint a Swabr saját gyorsítótára. Ezen felül az iCloud Drive, a kulcstartó, a Dokumentumok, az Asztal és a saját mappa határain kívül található összes elem mindig tiltott területnek számít.

## Hely és visszaállítás
A lista a `~/.config/swabr/whitelist` fájlban van tárolva (soronként egy minta). Amint valamit módosítasz, ez a fájl felülírja az alapértelmezett listát; az „Alapértelmezett értékek visszaállítása” gomb megnyomásával pedig újra törlődik.
