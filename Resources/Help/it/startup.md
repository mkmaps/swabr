# Avvio: elementi login e servizi

## Apri al login (Diretto)
Ogni app installata ha un interruttore **«Apri al login**». macOS apre le app attivate dopo che hai effettuato l’accesso. L’interruttore più piccolo **«Nascosta»** le avvia senza finestra. È lo stesso elenco che trovi in Impostazioni di Sistema → Generali → Elementi login; Swabr lo controlla tramite «Eventi di sistema» (macOS chiede l’autorizzazione una sola volta).

## Servizi in background
Di seguito (espandibile) trovi gli aggiornamenti e gli strumenti di supporto che le app configurano autonomamente (LaunchAgents/LaunchDaemons):
- **I tuoi servizi** (nella tua cartella Home): consenti/blocca l’avvio, rimuovi (Cestino).
- **Servizi a livello di sistema:** solo visualizzazione; modificali nelle Impostazioni di Sistema. Eccezione: se il programma corrispondente è mancante, **“Rimuovi…”** li elimina (macOS ti chiederà la password).
- **«Programma mancante»:** il servizio punta a un’app cancellata e non fa più nulla – puoi eliminarlo.

## Rimozione delle voci orfane
Gli elementi login e i servizi la cui app non è più installata sono contrassegnati in arancione con **la dicitura «Programma mancante**».
- Per un elemento login, **“Rimuovi dall’elenco”** elimina la voce dagli elementi login.
- In basso a destra, **"Rimuovi gli orfani (numero) …"** li elimina tutti in una volta, dopo aver chiesto conferma con l’elenco dei nomi.
- I file di servizio finiscono nel Cestino e possono essere ripristinati da lì. Swabr rimuove i servizi di sistema solo se il programma corrispondente è stato effettivamente disinstallato.

## Versione App Store
L’edizione App Store non può né controllare gli eventi di sistema né avviare o arrestare servizi. Mostra i tuoi servizi in background e può rimuoverli; gestisce gli Elementi login tramite il pulsante che porta alle Impostazioni di Sistema.
