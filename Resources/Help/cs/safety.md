# Bezpečnost: Koš, mazání, protokol

## Nic se nestane bez vašeho potvrzení
Každá sekce nejprve zobrazí seznam. Než dojde k odstranění, v **okně pro kontrolu** se zobrazí seznam všech položek a jejich důsledků; pouze volby „Odstranit“ nebo „Přesunout do Koše“ něco změní.

## Do koše nebo trvale smazat?
|  | Koš | Trvale |
|---|---|---|
| Lze obnovit | ano, dokud není složka vyprázdněna („Vrátit zpět“ ve Finderu) | ne |
| Uvolněné místo | po vyprázdnění | okamžitě |
| Používá se v | Odinstalovat, Úložiště, Instalátory, Zeštíhlit, volitelně Úklid a Projekty | volitelně Úklid a Projekty |

Úklid a Projekty ve výchozím nastavení mazají trvale, protože mezipaměti a složky sestavení se stejně znovu vytvoří. Jako výchozí volbu vyberte Koš v části Nastavení → Chování.

## Několikrát ověřeno
- K odstranění dochází pouze uvnitř vaší domovské složky (a u aplikací ve složkách Aplikace).
- Symbolické odkazy se nikdy nesledují; odkaz v cestě zastaví mazání.
- Těsně před každým smazáním Swabr znovu zkontroluje: existuje položka stále? Nebyla mezitím chráněna?
- Zástupné symboly iCloudu se nikdy nestahují a nezapočítávají se.

## Protokol
Každá akce je zaznamenána s časem, cestou a velikostí. Najdete ji v části **Historie**.
