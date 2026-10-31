# Versiunea Direct și App Store

Swabr este disponibil în două ediții construite pe baza aceluiași cod. Puteți vedea care dintre ele o aveți în Configurări → General și în secțiunea „Despre”.

|  | Direct | App Store |
|---|---|---|
| Distribuție | GitHub (DMG) | Mac App Store |
| Acces | Întregul folder de bază cu Acces complet la disc | numai folderele pe care le acordați acces |
| Curățare, dezinstalați | da | da, după ce ați acordat acces |
| Aplicații deținute de sistem | da (Finder vă solicită parola) | da (macOS vă solicită parola) |
| Fișierele de sistem din /Library | da | da, după ce v-ați acordat accesul la /Library |
| Optimizați | toate cele 19 de sarcini | 5 sarcini fără drepturi de administrator |
| Actualizări | se instalează automat actualizările | afișează actualizări, deschide App Store sau site-ul web al furnizorului |
| Pornire | gestionați articolele de autentificare și serviciile | afișați și eliminați propriile servicii de fundal |
| Reducere a dimensiunii | da | nu |

## De ce versiunea din App Store oferă mai puține funcții
Apple impune un **mediu izolat (sandbox)** pentru App Store: aplicațiile pot accesa doar folderele pentru care li s-a acordat accesul, nu pot solicita drepturi de administrator, nu pot instala sau modifica alte aplicații și nu pot controla alte aplicații (Ghidul de evaluare al App Store, secțiunile 2.4.5 și 2.5.2). Swabr respectă aceste reguli și oferă tot ceea ce acestea permit.

## Acordați acces la foldere (ediția App Store)
La prima deschidere a secțiunilor Curățare, Optimizați sau „Aplicații”, apare mesajul „Permiteți accesul”. Faceți clic pe „Acordați acces …”; fereastra de dialog afișează deja folderul corect, trebuie doar să confirmați. Acordurile sunt memorate și pot fi revocate din Configurări → Acces.

## Versiunea Direct și codul sursă
Swabr este un program gratuit, distribuit sub licența MIT. Versiunea Direct și codul sursă complet sunt disponibile gratuit pe GitHub; linkul se găsește în Setări → Despre.
