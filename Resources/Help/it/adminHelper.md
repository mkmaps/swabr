# Diritti di amministratore (servizio di supporto)

## Che cos’è?
Alcuni passaggi richiedono i diritti di amministratore: la rimozione di app di sistema, ottimizzazioni come lo svuotamento della cache DNS e la lettura degli Elementi login registrati dalle app stesse. Senza il servizio di supporto, macOS ti chiederà la password ogni volta.

**Il servizio di supporto** di Swabr si occupa di questi passaggi una volta che gli hai dato l’autorizzazione. Accetta solo richieste provenienti da Swabr firmate con lo stesso certificato dello sviluppatore e si chiude dopo cinque minuti di inattività. È disponibile solo nella versione Direct.

## Come configurarlo
### 1. Configuralo in Swabr
Apri **Swabr → Impostazioni → Comportamento** e clicca **su Configura…** nella sezione **Diritti di amministratore**.

![](images/helfer-1-einstellungen.png)

### 2. Autorizzalo nelle Impostazioni di Sistema
Su macOS, apri **Impostazioni di Sistema** → **Generali** → **Elementi login**. Nella sezione **Attività in background delle app****, attiva **Swabr OP** e conferma con la tua password o con Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Fatto
Tornando su Swabr, nella sezione **Diritti di amministratore** c’è scritto "Configurazione: non serve più la password". D’ora in poi questi passaggi verranno eseguiti senza richiedere la password.

> Se compare il messaggio "In attesa della tua autorizzazione nelle Impostazioni di Sistema", il passaggio 2 è ancora mancante. L'icona **a** **forma** di **ingranaggio** accanto ti porta direttamente lì.

## Cosa cambia dopo?
- **App → Avvio** mostra anche le app che si registrano automaticamente (ad esempio con l’opzione “Apri al login” nell’app).
- **Disinstalla**, **Ottimizza** e le operazioni che richiedono i privilegi di root nelle sezioni **Pulisci**, **Progetti**, **Programmi di installazione** e **Alleggerisci** non richiedono più la password.
- I controlli di sicurezza rimangono gli stessi: tutti i blocchi fissi sono ancora attivi e ogni passaggio viene verificato e registrato.

## Rimuovi
Clicca su **Rimuovi** in **Impostazioni → Comportamento → Diritti di amministratore**. Swabr ti chiederà di nuovo la password ad ogni passaggio.
