# Sicurezza: Cestino, eliminazione, registro

## Niente senza la tua conferma
Ogni sezione mostra prima un elenco. Prima che qualcosa venga rimosso, una **finestra di conferma** elenca tutte le voci e i relativi effetti; solo "Elimina" o "Sposta nel Cestino" apportano modifiche.

## Cestino o eliminazione definitiva?
|  | Cestino | In modo permanente |
|---|---|---|
| Può essere ripristinato | sì, finché non viene svuotato (“Ripristina” nel Finder) | no |
| Spazio liberato | dopo lo svuotamento | immediatamente |
| Utilizzato da | Disinstalla, Spazio di archiviazione, Programmi di installazione, Alleggerisci, opzionalmente Pulisci e Progetti | Opzionalmente: Pulisci e Progetti |

Le opzioni “Pulisci” e “Progetti” eliminano definitivamente per impostazione predefinita, poiché le cache e le cartelle di compilazione vengono comunque ricreate. Scegli il Cestino come impostazione predefinita in Impostazioni → Comportamento.

## Verificato più volte
- L’eliminazione avviene solo all’interno della tua cartella Home (e, per le app, nella cartella Applicazioni).
- I collegamenti simbolici non vengono mai seguiti; un collegamento nel percorso blocca l’eliminazione.
- Subito prima di ogni eliminazione, Swabr ricontrolla: l’elemento esiste ancora? È stato protetto nel frattempo?
- I segnaposto di iCloud non vengono mai scaricati e non vengono conteggiati.

## Registro
Ogni azione viene registrata con ora, percorso e dimensione. La trovi in **Cronologia**.
