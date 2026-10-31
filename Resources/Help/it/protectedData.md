# Dati protetti (lista bianca)

L’elenco in Impostazioni → **Dati protetti** definisce ciò che Swabr **non** tocca **mai** durante la pulizia, anche se una regola lo includerebbe altrimenti. Altri strumenti lo chiamano “whitelist”.

## Come leggere l’elenco
- **Attivato = protetto.** La voce non compare più in “Pulisci” oppure appare con uno scudo verde.
- **Disattivato = potrebbe essere eliminato** se una regola di pulizia lo include.
- **"Predefinito"** indica le voci protette di default (cache di Gradle, browser Playwright, modelli Hugging Face).
- Ogni voce mostra quanto spazio occupa al momento, così puoi capire quanto costa proteggerla.

## Quando proteggere
Proteggi i dati che vengono ricreati ma richiedono molto tempo o consumano un sacco di volume di dati: i DerivedData di Xcode di un progetto grande, le cache di Gradle, i modelli di IA scaricati, i download di Homebrew con una connessione lenta.

## Le tue voci personalizzate
Alla voce “Le tue voci” puoi proteggere qualsiasi cartella o file:
- **Scegli cartella…** apre una finestra di dialogo; la cartella scelta viene protetta.
- Oppure digita un **modello**. Sotto vedrai subito quanti elementi corrispondono.

| Modello | Protegge |
|---|---|
| `~/Library/Caches/Foo` | esattamente questa cartella |
| `~/Library/Caches/Foo/*` | tutto ciò che si trova in questa cartella (e con essa la cartella stessa) |
| `~/Library/Caches/Foo*` | ogni cartella che inizia con "Foo" |

"~" indica la tua cartella home, "*" qualsiasi carattere.

## Regole di sicurezza
Alcune voci sono sempre protette e non possono essere disattivate: le cache che contengono lo stato di sincronizzazione di iCloud, l’accesso all’account Apple, Wallet, Home, i font, Spotlight o i download in background in corso e la cache di Swabr. Inoltre, iCloud Drive, il portachiavi, Documenti, il Desktop e tutto ciò che si trova al di fuori della tua cartella Home sono sempre off-limits.

## Posizione e ripristino
L'elenco è salvato in `~/.config/swabr/whitelist` (un modello per riga). Non appena modifichi qualcosa, questo file sostituisce l'elenco predefinito; l'opzione "Ripristina impostazioni predefinite" lo cancella di nuovo.
