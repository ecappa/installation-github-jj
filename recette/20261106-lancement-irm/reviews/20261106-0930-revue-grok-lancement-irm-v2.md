OK sur le périmètre

Revue v2 légère de `8effe9d..f7dbbdb`, 2026-11-06. Lecture seule. Les quatre points repris sont corrigés. Ctrl+C et le masque UAC ne sont pas rouverts.

| Constat v1 | Statut |
|---|---|
| Relance `src/README.md:41` et `:65` | corrigé |
| Texte fini par `exit $script:ExitCode` | corrigé |
| Un fichier par lancement, effacé, copies > 1 jour | corrigé |
| Adresse remplacée affichée | corrigé |
| Ctrl+C, élévation explicite si EnableLUA = 0 | non repris, sans effet nouveau |

Contrôles

- `src/README.md:41` dit de recoller la ligne, ou de double-cliquer `Installer.cmd` si le dossier a été copié. `:65` vise les deux. Cohérent avec `:19`.
- `install.ps1:43` : `TrimEnd()` retire `\r` et `\n` avant l'ancre `$`. Le dépôt finit par `exit $script:ExitCode` (`src/setup-github-jj.ps1:1209`). LF et CRLF passent. Sans `TrimEnd`, un CRLF final échouerait à cause du `\r`. La conversion CRLF est après (`:49`) et ne rejette pas un fichier déjà accepté.
- `$PID` du parent (`:31`) : deux fenêtres n'écrivent pas le même chemin. `Remove-Item` est dans le `finally` (`:71`), après la fin de `powershell.exe -File` et après la copie de `$LASTEXITCODE` (`:68`). L'enfant lit `$PSScriptRoot` pendant qu'il tourne. Ce dossier reste `%LOCALAPPDATA%\InstallationGitHubJJ\script` : le PID n'est que dans le nom. `src/setup-github-jj.ps1:606` ne correspond pas à `\Users\Public` pour un compte normal, ni à `\Users\PublicEric`. Le marqueur de fin n'est pas ce fichier : les codes de sortie ne changent pas.
- Le nettoyage (`:47-48`) ne retire que les copies de plus d'un jour, pas le fichier de l'autre fenêtre en cours. Une écriture ratée revient avant le lancement (`:56`) : rien de partiel n'est exécuté.
- L'adresse n'est affichée que si la variable est posée (`:24-26`), avant le téléchargement. `README.md:20` décrit le fichier par lancement et l'effacement.

Limite : pas d'exécution PowerShell. L'ancre a été contrôlée sur le texte du dépôt, en LF et en CRLF après `TrimEnd`.

FIN
