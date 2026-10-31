# Données protégées (liste blanche)

La liste accessible sous Réglages → **Données protégées** définit ce que Swabr **ne** modifie **jamais** lors du nettoyage, même si une règle l’inclurait normalement. D’autres outils appellent cela une «liste blanche».

## Comment lire la liste
- **Activé = protégé.** L’entrée n’apparaît plus dans « Nettoyer », ou s’affiche avec un bouclier vert.
- **Désactivé = peut être supprimé** si une règle pour nettoyer l’inclut.
- **La mention « Par défaut »** indique les éléments protégés par défaut (caches Gradle, navigateurs Playwright, modèles Hugging Face).
- Chaque entrée indique l’espace qu’elle occupe actuellement, ce qui vous permet de voir ce que coûte sa protection.

## Quand protéger
Protégez les données qui sont recréées mais dont la reconstitution prend du temps ou consomme beaucoup de volume de données : les fichiers DerivedData d’Xcode d’un gros projet, les caches Gradle, les modèles d’IA téléchargés, les téléchargements Homebrew sur une connexion lente.

## Vos propres entrées
Sous « Vos entrées », vous pouvez protéger n’importe quel dossier ou fichier :
- **L’option « Choisir un dossier… »** ouvre une boîte de dialogue ; le dossier sélectionné est alors protégé.
- Vous pouvez également saisir un **motif**. Vous verrez immédiatement en dessous le nombre d’éléments correspondants.

| Modèle | Protège |
|---|---|
| `~/Library/Caches/Foo` | exactement ce dossier |
| `~/Library/Caches/Foo/*` | tout ce qui se trouve dans ce dossier (ainsi que le dossier lui-même) |
| `~/Library/Caches/Foo*` | tous les dossiers commençant par « Foo » |

« ~ » correspond à votre dossier personnel, « * » à n’importe quel caractère.

## Règles de sécurité
Certaines entrées sont toujours protégées et ne peuvent pas être désactivées : les caches contenant l’état de synchronisation iCloud, la connexion au compte Apple, Wallet, Home, les polices, Spotlight ou les téléchargements en arrière-plan en cours, ainsi que le cache propre à Swabr. De plus, iCloud Drive, le trousseau, le dossier Documents, le Bureau et tout ce qui se trouve en dehors de votre dossier d’accueil sont toujours hors de portée.

## Emplacement et réinitialisation
La liste est stockée dans `~/.config/swabr/whitelist` (un motif par ligne). Dès que vous effectuez une modification, ce fichier remplace la liste par défaut ; l’option « Réinitialiser aux valeurs par défaut » le supprime à nouveau.
