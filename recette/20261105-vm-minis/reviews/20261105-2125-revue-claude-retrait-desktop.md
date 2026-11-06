# Revue Claude - retrait de l'option GitHub Desktop

Verdict : **OK sur le périmètre.** Un seul constat mineur, non bloquant (variable morte).

Objet : `git diff 7e47eab 785682d` (`src/setup-github-jj.ps1` -28 lignes, `src/README.md` 1 ligne). Lecture statique du fichier à 785682d (`git show 785682d:src/setup-github-jj.ps1`, 1203 lignes). Rien exécuté, aucun fichier du dépôt modifié. Revue GLM non lue.

## 1. Références restantes à Desktop

- `git grep -i desktop 785682d` sur tout le dépôt (hors `recette/`, absent de ce commit) : une seule occurrence, `src/setup-github-jj.ps1:468`, `Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`. C'est le paquet App Installer qui active winget, sans rapport avec GitHub Desktop : à garder.
- Plus aucun `desktopChoice`, `desktopDone`, `Install-Desktop` ni `GitHub.GitHubDesktop` dans le code, l'état, le plan à blanc, `src/README.md`, `README.md`, `Installer.cmd` ou `tests/`.

## 2. Branche winget retirée

- `$script:WingetReady` est écrit à `:498` (`$false` dans `Invoke-Preflight`) et à `:453` (`$true` dans `Add-WingetVersionCheck`), mais n'est plus **lu** nulle part (`rg -n WingetReady`). Rien ne dépendait de lui hors Desktop : `Install-Tool` (`:646`), la reprise et `Show-DryRunPlan` (`:1070`) ne le consultent pas. Pas de variable lue non initialisée.
- La décision d'installer et le contrôle de version winget restent pilotés par `$script:NeedInstall` (`:554-567`) puis `Invoke-WingetCheck` (`:584-586`) : chemin inchangé, celui validé en VM.
- Structure : `if ($script:NeedInstall) { Invoke-WingetCheck }` (`:584-586`) est bien fermé ; le bloc suivant `:588` est intact. Pas de `Set-StrictMode` dans le script, donc aucune lecture de variable absente ne pourrait de toute façon lever d'erreur.
- Effet de bord retiré : quand tous les outils sont prêts, le script n'appelle plus `winget --version`. Aucune perte : cet appel ne servait qu'à Desktop.

**Constat mineur** - `src/setup-github-jj.ps1:453` et `:498`. Scénario : tout lancement. Impact : aucun sur le comportement, mais une variable écrite et jamais lue induit en erreur le prochain lecteur. Correction attendue (facultative) : retirer les deux affectations, ou laisser en l'état si on veut garder le drapeau pour un usage futur.

## 3. Ancien fichier d'état avec desktopChoice

`Read-State` (`:265-281`) part de `New-EmptyState` et ne copie que les propriétés de ce gabarit (`foreach ($p in $state.PSObject.Properties.Name)`). `desktopChoice`/`desktopDone` d'un ancien `progression.json` sont donc ignorés sans erreur ; au premier `Save-State` (`:284`), ils disparaissent du fichier. Un ancien état `desktopChoice=true, desktopDone=false` ne déclenche plus rien. Pas de plantage possible sur ce point.

## 4. Déroulé complet tracé sans Desktop

- **Préliminaires** (`:1132-1158`) : verrou, `-Reset`, `Read-State`, `Invoke-Preflight`, puis à blanc -> `Show-DryRunPlan` et sortie, sinon `Confirm-Start`, activation winget si `WingetToActivate`.
- **1/5** (`:1161-1163`) : `foreach Install-Tool` puis `Complete-Step 'installation'` ; plus d'appel intercalé. Outils déjà prêts : `Install-Tool` sort sur `Ready` sans winget.
- **2/5 à 5/5** (`:1165-1180`) : non touchés par le diff.
- **Reprise** : toutes les étapes se rejouent de façon idempotente, état relu comme au point 3.
- **À blanc** : plan des trois outils puis compte GitHub ; seule la ligne Desktop a disparu, sans variable orpheline.

Aucun autre défaut introduit par le diff. Reste non prouvé : la version modifiée n'a pas tourné en VM ; un passage `-DryRun` puis un lancement réel sur la VM le confirmerait.

FIN
