# Accesso completo al disco

## Di cosa si tratta?
macOS protegge alcuni dati in modo speciale: Mail, Messaggi, Safari, il Cestino, i backup di Time Machine e i dati di alcune app. I programmi vedono queste cartelle solo se concedi loro l’**Accesso completo al disco**. Si tratta di una funzione di sicurezza di macOS, non di qualcosa inventato da Swabr.

## Perché Swabr ne ha bisogno?
Senza di essa, alcune parti del tuo Mac rimangono nascoste:
- **Pulisci:** Cestino, allegati di Mail, cache nei contenitori delle app e anteprime di Messaggi non vengono visualizzati.
- **Spazio su disco:** le cartelle come Mail o Safari vengono misurate con dimensioni troppo piccole o non vengono misurate affatto (c'è un "+" dopo la dimensione).
- **Ottimizzazione:** i database di Mail, Safari e Messaggi e i dati di utilizzo sono fuori dalla portata dell’app.

Swabr funziona anche senza, ma rileva meno elementi.

## Cosa può farci Swabr?
L’accesso consente la lettura e la scrittura. Swabr lo usa solo per le regole che vedi nell’app e cancella solo dopo che hai confermato nella finestra di conferma. I blocchi fissi valgono sempre: iCloud Drive, il portachiavi, Documenti, il Desktop e tutto ciò che è fuori dalla tua cartella Home non vengono mai toccati. Ogni cancellazione viene elencata nella Cronologia.

## Come consentire l’autorizzazione
### 1. Apri Impostazioni di Sistema
Clicca sull’**ingranaggio** nell’avviso arancione di Swabr (o nella finestra al primo avvio). Si aprirà “**Impostazioni di Sistema**”** → “Privacy e sicurezza” → “Accesso completo al disco**”.

### 2. Attiva Swabr
Attiva **Swabr OP.app** e conferma con la tua password o con Touch ID. Se la voce manca, aggiungi Swabr con **il segno +** oppure trascina l’app dal Finder nell’elenco.

![](images/festplattenvollzugriff-1-liste.png)

### 3. Riavvia Swabr
Di solito macOS te lo chiede. L’avviso arancione sparirà.

> Se sposti Swabr o installi una versione appena firmata, macOS potrebbe considerarla come una nuova app. Rimuovi la vecchia voce con **−** e aggiungi di nuovo Swabr.

## Revoca
Disattivala nello stesso elenco. Swabr mostrerà nuovamente l’avviso e funzionerà con un accesso ridotto.

## Versione App Store
L’edizione App Store non utilizza l’Accesso completo al disco, ma le autorizzazioni alle cartelle (vedi “Edizione Direct e App Store”).
