# Drepturi de administrator (serviciu auxiliar)

## Ce este?
Anumite etape necesită drepturi de administrator: eliminarea aplicațiilor care aparțin sistemului, optimizări precum golirea cache-ului DNS și citirea articolelor de autentificare pe care aplicațiile le-au înregistrat singure. Fără serviciul auxiliar, macOS vă solicită parola de fiecare dată.

**Serviciul auxiliar** al Swabr preia aceste etape odată ce i-ați acordat permisiunea. Acesta acceptă doar cererile provenite de la Swabr semnate cu același certificat de dezvoltator și se închide după cinci minute de inactivitate. Este disponibil numai în ediția Direct.

## Cum se configurează
### 1. Configurați-l în Swabr
Deschideți **Swabr → „Configurări” → „Comportament”** și faceți clic pe **„Configurare…”** în secțiunea **„Drepturi de administrator**”.

![](images/helfer-1-einstellungen.png)

### 2. Permiteți acest lucru în Configurări sistem
macOS deschide „**Configurări sistem” → „General” → „Articole de autentificare**”. În secțiunea **„Activitate în fundal a aplicațiilor**”, activați **Swabr** și confirmați cu parola sau Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Gata
Înapoi în Swabr, secțiunea ****Drepturi de** **administrator**** afișează mesajul „Configurare: nu mai este necesară parola”. De acum înainte, aceste etape se execută fără a mai solicita parola.

> Dacă apare mesajul „Așteptăm permisiunea dvs. în Configurări sistem”, pasul 2 încă lipsește. Roata **dințată** de lângă acesta vă duce direct acolo.

## Ce se schimbă după aceea?
- **Aplicații → Pornire** afișează, de asemenea, aplicațiile care se înregistrează automat (de exemplu, cu opțiunea „Deschideți la autentificare” din aplicație).
- **Dezinstalați**, **Optimizați** și pașii care necesită drepturi de root din secțiunile **Curățare**, **Proiecte**, **Programe de instalare** și **Reducere** nu mai solicită parola.
- Verificările de siguranță rămân neschimbate: toate blocările stabilite se aplică în continuare, iar fiecare pas este verificat și înregistrat.

## Eliminare
Faceți clic pe **„Eliminare”** în „**Configurări**”** → „Comportament” → „Drepturi de administrator**”. Swabr va solicita din nou parola la fiecare pas.
