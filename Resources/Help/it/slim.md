# Alleggerisci

Molte app sono “universali” e contengono codice sia per i Mac con processore Intel che per quelli con Apple Silicon. Un Mac con chip Apple ne ha bisogno solo in parte. Alleggerisci rimuove la parte relativa a Intel.

## Quali app?
Solo le app firmate con un Developer ID di tua proprietà, non provenienti dall’App Store, non di Apple, non impostate su “Apri con Rosetta” e non in esecuzione. Tutte le altre sono elencate sotto “Saltati” con la motivazione.

## Quanto è sicuro?
- Ogni app viene ottimizzata su una **copia**.
- La copia sostituisce l’originale solo se mantiene il codice per Apple Silicon, la firma del codice è valida, è stata firmata dallo stesso sviluppatore e Gatekeeper dà il via libera.
- L’originale finisce nel **Cestino**.

## Effetti
L’app funziona quindi solo sui Mac con Apple Silicon, non più con Rosetta né sui Mac Intel. Un aggiornamento dell’app riporta il codice Intel. Solo per l’edizione Direct.
