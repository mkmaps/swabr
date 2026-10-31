# Spustenie: Položky prihlásenia a služby

## Spustiť pri prihlásení (Priamo)
Každá nainštalovaná aplikácia má prepínač **„Spustiť pri prihlásení**“. macOS otvorí zapnuté aplikácie po prihlásení. Menší prepínač **„Skryto“** ich spustí bez okna. Je to ten istý zoznam ako v Nastavenia systému → Všeobecné → Položky prihlásenia; Swabr to ovláda prostredníctvom „Systémových udalostí“ (macOS raz požiada o povolenie).

## Služby bežiace na pozadí
Nižšie (rozbaliteľné) sú aktualizátory a pomocné nástroje, ktoré si aplikácie nastavujú samy (LaunchAgents/LaunchDaemons):
- **Vaše služby** (vo vašej domovskej zložke): povoliť/zablokovať spustenie, odstrániť (koš).
- **Služby v rámci celého systému:** iba na zobrazenie; zmeny vykonávajte v Nastaveniach systému. Výnimka: ak chýba program, **funkcia „Odstrániť …“** ich vymaže (macOS vás požiada o zadanie hesla).
- **„Chýba program“:** služba odkazuje na odstránenú aplikáciu a už nevykonáva žiadnu činnosť – môže byť odstránená.

## Odstránenie osirelých položiek
Položky prihlásenia a služby, ktorých aplikácia už nie je nainštalovaná, sú označené oranžovo s **nápisom „Chýba program**“.
- V prípade položky pri prihlásení funkcia **„Odstrániť zo zoznamu“** vymaže túto položku zo zoznamu položiek prihlásenia.
- V pravom dolnom rohu možnosť **„Odstrániť osirelé položky (počet) …“** odstráni všetky naraz po zobrazení zoznamu mien.
- Súbory služieb sa presunú do koša a je možné ich z neho obnoviť. Swabr odstraňuje systémové služby iba vtedy, ak je príslušný program skutočne odstránený.

## Verzia z App Store
Verzia z App Store nemôže ovládať systémové udalosti ani spúšťať či zastavovať služby. Zobrazuje vaše vlastné služby bežiace na pozadí a umožňuje ich odstrániť; Položky prihlásenia môžete spravovať pomocou tlačidla pre Nastavenia systému.
