# Nettoyer

Nettoyer identifie les données que les applications et macOS recréent en cas de besoin : caches, journaux, fichiers temporaires, caches de navigateur et de développement, ainsi que les résidus d’applications désinstallées. Swabr fonctionne avec deux types de règles :
- **Règles spécifiques** pour les navigateurs, les outils de développement (Xcode, Homebrew, npm, pip, Cargo, Gradle…) et certaines applications dont les données sont stockées plus en profondeur.
- **Règles générales** respectant les conventions de macOS en matière de dossiers : tout ce qui se trouve sous `~/Library/Caches`, les dossiers de cache de Chromium dans chaque application Electron (Slack, Discord, VS Code, Obsidian…), les caches, les journaux et les fichiers temporaires dans les conteneurs d’applications. De cette manière, les applications qui ne figurent dans aucune liste sont également prises en compte.

Chaque règle est associée à un type (cache, journaux, paquets, version…) et à sa propre note. Les règles spécifiques ont priorité sur les règles générales.

## Comment cela fonctionne-t-il ?
- **Lancer l’analyse :** Swabr se contente d’examiner, rien ne change.
- **Consultez la liste :** les catégories et leurs tailles figurent à gauche, les éléments de la catégorie sélectionnée à droite avec leur note, leur taille et leur effet. La case devant une catégorie permet de tout sélectionner ; développez une ligne pour voir ses chemins d’accès.
- **Vers la Corbeille : cliquez** sur le bouton en bas à droite, puis confirmez dans la fenêtre de vérification. Si l’option « Supprimer définitivement » est activée, le bouton s’intitule « Nettoyer » et la suppression s’effectue immédiatement.
- **C’est terminé :** la page finale indique l’espace libéré, réparti par catégorie, ainsi que l’espace libre avant et après l’opération.

## Sécurisé ou Vérifier
| Niveau | Signification | Présélectionné |
|---|---|---|
| **Sûr** (vert) | Cache, journaux ou données temporaires qui sont recréés | oui |
| **À vérifier** (orange) | peuvent contenir des données que vous souhaitez conserver ou dont le téléchargement prendrait beaucoup de temps : la Corbeille, les pièces jointes de Mail, l’état des fenêtres, les caches propres à macOS, les téléchargements volumineux tels que Gradle ou Playwright | non |

« Recommandés » sélectionne uniquement les entrées sûres, « Tout » sélectionne tout, « Aucun » ne sélectionne rien.

## Entrées ignorées
- **« est en cours d’exécution » :** les caches d’une application ouverte ne sont pas modifiés (par exemple, Chrome, Slack, VS Code). Cela s’applique également aux règles générales : Swabr reconnaît l’application grâce au nom de son dossier ou à son identifiant de bundle. Quittez l’application et relancez l’analyse.
- **Bouclier vert :** l’élément est protégé (voir « Données protégées ») ou se trouve dans une zone verrouillée.

## Catégories spéciales
- **Résidus des applications supprimées :** caches, journaux et états des fenêtres des applications qui ne sont plus installées et qui n’ont pas été modifiés depuis 30 jours (durée ajustable). Les gestionnaires de mots de passe, le trousseau et les données SSH sont exclus.
- **Ensembles de données volumineux (à titre indicatif uniquement) :** sauvegardes iOS, Mail, simulateurs, Docker, modèles d’IA. Swabr ne les supprime jamais automatiquement, mais vous indique où les nettoyer correctement.

## Plus besoin de nettoyer
Cliquez avec le bouton droit sur une entrée → **« Ne jamais nettoyer »** pour la protéger de manière permanente. Annulez cette action dans Réglages → Données protégées.

Cela s'applique également à tout ce que cette même règle détectera par la suite. Dans la liste développée, cliquez avec le bouton droit sur un emplacement pour protéger uniquement cet emplacement, l'intégralité d'une application ou tous les dossiers portant ce nom. Immédiatement après, **la commande « Annuler »** dans la barre située au-dessus de la liste annule la protection.

## Quels sont les changements par la suite ?
Les applications reconstruisent leurs caches ; le premier lancement ou le premier chargement de page peut prendre un peu plus de temps. Les identifiants de connexion, les documents, les paramètres et les signets sont conservés.
