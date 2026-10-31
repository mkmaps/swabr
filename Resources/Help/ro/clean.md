# Curățare

Funcția Curățare găsește datele pe care aplicațiile și macOS le recreează atunci când este necesar: cache-uri, jurnale, fișiere temporare, cache-uri ale browserului și ale dezvoltatorilor, precum și rămășițe ale aplicațiilor dezinstalate. Swabr funcționează cu două tipuri de reguli:
- **Reguli specifice** pentru browsere, instrumente de dezvoltare (Xcode, Homebrew, npm, pip, Cargo, Gradle …) și unele aplicații ale căror date se află mai adânc.
- **Reguli generale** care respectă convențiile de organizare a folderelor din macOS: tot ce se află în `~/Library/Caches`, folderele de cache Chromium din fiecare aplicație Electron (Slack, Discord, VS Code, Obsidian …), cache-urile, jurnalele și fișierele temporare din containerele aplicațiilor. În acest fel, sunt acoperite și aplicațiile despre care nicio listă nu are cunoștință.

Fiecare regulă are propriul tip (cache, jurnale, pachete, compilare…) și propriul nivel de prioritate. Regulile specifice au prioritate față de cele generale.

## Cum funcționează
- **Porniți scanarea:** Swabr doar verifică, nimic nu se modifică.
- **Verificați lista:** categoriile și dimensiunile acestora se află în stânga, iar intrările din categoria aleasă în dreapta, împreună cu evaluarea, dimensiunea și efectul lor. Caseta din fața unei categorii selectează tot conținutul acesteia; extindeți un rând pentru a vedea căile de acces ale acestuia.
- **Către Coșul de gunoi:** apăsați butonul din colțul din dreapta jos, apoi confirmați în fereastra de verificare. Dacă opțiunea „Șterge definitiv” este activată, butonul se numește „Curăță” și șterge imediat.
- **Gata:** pagina finală arată cât spațiu a fost eliberat, împărțit pe categorii, precum și spațiul liber înainte și după.

## Sigur sau Verificare
| Nivel | Adică | Preselectate |
|---|---|---|
| **Sigur**ă (verde) | cache-ul, jurnalele sau datele temporare care sunt recreate | da |
| **Verificați**ți (portocaliu) | pot conține date pe care doriți să le păstrați sau care necesită mult timp pentru a fi descărcate din nou: Coșul de gunoi, atașamentele din Mail, stările ferestrelor, cache-urile proprii ale macOS, descărcări mari precum Gradle sau Playwright | nu |

„Recomandate” selectează doar intrările sigure, „Toate” selectează totul, iar „Niciuna” nu selectează nimic.

## Intrări omise
- **„este în execuție”:** cache-urile unei aplicații deschise nu sunt modificate (de exemplu, Chrome, Slack, VS Code). Acest lucru se aplică și regulilor generale: Swabr recunoaște aplicația după numele folderului sau după ID-ul pachetului. Închideți aplicația și efectuați din nou scanarea.
- **Scut verde:** elementul este protejat (vezi „Date protejate”) sau se află într-o zonă blocată.

## Categorii speciale
- **Rămășițe ale aplicațiilor eliminate:** cache-uri, jurnale și stările ferestrelor aplicațiilor care nu mai sunt instalate și care nu au fost modificate de 30 de zile (perioadă ajustabilă). Managerii de parole, cheile de acces și datele SSH sunt excluse.
- **Seturi mari de date (doar ca indiciu):** copii de rezervă iOS, Mail, simulatoare, Docker, modele de IA. Swabr nu le șterge niciodată automat, ci îți indică unde să faci curățarea corespunzătoră.

## Nu mai curățați niciodată
Faceți clic dreapta pe o intrare → **„Nu curățați niciodată”** o protejează permanent. Anulați acțiunea din Configurări → Date protejate.

Acest lucru se aplică și tuturor elementelor pe care aceeași regulă le identifică ulterior. În lista extinsă, faceți clic dreapta pe o locație pentru a proteja doar acea locație, tot conținutul unei aplicații sau toate folderele cu acel nume. Imediat după aceea, butonul **„Anulare”** din bara de deasupra listei anulează protecția.

## Ce se schimbă după aceea?
Aplicațiile își reconstruiesc cache-urile; prima lansare sau prima încărcare a paginii poate dura puțin mai mult. Datele de autentificare, documentele, setările și marcajele rămân neschimbate.
