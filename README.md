# installation-github-jj (developpement)

Script Windows qui installe Git, GitHub CLI et Jujutsu, connecte le compte GitHub et configure le tout, pour des utilisateurs non techniques. Le mode d'emploi utilisateur est dans [`src/README.md`](src/README.md).

## Etat au 2026-11-05

- Reviews 2, 3 et 4 corrigees et livrees. Review 5 arretee volontairement : plus de boucle de review.
- `tests/run-all.ps1` : 289 verifications simulees reussies, 0 echouee (`tests/result.txt`).
- Version livree sur le PC : `C:\Windows\System32\installation-github-jj` (copie de `build/`).
- **Pas encore lance pour de vrai.** Le compte de test `TestGitHub` a ete supprime.

## Prochaine etape

1. Sur le PC, double-cliquer sur `Installer.cmd` dans le dossier livre : premier vrai lancement.
2. Si quelque chose echoue : noter le code d'erreur (`E-...`) et recuperer le dernier journal dans `%LOCALAPPDATA%\InstallationGitHubJJ\journaux`.
3. Corriger uniquement ce qui a echoue, dans `src/`, puis relancer `tests/run-all.ps1` et recopier `build/` vers le dossier livre.

## Arborescence

| Dossier | Contenu |
|---|---|
| `src/` | Sources : `Installer.cmd`, `setup-github-jj.ps1`, `README.md` |
| `tests/` | `run-all.ps1` (lanceur), `run-case.ps1`, `stub.ps1` (faux winget/gh), `console-check.ps1` |
| `review2.md` | Notes de la review 2 |

## Lancer les tests

Les tests ont besoin des versions portables des outils, hors du depot (225 Mo) :

- `tools/mingit/` : MinGit 64 bits (https://github.com/git-for-windows/git/releases), `tools/mingit/cmd/git.exe`
- `tools/gh/` : GitHub CLI zip Windows (https://github.com/cli/cli/releases), `tools/gh/bin/gh.exe`
- `tools/jj/` : Jujutsu zip Windows (https://github.com/jj-vcs/jj/releases), `tools/jj/jj.exe`

Puis, dans Windows PowerShell 5.1 :

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run-all.ps1            # tout (plus de 10 minutes)
powershell -ExecutionPolicy Bypass -File .\tests\run-all.ps1 -Only nom   # un seul cas
```

`run-all.ps1` construit d'abord `build/` (BOM UTF-8 pour PowerShell 5.1, fins de ligne CRLF), puis lance chaque cas dans un bac a sable sous `boxes/`. `build/` est la version a livrer.

Note : `tests/run-all.ps1` doit garder son BOM UTF-8 (il contient des accents et tourne sous PowerShell 5.1).
