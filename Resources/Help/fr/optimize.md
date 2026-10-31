# Optimiser

Optimiser exécute des tâches de maintenance pour macOS. Les étapes superflues sont ignorées, avec justification.

## Utilisation
- Sélectionnez les tâches à l’aide **des cases à cocher** ; utilisez les boutons « Tout sélectionner/Tout désélectionner » en haut à droite. Swabr mémorise les tâches non cochées.
- Chaque tâche décrit ce qu’elle fait et les changements qui en découlent. Orange : effet secondaire perceptible.
- **Mot de passe :** les tâches nécessitant des droits d’administrateur s’exécutent en une seule fois ; le mot de passe n’est demandé qu’une seule fois. L’annulation ne fait que sauter ces tâches.

## Les tâches
| Tâche | Que se passe-t-il ? | Mot de passe |
|---|---|---|
| Aperçus QuickLook | Réinitialiser le cache des vignettes de QuickLook | non |
| États des fenêtres | Supprimer les fenêtres enregistrées datant de plus de 30 jours, sauf pour les applications en cours d’exécution | non |
| Préférences corrompues | déplacer les fichiers de préférences tiers endommagés vers la Corbeille | non |
| Cache DNS | vider le cache de résolution des noms (ignoré si un VPN est actif ou si vous êtes hors ligne) | oui |
| Itinéraires réseau | vider la table de routage et renouveler les adresses via DHCP, uniquement si toutes les interfaces utilisent DHCP (brève interruption) | oui |
| .DS_Store | Aucun fichier du Finder sur les disques réseau et USB | non |
| Anciens paramètres de réglage | App Nap et vérification des images : retour aux paramètres par défaut | non |
| Autorisations | Réinitialisez les autorisations dans votre dossier de base, uniquement si un problème survient (cela ne prend que quelques minutes) | oui |
| Index Spotlight | Vérifier l’état, reconstruire uniquement en cas d’erreurs ou lorsque l’indexation est désactivée | oui |
| Exclusions Spotlight | signaler les exclusions dont l’emplacement n’existe plus ; lit les réglages avec des droits d’administrateur, ne modifie rien | oui |
| Maintenance périodique | uniquement les périodes arrivées à échéance ; cette fonctionnalité n’existe plus depuis macOS 26 | oui |
| Barre latérale et historique récent | déplacer les listes illisibles de la barre latérale et des éléments récents dans la Corbeille | non |
| Vérifier le volume de démarrage | Vérifier le système de fichiers, cela ne change rien | non |
| Ouverture | Signaler les entrées dont le programme est manquant | non |
| Historique des téléchargements | Effacer l’historique des téléchargements de Gatekeeper (confidentialité) | non |
| Services en arrière-plan | signaler les services dont le programme est manquant | non |
| Notifications | Supprimer les notifications livrées datant de plus de 30 jours | non |
| Bases de données | compacter les bases de Mail, Safari et Messages (seulement si l’app est fermée, la base intacte et < 100 Mo) | non |

## Édition App Store
Dans cette version, seules les tâches pouvant être effectuées dans votre dossier de départ sans droits d’administrateur sont disponibles : états des fenêtres, préférences corrompues, barre latérale et historique récent, historique des téléchargements et services en arrière-plan.
