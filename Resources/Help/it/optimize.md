# Ottimizza

Ottimizza esegue operazioni di manutenzione per macOS. I passaggi non necessari vengono saltati, spiegandone il motivo.

## Come usarla
- Seleziona le attività con **le caselle di controllo**; "Seleziona tutto/Niente" in alto a destra. Swabr ricorda le attività non selezionate.
- Ogni attività descrive cosa fa e quali cambiamenti comporta. Arancione: effetto collaterale evidente.
- **Password:** le attività che richiedono i diritti di amministratore vengono eseguite tutte insieme; la password ti viene richiesta una sola volta. Annullando l’operazione, vengono saltate solo quelle attività.

## Le attività
| Attività | Cosa succede | Password |
|---|---|---|
| Anteprime QuickLook | ripristina la cache delle miniature di QuickLook | no |
| Stati delle finestre | rimuovi le finestre salvate più vecchie di 30 giorni, non per le app in esecuzione | no |
| Preferenze danneggiate | sposta i file di preferenze di terze parti danneggiati nel Cestino | no |
| Cache DNS | Svuota la risoluzione dei nomi (viene saltata se hai una VPN attiva o quando sei offline) | sì |
| Percorsi di rete | svuota la tabella di routing e aggiorna gli indirizzi tramite DHCP, solo se tutte le interfacce usano il DHCP (breve interruzione) | sì |
| .DS_Store | nessun file del Finder su unità di rete e USB | no |
| Vecchi parametri di ottimizzazione | App Nap e verifica delle immagini riportati ai valori predefiniti | no |
| Autorizzazioni | ripristina i permessi nella tua cartella home, solo se c’è qualcosa che non va (ci vogliono pochi minuti) | sì |
| Indice Spotlight | controlla lo stato, ricostruisci solo in caso di errori o quando l’indicizzazione è disattivata | sì |
| Esclusioni da Spotlight | segnala le esclusioni la cui posizione non esiste più; legge le impostazioni con i diritti di amministratore, non modifica nulla | sì |
| Manutenzione periodica | solo le voci in scadenza; non più presenti a partire da macOS 26 | sì |
| Barra laterale e elementi recenti | sposta nel Cestino le liste della barra laterale e degli elementi recenti illeggibili | no |
| Verifica il volume di avvio | controlla il file system, non cambia nulla | no |
| Elementi login | segnala le voci il cui programma è mancante | no |
| Cronologia dei download | Cancella la cronologia dei download di Gatekeeper (privacy) | no |
| Servizi in background | segnala i servizi il cui programma è mancante | no |
| Notifiche | elimina le notifiche consegnate più vecchie di 30 giorni | no |
| Database | Compatta Mail, Safari, Messaggi (solo se chiusi, integri e con meno di 100 MB) | no |

## Versione App Store
Qui sono disponibili solo le operazioni che funzionano nella tua cartella home senza diritti di amministratore: stati delle finestre, preferenze danneggiate, barra laterale e elementi recenti, cronologia dei download e servizi in background.
