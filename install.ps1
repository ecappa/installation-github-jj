# Lancement en une ligne de l'installation Git, GitHub CLI et Jujutsu.
# Dans Windows PowerShell (pas en administrateur) :
#
#   irm https://raw.githubusercontent.com/ecappa/installation-github-jj/main/install.ps1 | iex
#
# Essai a blanc ou reponses oubliees :
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/ecappa/installation-github-jj/main/install.ps1))) -DryRun
#
# Ce fichier reste en ASCII : il est lu par irm, sans BOM. Il telecharge
# src/setup-github-jj.ps1, l'enregistre en UTF-8 avec BOM (PowerShell 5.1) et le
# lance dans un processus a part, comme Installer.cmd : un "exit" du script ne
# ferme pas la fenetre de l'utilisateur.
# INSTALLATION_GITHUB_JJ_URL remplace l'adresse du dossier src/ (essais).
param([switch]$DryRun, [switch]$Reset)

function Start-InstallationGitHubJJ([switch]$DryRun, [switch]$Reset) {
    $ProgressPreference = 'SilentlyContinue'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }

    $base = 'https://raw.githubusercontent.com/ecappa/installation-github-jj/main/src'
    if ($env:INSTALLATION_GITHUB_JJ_URL) {
        $base = $env:INSTALLATION_GITHUB_JJ_URL.TrimEnd('/')
        Write-Host "Adresse remplacee par INSTALLATION_GITHUB_JJ_URL : $base" -ForegroundColor Yellow
    }
    $appDir = Join-Path $env:LOCALAPPDATA 'InstallationGitHubJJ'
    $scriptDir = Join-Path $appDir 'script'
    # Un fichier par lancement : deux fenetres ouvertes en meme temps ne s'ecrasent pas le script.
    $target = Join-Path $scriptDir ('setup-github-jj-{0}.ps1' -f $PID)
    $marker = Join-Path $appDir 'fin-du-script.txt'
    $logs = Join-Path $appDir 'journaux'
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

    Write-Host 'Telechargement du script d''installation...'
    try {
        $client = New-Object Net.WebClient
        $bytes = $client.DownloadData("$base/setup-github-jj.ps1")
        # Decodage strict : un fichier coupe ou une page d'erreur ne doit pas etre lance.
        $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes)
        if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
        if (-not $text.StartsWith('<#') -or $text -notmatch 'function Invoke-Main' -or $text.TrimEnd() -notmatch 'exit \$script:ExitCode$') {
            throw 'contenu inattendu ou incomplet'
        }
        New-Item -ItemType Directory -Force -Path $scriptDir -ErrorAction Stop | Out-Null
        Get-ChildItem $scriptDir -Filter 'setup-github-jj*.ps1' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
        $text = $text -replace "`r?`n", "`r`n"
        [IO.File]::WriteAllText($target, $text, (New-Object Text.UTF8Encoding($true)))
    } catch {
        Write-Host ''
        Write-Host "Le script n'a pas pu etre telecharge : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'Verifie ta connexion internet, puis relance la commande.'
        Write-Host 'Code de l''erreur : E-TELECHARGEMENT'
        return
    }

    if (Test-Path $marker) { Remove-Item $marker -Force -ErrorAction SilentlyContinue }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $target)
    if ($DryRun) { $arguments += '-DryRun' }
    if ($Reset) { $arguments += '-Reset' }

    $previous = $env:INSTALLATION_GITHUB_JJ_LANCEUR
    $env:INSTALLATION_GITHUB_JJ_LANCEUR = 'commande'
    try {
        & $ps @arguments
        $code = $LASTEXITCODE
    } finally {
        $env:INSTALLATION_GITHUB_JJ_LANCEUR = $previous
        Remove-Item $target -Force -ErrorAction SilentlyContinue
    }

    # Memes regles qu'Installer.cmd : sans le fichier de fin, le script n'est pas alle au bout.
    if ($code -eq -1073741510 -or ($code -eq 0 -and -not (Test-Path $marker))) {
        Write-Host ''
        Write-Host 'Installation interrompue. Relance la commande quand tu veux, le script reprendra.'
        Write-Host "Journaux : $logs"
        return
    }
    if (@(0, 10, 20, 30) -notcontains $code) {
        Write-Host ''
        Write-Host "Le script n'a pas pu demarrer, ou il s'est arrete net, code $code."
        Write-Host 'Sur un PC d''entreprise, une regle de securite peut bloquer les scripts :'
        Write-Host 'montre ce message a ton service informatique.'
        Write-Host 'Code de l''erreur : E-LANCEMENT'
        Write-Host "Journaux : $logs"
    }
}

Start-InstallationGitHubJJ -DryRun:$DryRun -Reset:$Reset
