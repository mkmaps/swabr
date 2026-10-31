# Acces complet la disc

## Ce este aceasta?
macOS protejează anumite date în mod special: Mail, Mesaje, Safari, Coșul de gunoi, copiile de rezervă Time Machine și datele unor aplicații. Programele pot vedea aceste foldere doar dacă le acordați „**Acces complet la disc**”. Aceasta este o caracteristică de securitate a macOS, nu ceva inventat de Swabr.

## De ce are Swabr nevoie de aceasta?
Fără aceasta, anumite părți ale Mac-ului tău rămân ascunse:
- **Curățare:** Coșul de gunoi, atașamentele din Mail, cache-urile din containerele aplicațiilor și previzualizările din Mesaje sunt invizibile.
- **Spațiu de stocare:** folderele precum Mail sau Safari sunt măsurate ca având o dimensiune prea mică sau nu sunt măsurate deloc („+” după dimensiune).
- **Optimizare:** bazele de date și datele de utilizare ale aplicațiilor Mail, Safari și Mesaje sunt inaccesibile.

Swabr funcționează și fără aceasta, dar găsește mai puține elemente.

## Ce poate face Swabr cu aceste permisiuni?
Accesul permite citirea și scrierea. Swabr îl utilizează doar pentru regulile pe care le vedeți în aplicație și șterge numai după ce confirmați fereastra de verificare. Blocările fixe se aplică întotdeauna: iCloud Drive, keychain-ul, Documentele, Desktopul și tot ce se află în afara folderului dvs. de bază nu sunt niciodată atinse. Fiecare ștergere este listată în „Istoric”.

## Cum se acordă accesul
### 1. Deschideți Configurările sistem
Faceți clic pe **rotița** din notificarea portocalie a Swabr (sau în fereastra de la prima pornire). Se deschide „**Configurări sistem” → „Confidențialitate și securitate” → „Acces complet la disc**”.

### 2. Activați Swabr
Activați **Swabr.app** și confirmați cu parola sau Touch ID. Dacă intrarea lipsește, adăugați Swabr cu **+** sau trageți aplicația din Finder în listă.

![](images/festplattenvollzugriff-1-liste.png)

### 3. Reporniți Swabr
macOS vă solicită de obicei acest lucru. Notificarea portocalie dispare apoi.

> Dacă mutați Swabr sau instalați o versiune nou semnată, macOS o poate trata ca pe o aplicație nouă. Ștergeți vechea intrare cu **−** și adăugați din nou Swabr.

## Revocare
Dezactivați-l din aceeași listă. Swabr afișează din nou notificarea și funcționează cu acces redus.

## Ediția din App Store
Ediția din App Store nu utilizează „Acces complet la disc”, ci permisiuni la nivel de folder (vezi „Ediția directă și cea din App Store”).
