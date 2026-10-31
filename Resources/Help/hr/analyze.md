# Prostor

Prostor prikazuje gdje nestaje vaš prostor – poput rendgenskog snimka vašeg diska.

## Pregled
Početna stranica mjeri glavne lokacije: Početna (bez Medijske knjižnice), Medijska knjižnica, Aplikacije, sistemska Medijska knjižnica i uobičajeni "pojedinci" koji zauzimaju prostor kao što su iOS sigurnosne kopije, stari preuzimanja (stariji od 90 dana), Xcode i Docker podaci.

## Korištenje
- **Dvostruki klik** otvara mapu; gornja traka s putanjom se vraća.
- **Popis ili pločice:** prebacite se na gornjem desnom dijelu. Prikaz pločica (treemap) prikazuje veličine kao površine.
- **Najveće datoteke:** ikona dokumenta u alatnoj traci prikazuje 20 najvećih datoteka.
- **Brzi pregled:** tipka za razmak prikazuje pretpregled.
- **Kutijice za označavanje** odabiru stavke za Kantu za smeće.

## Oznake
- **"removable":** mape izrade ili ovisnosti (npr. node_modules) koje se ponovno stvaraju.
- **Veličina s "+":** najmanje ove veličine; neki su stavci bili nečitljivi (Potpuni pristup disku?) ili je mjerenje trajalo dulje od vremenskog ograničenja (30 sekundi, podesivo).

## Što se događa prilikom brisanja?
Odabrani stavci idu u Kantu za smeće i mogu se vratiti. Prozor za pregled upozorava na podatke aplikacije, mape u iCloudu i medijske biblioteke. Sustavne mape, sama vaša početna mapa i podaci aktivnih VM-ova su zaključani.

## Bilješke
- Mjesta držača u iCloudu se ne preuzimaju i računaju se prema svojoj lokalnoj veličini (često gotovo 0).
- Ostali diskovi nisu uključeni.
