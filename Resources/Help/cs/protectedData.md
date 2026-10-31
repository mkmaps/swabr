# Chráněná data (whitelist)

Seznam v části Nastavení → **Chráněná data** definuje, čeho se Swabr při Úklidu **nikdy** nedotkne – i kdyby to pravidlo jinak zahrnovalo. Jiné nástroje tomu říkají „whitelist“.

## Jak číst seznam
- **Zapnuto = chráněno.** Položka se již nezobrazuje v aplikaci Úklid nebo se zobrazuje se zeleným štítem.
- **Vypnuto = může být odstraněno,** pokud to zahrnuje pravidlo pro Úklid.
- **„Výchozí“** označuje položky chráněné již od začátku (mezipaměti Gradle, prohlížeče Playwright, modely Hugging Face).
- Každá položka ukazuje, kolik místa právě zabírá, takže vidíte, kolik místa vás její ochrana stojí.

## Kdy chránit
Chraňte data, která se sice znovu vytvoří, ale jejich obnovení trvá dlouho nebo spotřebovává velké množství datového objemu: DerivedData z Xcode u velkých projektů, mezipaměti Gradle, stažené modely AI, soubory stažené přes Homebrew při pomalém připojení.

## Vaše vlastní položky
V části „Vaše položky“ můžete chránit libovolnou složku nebo soubor:
- **Možnost „Vybrat složku …“** otevře dialogové okno; vybraná složka je chráněna.
- Nebo zadejte **vzor**. Pod ním okamžitě uvidíte, kolik položek tento vzor odpovídá.

| Vzor | Chrání |
|---|---|
| `~/Library/Caches/Foo` | přesně tato složka |
| `~/Library/Caches/Foo/*` | vše v této složce (a s ní i samotná složka) |
| `~/Library/Caches/Foo*` | všechny složky začínající na „Foo“ |

„~“ označuje vaši domovskou složku, „*“ jakékoli znaky.

## Bezpečnostní pravidla
Některé položky jsou vždy chráněny a nelze je deaktivovat: mezipaměti obsahující stav synchronizace iCloud, přihlášení k účtu Apple, Wallet, Home, písma, Spotlight nebo probíhající stahování na pozadí a vlastní mezipaměť aplikace Swabr. Kromě toho jsou vždy mimo dosah iCloud Drive, klíčenka, složka Dokumenty, plocha a vše mimo vaši domovskou složku.

## Umístění a obnovení
Seznam je uložen v souboru `~/.config/swabr/whitelist` (jeden vzor na řádek). Jakmile něco změníte, tento soubor nahradí výchozí seznam; volba „Obnovit výchozí nastavení“ jej opět smaže.
