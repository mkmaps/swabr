# Práva správcu (pomocná služba)

## Čo to je?
Niektoré kroky vyžadujú práva správcu: odstránenie aplikácií, ktoré patria k systému, optimalizácie, ako je vyprázdnenie vyrovnávacej pamäte DNS, a čítanie položiek prihlásenia, ktoré si aplikácie zaregistrovali samy. Bez pomocnej služby vás macOS požiada o heslo zakaždým.

**Pomocná služba** aplikácie Swabr prevezme tieto kroky, akonáhle jej to povolíte. Prijíma iba požiadavky od aplikácie Swabr podpísané tým istým certifikátom vývojára a po piatich minútach nečinnosti sa ukončí. Je k dispozícii iba vo verzii Direct.

## Ako to nastaviť
### 1. Nastavte to v aplikácii Swabr
Otvorte **Swabr → Nastavenia → Správanie** a kliknite na **Nastaviť…** v sekcii **Práva správcu**.

![](images/helfer-1-einstellungen.png)

### 2. Povoliť v Nastaveniach systému
V systéme macOS otvorte **Nastavenia systému** → **Všeobecné** → **Položky prihlásenia**. V časti **Aktivity aplikácií na pozadí**** zapnite **Swabr OP** a potvrďte heslom alebo Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Hotovo
Späť v aplikácii Swabr sa v sekcii **Práva správcu** zobrazuje text „Nastavenie: heslo už nie je potrebné“. Odteraz sa tieto kroky vykonávajú bez žiadosti o heslo.

> Ak sa zobrazuje hlásenie „Čaká sa na vaše povolenie v Nastaveniach systému“, krok 2 stále chýba. Ozubené **koliesko** vedľa neho vás tam priamo presmeruje.

## Čo sa potom zmení?
- **Aplikácie → Spustenie** tiež zobrazuje aplikácie, ktoré sa registrujú samy (napríklad pomocou možnosti „Spustiť pri prihlásení“ v aplikácii).
- **Odinštalovať**, **Optimalizovať** a kroky súvisiace s rootom v sekciách **Upratanie**, **Projekty**, **Inštalátory** a **Zoštíhliť** už nevyžadujú zadanie hesla.
- Bezpečnostné kontroly zostávajú nezmenené: všetky nastavené obmedzenia stále platia a každý krok je kontrolovaný a zaznamenávaný.

## Odstrániť
Kliknite na **Odstrániť** v časti **Nastavenia → Správanie → Práva správcu**. Swabr potom opäť požiada o heslo pri každom kroku.
