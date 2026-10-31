# Alkalmazásfrissítések

A Swabr minden telepített alkalmazást ellenőriz új verziók után. Követelmény: **az online információk** be vannak kapcsolva (Beállítások → Általános).

## Források
| Forrás | Felismerés | Közvetlen szerkesztés | App Store-kiadás |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | weboldal megnyitása |
| App Store | Összehasonlítás az App Store-ral | Az App Store megnyitja a frissítések oldalát | ugyanaz |
| Az alkalmazás frissítési csatornája (Sparkle) | A gyártó appcastja | letölti és telepíti az új verziót | weboldal megnyitása |
| Gyártó (Homebrew katalógus) | verzióösszehasonlítás | letöltések a gyártótól és telepítés | weboldal megnyitása |

## Biztonság a telepítés során (Közvetlen)
A letöltés csak akkor cseréli le az alkalmazást, ha az **ellenőrző összeg** egyezik, a **fejlesztői aláírás** megegyezik a telepített alkalmazáséval, és ** Gatekeeper** is jóváhagyja. A régi verzió a Kuka kosárba kerül. A futó alkalmazások a rendszer kérésére bezáródnak, majd utána újra megnyílnak.

## Használata
- Egyenként a **Frissítés** gombbal, vagy többet ** jelölőnégyzetek** és a „Kijelöltek frissítése” gomb segítségével.
- A ⋯ menü elrejti a frissítést.
- A „Naprakész” és a „Nem ellenőrizhető” menüpontok a többi alkalmazást sorolják fel; a Safari webalkalmazásokhoz nincs frissítés.

> A .pkg telepítőfájlokból származó alkalmazások megnyitják a macOS telepítőt; ott fejezze be a telepítést.
