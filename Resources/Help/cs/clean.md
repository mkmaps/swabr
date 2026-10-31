# Úklid

Úklid vyhledává data, která aplikace a macOS v případě potřeby znovu vytvoří: mezipaměti, protokoly, dočasné soubory, mezipaměti prohlížeče a vývojářů a zbytky odinstalovaných aplikací. Swabr pracuje se dvěma druhy pravidel:
- **Specifická pravidla** pro prohlížeče, vývojářské nástroje (Xcode, Homebrew, npm, pip, Cargo, Gradle …) a některé aplikace, jejichž data jsou uložena hlouběji.
- **Obecná pravidla**, která se řídí konvencemi složek v systému macOS: vše pod `~/Library/Caches`, složky mezipaměti Chromium v každé aplikaci Electron (Slack, Discord, VS Code, Obsidian …), mezipaměti, protokoly a dočasné soubory v kontejnerech aplikací. Tímto způsobem jsou pokryty i aplikace, o kterých žádný seznam neví.

Každé pravidlo má svůj typ (mezipaměť, protokoly, balíčky, sestavení…) a vlastní hodnocení. Specifická pravidla mají přednost před obecnými.

## Jak to funguje
- **Spustit skenování:** Swabr pouze prohlíží, nic se nemění.
- **Zkontrolujte seznam:** vlevo jsou kategorie a jejich velikosti, vpravo položky vybrané kategorie s jejich hodnocením, velikostí a účinkem. Zaškrtnutím políčka před kategorií vyberete celou kategorii; rozbalením řádku zobrazíte příslušné cesty.
- **Do koše:** klikněte na tlačítko vpravo dole a poté potvrďte v okně s přehledem. Pokud je zapnuta možnost „Trvale smazat“, tlačítko se nazývá „Vyčistit“ a data se smažou okamžitě.
- **Hotovo:** na závěrečné stránce se zobrazí, kolik místa bylo uvolněno, rozděleno podle kategorií, a volné místo před a po operaci.

## Bezpečné nebo Zkontrolovat
| Úroveň | Význam | Předvolené |
|---|---|---|
| **Bezpečné** (zelené) | mezipaměť, protokoly nebo dočasná data, která se znovu vytvoří | ano |
| **Zkontrolovat** (oranžové) | mohou obsahovat data, která stále chcete, nebo jejichž opětovné stažení trvá dlouho: Koš, přílohy e-mailů, stavy oken, vlastní mezipaměti systému macOS, velké soubory ke stažení, jako jsou Gradle nebo Playwright | ne |

Možnost „Doporučené“ vybírá pouze bezpečné položky, „Vše“ vybere vše, „Žádné“ nevybere nic.

## Přeskočené položky
- **„Je spuštěna“:** mezipaměti otevřené aplikace zůstanou nedotčeny (např. Chrome, Slack, VS Code). To platí i pro obecná pravidla: Swabr rozpoznává aplikaci podle názvu složky nebo ID balíčku. Ukončete aplikaci a proveďte skenování znovu.
- **Zelený štít:** položka je chráněna (viz „Chráněná data“) nebo se nachází v uzamčené oblasti.

## Speciální kategorie
- **Zbytky odstraněných aplikací:** mezipaměti, protokoly a stavy oken aplikací, které již nejsou nainstalovány a které se 30 dní (lze nastavit) nezměnily. Správci hesel, klíčenka a data SSH jsou z toho vyloučeny.
- **Velké datové soubory (pouze jako tip):** zálohy iOS, Mail, simulátory, Docker, modely AI. Swabr je nikdy automaticky nemaže, ale poradí vám, kde je správně provést Úklid.

## Už nikdy nemusíte čistit
Kliknutím pravým tlačítkem myši na položku → **„Nikdy nečistit“** ji trvale ochráníte. Zrušení provedete v Nastavení → Chráněná data.

To se vztahuje i na vše, co stejné pravidlo najde později. V rozbaleném seznamu klikněte pravým tlačítkem myši na umístění, chcete-li chránit pouze toto umístění, vše v jedné aplikaci nebo všechny složky s tímto názvem. Hned poté můžete ochranu zrušit kliknutím na **„Zpět“** v liště nad seznamem.

## Co se poté změní?
Aplikace znovu vytvoří své mezipaměti; první spuštění nebo první načtení stránky může trvat o něco déle. Přihlašovací údaje, dokumenty, nastavení a záložky zůstanou zachovány.
