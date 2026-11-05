# Installation de GitHub et Jujutsu sur Windows

## Lancer

1. Copie ce dossier sur la machine (extrais-le s'il est dans un ZIP).
2. Double-clique sur `Installer.cmd`. N'utilise pas « Exécuter en tant qu'administrateur ».
3. Suis les instructions à l'écran.

Il faut une connexion internet. Compte 5 à 10 minutes.

### Si Windows bloque le fichier

Vérifie d'abord que le dossier vient d'une personne de confiance. Ensuite :

- **Message « Windows a protégé votre ordinateur » :** clique sur **Informations complémentaires**, puis sur **Exécuter quand même**.
- **Pas de bouton « Exécuter quand même » :** ferme le message. Fais un clic droit sur le fichier ZIP téléchargé, choisis **Propriétés**, coche **Débloquer** en bas, puis clique sur **OK**. Extrais le ZIP à nouveau et relance.
- **Le blocage continue, par exemple avec un message sur « Smart App Control » :** ne désactive pas cette protection. Envoie une capture du message à la personne qui t'a donné le dossier.

## Ce que fait le script

1. **Vérifie la machine** : version de Windows, compte, espace disque, internet et winget. Si quelque chose bloque, il l'explique et s'arrête avant toute installation.
2. **Installe** Git, GitHub CLI et Jujutsu avec winget, et propose GitHub Desktop en option. Avec un compte administrateur, Windows peut demander de cliquer sur « Oui ». Avec un compte standard, ou si tu refuses, les logiciels sont installés pour ce compte uniquement. En continuant, tu acceptes leurs licences.
3. **Ouvre la page d'inscription GitHub** si tu n'as pas de compte. L'inscription se fait à la main : GitHub interdit les comptes créés par un script et autorise un seul compte gratuit par personne.
4. **Connecte ton compte** dans le navigateur. Tu n'as aucun mot de passe à taper dans la fenêtre du script.
5. **Récupère tes infos** et écrit dans `~\github-compte.json` : login, id, nom, adresse du profil et e-mail choisi pour les commits.
6. **Configure** ton nom et ton e-mail dans Git et Jujutsu, puis relie Git à ta connexion GitHub.
7. **Teste le tout** : connexion GitHub, accès de Git à GitHub, lien entre Git et ta connexion, disponibilité des outils dans une nouvelle fenêtre et dépôt Jujutsu temporaire.

## Si ça plante

Relance `Installer.cmd`. Le script revérifie les étapes déjà faites et te propose de garder tes réponses. Chaque erreur indique ce qui s'est passé, pourquoi, quoi faire et un code.

| Fichier | Emplacement |
|---|---|
| Journaux (les 20 derniers) | `%LOCALAPPDATA%\InstallationGitHubJJ\journaux` |
| Progression | `%LOCALAPPDATA%\InstallationGitHubJJ\progression.json` |

Si tu demandes de l'aide, envoie le code de l'erreur et le dernier journal. Il ne contient pas ta clé d'accès GitHub, mais il contient le nom de ton compte Windows, le dossier du script, ton login GitHub, ainsi que le nom et l'e-mail choisis pour tes commits.

## Bon à savoir

- **Compte Windows :** la connexion GitHub et la configuration sont enregistrées pour le compte qui lance le script.
- **Connexion GitHub :** GitHub CLI garde une clé d'accès (un « token ») dans le coffre de Windows. Si ce coffre n'est pas disponible, il l'enregistre dans un fichier non chiffré, et le script te prévient.
- **Autorisations demandées :** en plus de celles de GitHub CLI, `user:email` (lire ton e-mail) et `workflow` (publier des workflows).
- **Réglages existants :** ton nom et ton e-mail Git et Jujutsu sont remplacés par ceux que tu choisis. Une fois l'installation terminée, une relance ne change plus les réglages que tu as modifiés à la main. La branche par défaut n'est réglée que si elle est absente.
- **Dossiers de projet :** avec Jujutsu, garde tes projets dans un dossier court, par exemple `C:\Users\toi\code`. Dans un chemin de plus de 100 caractères environ, Jujutsu peut échouer avec l'erreur `Failed to write index file`.
- **Fins de ligne :** le script ne change pas le réglage de Git. Il aligne Jujutsu dessus, pour tous les dépôts. Jujutsu ignore `.gitattributes` : si un dépôt affiche des fichiers modifiés sans raison, désactive la conversion pour ce dépôt. **Attention :** `jj abandon` jette aussi les vraies modifications en cours. Ne le lance que si les seules différences sont des fins de ligne.

  ```powershell
  git config core.autocrlf input
  jj config set --repo working-copy.eol-conversion none
  jj abandon
  ```

- **PC géré par une entreprise :** une règle de sécurité peut bloquer le script malgré `Installer.cmd`. Dans ce cas, contacte ton service informatique.

## Options

```powershell
# Voir ce qui serait fait : seuls un journal et un petit fichier de fin sont écrits
powershell -ExecutionPolicy Bypass -File .\setup-github-jj.ps1 -DryRun

# Oublier les réponses enregistrées, puis relancer
powershell -ExecutionPolicy Bypass -File .\setup-github-jj.ps1 -Reset
```
