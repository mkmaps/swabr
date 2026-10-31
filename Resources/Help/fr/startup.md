# Démarrage : ouverture et services

## Ouvrir à la connexion (Direct)
Chaque application installée dispose d’un bouton **« Ouvrir à la connexion** ». macOS ouvre les applications activées après votre connexion. Le petit bouton **« Masquée »** les lance sans afficher de fenêtre. Il s’agit de la même liste que celle accessible via Réglages Systèmes → Générals → Ouverture ; Swabr la contrôle via les « Événements système » (macOS vous demande une seule fois l’autorisation).

## Services d’arrière-plan
Vous trouverez ci-dessous (liste déroulante) les programmes de mise à jour et les outils d’aide que les applications configurent elles-mêmes (LaunchAgents/LaunchDaemons) :
- **Vos services** (dans votre dossier de départ) : autoriser/bloquer le démarrage, supprimer (Corbeille).
- **Services à l’échelle du système :** affichage uniquement ; modifiez-les dans les Réglages Système. Exception : si le Programme correspondant est manquant, **« Supprimer… »** les supprime (macOS vous demande votre mot de passe).
- **« Programme manquant » :** le service pointe vers une application supprimée et ne fait plus rien – il peut être supprimé.

## Suppression des entrées orphelines
Les éléments d’ouverture et les services dont l’application n’est plus installée sont signalés en orange par **la mention « Programme manquant** ».
- Pour un élément d’ouverture, **« Supprimer de la liste »** supprime l’entrée de la liste des éléments d’ouverture.
- En bas à droite, **« Supprimer les orphelins (nombre) … »** les supprime tous d’un seul coup, après vous avoir demandé confirmation à l’aide de la liste des noms.
- Les fichiers de service sont placés dans la Corbeille et peuvent y être restaurés. Swabr ne supprime les services système que si le programme correspondant a bel et bien disparu.

## Édition App Store
La version de l’App Store ne peut ni contrôler les événements système, ni démarrer ou arrêter des services. Elle affiche vos propres services d’arrière-plan et permet de les supprimer ; elle gère l’ouverture via le bouton menant aux Réglages Système.
