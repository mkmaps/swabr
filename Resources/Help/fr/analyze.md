# Stockage

La section « Stockage » vous montre où va votre espace – comme une radiographie de votre disque.

## Aperçu
La page d’accueil analyse les emplacements principaux : Accueil (hors Bibliothèque), Bibliothèque, Applications, Bibliothèque système et les éléments typiquement volumineux tels que les sauvegardes iOS, les anciens téléchargements (datant de plus de 90 jours), ainsi que les données Xcode et Docker.

## Utilisation
- **Un double-clic** ouvre un dossier ; la barre de chemin d’accès en haut revient à la page précédente.
- **Liste ou vignettes :** basculez en haut à droite. L’affichage sous forme de vignettes (treemap) présente les tailles sous forme de zones.
- **Fichiers les plus volumineux :** l’icône de document dans la barre d’outils affiche les 20 fichiers les plus volumineux.
- **Coup d’œil :** la barre d’espace affiche un aperçu.
- **Les cases à cocher permettent de** sélectionner les éléments à placer dans la Corbeille.

## Marqueurs
- **« amovible » :** dossiers de compilation ou de dépendances (par exemple, node_modules) qui sont recréés.
- **Taille avec « + » :** au moins cette taille ; certains éléments étaient illisibles (Accès complet au disque ?) ou leur mesure a dépassé le délai imparti (30 secondes, réglable).

## Que se passe-t-il lors de la suppression ?
Les éléments sélectionnés sont placés dans la Corbeille et peuvent être restaurés. La fenêtre de vérification vous avertit concernant les données d’application, les dossiers iCloud et les bibliothèques multimédias. Les dossiers système, votre dossier personnel lui-même et les données des machines virtuelles en cours d’exécution sont verrouillés.

## Remarques
- Les marqueurs de placeholder iCloud ne sont pas téléchargés et sont comptabilisés selon leur taille locale (souvent proche de 0).
- Les autres disques ne sont pas pris en compte.
