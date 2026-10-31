# Aggiornamenti delle app

Swabr controlla tutte le app installate per verificare la presenza di nuove versioni. Requisito: le **informazioni online** devono essere attive (Impostazioni → Generali).

## Fonti
| Fonte | Rilevamento | Modifica diretta | Versione App Store |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | apri il sito web |
| App Store | Confronto con l’App Store | L’App Store apre la sua pagina degli aggiornamenti | stesso |
| Il canale di aggiornamento dell’app (Sparkle) | appcast del fornitore | scarica e installa la nuova versione | apri il sito web |
| Fornitore (catalogo Homebrew) | Confronto tra le versioni | scarica dal sito del produttore e installa | apri il sito web |

## Sicurezza durante l’installazione (diretta)
Un download sostituisce un’app solo se il **checksum** corrisponde, la **firma dello sviluppatore** è la stessa dell’app installata e **Gatekeeper** dà il via libera. La versione precedente finisce nel Cestino. Le app in esecuzione vengono chiuse dopo aver chiesto conferma e riaperte in seguito.

## Come si usa
- Una alla volta con "Aggiorna", oppure più app contemporaneamente utilizzando **le caselle di selezione** e "**Aggiorna** quelle selezionate".
- Il menu ⋯ nasconde un aggiornamento.
- “Aggiornate” e “Impossibile verificare” elencano le altre app; le app web di Safari non hanno aggiornamenti.

> Le app provenienti da installer .pkg aprono il programma di installazione di macOS; completa l’installazione da lì.
