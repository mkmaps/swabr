# Désinstallation d’applications

Glisser une application dans la Corbeille ne supprime pas toutes ses données : caches, réglages, services en arrière-plan et parfois fichiers système. Swabr détecte ces résidus.

## Fonctionnement
- Sélectionnez les applications à gauche à l’aide de la **case à cocher** (plusieurs choix possibles). Les informations et tous les fichiers détectés s’affichent à droite.
- **Désinstaller…** ouvre la fenêtre de récapitulatif présentant toutes les conséquences.
- Les applications en cours d’exécution sont d’abord fermées. Tout est envoyé dans l’**Corbeille**.

## Qu’est-ce qui est supprimé ?
| Groupe | Exemples | Présélectionnées |
|---|---|---|
| **Sera supprimé** | application, caches, journaux, état de la fenêtre, agents de lancement | oui |
| **Données personnelles** | paramètres, conteneurs, comptes, bibliothèques | non |
| **Sensibles** | Profils de navigateur (mots de passe, historique), données des groupes d’applications | jamais automatiquement |
| **Fichiers système** | fichiers dans /Library, services système, outils d’aide | non, mot de passe requis |

Les données personnelles sont conservées par défaut ; vos réglages et comptes sont ainsi restaurés si vous réinstallez l’application. « Tout supprimer aussi » les sélectionne. Modifiez le paramètre par défaut dans Réglages → Comportement.

## À propos de l’application
La section « Informations » affiche le développeur (d’après la signature), la catégorie, la version, la dernière utilisation et, si des infos en ligne sont disponibles, une description ainsi que des liens vers le site web, l’App Store et les résultats de recherche sur Internet. Cela vous aide à identifier les applications inconnues avant de les supprimer.

## Symboles
- **Cadenas :** protégé (composant système, logiciel de sécurité doté de son propre programme pour désinstaller, Swabr lui-même).
- **Clé :** appartient à un autre utilisateur ou au système ; macOS vous demande votre mot de passe lors de la suppression.

## Homebrew
Les applications installées via Homebrew sont désinstallées à l’aide de la commande `brew uninstall`, ce qui permet à Homebrew de rester synchronisé.
