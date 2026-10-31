# Pokretanje: stavke za prijavu i usluge

## Otvori pri prijavi (izravno)
Svaka instalirana aplikacija ima prekidač **"Otvori pri prijavi"**. macOS otvara aplikacije s uključenim automatskim pokretanjem nakon što se prijavite. Manji prekidač **"Skriveno"** pokreće ih bez prozora. To je ista lista kao u Uređivanje sustava → Općenito → Stavke prijave; Swabr njome upravlja putem "System Events" (macOS jednom traži dopuštenje).

## Pozadinske usluge
Ispod (može se proširiti) nalaze se ažuratori i pomoćni alati koje aplikacije postavljaju same (LaunchAgents/LaunchDaemons):
- **Vaše usluge** (u vašem korisničkom direktoriju): dopustiti/blokirati pokretanje, ukloniti (Kanta za smeće).
- **Sustavne usluge:** prikazivanje samo; mijenjajte ih u Postavkama sustava. Iznimka: ako njihov program nedostaje, **"Ukloni …"** ih briše (macOS traži vašu lozinku).
- **"Program nedostaje":** usluga upućuje na izbrisanu aplikaciju i više ne radi ništa – može se ukloniti.

## Uklanjanje siročadi
Prilikazom se prikazuju vlastite pozadinske usluge i mogu ih ukloniti; upravljaju se stavkama za prijavu pomoću gumba za Postavke sustava. Stavke za prijavu i usluge čija aplikacija više nije instalirana označene su narančastom bojom s porukom **"Program nedostaje"**.
- Za stavku za prijavu, **"Ukloni sa popisa"** briše unos sa popisa stavki za prijavu.
- Na donjoj desnoj strani, **opcija "Ukloni siročad (broj) …"** uklanja ih sve odjednom, nakon što zatraži popis imena.
- Datoteke usluga idu u Kantu za smeće i mogu se tamo vratiti. Swabr uklanja usluge na razini sustava samo ako je njihov program doista nestao.

## Izdanje za App Store
Izdanje za App Store ne može ni kontrolirati događaje sustava ni pokretati ili zaustavljati usluge. Prikazuje vaše vlastite pozadinske usluge i može ih ukloniti; upravljajte stavkama za prijavu pomoću gumba za Postavke sustava.
