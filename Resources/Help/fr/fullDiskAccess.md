# Accès complet au disque

## De quoi s’agit-il ?
macOS protège certaines données de manière particulière : Mail, Messages, Safari, la Corbeille, les sauvegardes Time Machine et les données de certaines applications. Les programmes ne peuvent accéder à ces dossiers que si vous leur accordez l’**Accès complet au disque**. Il s’agit d’une fonctionnalité de sécurité de macOS, et non d’une invention de Swabr.

## Pourquoi Swabr en a-t-il besoin ?
Sans cela, certaines parties de votre Mac restent masquées :
- **Nettoyer :** la Corbeille, les pièces jointes de Mail, les caches dans les conteneurs d’applications et les aperçus de Messages sont invisibles.
- **Stockage :** la taille des dossiers tels que Mail ou Safari est sous-estimée, voire non indiquée (« + » après la taille).
- **Optimisation :** les bases de données et les données d’utilisation de Mail, Safari et Messages sont hors de portée.

Swabr fonctionne sans cette autorisation, mais détecte moins d’éléments.

## Que peut faire Swabr avec ces autorisations ?
Cet accès autorise la lecture et l’écriture. Swabr ne l’utilise que pour les règles que vous voyez dans l’application et ne supprime rien tant que vous n’avez pas confirmé dans la fenêtre de vérification. Des verrous fixes s’appliquent systématiquement : iCloud Drive, le trousseau, les Documents, le Bureau et tout ce qui se trouve en dehors de votre dossier de départ ne sont jamais modifiés. Chaque suppression est répertoriée dans l’Historique.

## Comment l’autoriser
### 1. Ouvrez les Réglages Système
Cliquez sur l’icône **en** **forme** **de** **roue dentée** dans la notification orange de Swabr (ou dans la fenêtre lors du premier démarrage). La fenêtre « **Réglages Système » → « Confidentialité et sécurité » → « Accès complet au disque »** s’ouvre.

### 2. Activez Swabr
Activez **Swabr OP.app** et confirmez à l’aide de votre mot de passe ou de Touch ID. Si l’entrée est manquante, ajoutez Swabr à l’aide du **signe** **+** ou faites glisser l’application depuis le Finder vers la liste.

![](images/festplattenvollzugriff-1-liste.png)

### 3. Redémarrez Swabr
macOS vous le demande généralement. La notification orange disparaît alors.

> Si vous déplacez Swabr ou installez une nouvelle version signée, macOS peut la considérer comme une nouvelle application. Supprimez l’ancienne entrée à l’aide de **−** et ajoutez à nouveau Swabr.

## Révocation
Désactivez-la dans la même liste. Swabr affiche à nouveau la notification et fonctionne avec des droits d’accès réduits.

## Édition App Store
La version App Store n’utilise pas l’Accès complet au disque, mais des autorisations de dossier (voir « Version directe et version App Store »).
