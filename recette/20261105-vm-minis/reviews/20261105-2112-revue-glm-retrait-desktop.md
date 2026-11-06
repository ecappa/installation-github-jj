# Revue du retrait de l'option GitHub Desktop — 2026-11-05 21:12 (GLM)

**Verdict : OK sur le périmètre.** Le diff retire proprement l'option Desktop ; aucun défaut bloquant introduit. Un résidu mineur (variable devenue morte) à considérer au prochain passage.

Périmètre : `git diff` sur `src/setup-github-jj.ps1` (29 lignes retirées) et `src/README.md` (1 ligne). Base 7e47eab. Revue statique uniquement, conformément aux preuves déjà acquises.

## 1. Plus aucune référence à Desktop

`grep -ri "desktop"` sur `src/` ne trouve que `Microsoft.DesktopAppInstaller_8wekyb3d8bbwe` (src/setup-github-jj.ps1:468), le nom de paquet officiel de winget — package renommé en « App Installer », aucun rapport avec GitHub Desktop. Plus aucune trace de `desktopChoice`, `desktopDone`, `Install-Desktop` ni « GitHub Desktop » dans le script ni dans `src/README.md` (la mention « propose GitHub Desktop en option » est retirée de l'étape 2). OK.

## 2. Le retrait de la branche winget ne casse rien

- La structure if/elseif devenue if simple (src/setup-github-jj.ps1:584-586) est valide : `if ($script:NeedInstall) { Invoke-WingetCheck }` sans else, analyse PS 5.1 sans erreur.
- `$script:WingetReady` : encore **écrit** en 453 et 498, mais **plus jamais lu** après le retrait des lectures en 587-590 (branche elseif), 1094 (dry-run) et 1104. Variable morte, initialisée à `$false` en 498 puis `$true` en 453 : pas de « variable non initialisée », aucune lecture ne peut échouer. Résidu de code mort, impact nul.
- `Test-Tool 'winget'` reste utilisé aux lignes 445 et 459 pour la vérification de version winget, indépendante de la branche retirée.
- Installation des trois outils et reprise après redémarrage : boucle `foreach ($tool in $script:Tools)` (ligne 1163) et `Invoke-WingetActivation` (1155) intacts, le retrait ne les touche pas.
- Dry-run : le plan des trois outils (1075-1081) est complet après le retrait de la ligne Desktop (1094-1096 de l'ancienne version) ; le `Write-Host` final « Essai à blanc terminé » suit toujours. OK.

## 3. Ancien fichier d'état avec desktopChoice

`Read-State` (src/setup-github-jj.ps1:265-272) part de `New-EmptyState` et copie **uniquement** les propriétés connues de l'état sauvegardé (`foreach ($p in $state.PSObject.Properties.Name)`), puis `stepsDone` est recasté en tableau. Les propriétés inconnues (`desktopChoice`, `desktopDone` dans un état écrit par l'ancienne version) sont ignorées : pas de plantage, pas de propriété orpheline dans `$script:State`. OK.

## 4. Autres défauts graves introduits par le diff

Aucun. Les 29 lignes retirées forment un bloc cohérent (fonction, propriétés d'état, plan, appel) sans coupure au milieu d'une autre fonction. La suppression de l'appel `Install-Desktop` après la boucle d'installation laisse `Complete-Step 'installation'` (ligne 1164) directement après la boucle. OK.

## À considérer (hors périmètre, non bloquant)

- `$script:WingetReady` (498, 453) est du code mort ; si le dossier doit rester propre, retirer ces deux écritures au prochain passage, avec les éventuelles lectures résiduelles de `WingetMinimum` si elles deviennent orphelines (48 et 449 restent utiles tant que `Add-WingetVersionCheck` existe).
- La version modifiée n'a **pas** été exécutée (seulement analysée par le parseur PS 5.1) ; la validation bout en bout de la 5/5 date de la version antérieure. Éric décide si une reprise partielle de la VM est nécessaire avant le commit.

FIN.