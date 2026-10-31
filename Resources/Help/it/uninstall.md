# Disinstallazione delle app

Trascinando un’app nel Cestino, i suoi dati rimangono sul sistema: cache, impostazioni, servizi in background e, a volte, file di sistema. Swabr individua questi residui.

## Come funziona
- Seleziona le app a sinistra con la **casella di spunta** (puoi selezionarne più di una). Le informazioni e tutti i file trovati appaiono a destra.
- **Disinstalla…** apre la finestra di conferma con tutti gli effetti.
- Le app in esecuzione vengono prima chiuse. Tutto finisce nel**Cestino**.

## Cosa viene rimosso?
| Gruppo | Esempi | Preselezionate |
|---|---|---|
| **Verrà rimosso** | app, cache, log, stato delle finestre, agenti di avvio | sì |
| **Dati personali** | impostazioni, container, account, librerie | no |
| **Dati sensibili** | profili del browser (password, cronologia), dati dei gruppi di app | mai automaticamente |
| **File di sistema** | file in /Library, servizi di sistema, strumenti di supporto | no, serve la password |

I dati personali rimangono di default, quindi le impostazioni e gli account tornano se reinstalli l’app. “Rimuovi anche il resto” li seleziona. Modifica l’impostazione predefinita in Impostazioni → Comportamento.

## Informazioni sull’app
La sezione "Informazioni" mostra lo sviluppatore (dalla firma), la categoria, la versione, l'ultimo utilizzo e – se sono disponibili informazioni online – una descrizione e i link al sito web, all'App Store e alla ricerca sul web. Questo ti aiuta a riconoscere le app sconosciute prima di eliminarle.

## Simboli
- **Lucchetto:** protetto (componente di sistema, software di sicurezza con il proprio programma di disinstallazione, Swabr stesso).
- **Chiave:** di proprietà di un altro utente o del sistema; macOS ti chiede la password al momento dell’eliminazione.

## Homebrew
Le app installate con Homebrew vengono rimosse con il comando `brew uninstall`, così Homebrew rimane sincronizzato.
