# Administratorska prava (pomoćna usluga)

## Što je to?
Neki koraci zahtijevaju administratorska prava: uklanjanje aplikacija koje pripadaju sustavu, optimizacije kao što je pražnjenje DNS predmemorije i čitanje stavki za prijavu koje su aplikacije same registrirale. Bez pomoćne usluge, macOS traži vašu lozinku svaki put.

**Pomoćna usluga** Swabr preuzima ove korake nakon što joj to dopustite. Prihvaća samo zahtjeve iz Swabra potpisane istim certifikatom programera i zatvara se nakon pet minuta neaktivnosti. Dostupna je samo u Direct izdanju.

## Kako postaviti
### 1. Postavite ga u Swabru
Otvorite **Swabr → Postavke → Ponašanje** i kliknite na **Postavi …** u odjeljku **Administratorova prava**.

![](images/helfer-1-einstellungen.png)

### 2. Dopustite to u postavkama sustava
macOS otvara **Postavke sustava → Općenito → Stavke prijave**. U odjeljku **App Background Activity** (Aktivnost u pozadini aplikacije) uključite **Swabr** i potvrdite svojom lozinkom ili Touch ID-om.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Gotovo
Natrag u Swabru, odjeljak **Administrator prava** prikazuje "Postavljeno: lozinka više nije potrebna". Od sada se ovi koraci izvršavaju bez upita.

> Ako piše "Čeka se vaša dozvola u Sustavnim postavkama", korak 2 i dalje nedostaje. **Zupčanik** pokraj njega vodi vas izravno tamo.

## Što se mijenja nakon toga?
- **Aplikacije → Pokretanje** također prikazuje aplikacije koje se same pokreću (na primjer, s opcijom "Otvori pri prijavi" unutar aplikacije).
- **Deinstaliraj**, **Optimiziraj** i početni koraci u **Čišćenje**, **Projekti**, **Instalacijski programi** i **Smanjivanje** više ne traže lozinku.
- Sigurnosne provjere ostaju iste: sve fiksne brave i dalje vrijede, a svaki se korak provjerava i bilježi.

## Ukloni
Kliknite **Ukloni** u **Postavke → Ponašanje → Administratorova prava**. Swabr će zatim ponovno tražiti lozinku na svakom koraku.
