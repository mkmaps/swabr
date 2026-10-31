# Verze Direct a App Store

Swabr je k dispozici ve dvou edicích vytvořených ze stejného kódu. Kterou z nich máte, zjistíte v části Nastavení → Obecné a v sekci „O aplikaci“.

|  | Přímo | App Store |
|---|---|---|
| Distribuce | GitHub (DMG) | Mac App Store |
| Přístup | celá domovská složka s Plný přístup k disku | pouze složky, ke kterým zpřístupníte oprávnění |
| Úklid, Odinstalovat | ano | ano, po zpřístupnění oprávnění |
| Aplikace patřící systému | ano (Finder vás požádá o zadání hesla) | ano (macOS vás požádá o zadání hesla) |
| Systémové soubory v adresáři /Library | ano | ano, po zpřístupnění /Library |
| Optimalizovat | všech 19 úkolů | 5 úkolů bez oprávnění správce |
| Aktualizace | aplikace si aktualizace instaluje sama | zobrazuje aktualizace, otevírá App Store nebo webové stránky prodejce |
| Spuštění | správa položek přihlášení a služeb | Zobrazit a odstranit vlastní služby běžící na pozadí |
| Zeštíhlit zařízení | ano | ne |

## Proč verze pro App Store nabízí méně funkcí
Společnost Apple pro App Store vyžaduje **sandbox**: aplikace smí přistupovat pouze k zpřístupněným složkám, nesmí vyžadovat práva správce, nesmí instalovat ani měnit jiné aplikace a nesmí ovládat jiné aplikace (Pokyny pro posuzování aplikací v App Store 2.4.5 a 2.5.2). Aplikace Swabr se těmito pravidly řídí a nabízí vše, co tato pravidla umožňují.

## Zpřístupnění oprávnění ke složkám (verze pro App Store)
Při prvním otevření funkcí Úklid, Optimalizovat nebo Aplikace se zobrazí hlášení „Povolit přístup“. Klikněte na „Zpřístupnit …“; v dialogovém okně je již zobrazena správná složka, stačí pouze potvrdit. Zpřístupněná oprávnění se ukládají do paměti a lze je zrušit v části Nastavení → Přístup.

## Verze Direct a zdrojový kód
Swabr je svobodný software pod licencí MIT. Verze Direct a kompletní zdrojový kód jsou zdarma k dispozici na GitHubu; odkaz najdete v nabídce Nastavení → O aplikaci.
