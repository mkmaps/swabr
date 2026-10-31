# Projets

La fonctionnalité « Projets » supprime les dossiers de compilation et de dépendances de vos projets logiciels, par exemple : `node_modules`, `target`, `build`, `dist`, `.venv`, `Pods`, `.build` et 27 autres types.

## Emplacements de recherche
Par défaut : ~/dev, ~/Projects, ~/GitHub, ~/Code et d’autres dossiers courants. Ajoutez les vôtres avec **Ajouter un dossier…** en haut, y compris sur des disques externes. La recherche descend jusqu’à 6 niveaux (réglable).

## Règles de sécurité
- Uniquement les dossiers situés à l’intérieur d’un projet (contenant un fichier `package.json`, `Cargo.toml`, `go.mod`, `Package.swift` ou autres).
- Les dossiers contenant des fichiers suivis par Git ou des fichiers de clés (`*-keypair.json`) ne sont pas supprimés.
- `bin` uniquement dans les projets .NET, `vendor` uniquement avec PHP/Composer.
- Les dossiers utilisés au cours des 7 derniers jours sont signalés et ne sont pas présélectionnés (paramètre réglable).

## Par la suite
Chaque ligne indique comment récupérer le dossier (par exemple, `npm install`, `cargo build`). Par défaut, ils sont supprimés définitivement ; l’option « Placer dans la Corbeille à la place » est disponible.
