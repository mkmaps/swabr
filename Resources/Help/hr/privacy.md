# Privatnost

Swabr ne prikuplja nikakve podatke, ne sadrži analitiku ni oglase i nema korisnički račun.

## Što ostaje na vašem Macu
Sva skeniranja, mjerenja, postavke, zaštićeni podaci i zapisnik pohranjuju se isključivo lokalno.

## Što se šalje putem interneta (samo s opcijom "online info")
| Gdje | Što | Zašto |
|---|---|---|
| formulae.brew.sh | preuzimanje javnog kataloga Homebrew (oko 10 MB, kešira se 7 dana), bez vaših podataka | opis i verzije |
| itunes.apple.com | identifikatora vaših aplikacija iz App Storea (npr. com.bitwarden.desktop) | opis, verzija, poveznica na trgovinu |
| kanali ažuriranja aplikacija | Preuzimanje vendorove appcast datoteke | usporedba verzija |
| vendor preuzimanja | samo kada pokrenete ažuriranje (izravno) | preuzmite novu verziju |

Isključite "online info" u Postavke → Općenito; Swabr tada radi potpuno izvan mreže. U izdanju iz App Storea ta je opcija isključena prema zadanim postavkama.

## Dozvole
Swabr koristi Potpuni pristup disku (izravan) ili dozvole za mape (App Store) samo za vidljive značajke. Sve se dozvole mogu opozvati u Postavkama sustava ili pod Postavke → Pristup.

## Brisanje vaših podataka
Uklonite Swabr i izbrišite `~/.config/swabr` i `~/Library/Application Support/Swabr` (izdanje iz App Storea: njegov spremnik u ~/Library/Containers).
