# Direktno i App Store izdanje

Swabr dolazi u dvije izdanja izgrađene od istog koda. Možete vidjeti koje imate pod Postavke → Općenito i u "O aplikaciji".

|  | Izravno | App Store |
|---|---|---|
| Distribucija | GitHub (DMG) | Mac App Store |
| Pristup | cijelu korisničku mapu s Potpuni pristup disku | samo mape za koje odobrite pristup |
| Očisti, deinstaliraj | da | da, nakon dodjeljivanja |
| Aplikacije u vlasništvu sustava | da (Finder će zatražiti vašu lozinku) | da (macOS traži vašu lozinku) |
| Sistemski datoteci u /Library | da | da, nakon dodjele /Library |
| Optimiziraj | svi 19 zadataka | 5 zadataka bez administratorskih prava |
| Ažuriranja | instalira ažuriranja samostalno | prikazuje ažuriranja, otvara App Store ili web-stranicu prodavača |
| Pokretanje | upravljanje stavkama za prijavu i uslugama | prikaži i ukloni vlastite pozadinske usluge |
| Smanjiti | da | ne |

## Zašto App Store izdanje nudi manje
Apple zahtijeva **sandbox** za App Store: aplikacije smiju pristupati samo dodijeljenim mapama, ne smiju tražiti administratorska prava, ne smiju instalirati ili mijenjati druge aplikacije i ne smiju kontrolirati druge aplikacije (Smjernice za pregled App Storea 2.4.5 i 2.5.2). Swabr se pridržava tih pravila i nudi sve što je dopušteno.

## Dodjeljivanje mapa (izdanje za App Store)
Prvi put kada otvorite Čišćenje, Optimiziraj ili Apps, pojavit će se "Dopusti pristup". Kliknite na "Odobri …"; dijalog već prikazuje ispravnu mapu, vi samo potvrđujete. Odobrenja se pamte i mogu se opozvati u Postavke → Pristup.

## Verzija Direct i izvorni kod
Swabr je besplatan softver pod MIT licencom. Verzija Direct i cjelokupni izvorni kod dostupni su besplatno na GitHubu; poveznica se nalazi pod Postavke → O aplikaciji.
