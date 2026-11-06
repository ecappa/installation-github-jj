à corriger

Revue complète du diff `c1497a7..8effe9d` (tête `8effe9d`), 2026-11-06. Lecture seule. Preuves VM du 2026-11-06 non refaites : HTTP local, politique Restricted, UAC désactivé, compte admin — scriptblock `-DryRun`, `irm | iex` réponse n, 404 → E-TELECHARGEMENT. Pas d'installation réelle par cette voie. Dépôt privé : l'URL raw publique est hors revue.

Défaut à corriger avant livraison

1. `src/README.md:41` — la personne a collé la ligne (`:16`), un problème survient, elle suit « Si ça plante ». La consigne dit seulement « Relance `Installer.cmd` », fichier qu'elle n'a pas. `:19` dit de recoller la commande, et `:65` parle encore d'un blocage « malgré `Installer.cmd` ». Les quatre messages du script passent, eux, par `$script:RelaunchHint`. Correction : relancer de la même façon (recolle la ligne, ou `Installer.cmd` si le dossier a été copié).

Remarques

- Intégrité (`install.ps1:39`) : préfixe `<#` et `function Invoke-Main` quelque part. UTF-8 invalide ou page qui ne commence pas ainsi : rejeté (404 VM → E-TELECHARGEMENT). Une coupe dans `Invoke-Main` ne parse pas (E-LANCEMENT). Une coupe après la fonction mais avant l'appel (`src/setup-github-jj.ps1:1196`) ne lance rien, sort 0 sans marqueur : « interrompue » (`install.ps1:66`). Pas d'installation partielle. Proportionné, sans signature : exiger aussi que le texte finisse par `exit $script:ExitCode`. Afficher l'URL utilisée (`install.ps1:24-35`) : un `INSTALLATION_GITHUB_JJ_URL` oublié redirige sans le dire.
- Deux lancements écrivent le même fichier (`install.ps1:42`, `:59`). Le verrou `Local\InstallationGitHubJJ` (`src/setup-github-jj.ps1:1125`) ne protège que le script déjà parsé. Une écriture simultanée peut le tronquer et afficher E-LANCEMENT (« règle de sécurité »). Fenêtre courte, même contenu. Proportionné : un fichier par lancement, le verrou reste.
- Ctrl+C : le parent PowerShell est interrompu aussi, donc `install.ps1:66-70` peut ne pas s'afficher. `finally` (`:61-63`) restaure la variable. L'arrêt est effectif, le marqueur de fin n'est pas écrit.
- `EnableLUA` = 0 masque aussi un « Exécuter en tant qu'administrateur » du même compte : le jeton est toujours élevé. Clé absente, valeur non entière ou lecture refusée : `$script:UacOff` reste faux (`:370-373`), l'avertissement s'affiche. Compte standard : pas élevé, pas d'avertissement. E-PRE-COMPTE (`:523-524`) ne dépend pas de ce drapeau.

Contrôles réussis

- Ce qui tourne : `install.ps1` via `iex`, puis `src/setup-github-jj.ps1` en HTTPS par défaut (`install.ps1:23`). TLS 1.2 ajouté, certificat non court-circuité (`:20`). UTF-8 strict (`:37`). Écriture seulement sous `%LOCALAPPDATA%\InstallationGitHubJJ\script\` (`:25-27`). Téléchargement en échec : `return` dans la fonction (`:48`), l'ancienne copie n'est pas lancée. Enfant `powershell.exe -File` (`:30`, `:52-59`) : `exit` ne ferme pas la fenêtre. `Bypass` couvre Restricted (preuve VM).
- `param()` en tête tient sous `iex` (preuve VM). Arguments en tableau : espaces et accents de `%LOCALAPPDATA%` restent un seul argument. Depuis `pwsh`, le script réel part dans Windows PowerShell 5.1. `$LASTEXITCODE` est copié tout de suite (`:60`). `INSTALLATION_GITHUB_JJ_LANCEUR` est posée avant l'enfant et restaurée dans `finally` ; `$null` retire la variable.
- Mêmes codes que `src/Installer.cmd:20-28` : -1073741510 ou 0 sans marqueur → interrompu ; 0, 10, 20, 30 laissent le script parler ; autre → E-LANCEMENT. Pas de `pause` : la fenêtre est déjà celle de l'utilisateur.
- Quatre messages (`src/setup-github-jj.ps1:432`, `:434`, `:524`, `:531`) : chaînes doubles, hint développé, apostrophe de « d'installation » via `''` (`:52`). `Installer.cmd` ne pose pas la variable : le texte reste le double-clic.
- README racine : remote `ecappa/installation-github-jj`, condition « dépôt public » (`README.md:26`), `run-all.ps1` annoncé manquant et absent, fichiers cités présents. `WingetReady` : plus aucune occurrence dans `src/setup-github-jj.ps1`.

Limite : pas de PowerShell ici. Chemins accentués, `pwsh` et deux fenêtres : lecture seulement.

FIN
