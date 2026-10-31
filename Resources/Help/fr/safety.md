# Sécurité : Corbeille, suppression, journal

## Rien ne se fait sans votre confirmation
Chaque section affiche d’abord une liste. Avant toute suppression, une **fenêtre de vérification** répertorie toutes les entrées et leurs conséquences ; seules les options « Supprimer » ou « Placer dans la Corbeille » entraînent une modification.

## Corbeille ou suppression définitive ?
|  | Corbeille | Définitivement |
|---|---|---|
| Peut être restauré | Oui, jusqu’à ce qu’il soit vidé (« Remettre » dans le Finder) | non |
| Espace libéré | après le vidage | immédiatement |
| Utilisé par | Désinstaller, Stockage, Programme d’installation, Alléger, Nettoyer (en option) et Projets | En option : Nettoyer et Projets |

Les fonctions « Nettoyer » et « Projets » suppriment définitivement par défaut, car les caches et les dossiers de compilation sont de toute façon recréés. Choisissez la Corbeille comme option par défaut dans Réglages → Comportement.

## Vérifié à plusieurs reprises
- La suppression s’effectue uniquement dans votre dossier de départ (et, pour les applications, dans le dossier « Applications »).
- Les liens symboliques ne sont jamais suivis ; la présence d’un lien dans le chemin d’accès interrompt la suppression.
- Juste avant chaque suppression, Swabr vérifie à nouveau : l’élément existe-t-il toujours ? A-t-il été protégé entre-temps ?
- Les fichiers iCloud non téléchargés ne sont jamais téléchargés ni comptés.

## Journal
Chaque action est consignée avec l’heure, le chemin d’accès et la taille. Vous les trouverez dans l’**Historique**.
