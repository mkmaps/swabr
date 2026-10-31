# Dépannage

## « Accès complet au disque manquant » bien qu’il soit autorisé
macOS lie l’accès à la signature de l’application. Après une mise à jour ou le déplacement de l’application : supprimez l’entrée à l’aide du signe « **−** », ajoutez à nouveau Swabr, puis redémarrez.

## Une application ne peut pas être supprimée
- **Symbole de la clé :** l’application appartient au système. macOS vous demande votre mot de passe ; si le message « Annulé » s’affiche, réessayez simplement.
- **« Swabr n’est pas autorisé à contrôler le Finder »:** Réglages Système → Confidentialité et sécurité → Automatisation → Swabr → activez le Finder.

## Certaines entrées sont ignorées
« est en cours d’exécution » : fermez l’application et relancez l’analyse. Bouclier vert : protégé, voir « Données protégées ».

## Les routes DNS ou réseau ont été « ignorées »
Lorsqu’un VPN est actif, Swabr ignore délibérément ces deux éléments.

## La section « Stockage » affiche un « + » après les tailles
Certains dossiers étaient illisibles ou leur analyse a dépassé le délai imparti. Vérifiez l’Accès complet au disque ou augmentez le délai imparti dans Réglages → Comportement.

## Aucune mise à jour n’apparaît
Activez les infos en ligne (Réglages → Général). Les applications dont la source est inconnue sont répertoriées sous « Impossible de vérifier ».

## Un élément supprimé par erreur
Les éléments placés dans la Corbeille peuvent être restaurés dans le Finder. Ce qui a été supprimé définitivement était un dossier de cache ou de compilation, qui est recréé. L’historique indique ce qui a été supprimé et à quelle date.
