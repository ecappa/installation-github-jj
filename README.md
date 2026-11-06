# installation-github-jj (developpement)

Script Windows qui installe Git, GitHub CLI et Jujutsu, connecte le compte GitHub et configure le tout, pour des utilisateurs non techniques. Le mode d'emploi utilisateur est dans [`src/README.md`](src/README.md).

## Etat au 2026-11-06

- Premier vrai lancement reussi le 2026-11-05 dans la VM Windows `ecosai-win` (minis) : git, gh et jj installes, connexion GitHub, depot cree, clone et push jj verifies. Trace : `recette/20261105-vm-minis/`.
- GitHub Desktop retire de l'installation (785682d).
- Lancement en une ligne ajoute : `install.ps1` (voir plus bas), essaye dans la VM le 2026-11-06 en essai a blanc, en refus au demarrage et avec une mauvaise adresse.
- `tests/run-all.ps1` (lanceur des 289 verifications simulees et construction de `build/`) n'a jamais ete versionne et reste introuvable : les tests automatiques ne peuvent pas etre relances depuis ce depot. `run-case.ps1`, `stub.ps1` et `console-check.ps1` sont les seules pieces presentes.

## Lancer sur un PC

Dans Windows PowerShell, sans « Executer en tant qu'administrateur » :

```powershell
irm https://raw.githubusercontent.com/ecappa/installation-github-jj/main/install.ps1 | iex
```

`install.ps1` telecharge `src/setup-github-jj.ps1`, verifie qu'il est complet, l'enregistre dans `%LOCALAPPDATA%\InstallationGitHubJJ\script\` (un fichier par lancement, efface a la fin) en UTF-8 avec BOM et le lance dans un processus a part, comme `Installer.cmd`. Il marche meme avec la politique d'execution `Restricted`. Essai a blanc :

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ecappa/installation-github-jj/main/install.ps1))) -DryRun
```

L'adresse ne marche que si le depot est public. Pour un essai depuis un autre serveur, `INSTALLATION_GITHUB_JJ_URL` remplace l'adresse du dossier `src/`.

Autre voie : copier `src/` sur le PC et double-cliquer sur `Installer.cmd`.

## Arborescence

| Dossier | Contenu |
|---|---|
| `src/` | Sources : `Installer.cmd`, `setup-github-jj.ps1`, `README.md` |
| `install.ps1` | Lancement en une ligne (`irm ... \| iex`) |
| `tests/` | `run-case.ps1`, `stub.ps1` (faux winget/gh), `console-check.ps1` ; `run-all.ps1` manquant |
| `recette/` | Recettes reelles et revues |

## Lancer les tests

Le lanceur `tests/run-all.ps1` manque (voir l'etat ci-dessus). Pour le reecrire : il construisait `build/` (BOM UTF-8 pour PowerShell 5.1, fins de ligne CRLF), puis lancait chaque cas dans un bac a sable sous `boxes/` avec `run-case.ps1` et les faux outils de `stub.ps1`. Les tests ont besoin des versions portables des outils, hors du depot (225 Mo) :

- `tools/mingit/` : MinGit 64 bits (https://github.com/git-for-windows/git/releases), `tools/mingit/cmd/git.exe`
- `tools/gh/` : GitHub CLI zip Windows (https://github.com/cli/cli/releases), `tools/gh/bin/gh.exe`
- `tools/jj/` : Jujutsu zip Windows (https://github.com/jj-vcs/jj/releases), `tools/jj/jj.exe`

En attendant, la preuve est la recette reelle dans une VM Windows (`recette/`).
