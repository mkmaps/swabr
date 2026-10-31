# Spuštění: Položky přihlášení a služby

## Spustit při přihlášení (přímo)
Každá nainstalovaná aplikace má přepínač **„Spustit při přihlášení**“. macOS spustí zapnuté aplikace po přihlášení. Menší přepínač **„Skrytě“** je spustí bez okna. Jedná se o stejný seznam jako v Nastavení systému → Obecné → Položky přihlášení; Swabr jej ovládá prostřednictvím „Systémových událostí“ (macOS jednou požádá o povolení).

## Služby na pozadí
Níže (rozbalitelné) jsou aktualizační programy a pomocné nástroje, které si aplikace nastavují samy (LaunchAgents/LaunchDaemons):
- **Vaše služby** (ve vaší domovské složce): povolit/zablokovat spuštění, odstranit (koš).
- **Služby v rámci celého systému:** pouze zobrazení; změny proveďte v Nastavení systému. Výjimka: pokud chybí program, funkce **„Odstranit …“** je smaže (macOS vás požádá o zadání hesla).
- **„Chybí program“:** služba odkazuje na smazanou aplikaci a již nic nedělá – lze ji odstranit.

## Odstranění osamocených položek
Položky přihlášení a služby, jejichž aplikace již není nainstalována, jsou označeny oranžově s **hlášením „Chybí program**“.
- U položky při přihlášení funkce **„Odstranit ze seznamu“** vymaže danou položku ze seznamu položek přihlášení.
- V pravém dolním rohu možnost **„Odstranit osamocené položky (počet) …“** odstraní všechny najednou, poté co se zobrazí seznam jmen k potvrzení.
- Soubory služeb se přesouvají do koše a lze je odtud obnovit. Swabr odstraňuje systémové služby pouze v případě, že příslušný program byl skutečně odstraněn.

## Verze z App Store
Verze z App Store nemůže ovládat systémové události ani spouštět či zastavovat služby. Zobrazuje vaše vlastní služby běžící na pozadí a umožňuje je odstranit; Položky přihlášení lze spravovat pomocí tlačítka pro otevření Nastavení systému.
