# Versione Direct e App Store

Swabr è disponibile in due edizioni basate sullo stesso codice. Puoi vedere quale hai in Impostazioni → Generali e in "Informazioni".

|  | Diretto | App Store |
|---|---|---|
| Distribuzione | GitHub (DMG) | Mac App Store |
| Accesso | L'intera cartella Home con "Accesso completo al disco" | solo le cartelle che consenti l’accesso a esse |
| Pulisci, disinstalla | sì | sì, dopo aver consentito l’accesso |
| App di proprietà del sistema | sì (Finder ti chiederà la password) | sì (macOS ti chiederà la password) |
| File di sistema in /Library | sì | Sì, dopo aver consentito l’accesso a /Library |
| Ottimizza | tutte le 19 attività | 5 operazioni senza diritti di amministratore |
| Aggiornamenti | Si aggiorna automaticamente | mostra gli aggiornamenti, apre l’App Store o il sito web del produttore |
| Avvio | gestisci gli elementi login e i servizi | Visualizza e rimuovi i tuoi servizi in background |
| Alleggerisci | sì | no |

## Perché la versione App Store offre meno funzionalità
Apple richiede una **sandbox** per l’App Store: le app possono accedere solo alle cartelle consentite, non possono richiedere diritti di amministratore, non possono installare o modificare altre app e non possono controllarle (Linee guida per la revisione dell’App Store 2.4.5 e 2.5.2). Swabr rispetta queste regole e offre tutto ciò che è consentito.

## Consenti le cartelle (versione App Store)
La prima volta che apri Pulisci, Ottimizza o App, compare il messaggio “Consenti l’accesso”. Clicca su “Consenti…”; la finestra di dialogo mostra già la cartella giusta, devi solo confermare. Le autorizzazioni vengono memorizzate e possono essere revocate in Impostazioni → Accesso.

## Versione Direct e codice sorgente
Swabr è un software libero con licenza MIT. La versione Direct e il codice sorgente completo sono disponibili gratuitamente su GitHub; il link si trova in Impostazioni → Informazioni.
