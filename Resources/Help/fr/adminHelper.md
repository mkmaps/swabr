# Droits d’administrateur (service d’assistance)

## De quoi s’agit-il ?
Certaines étapes nécessitent des droits d’administrateur : la suppression d’applications appartenant au système, certaines optimisations telles que le vidage du cache DNS, ainsi que la lecture des éléments d’ouverture que les applications ont elles-mêmes enregistrés. Sans le service d’assistance, macOS vous demande votre mot de passe à chaque fois.

**Le service d’assistance** de Swabr prend en charge ces étapes une fois que vous l’avez autorisé. Il n’accepte que les requêtes provenant de Swabr signées avec le même certificat de développeur et se ferme après cinq minutes d’inactivité. Il n’est disponible que dans l’édition Direct.

## Comment le configurer
### 1. Configurez-le dans Swabr
Ouvrez **Swabr → « Réglages » → « Comportement »** et cliquez sur « **Configurer… »** dans la section « **Droits d’administrateur** ».

![](images/helfer-1-einstellungen.png)

### 2. Autorisez-le dans les Réglages Système
Sous macOS, ouvrez «**Réglages Système** » **→ « Général » → « Ouverture** ». Dans la section « **Activité en arrière-plan des applications** », activez **Swabr** et confirmez à l’aide de votre mot de passe ou de Touch ID.

![](images/helfer-2-anmeldeobjekte.png)

### 3. Terminé
De retour dans Swabr, la section « **Droits d’administrateur** » indique « Configuration : plus besoin de mot de passe ». Désormais, ces étapes s’exécutent sans demande de mot de passe.

> Si le message « En attente de votre autorisation dans les Réglages Système » s’affiche, l’étape 2 n’a pas encore été effectuée. L’icône **en** **forme** **’engrenage** située à côté vous y mènera directement.

## Quels changements en découlent ?
- **Apps → Démarrage** affiche également les applications qui s’enregistrent automatiquement (par exemple avec l’option « Ouvrir à la connexion » dans l’application).
- Les fonctions « **Désinstaller** », « **Optimiser** » ainsi que les étapes nécessitant des droits root dans les rubriques « **Nettoyer** », « **Projets** », « **Programmes d’installation** » et « **Alléger** » ne vous demandent plus le mot de passe.
- Les contrôles de sécurité restent inchangés : tous les verrouillages mis en place s’appliquent toujours, et chaque étape est vérifiée et consignée.

## Supprimer
Cliquez sur **« Supprimer »** dans « **Réglages** » **→ « Comportement » → « Droits d’administrateur** ». Swabr vous demandera alors à nouveau le mot de passe à chaque étape.
