# Alléger

De nombreuses applications sont « universelles » et contiennent du code pour les Mac Intel et Apple Silicon. Un Mac équipé d’une puce Apple n’en a besoin que d’une partie. Alléger supprime la partie Intel.

## Quelles applications ?
Uniquement les applications signées avec un identifiant de développeur dont vous êtes propriétaire, qui ne proviennent pas de l’App Store ni d’Apple, qui ne sont pas configurées sur « Ouvrir avec Rosetta » et qui ne sont pas en cours d’exécution. Toutes les autres sont répertoriées sous « Ignorés » avec la raison correspondante.

## Est-ce sûr ?
- Chaque application est allégée sur une **copie**.
- La copie ne remplace l’original que si elle conserve son code Apple Silicon, si la signature du code est valide, si elle a été signée par le même développeur et si Gatekeeper donne son accord.
- L’original est envoyé dans la **Corbeille**.

## Conséquences
L’application ne fonctionne alors plus que sur les Mac équipés d’Apple Silicon, ni avec Rosetta, ni sur les Mac Intel. Une mise à jour de l’application rétablit le code Intel. Édition directe uniquement.
