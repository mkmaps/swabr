# Dezinstalația aplicațiilor

Dacă trageți o aplicație în Coșul de gunoi, datele acesteia rămân în sistem: cache-uri, setări, servicii de fundal și, uneori, fișiere de sistem. Swabr găsește aceste rămășițe.

## Cum funcționează
- Selectați aplicațiile din stânga folosind caseta **de selectare** (se pot selecta mai multe). Informațiile și toate fișierele găsite apar în partea dreaptă.
- **Dezinstalați …** deschide fereastra de verificare cu toate efectele.
- Aplicațiile care rulează sunt închise mai întâi. Totul ajunge în Coșul **de gunoi**.

## Ce se elimină?
| Grup | Exemple | Preselectate |
|---|---|---|
| **Va fi eliminat** | aplicație, cache-uri, jurnale, starea ferestrei, agenți de lansare | da |
| **Date personale** | setări, containere, conturi, biblioteci | nu |
| **Sensibile** | profiluri de browser (parole, istoric), date ale grupurilor de aplicații | niciodată automat |
| **Fișiere de sistem** | fișiere din /Library, servicii de sistem, instrumente auxiliare | nu, necesită parolă |

Datele personale rămân în mod implicit, astfel încât setările și conturile sunt restabilite dacă reinstalați aplicația. Opțiunea „Elimină tot” le selectează. Modificați setarea implicită din Configurări → Comportament.

## Despre aplicație
Secțiunea „Informații” afișează dezvoltatorul (din semnătură), categoria, versiunea, ultima utilizare și – dacă sunt disponibile informații online – o descriere și linkuri către site-ul web, App Store și căutarea pe web. Acest lucru vă ajută să recunoașteți aplicațiile necunoscute înainte de a le șterge.

## Simboluri
- **Lacăt:** protejat (componentă de sistem, software de securitate cu propriul program de Dezinstalați, aplicația Swabr însăși).
- **Cheie:** aparține unui alt utilizator sau sistemului; macOS vă solicită parola la ștergere.

## Homebrew
Aplicațiile instalate cu Homebrew sunt dezinstalate cu comanda `brew uninstall`, astfel încât Homebrew rămâne sincronizat.
