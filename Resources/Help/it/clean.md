# Pulisci

Pulisci individua i dati che le app e macOS ricreano quando necessario: cache, log, file temporanei, cache del browser e degli sviluppatori e residui di app disinstallate. Swabr funziona con due tipi di regole:
- **Regole specifiche** per browser, strumenti di sviluppo (Xcode, Homebrew, npm, pip, Cargo, Gradle …) e alcune app i cui dati si trovano più in profondità.
- **Regole generali** che seguono le convenzioni delle cartelle di macOS: tutto ciò che si trova in `~/Library/Caches`, le cartelle di cache di Chromium in ogni app Electron (Slack, Discord, VS Code, Obsidian…), cache, log e file temporanei nei container delle app. In questo modo vengono coperte anche le app che nessun elenco conosce.

Ogni regola ha il proprio tipo (cache, log, pacchetti, build…) e il proprio livello di priorità. Le regole specifiche hanno la precedenza su quelle generali.

## Come funziona
- **Avvia scansione:** Swabr si limita a dare un’occhiata, non cambia nulla.
- **Controlla l’elenco:** a sinistra ci sono le categorie e le loro dimensioni, a destra le voci della categoria scelta con la valutazione, la dimensione e l’effetto. La casella davanti a una categoria seleziona tutto ciò che ne fa parte; espandi una riga per vedere i relativi percorsi.
- **Nel Cestino:** **clicca **sul pulsante in basso a destra, poi conferma nella finestra di conferma. Se l’opzione “Elimina definitivamente” è attiva, il pulsante si chiama “Pulisci” ed elimina immediatamente.
- **Fatto:** la pagina finale mostra quanto spazio è stato liberato, suddiviso per categoria, e lo spazio libero prima e dopo.

## Sicuro o Verifica
| Livello | Significato | Preselezionati |
|---|---|---|
| **Sicuro** (verde) | Cache, log o dati temporanei che vengono ricreati | sì |
| **Da verificare** (arancione) | Potrebbero contenere dati che vuoi conservare o che richiedono molto tempo per essere scaricati di nuovo: Cestino, allegati di Mail, stati delle finestre, cache di macOS, download di grandi dimensioni come Gradle o Playwright | no |

«Consigliati» seleziona solo le voci sicure, «Tutti» seleziona tutto, «Nessuno» non seleziona nulla.

## Voci ignorate
- **"È in esecuzione":** le cache di un’app aperta non vengono modificate (ad es. Chrome, Slack, VS Code). Questo vale anche per le regole generali: Swabr riconosce l’app dal nome della cartella o dall’ID bundle. Chiudi l’app ed esegui nuovamente la scansione.
- **Scudo verde:** la voce è protetta (vedi “Dati protetti”) o si trova in un’area bloccata.

## Categorie speciali
- **Resti delle app rimosse:** cache, log e stati delle finestre delle app non più installate e rimasti invariati per 30 giorni (tempo regolabile). Sono esclusi i gestori di password, il portachiavi e i dati SSH.
- **Set di dati di grandi dimensioni (solo come suggerimento):** backup iOS, Mail, simulatori, Docker, modelli di IA. Swabr non li elimina mai automaticamente, ma ti indica dove pulirli correttamente.

## Non dovrai più pulire mai più
Fai clic con il tasto destro su una voce → **“Non pulire mai”** la protegge in modo permanente. Annulla da Impostazioni → Dati protetti.

Questo vale anche per tutto ciò che la stessa regola individua in seguito. Nell’elenco espanso, fai clic con il tasto destro su una posizione per proteggere solo quella, tutto ciò che riguarda una singola app o tutte le cartelle con quel nome. Subito dopo, clicca su **“Annulla”** nella barra sopra l’elenco per rimuovere la protezione.

## Cosa cambia dopo?
Le app ricreano le loro cache; il primo avvio o il primo caricamento di una pagina potrebbero richiedere un po’ più di tempo. Accessi, documenti, impostazioni e segnalibri rimangono invariati.
