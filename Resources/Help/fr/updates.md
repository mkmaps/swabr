# Mises à jour des applications

Swabr vérifie si de nouvelles versions sont disponibles pour toutes les applications installées. Condition requise : la fonction **infos en ligne** doit être activée (Réglages → Général).

## Sources
| Source | Détection | Édition directe | Édition App Store |
|---|---|---|---|
| Homebrew | `brew outdated` | `brew upgrade` | Ouvrir le site web |
| App Store | Comparaison avec l’App Store | L’App Store ouvre sa page de mises à jour | idem |
| Le canal de mise à jour de l’application (Sparkle) | Appcast du fournisseur | télécharge et installe la nouvelle version | Ouvrir le site web |
| Éditeur (catalogue Homebrew) | Comparaison des versions | Téléchargements depuis le site du fournisseur et installations | Ouvrir le site web |

## Sécurité lors de l’installation (directe)
Un téléchargement ne remplace une application que si la **somme de contrôle** correspond, si la **signature du développeur** est identique à celle de l’application installée et si **Gatekeeper** donne son accord. L’ancienne version est placée dans la Corbeille. Les applications en cours d’exécution sont fermées après confirmation, puis rouvertes par la suite.

## Utilisation
- Une à la fois avec **Mettre à jour**, ou plusieurs à l’aide des **cases à cocher** et de l’option « Mettre à jour la sélection ».
- Le menu ⋯ masque une mise à jour.
- Les rubriques « À jour » et « Impossible de vérifier » répertorient les autres applications ; les applications Web de Safari ne disposent d’aucune mise à jour.

> Les applications provenant de programmes d’installation .pkg ouvrent le programme d’installation de macOS ; terminez l’installation à cet endroit.
