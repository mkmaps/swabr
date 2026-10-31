# Optimalizovat

Optimalizovat spouští údržbové úlohy pro macOS. Zbytečné kroky jsou s odůvodněním přeskočeny.

## Použití
- Úkoly vyberte pomocí **zaškrtávacích políček**; v pravém horním rohu je tlačítko „Vybrat vše/nic“. Swabr si zapamatuje nezaškrtnuté úkoly.
- Každý úkol popisuje, co dělá a jaké změny po něm nastanou. Oranžová barva: znatelný vedlejší účinek.
- **Heslo:** úkoly vyžadující práva správce se spouštějí najednou; heslo se zadává pouze jednou. Zrušením se přeskočí pouze tyto úkoly.

## Úkoly
| Úkol | Co se stane | Heslo |
|---|---|---|
| Náhledy QuickLook | vynulovat mezipaměť miniatur QuickLooku | ne |
| Stavy oken | odstranit uložená okna starší než 30 dní, neplatí pro spuštěné aplikace | ne |
| Poškozené předvolby | přesunout poškozené soubory předvoleb třetích stran do koše | ne |
| DNS cache | vyprázdnit překlad názvů (přeskočeno při aktivní VPN nebo v režimu offline) | ano |
| Síťové trasy | vyprázdnit směrovací tabulku a obnovit adresy přes DHCP, pouze pokud všechna rozhraní používají DHCP (krátké přerušení) | ano |
| .DS_Store | žádné soubory Finderu na síťových a USB discích | ne |
| Staré přepínače pro ladění | App Nap a ověřování obrázků zpět na výchozí nastavení | ne |
| Oprávnění | Obnovte oprávnění ve vaší domovské složce, pouze pokud něco nefunguje správně (trvá to několik minut) | ano |
| Index Spotlight | zkontrolujte stav, proveďte obnovu pouze v případě chyb nebo pokud je indexování vypnuté | ano |
| Vyloučení ze Spotlightu | nahlásí výjimky, jejichž umístění již neexistuje; načte nastavení s oprávněními správce, nic nemění | ano |
| Pravidelná údržba | pouze úkoly, jejichž termín již uplynul; od verze macOS 26 již nejsou k dispozici | ano |
| Postranní panel a nedávné položky | přesunout nečitelné seznamy v postranním panelu a seznamy nedávných položek do Koše | ne |
| Ověřit spouštěcí svazek | zkontrolujte souborový systém, nic se nezmění | ne |
| Položky přihlášení | nahlásit položky, u nichž chybí program | ne |
| Historie stahování | vymazat historii stahování Gatekeeperu (ochrana soukromí) | ne |
| Služby na pozadí | nahlásit služby, u nichž chybí program | ne |
| Oznámení | smazat doručená oznámení starší než 30 dní | ne |
| Databáze | komprimovat Mail, Safari, Zprávy (pouze zavřené, nepoškozené, < 100 MB) | ne |

## Verze z App Store
K dispozici jsou zde pouze úkoly, které lze provést ve vaší domovské složce bez oprávnění správce: stavy oken, poškozené předvolby, postranní panel a nedávné položky, historie stahování a služby na pozadí.
