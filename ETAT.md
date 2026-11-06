---
projet: installation-github-jj (clone ~/devRoot/cappasoft/rnd/installation-github-jj, github ecappa/installation-github-jj)
slug: outillage-installeur-github-jj
type: audit
agent: session principale (Claude, onglet Orca term_66d0af5c)
branche: main
mis_a_jour: 2026-11-06 09:35
statut: pret-a-reprendre
tache: t_1a1ae3b56e45e23e1e5
prochaine_action: Rendre le dépôt public (ou héberger install.ps1 ailleurs) pour que irm | iex marche, sur décision d'Éric
---

# État - installeur Git/GitHub CLI/jj

## Objectif
Installeur Windows pour non-techniciens, lancé par double-clic sur `src/Installer.cmd`
ou en une ligne : `irm https://raw.githubusercontent.com/ecappa/installation-github-jj/main/install.ps1 | iex`.

## Problématique
Le dépôt est privé : l'URL raw répond 404 sans jeton, donc le lancement en une ligne ne
marche qu'une fois le dépôt public ou le fichier hébergé ailleurs. La VM `ecosai-win`
(minis) appartient à Eco-Sai : ne jamais la désinstaller, la laisser comme trouvée.

## Fait et vérifié
- Recette de bout en bout le 2026-11-05 (git, gh, jj, connexion, push jj, commit 210140d) : `recette/20261105-vm-minis/`.
- Retrait de GitHub Desktop (785682d), 3 revues OK (GLM, Codex, Claude).
- 8effe9d : `install.ps1` ; UAC désactivé ne déclenche plus « Fenêtre administrateur » ;
  messages de relance selon le lanceur ; `WingetReady` retiré ; README à jour (run-all.ps1 manquant dit, System32 retiré).
- Essais dans la VM le 2026-11-06 (politique Restricted, UAC off), fichiers servis en HTTP local :
  scriptblock `-DryRun` OK (BOM EFBBBF, CRLF, pas d'avertissement admin), `irm | iex` + « n » arrêt propre,
  mauvaise adresse -> E-TELECHARGEMENT.
- f7dbbdb : corrections de la revue Grok v1 (relance dans src/README.md, script refusé s'il ne finit pas
  par son exit, un fichier par lancement effacé à la fin, adresse remplacée affichée). Grok v2 : OK sur le périmètre.
  Réessayé dans la VM : les trois cas passent, script coupé refusé, aucune copie restante.
- VM nettoyée : ni git/gh/jj, ni %LOCALAPPDATA%\InstallationGitHubJJ, ni dossier d'essai ;
  `~/vms/ecosai-win/shared/installation-github-jj{,-v2}` supprimés sur minis. VM laissée arrêtée.
- Snapshot propre `~/vms/ecosai-win/snapshots/20261106-propre-sans-git/` (cmp identique, LISEZMOI.md avec la
  commande de restauration). minis : 17 Go libres (98 %), avec deux snapshots de 25 Go.

## Fait mais non vérifié
- Installation réelle complète par `irm | iex` : pas faite (seulement préflight, essai à blanc et refus).
- `tests/run-all.ps1` introuvable (ni Mac, ni minis, ni VM) : aucun test automatique relançable.

## Reste à faire
1. Décision d'Éric : rendre `ecappa/installation-github-jj` public, ou héberger `install.ps1` + `src/setup-github-jj.ps1` ailleurs.
2. Une fois public : restaurer le snapshot propre, vraie installation par `irm | iex` avec le compte de test, puis restaurer.
3. Place sur minis : supprimer l'ancien snapshot `20261105-avant-github-jj` si Éric l'accepte.

## Fichiers importants
- `install.ps1` - amorce ASCII, télécharge et lance le script dans un processus enfant.
- `src/setup-github-jj.ps1` - `Read-AccountRights` (détection UAC), `$script:RelaunchHint`.
- Compte de test GitHub `cappasoft-test-jj` conservé pour les essais (Éric, 2026-11-06) ;
  identifiants `~/.config/installation-github-jj/compte-test-github.txt` (ne pas afficher).

## Ce qui a raté
- HTTP de minis vers la VM : bloqué par le pare-feu (Tailscale et passerelle docker 172.26.0.1). Servir depuis la VM (HttpListener sur localhost).
- `Start-Job` dans la VM : refusé par la politique Restricted ; lancer `powershell -ExecutionPolicy Bypass -File` via Start-Process.
- `vmps.sh` filtre les lignes CLIXML : les erreurs PowerShell disparaissent, ajouter `2>&1 | Out-String`.
- Orca : le terminal parent est maintenant term_66d0af5c (term_2fa84d85 refusé, consumer_fenced).

## Reprendre
```
cd ~/devRoot/cappasoft/rnd/installation-github-jj && git status -sb && git log --oneline -3
```
Demander à Éric le dépôt public, puis faire la vraie installation par `irm | iex` dans la VM restaurée depuis le snapshot propre.
