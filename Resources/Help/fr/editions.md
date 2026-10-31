# Version Direct et version App Store

Swabr se décline en deux éditions basées sur le même code. Vous pouvez vérifier laquelle vous possédez dans Réglages → Général et dans la section « À propos ».

|  | Direct | App Store |
|---|---|---|
| Distribution | GitHub (DMG) | Mac App Store |
| Accès | L’intégralité du dossier de la maison avec l’Accès complet au disque | uniquement les dossiers que vous autorisez |
| Nettoyer, désinstaller | oui | Oui, après avoir autorisé l’autorisation |
| Applications appartenant au système | Oui (le Finder vous demande votre mot de passe) | Oui (macOS vous demande votre mot de passe) |
| Fichiers système dans /Library | oui | Oui, après avoir autorisé l’accès à /Library |
| Optimiser | les 19 tâches | 5 tâches sans droits d’administrateur |
| Mises à jour | installe les mises à jour automatiquement | affiche les mises à jour, ouvre l’App Store ou le site web de l’éditeur |
| Démarrage | Gérer les ouvertures et les services | Afficher et supprimer vos propres services d’arrière-plan |
| Alléger | oui | non |

## Pourquoi la version App Store offre-t-elle moins de fonctionnalités ?
Apple impose un environnement **sandbox** pour l’App Store : les applications ne peuvent accéder qu’aux dossiers autorisés, ne peuvent pas demander des droits d’administrateur, ne peuvent pas installer ni modifier d’autres applications et ne peuvent pas contrôler d’autres applications (Directives de validation de l’App Store 2.4.5 et 2.5.2). Swabr respecte ces règles et offre toutes les fonctionnalités autorisées par celles-ci.

## Autoriser les dossiers (version App Store)
La première fois que vous ouvrez « Nettoyer », « Optimiser » ou « Applications », le message « Autoriser l’accès » s’affiche. Cliquez sur « Autoriser… » ; la boîte de dialogue indique déjà le dossier approprié, il vous suffit de confirmer. Les autorisations sont mémorisées et peuvent être révoquées dans Réglages → Accès.

## Version Direct et code source
Swabr est un logiciel libre sous licence MIT. La version Direct et le code source complet sont disponibles gratuitement sur GitHub ; le lien se trouve dans Paramètres → À propos.
