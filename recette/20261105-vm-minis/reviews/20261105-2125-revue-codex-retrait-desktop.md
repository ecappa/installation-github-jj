OK sur le périmètre

Revue légère indépendante du diff `7e47eab..785682d`, le 2026-11-05.
Portée : retrait de GitHub Desktop, dépendances winget, reprise et déroulé complet.
Lecture des sources à `785682d` ; aucune consultation de la revue GLM, aucune exécution du script.

Constats bloquants : aucun défaut introduit identifié. Aucune correction requise pour ce retrait.

Contrôles réussis :
- Recherche dans tous les fichiers suivis à `785682d` : aucune occurrence de `GitHub Desktop`, `desktopChoice`, `desktopDone` ou `Install-Desktop`.
- `src/README.md:22` décrit uniquement Git, GitHub CLI et Jujutsu ; le README racine et les tests suivis ne proposent plus Desktop.
- Seule occurrence du mot Desktop : `src/setup-github-jj.ps1:468`, dans `Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`, l'identifiant d'App Installer nécessaire à winget. À conserver.
- `src/setup-github-jj.ps1:498` initialise toujours `WingetReady` à faux ; `:453` peut le passer à vrai. Il ne reste aucune lecture de cette variable : pas de dépendance ni de variable non initialisée créée par le retrait.
- `src/setup-github-jj.ps1:584` garde un bloc `if (NeedInstall)` correctement fermé. L'ancien `elseif` ne préparait que Desktop ; aucune branche restante n'est détachée.
- `src/setup-github-jj.ps1:554` recalcule le besoin des trois outils. Si tous sont prêts, `Install-Tool` retourne avant tout appel winget (`:646`) : winget absent ou ancien n'empêche pas cette poursuite.
- Si un outil manque, est cassé ou trop ancien, `Invoke-WingetCheck` reste appelé (`:585`). Winget présent est contrôlé contre 1.6 (`:443`) ; absent, son activation est planifiée (`:458`), puis effectuée et sa version contrôlée après accord (`:1155`, `:465`). Un contrôle bloquant arrête le parcours.
- Ancien état : `src/setup-github-jj.ps1:258` définit les seuls champs conservés ; `:270` parcourt ces champs, pas ceux du JSON. Des propriétés `desktopChoice`/`desktopDone` supplémentaires sont donc ignorées sans affectation inconnue ; nom, e-mail, login et progression sont conservés. La sauvegarde suivante (`:284`) omet les anciens champs.

Déroulé vérifié par lecture :
1. Entrée : journal, verrou, éventuel Reset, lecture d'état, prévol puis accord (`src/setup-github-jj.ps1:1132`). Refus : sortie 30 ; prévol ou activation bloquants : sortie 20.
2. Étape 1/5 : boucle sur les trois outils, installation/réinstallation/mise à jour selon leur état réel, puis sauvegarde `installation` (`:1161`, `:646`). Aucun appel Desktop entre cette boucle et l'étape suivante.
3. Étape 2/5 : contrôle de la connexion gh, inscription manuelle si nécessaire, connexion/reconnexion et autorisations, puis sauvegarde `compte` (`:1165`, `:786`). Changement de compte : nom et e-mail précédents effacés (`:828`).
4. Étape 3/5 : lecture du profil et des adresses, choix ou reprise du nom/e-mail, écriture de `github-compte.json`, puis sauvegarde `informations` (`:1169`, `:925`).
5. Étape 4/5 : identité Git/jj, branche si absente, lien gh-Git, fins de ligne jj, puis sauvegarde `configuration` (`:1173`, `:993`). Les réglages modifiés après une installation terminée restent protégés (`:973`).
6. Étape 5/5 : connexion gh, accès Git, helper, PATH persistant et dépôt jj temporaire ; `completed` ne passe à vrai qu'après succès (`:1177`, `:1016`). Exceptions : sortie 10 ; marqueur final et code conservés (`:1189`).
7. Reprise après interruption/redémarrage : `stepsDone` informe sans court-circuiter les étapes (`:610`, `:1161`) ; outils et PATH sont redétectés (`:325`). Aucune reprise ne requiert les anciens champs Desktop, ni une valeur sauvegardée de `WingetReady`.
8. Mode à blanc : prévol puis `Show-DryRunPlan` et retour avant accord, activation et étapes réelles (`:1145`). Le plan couvre les trois outils et la suite (`:1070`) ; aucune question Desktop, aucune sauvegarde de progression (`:285`). `-Reset -DryRun` ne supprime pas l'état (`:1139`).

Limite de preuve : la VM Windows 11 du 2026-11-05 validait la version avant retrait (5/5, gh connecté, clone/push jj), selon le mandat. Le parseur PowerShell 5.1 a accepté la version modifiée, selon le mandat ; aucun de ces acquis n'a été refait. Le verdict valide le diff par lecture, sans attester une exécution Windows de `785682d` ; cette exécution reste non acquise.

FIN
