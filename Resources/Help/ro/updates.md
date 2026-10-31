# Actualizări ale aplicațiilor

Swabr verifică toate aplicațiile instalate pentru a vedea dacă există versiuni noi. Cerință: **informațiile online** trebuie să fie activate (Configurări → General).

## Surse
| Sursă | Detectare | Editare directă | Ediția App Store |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | deschide site-ul web |
| App Store | comparație cu App Store | App Store deschide pagina sa de actualizări | la fel |
| Canalul de actualizare al aplicației (Sparkle) | appcast-ul furnizorului | descărcă și instalează noua versiune | deschide site-ul web |
| Furnizor (catalogul Homebrew) | comparare între versiuni | descărcări de la furnizor și instalări | deschide site-ul web |

## Siguranță la instalare (directă)
O descărcare înlocuiește o aplicație numai dacă **suma de control** se potrivește, **semnătura dezvoltatorului** este aceeași cu cea a aplicației instalate și **Gatekeeper** este de acord. Versiunea veche este mutată în Coșul de gunoi. Aplicațiile care rulează sunt închise după ce vi se cere confirmarea și redeschise ulterior.

## Utilizare
- Câte una pe rând cu **Actualizați**, sau mai multe folosind **casetele de selectare** și opțiunea „Actualizați cele selectate”.
- Meniul ⋯ ascunde o actualizare.
- „La zi” și „Nu se poate verifica” afișează celelalte aplicații; aplicațiile web Safari nu au actualizări.

> Aplicațiile din fișierele de instalare .pkg deschid programul de instalare macOS; finalizați instalarea acolo.
