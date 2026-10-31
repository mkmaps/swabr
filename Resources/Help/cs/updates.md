# Aktualizace aplikací

Swabr zkontroluje všechny nainstalované aplikace, zda nejsou k dispozici nové verze. Požadavek: musí být zapnuto **připojení k internetu** (Nastavení → Obecné).

## Zdroje
| Zdroj | Detekce | Přímá úprava | Verze z App Store |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | otevřít webovou stránku |
| App Store | Srovnání s App Storem | App Store otevře stránku s aktualizacemi | stejné |
| Kanál aktualizací aplikace (Sparkle) | aplikace od výrobce | stáhne a nainstaluje novou verzi | otevřít webovou stránku |
| Výrobce (katalog Homebrew) | Porovnání verzí | stahování od výrobce a instalace | otevřít webovou stránku |

## Bezpečnost při instalaci (přímá)
Stažený soubor nahradí aplikaci pouze v případě, že se shoduje **kontrolní součet**, **podpis vývojáře** je stejný jako u nainstalované aplikace a **Gatekeeper** s tím souhlasí. Stará verze se přesune do koše. Spuštěné aplikace se po zobrazení dotazu ukončí a poté znovu spustí.

## Použití
- Jednu po druhé pomocí tlačítka **Aktualizovat** nebo více najednou pomocí **zaškrtávacích políček** a volby „Aktualizovat vybrané“.
- Nabídka ⋯ skryje aktualizaci.
- Položky „Aktuální“ a „Nelze zkontrolovat“ zobrazují seznam ostatních aplikací; webové aplikace Safari nemají žádné aktualizace.

> Aplikace z instalačních balíčků .pkg otevřou instalační program macOS; instalaci dokončete tam.
