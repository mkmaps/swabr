# Pornire: articole de autentificare și servicii

## Deschideți la autentificare (Direct)
Fiecare aplicație instalată are un comutator **„Deschideți la autentificare**”. macOS deschide aplicațiile activate după ce vă autentificați. Comutatorul mai mic **„Ascuns”** le pornește fără fereastră. Este aceeași listă ca în Configurări sisteme → Generale → Articole de autentificare; Swabr o controlează prin „Evenimente de sistem” (macOS solicită o singură dată permisiunea).

## Servicii care rulează în fundal
Mai jos (listă extensibilă) se află programele de actualizare și instrumentele auxiliare pe care aplicațiile le configurează singure (LaunchAgents/LaunchDaemons):
- **Serviciile dvs.** (din folderul dvs. de bază): permiteți/blocați pornirea, eliminați (Coșul de gunoi).
- **Serviciile la nivel de sistem:** doar afișare; modificați-le în Configurări sistem. Excepție: dacă Programul corespunzător este lipsă, **opțiunea „Eliminare …”** le șterge (macOS vă solicită parola).
- **„Program lipsă”:** serviciul indică o aplicație ștersă și nu mai face nimic – poate fi eliminat.

## Eliminarea intrărilor orfane
Articolele de autentificare și serviciile ale căror aplicații nu mai sunt instalate sunt marcate cu portocaliu cu **mențiunea „Program lipsă**”.
- Pentru un element de autentificare, **opțiunea „Eliminare din listă”** șterge intrarea din lista articolelor de autentificare.
- În colțul din dreapta jos, **opțiunea „Elimină orfanii (număr) …”** îi elimină pe toți odată, după ce îți solicită confirmarea cu lista de nume.
- Fișierele serviciilor sunt mutate în Coșul de gunoi și pot fi restaurate de acolo. Swabr elimină serviciile la nivel de sistem numai dacă programul aferent a fost eliminat definitiv.

## Ediția din App Store
Ediția din App Store nu poate controla evenimentele de sistem și nici nu poate porni sau opri serviciile. Afișează propriile servicii care rulează în fundal și le poate elimina; gestionează articolele de autentificare cu ajutorul butonului către Configurări sistem.
