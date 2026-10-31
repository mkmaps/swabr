# Verzia Direct a verzia pre App Store

Aplikácia Swabr je k dispozícii v dvoch verziách vytvorených na základe rovnakého kódu. Ktorú verziu máte, zistíte v časti Nastavenia → Všeobecné a v položke „O aplikácii“.

|  | Priamo | App Store |
|---|---|---|
| Distribúcia | GitHub (DMG) | Mac App Store |
| Prístup | Úplný prístup k disku k celému domovskému priečinku | len zložky, ktoré sprístupníte |
| Upratanie, Odinštalovanie | áno | áno, po sprístupnení |
| Aplikácie, ktoré vlastní systém | áno (Finder vás požiada o zadanie hesla) | áno (macOS vás požiada o zadanie hesla) |
| Systémové súbory v priečinku /Library | áno | áno, po sprístupnení prístupu k /Library |
| Optimalizovať | všetkých 19 úloh | 5 úloh bez správcovských práv |
| Aktualizácie | sám inštaluje aktualizácie | zobrazuje aktualizácie, otvorí App Store alebo webovú stránku dodávateľa |
| Spustenie | správa položiek prihlásenia a služieb | zobraziť a odstrániť vlastné služby bežiace na pozadí |
| Zoštíhliť | áno | nie |

## Prečo verzia pre App Store ponúka menej funkcií
Spoločnosť Apple vyžaduje pre App Store **sandbox**: aplikácie môžu pristupovať iba k sprístupneným zložkám, nesmú žiadať o práva správcu, nesmú inštalovať ani meniť iné aplikácie a nesmú ovládať iné aplikácie (Smernice pre posudzovanie v App Store 2.4.5 a 2.5.2). Aplikácia Swabr dodržiava tieto pravidlá a ponúka všetko, čo tieto pravidlá povoľujú.

## Sprístupnenie prístupu k zložkám (verzia z App Store)
Pri prvom otvorení aplikácie Upratanie, Optimalizovať alebo Apps sa zobrazí hlásenie „Povoliť prístup“. Kliknite na „Sprístupniť …“; v dialógovom okne je už zobrazený správny priečinok, stačí len potvrdiť. Udelené oprávnenia sa uložia do pamäti a je možné ich zrušiť v časti Nastavenia → Prístup.

## Verzia Direct a zdrojový kód
Swabr je voľne dostupný softvér pod licenciou MIT. Verzia Direct a kompletný zdrojový kód sú bezplatne k dispozícii na GitHub; odkaz nájdete v Nastaveniach → O programe.
