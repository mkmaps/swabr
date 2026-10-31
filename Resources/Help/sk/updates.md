# Aktualizácie aplikácií

Swabr skontroluje všetky nainštalované aplikácie, či nie sú k dispozícii nové verzie. Požiadavka: musia byť zapnuté **online informácie** (Nastavenia → Všeobecné).

## Zdroje
| Zdroj | Detekcia | Priama úprava | Verzia z App Store |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | otvoriť webovú stránku |
| App Store | Porovnanie s App Store | App Store otvorí svoju stránku s aktualizáciami | rovnako |
| Kanál aktualizácií aplikácie (Sparkle) | aplikácia od výrobcu | stiahne a nainštaluje novú verziu | otvoriť webovú stránku |
| Dodávateľ (katalóg Homebrew) | Porovnanie verzií | stiahnutie od dodávateľa a inštalácia | otvoriť webovú stránku |

## Bezpečnosť pri inštalácii (priamo)
Stiahnutá aplikácia nahradí pôvodnú iba vtedy, ak sa zhoduje **kontrolný súčet**, **podpis vývojára** je rovnaký ako u nainštalovanej aplikácie a **Gatekeeper** s tým súhlasí. Stará verzia sa presunie do koša. Spustené aplikácie sa po zobrazení výzvy ukončia a následne znovu spustia.

## Používanie
- Jednu po druhej pomocou funkcie **Aktualizovať** alebo viacero pomocou **začiarkavacích políčok** a možnosti „Aktualizovať vybrané“.
- Ponuka ⋯ skryje aktualizáciu.
- V položkách „Aktualizované“ a „Nemožno skontrolovať“ sa zobrazia ostatné aplikácie; webové aplikácie Safari nemajú žiadne aktualizácie.

> Aplikácie z inštalačných súborov .pkg otvoria inštalátor macOS; inštaláciu dokončite tam.
