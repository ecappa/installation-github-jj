<#
.SYNOPSIS
    Prépare une machine Windows : Git, GitHub CLI, Jujutsu et compte GitHub.

.DESCRIPTION
    Pensé pour une personne qui n'a jamais utilisé ces outils :
    - vérifie d'abord que la machine est prête, avant de changer quoi que ce soit ;
    - guide chaque étape en français et explique chaque erreur ;
    - peut être relancé à tout moment : il reprend là où il s'est arrêté ;
    - écrit un journal détaillé, sans jamais y mettre de token.

    La création du compte GitHub reste manuelle : les conditions de GitHub
    interdisent les comptes créés par un script.

    Codes de sortie : 0 terminé, 10 erreur, 20 vérifications bloquantes, 30 arrêt demandé.

.PARAMETER DryRun
    Vérifie la machine et affiche ce qui serait fait. Seuls un journal et un petit fichier de fin sont écrits.

.PARAMETER Reset
    Oublie les réponses enregistrées avant de commencer.
    Les logiciels installés et la configuration déjà faite ne sont pas touchés.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Reset
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch { }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# --- Constantes ---------------------------------------------------------------

$script:AppDir    = Join-Path $env:LOCALAPPDATA 'InstallationGitHubJJ'
$script:LogDir    = Join-Path $script:AppDir 'journaux'
$script:StatePath = Join-Path $script:AppDir 'progression.json'
$script:LogPath   = $null
$script:ExitCode  = 0

$script:GitHubScopes  = @('user:email', 'workflow')
$script:WingetMinimum = [version]'1.6'
$script:WingetAgreements = @('--accept-package-agreements', '--accept-source-agreements')
$script:StoreAppInstallerUrl = 'https://apps.microsoft.com/detail/9nblggh4nns1'

$script:WingetLinkDirs = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
    (Join-Path $env:ProgramFiles 'WinGet\Links')
)
$script:Tools = @(
    @{ Label = 'Git'; Id = 'Git.Git'; Command = 'git'; Minimum = [version]'2.42'
       Dirs = @((Join-Path $env:ProgramFiles 'Git\cmd'), (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd')) },
    @{ Label = 'GitHub CLI'; Id = 'GitHub.cli'; Command = 'gh'; Minimum = $null
       Dirs = @((Join-Path $env:ProgramFiles 'GitHub CLI')) + $script:WingetLinkDirs },
    @{ Label = 'Jujutsu'; Id = 'jj-vcs.jj'; Command = 'jj'; Minimum = $null
       Dirs = $script:WingetLinkDirs }
)

# Codes winget : https://github.com/microsoft/winget-cli (returnCodes.md)
$script:WingetSuccessCodes = @(0, -1978335135, -1978334963, -1978335189)
$script:WingetFriendly = @{
    -1978334964 = @('Windows a demandé une autorisation et elle a été refusée ou annulée.', 'Relance et clique sur « Oui » quand Windows demande l''autorisation.')
    -1978335227 = @('L''installation a été interrompue.', 'Relance quand tu es prêt.')
    -1978334967 = @('L''installation a besoin d''un redémarrage pour se terminer.', 'Redémarre le PC, puis relance.')
    -1978334966 = @('Windows doit redémarrer avant cette installation.', 'Redémarre le PC, puis relance.')
    -1978334974 = @('Une autre installation est en cours sur le PC.', 'Attends qu''elle se termine (Windows Update par exemple), puis relance.')
    -1978334959 = @('Le logiciel est en cours d''utilisation.', 'Ferme les fenêtres de terminal et les éditeurs ouverts, puis relance.')
    -1978334971 = @('Il n''y a pas assez d''espace sur le disque.', 'Libère au moins 3 Go, puis relance.')
    -1978334970 = @('Il n''y a pas assez de mémoire disponible.', 'Ferme les autres applications, puis relance.')
    -1978335174 = @('L''organisation qui gère ce PC bloque cette opération.', 'Montre ce message à ton service informatique.')
    -1978334961 = @('L''organisation qui gère ce PC bloque cette installation.', 'Montre ce message à ton service informatique.')
    -1978334969 = @('La connexion internet a été coupée pendant l''installation.', 'Vérifie ta connexion, puis relance.')
    -1978335163 = @('Le catalogue winget n''a pas pu être ouvert.', 'Vérifie ta connexion, puis relance. Si cela continue, mets à jour « App Installer » dans le Microsoft Store.')
    -1978335157 = @('Le catalogue winget n''a pas pu être ouvert.', 'Vérifie ta connexion, puis relance. Si cela continue, mets à jour « App Installer » dans le Microsoft Store.')
    -1978335224 = @('Le téléchargement a échoué.', 'Vérifie ta connexion, puis relance.')
    -1978334975 = @('Le logiciel est en cours d''utilisation.', 'Ferme les fenêtres de terminal et les éditeurs ouverts, puis relance.')
    -1978334973 = @('Un fichier du logiciel est en cours d''utilisation.', 'Ferme les fenêtres de terminal et les éditeurs ouverts, puis relance.')
    -1978335216 = @('Aucune version de ce logiciel ne convient à ce PC.', 'Fais les mises à jour de Windows, puis relance. Si cela continue, envoie le journal à la personne qui t''aide.')
    -1978335215 = @('Le fichier téléchargé ne correspond pas à celui attendu : par sécurité, il n''a pas été installé.', 'Réessaie dans quelques heures. Si cela continue, envoie le journal à la personne qui t''aide.')
    -1978334957 = @('Ce logiciel n''est pas compatible avec cette version de Windows.', 'Fais les mises à jour de Windows, puis relance.')
}

# --- Journal et affichage -----------------------------------------------------

# Un token ne doit jamais atterrir dans le journal, même si un outil l'affiche.
function Protect-Text([string]$Text) {
    return ($Text -replace 'gh[pousr]_[A-Za-z0-9_]+', '[token masqué]' -replace 'github_pat_[A-Za-z0-9_]+', '[token masqué]')
}

function Write-Log([string]$Level, [string]$Text) {
    if (-not $script:LogPath) { return }
    try {
        $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Level, (Protect-Text $Text)
        [IO.File]::AppendAllText($script:LogPath, "$line`r`n", (New-Object System.Text.UTF8Encoding($true)))
    } catch { }
}

function Write-Step([string]$Text) { Write-Host "`n=== $Text ===" -ForegroundColor Cyan; Write-Log 'ETAPE' $Text }
function Write-Ok([string]$Text)   { Write-Host "[OK] $Text" -ForegroundColor Green; Write-Log 'OK' $Text }
function Write-Info([string]$Text) { Write-Host "     $Text"; Write-Log 'INFO' $Text }
function Write-Warn([string]$Text) { Write-Host "[ATTENTION] $Text" -ForegroundColor Yellow; Write-Log 'ATTENTION' $Text }
function Write-Plan([string]$Text) { Write-Host "[essai à blanc] $Text" -ForegroundColor Yellow; Write-Log 'PLAN' $Text }

function New-SetupError([string]$Code, [string]$What, [string]$Why, [string]$Fix) {
    $e = New-Object System.Exception($What)
    $e.Data['Code'] = $Code
    $e.Data['Why'] = $Why
    $e.Data['Fix'] = $Fix
    return $e
}

function Show-Failure([string]$Code, [string]$What, [string]$Why, [string]$Fix) {
    Write-Log 'ERREUR' "$Code | $What | $Why | $Fix"
    Write-Host "`n================ PROBLÈME ================" -ForegroundColor Red
    Write-Host "Ce qui s'est passé : $What"
    if ($Why) { Write-Host "Pourquoi           : $Why" }
    if ($Fix) { Write-Host "Que faire          : $Fix" -ForegroundColor Yellow }
    Write-Host "Code de l'erreur   : $Code"
    if ($script:LogPath) { Write-Host "Journal détaillé   : $script:LogPath" }
    Write-Host "`nTu peux relancer quand tu veux : le script reprendra là où il s'est arrêté."
    Write-Host "Si tu demandes de l'aide, envoie le code de l'erreur et le journal (il ne contient pas ta clé d'accès GitHub)."
}

# --- Exécution de commandes ---------------------------------------------------

# Output : la sortie standard seule, à utiliser comme donnée. Text : tout, pour reconnaître un message.
# La sortie brute des outils (en anglais) reste dans le journal : elle n'est pas montrée à l'utilisateur.
# -Private : la sortie standard contient des données personnelles et n'est pas journalisée.
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments = @(), [switch]$Private)
    Write-Log 'CMD' "$Exe $($Arguments -join ' ')"
    $all = New-Object System.Collections.Generic.List[string]
    $output = New-Object System.Collections.Generic.List[string]
    $code = 0
    try {
        $global:LASTEXITCODE = 0
        & $Exe @Arguments 2>&1 | ForEach-Object {
            $isError = $_ -is [System.Management.Automation.ErrorRecord]
            $line = "$_".TrimEnd()
            if (-not $line) { return }
            # Barres de progression de winget, à ne pas filtrer ailleurs : un nom de profil peut contenir ces caractères.
            if ($Exe -eq 'winget' -and ($line -match '^[\s\-\\|/]*$' -or $line -match '[▀-▟]')) { return }
            # Ligne vide sur stderr : PowerShell 5.1 la transforme en ce texte.
            if ($isError -and $line -eq 'System.Management.Automation.RemoteException') { return }
            $all.Add($line)
            if (-not $isError) { $output.Add($line) }
            if ($isError -or -not $Private) { Write-Log 'SORTIE' $line }
        }
        $code = $LASTEXITCODE
    } catch {
        Write-Log 'SORTIE' "Lancement impossible : $($_.Exception.Message)"
        $code = 9009
    }
    Write-Log 'CODE' "$Exe -> $code"
    return [pscustomobject]@{ ExitCode = $code; Text = ($all -join "`n"); Output = ($output -join "`n") }
}

# Pour les commandes qui dialoguent avec l'utilisateur. Le programme doit recevoir la vraie console :
# avec « & $Exe », sa sortie serait capturée par cette fonction et gh n'ouvrirait jamais le navigateur.
function Invoke-Interactive([string]$Exe, [string[]]$Arguments) {
    Write-Log 'CMD' "$Exe $($Arguments -join ' ') (interactif)"
    $code = 9009
    try {
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = (Get-Command $Exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        $start.Arguments = (@($Arguments | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join ' ')
        $start.UseShellExecute = $false
        $process = [System.Diagnostics.Process]::Start($start)
        $process.WaitForExit()
        $code = $process.ExitCode
        $process.Dispose()
    } catch {
        Write-Log 'SORTIE' "Lancement impossible : $($_.Exception.Message)"
    }
    Write-Log 'CODE' "$Exe -> $code"
    return $code
}

function Invoke-Checked([string]$Exe, [string[]]$Arguments, [string]$Purpose) {
    $result = Invoke-Native $Exe $Arguments
    if ($result.ExitCode -ne 0) {
        throw (New-SetupError 'E-CONFIG' $Purpose 'L''outil a refusé ce réglage. Le détail est dans le journal.' 'Relance le script. Si cela continue, envoie le journal à la personne qui t''aide.')
    }
}

# La page peut ne pas s'ouvrir (pas de navigateur par défaut) : l'adresse est donc toujours affichée.
function Open-Url([string]$Url) {
    Write-Host "     Adresse de la page : $Url"
    try {
        Start-Process $Url -ErrorAction Stop
    } catch {
        Write-Warn 'La page ne s''est pas ouverte toute seule : copie l''adresse ci-dessus dans ton navigateur.'
    }
}

# --- Questions ----------------------------------------------------------------

# Les touches pressées pendant une longue installation ne doivent pas répondre à la question suivante.
function Clear-TypedKeys {
    try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
}

function Read-YesNo([string]$Question, [bool]$Default) {
    $hint = if ($Default) { 'O/n' } else { 'o/N' }
    Clear-TypedKeys
    while ($true) {
        # Ce qui est tapé ne va pas dans le journal : une clé d'accès peut être collée par erreur.
        $answer = (Read-Host "$Question ($hint)").Trim().ToLower()
        $result = $null
        if ($answer -eq '') { $result = $Default }
        elseif ($answer -in 'o', 'oui', 'y', 'yes') { $result = $true }
        elseif ($answer -in 'n', 'non', 'no') { $result = $false }
        if ($null -ne $result) {
            Write-Log 'QUESTION' "$Question -> $result"
            return $result
        }
        Write-Host 'Réponds par o (oui) ou n (non).'
    }
}

function Read-WithDefault([string]$Question, [string]$Default) {
    $prompt = if ($Default) { "$Question (appuie sur Entrée pour garder : $Default)" } else { $Question }
    Clear-TypedKeys
    $answer = (Read-Host $prompt).Trim()
    Write-Log 'QUESTION' "$Question -> réponse reçue"
    if ($answer -eq '') { return $Default }
    return $answer
}

function Get-NameProblem([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return 'le nom est vide' }
    if ($Name.Length -gt 100) { return 'le nom dépasse 100 caractères' }
    if ($Name -match '["\\<>]') { return 'les caractères " \ < > ne sont pas acceptés' }
    if ($Name -match "'''") { return 'trois apostrophes de suite ne sont pas acceptées' }
    if ($Name -match '[\x00-\x1F]') { return 'le nom contient un caractère invisible' }
    return $null
}

function Read-CommitName([string]$Default) {
    if (Get-NameProblem $Default) { $Default = '' }
    Write-Info 'Chaque modification que tu enverras sur GitHub (on appelle cela un « commit ») porte un nom et une adresse e-mail, visibles par tout le monde.'
    while ($true) {
        $name = Read-WithDefault 'Quel nom afficher ? Ton vrai nom ou un pseudo' $Default
        $problem = Get-NameProblem $name
        if (-not $problem) { return $name }
        Write-Host "Ce nom ne convient pas : $problem. Essaie sans ces caractères." -ForegroundColor Yellow
    }
}

# --- Reprise ------------------------------------------------------------------

function New-EmptyState {
    return [pscustomobject]@{
        login = $null; name = $null; email = $null
        desktopChoice = $null; desktopDone = $false
        stepsDone = @(); completed = $false
    }
}

function Read-State {
    $state = New-EmptyState
    if (-not (Test-Path $script:StatePath)) { return $state }
    try {
        $saved = [IO.File]::ReadAllText($script:StatePath) | ConvertFrom-Json
        foreach ($p in $state.PSObject.Properties.Name) {
            if ($saved.PSObject.Properties[$p]) { $state.$p = $saved.$p }
        }
        $state.stepsDone = @($state.stepsDone)
        Write-Log 'INFO' "Progression chargée : $($state.stepsDone -join ', ')"
    } catch {
        Write-Log 'ATTENTION' "Progression illisible, on repart de zéro : $($_.Exception.Message)"
        $script:StateUnreadable = $true
        $state = New-EmptyState
    }
    return $state
}

# Écriture dans un fichier temporaire d'abord : une coupure ne peut pas abîmer la progression.
function Save-State {
    if ($DryRun) { return }
    $temp = "$script:StatePath.tmp"
    [IO.File]::WriteAllText($temp, ($script:State | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item $temp $script:StatePath -Force -ErrorAction Stop
}

function Complete-Step([string]$Name) {
    if ($script:State.stepsDone -notcontains $Name) { $script:State.stepsDone = @($script:State.stepsDone) + $Name }
    Save-State
    Write-Log 'INFO' "Étape terminée : $Name"
}

# --- Outils -------------------------------------------------------------------

function Test-Tool([string]$Name) {
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Set-PathValue([string[]]$Entries) {
    $seen = @{}
    $unique = foreach ($entry in $Entries) {
        if ($entry -and -not $seen.ContainsKey($entry.ToLower())) { $seen[$entry.ToLower()] = $true; $entry }
    }
    $env:Path = $unique -join ';'
}

# Le PATH enregistré dans Windows : celui que verra une nouvelle fenêtre de terminal.
function Get-StoredPathEntries {
    $keys = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'HKCU:\Environment'
    $entries = foreach ($key in $keys) {
        try { (Get-ItemProperty -Path $key -Name 'Path' -ErrorAction Stop).Path -split ';' } catch { }
    }
    return @($entries | Where-Object { $_ })
}

# winget met à jour le PATH dans le registre, pas dans la session en cours.
function Update-SessionPath {
    Set-PathValue (@($env:Path -split ';') + @(Get-StoredPathEntries))
}

function Find-Tool($Tool) {
    if (Test-Tool $Tool.Command) { return $true }
    Update-SessionPath
    if (Test-Tool $Tool.Command) { return $true }
    foreach ($dir in $Tool.Dirs) {
        if ($dir -and (Test-Path (Join-Path $dir "$($Tool.Command).exe"))) {
            Set-PathValue ("$dir;$env:Path" -split ';')
            Write-Log 'INFO' "$($Tool.Label) trouvé dans $dir (ajouté au PATH de cette session)"
            return $true
        }
    }
    return $false
}

function Get-ToolVersion([string]$Command) {
    $result = Invoke-Native $Command @('--version')
    if ($result.ExitCode -eq 0 -and $result.Output -match '(\d+\.\d+(\.\d+)?)') { return [version]$Matches[1] }
    return $null
}

# Broken : le programme existe mais ne répond pas (installation coupée par exemple).
function Get-ToolCondition($Tool) {
    if (-not (Find-Tool $Tool)) { return 'Missing' }
    $version = Get-ToolVersion $Tool.Command
    if ($null -eq $version) { return 'Broken' }
    if ($Tool.Minimum -and $version -lt $Tool.Minimum) { return 'TooOld' }
    return 'Ready'
}

# Un compte standard ne peut pas autoriser une installation pour tout le PC.
function Get-InstallScope {
    if ($script:IsAdminAccount) { return @() }
    return @('--scope', 'user')
}

# Les groupes du compte peuvent révéler ceux de l'entreprise : seul le résultat est journalisé.
# S-1-5-32-544 : administrateurs. S-1-16-12288 : fenêtre lancée « en tant qu'administrateur ».
function Read-AccountRights {
    $result = Invoke-Native 'whoami' @('/groups', '/fo', 'csv') -Private
    $script:IsAdminAccount = ($result.ExitCode -ne 0 -or $result.Text -match 'S-1-5-32-544')
    $script:IsElevated = ($result.ExitCode -eq 0 -and $result.Text -match 'S-1-16-12288')
    Write-Log 'INFO' "Compte administrateur : $script:IsAdminAccount. Fenêtre élevée : $script:IsElevated"
}

function Get-SessionOwner {
    try {
        $session = (Get-Process -Id $PID).SessionId
        $shell = Get-CimInstance Win32_Process -Filter "Name='explorer.exe' AND SessionId=$session" -ErrorAction Stop | Select-Object -First 1
        if (-not $shell) { return $null }
        return (Invoke-CimMethod -InputObject $shell -MethodName GetOwner -ErrorAction Stop).User
    } catch {
        Write-Log 'INFO' "Compte de la session non déterminé : $($_.Exception.Message)"
        return $null
    }
}

function Test-InstallerRunning {
    $mutex = $null
    try {
        $found = [Threading.Mutex]::TryOpenExisting('Global\_MSIExecute', [ref]$mutex)
        if ($mutex) { $mutex.Dispose() }
        return $found
    } catch [UnauthorizedAccessException] {
        return $true
    } catch {
        return $false
    }
}

function Test-UrlReachable([string]$Url) {
    try {
        Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop | Out-Null
        return $true
    } catch {
        $response = $_.Exception.Response
        if ($response -and [int]$response.StatusCode -ne 407) { return $true }
        Write-Log 'INFO' "$Url injoignable : $($_.Exception.Message)"
        return $false
    }
}

function Get-WingetCommandLine([string]$Verb, [string]$Id, [string[]]$Extra) {
    # Un $Extra vide ne doit pas devenir un argument vide pour winget.
    return @($Verb, '--id', $Id, '--exact', '--source', 'winget', '--silent') + @($Extra | Where-Object { $_ }) + $script:WingetAgreements
}

function Get-WingetExplanation([int]$Code) {
    if ($script:WingetFriendly.ContainsKey($Code)) { return $script:WingetFriendly[$Code] }
    $hex = '0x{0:X8}' -f $Code
    # Cet appel sert à écrire l'explication de winget dans le journal.
    [void](Invoke-Native 'winget' @('error', $hex))
    return @("winget a renvoyé le code $hex.", 'Relance le script. Si cela continue, envoie le journal à la personne qui t''aide.')
}

function Get-TokenFix([string]$Variable, [bool]$InUser, [bool]$InMachine) {
    if ($InMachine) {
        return "$Variable est réglée pour tout le PC : demande à ton service informatique ou à la personne qui t'aide de la retirer."
    }
    if ($InUser) {
        return "Si elle sert à un autre outil, demande d'abord à la personne qui t'aide. Sinon : menu Démarrer, tape « variables d'environnement », ouvre « Modifier les variables d'environnement pour votre compte », sélectionne $Variable, clique sur Supprimer puis OK. Double-clique ensuite à nouveau sur Installer.cmd."
    }
    return "$Variable n'existe que dans cette fenêtre : ferme-la et double-clique à nouveau sur Installer.cmd."
}

# --- Étape 0 : vérifications avant de commencer -------------------------------

function Add-Check([string]$Status, [string]$Name, [string]$Detail, [string]$Fix, [string]$Code) {
    $script:Checks += [pscustomobject]@{ Status = $Status; Name = $Name; Detail = $Detail; Fix = $Fix; Code = $Code }
    Write-Log 'VERIF' "$Status | $Code | $Name | $Detail | $Fix"
    $label, $color = switch ($Status) {
        'OK'   { '[OK]       ', 'Green' }
        'WARN' { '[ATTENTION]', 'Yellow' }
        'STOP' { '[BLOQUANT] ', 'Red' }
    }
    Write-Host "$label $Name : $Detail" -ForegroundColor $color
    if ($Status -eq 'WARN' -and $Fix) { Write-Host "            $Fix" -ForegroundColor $color }
}

function Add-WingetVersionCheck {
    $noStore = "Si le Microsoft Store est bloqué sur ce PC, montre ce message à ton service informatique ou à la personne qui t'aide (winget existe aussi ici : https://github.com/microsoft/winget-cli/releases)."
    $version = if (Test-Tool 'winget') { Get-ToolVersion 'winget' } else { $null }
    if (-not $version) {
        $script:StoreUrlNeeded = $true
        Add-Check 'STOP' 'Installateur winget' 'pas encore disponible' "Sur un PC neuf, Windows l'active quelques minutes après la première connexion : attends 10 minutes et relance. Sinon, installe « App Installer » ($script:StoreAppInstallerUrl). $noStore" 'E-PRE-WINGET'
    } elseif ($version -lt $script:WingetMinimum) {
        $script:StoreUrlNeeded = $true
        Add-Check 'STOP' 'Installateur winget' "version $version trop ancienne (il faut au moins $script:WingetMinimum)" "Mets à jour « App Installer » ($script:StoreAppInstallerUrl), puis relance. $noStore" 'E-PRE-WINGET'
    } else {
        $script:WingetReady = $true
        Add-Check 'OK' 'Installateur winget' "version $version" ''
    }
}

function Invoke-WingetCheck {
    if (Test-Tool 'winget') { Add-WingetVersionCheck; return }
    $script:WingetToActivate = $true
    Add-Check 'WARN' 'Installateur winget' 'absent : si tu acceptes de commencer, le script demandera à Windows de l''activer' ''
}

# Après l'accord de l'utilisateur, car cette étape change quelque chose sur le PC.
function Invoke-WingetActivation {
    Write-Step 'Activation de winget (l''installateur de logiciels de Windows)'
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    } catch {
        Write-Log 'INFO' "Enregistrement de winget refusé : $($_.Exception.Message)"
    }
    Update-SessionPath
    $apps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    Set-PathValue ("$env:Path;$apps" -split ';')
    Add-WingetVersionCheck
    return (Show-BlockingChecks 'Aucun logiciel n''a été installé.')
}

# Renvoie $true s'il n'y a rien de bloquant ; sinon explique quoi faire et renvoie $false.
function Show-BlockingChecks([string]$Summary) {
    $blocking = @($script:Checks | Where-Object { $_.Status -eq 'STOP' })
    if (-not $blocking.Count) { return $true }

    Write-Host "`nLe script ne peut pas continuer pour l'instant. $Summary" -ForegroundColor Red
    foreach ($check in $blocking) {
        Write-Host "`nCe qui bloque    : $($check.Name) : $($check.Detail)"
        Write-Host "Que faire        : $($check.Fix)" -ForegroundColor Yellow
        Write-Host "Code de l'erreur : $($check.Code)"
    }
    if ($script:LogPath) { Write-Host "`nJournal détaillé : $script:LogPath" }
    if ($script:StoreUrlNeeded -and -not $DryRun) { Open-Url $script:StoreAppInstallerUrl }
    return $false
}

function Invoke-Preflight {
    Write-Step 'Vérification de la machine (rien n''est modifié)'
    $script:Checks = @()
    $script:WingetReady = $false
    $script:WingetToActivate = $false
    $script:StoreUrlNeeded = $false

    $build = [Environment]::OSVersion.Version.Build
    if (-not [Environment]::Is64BitOperatingSystem) {
        Add-Check 'STOP' 'Windows' 'version 32 bits' 'Ces outils demandent un Windows 64 bits : ils ne peuvent pas être installés sur ce PC.' 'E-PRE-WINDOWS'
    } elseif ($build -lt 17763) {
        Add-Check 'STOP' 'Windows' "build $build trop ancienne" 'Fais les mises à jour de Windows (il faut au moins Windows 10 version 1809), puis relance.' 'E-PRE-WINDOWS'
    } else {
        Add-Check 'OK' 'Windows' "build $build" ''
    }

    if ($PSVersionTable.PSVersion -lt [version]'5.1') {
        Add-Check 'STOP' 'PowerShell' "version $($PSVersionTable.PSVersion) trop ancienne" 'Fais les mises à jour de Windows, puis relance.' 'E-PRE-POWERSHELL'
    }

    $identity = ([Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1]
    $sessionOwner = Get-SessionOwner
    if ($sessionOwner -and $sessionOwner -ne $identity) {
        Add-Check 'STOP' 'Compte Windows' "le script tourne sous « $identity » alors que la session ouverte est celle de « $sessionOwner »" 'Ferme cette fenêtre et double-clique sur Installer.cmd, sans « Exécuter en tant qu''administrateur » : sinon la connexion GitHub irait sur le mauvais compte.' 'E-PRE-COMPTE'
    } else {
        Add-Check 'OK' 'Compte Windows' $identity ''
    }

    Read-AccountRights
    if ($script:IsElevated) {
        Add-Check 'WARN' 'Fenêtre administrateur' 'le script a été lancé « en tant qu''administrateur », ce n''est pas recommandé' 'Si possible, ferme cette fenêtre et double-clique simplement sur Installer.cmd.'
    }
    if ($script:IsAdminAccount) {
        Add-Check 'OK' 'Droits' 'compte administrateur : Windows demandera peut-être de cliquer sur « Oui »' ''
    } else {
        Add-Check 'OK' 'Droits' 'compte standard : les logiciels seront installés pour ce compte uniquement' ''
    }

    $drive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
    if ($drive) {
        $freeGb = [math]::Round($drive.Free / 1GB, 1)
        if ($freeGb -lt 1) {
            Add-Check 'STOP' 'Espace disque' "$freeGb Go libres" 'Libère au moins 3 Go, puis relance.' 'E-PRE-DISQUE'
        } elseif ($freeGb -lt 3) {
            Add-Check 'WARN' 'Espace disque' "$freeGb Go libres, c'est juste" 'Libère de l''espace si l''installation échoue.'
        } else {
            Add-Check 'OK' 'Espace disque' "$freeGb Go libres" ''
        }
    }

    foreach ($variable in 'GH_TOKEN', 'GITHUB_TOKEN') {
        $inProcess = [bool][Environment]::GetEnvironmentVariable($variable, 'Process')
        $inUser = [bool][Environment]::GetEnvironmentVariable($variable, 'User')
        $inMachine = [bool][Environment]::GetEnvironmentVariable($variable, 'Machine')
        if ($inProcess -or $inUser -or $inMachine) {
            Add-Check 'STOP' 'Clé d''accès GitHub' "un réglage du PC nommé $variable contient une clé d'accès qui empêcherait ta connexion à GitHub" (Get-TokenFix $variable $inUser $inMachine) 'E-PRE-CLE'
        }
    }

    $script:NeedInstall = $false
    foreach ($tool in $script:Tools) {
        switch (Get-ToolCondition $tool) {
            'Missing' {
                $script:NeedInstall = $true
                Add-Check 'OK' $tool.Label 'à installer' ''
            }
            'Broken' {
                $script:NeedInstall = $true
                Add-Check 'WARN' $tool.Label 'installé mais ne répond pas' 'Le script va le réinstaller.'
            }
            'TooOld' {
                $script:NeedInstall = $true
                Add-Check 'WARN' $tool.Label "version trop ancienne (minimum $($tool.Minimum))" 'Le script va tenter de le mettre à jour.'
            }
            default {
                Add-Check 'OK' $tool.Label 'déjà installé' ''
            }
        }
    }

    $sites = @('https://github.com', 'https://api.github.com')
    if ($script:NeedInstall) { $sites += 'https://cdn.winget.microsoft.com/cache/source.msix' }
    $unreachable = @($sites | Where-Object { -not (Test-UrlReachable $_) })
    if ($unreachable.Count) {
        Add-Check 'STOP' 'Internet' "injoignable : $($unreachable -join ', ')" 'Vérifie le Wi-Fi ou le câble, et que la date et l''heure du PC sont justes. Au travail, un pare-feu peut bloquer ces sites : montre ce message à ton service informatique.' 'E-PRE-INTERNET'
    } else {
        Add-Check 'OK' 'Internet' 'GitHub est joignable' ''
    }

    if ($script:NeedInstall) {
        Invoke-WingetCheck
    } elseif (Test-Tool 'winget') {
        # winget ne sert plus qu'à l'option GitHub Desktop : son absence n'est pas bloquante.
        $version = Get-ToolVersion 'winget'
        $script:WingetReady = ($null -ne $version -and $version -ge $script:WingetMinimum)
    }

    if ($script:NeedInstall -and (Test-InstallerRunning)) {
        Add-Check 'WARN' 'Autre installation' 'une installation semble en cours sur le PC' 'Attends qu''elle se termine si le script échoue.'
    }

    $rebootKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    if ($rebootKeys | Where-Object { Test-Path $_ }) {
        Add-Check 'WARN' 'Redémarrage' 'Windows attend un redémarrage' 'Si une installation échoue, redémarre le PC puis relance.'
    }

    if ($PSScriptRoot -match '\\Users\\Public(\\|$)') {
        Add-Check 'WARN' 'Emplacement du script' 'tout utilisateur du PC peut modifier ce dossier' 'Copie le dossier dans ton propre compte si d''autres personnes utilisent ce PC.'
    }

    return (Show-BlockingChecks 'Rien n''a été modifié.')
}

function Confirm-Start {
    Write-Host ''
    Write-Info 'Pour répondre : tape o (oui) ou n (non), puis Entrée. Entrée seule choisit la lettre en majuscule.'
    if (@($script:State.stepsDone).Count -gt 0 -and -not $script:State.completed) {
        Write-Info "Reprise : déjà fait -> $(@($script:State.stepsDone) -join ', '). Ces étapes seront revérifiées et tes réponses sont conservées."
    } elseif ($script:State.completed) {
        Write-Info 'Tout avait déjà été fait : le script va revérifier que tout fonctionne, sans changer tes réglages actuels.'
    }
    if ($script:WingetToActivate) {
        Write-Info 'Le script va d''abord demander à Windows d''activer winget, son installateur de logiciels.'
    }
    if ($script:NeedInstall) {
        Write-Info 'Le script va installer Git, GitHub CLI et Jujutsu si besoin (5 à 10 minutes).'
        Write-Info 'En continuant, tu acceptes les licences de ces logiciels.'
        Write-Info 'Si Windows demande une autorisation, clique sur « Oui ».'
    }
    Write-Info 'Ensuite : connexion à ton compte GitHub dans le navigateur, puis configuration.'
    if (-not (Read-YesNo 'On commence ?' $true)) {
        Write-Info 'D''accord, rien n''a été modifié. Tu peux relancer quand tu veux.'
        $script:ExitCode = 30
        return $false
    }
    return $true
}

# --- Étape 1 : installation ---------------------------------------------------

function Invoke-WingetInstall($Tool, [string[]]$Extra) {
    Write-Info "Installation de $($Tool.Label)... Cela peut prendre quelques minutes, sans rien afficher ici."
    Write-Info 'Si rien ne bouge, regarde si Windows demande une autorisation derrière les autres fenêtres (icône qui clignote dans la barre des tâches).'
    $result = Invoke-Native 'winget' (Get-WingetCommandLine 'install' $Tool.Id $Extra)
    return $result.ExitCode
}

function Stop-InstallFailed($Tool, [int]$Code) {
    $why, $fix = Get-WingetExplanation $Code
    throw (New-SetupError "E-INSTALL-$($Tool.Command.ToUpper())" "$($Tool.Label) n'a pas pu être installé." $why $fix)
}

function Install-Tool($Tool) {
    $condition = Get-ToolCondition $Tool
    if ($condition -eq 'Ready') {
        Write-Ok "$($Tool.Label) est prêt."
        return
    }
    if ($condition -eq 'TooOld') {
        Write-Info "Mise à jour de $($Tool.Label)..."
        $result = Invoke-Native 'winget' (Get-WingetCommandLine 'upgrade' $Tool.Id @())
        if ((Get-ToolCondition $Tool) -ne 'Ready') {
            throw (New-SetupError "E-MAJ-$($Tool.Command.ToUpper())" "$($Tool.Label) est trop ancien et n'a pas pu être mis à jour (code $($result.ExitCode))." "Jujutsu a besoin de $($Tool.Label) $($Tool.Minimum) ou plus récent." "Désinstalle $($Tool.Label) depuis Paramètres > Applications, puis relance.")
        }
        Write-Ok "$($Tool.Label) est à jour."
        return
    }
    if ($condition -eq 'Broken') {
        Write-Warn "$($Tool.Label) est présent mais ne répond pas. Une installation a peut-être été coupée : je le réinstalle."
        $code = Invoke-WingetInstall $Tool (@(Get-InstallScope) + '--force')
        if ((Get-ToolCondition $Tool) -ne 'Ready') {
            throw (New-SetupError "E-CASSE-$($Tool.Command.ToUpper())" "$($Tool.Label) ne répond pas et n'a pas pu être réinstallé (code $code)." 'Son installation est probablement abîmée.' "Désinstalle $($Tool.Label) depuis Paramètres > Applications, puis relance.")
        }
        Write-Ok "$($Tool.Label) est réinstallé."
        return
    }

    $code = Invoke-WingetInstall $Tool @(Get-InstallScope)
    if (Find-Tool $Tool) { Write-Ok "$($Tool.Label) est installé."; return }

    # Le repli ne vise que les refus d'autorisation et les codes propres aux installeurs.
    # Réseau, disque ou stratégie échoueraient pareil : autant l'expliquer tout de suite.
    # -1978334961 : un MSI silencieux sans élévation peut aussi rendre ce code « bloqué par une règle ».
    $mayBeRights = ($code -eq -1978334964 -or $code -eq -1978334961 -or -not $script:WingetFriendly.ContainsKey($code))
    if ($script:IsAdminAccount -and $mayBeRights -and $code -notin $script:WingetSuccessCodes) {
        Write-Warn "L'installation pour tout le PC n'a pas abouti. Nouvel essai pour ce compte uniquement, sans droits administrateur."
        $fallback = Invoke-WingetInstall $Tool @('--scope', 'user')
        if (Find-Tool $Tool) { Write-Ok "$($Tool.Label) est installé pour ce compte."; return }
        if ($fallback -notin $script:WingetSuccessCodes) { $code = $fallback }
    }

    if ($code -in $script:WingetSuccessCodes) {
        throw (New-SetupError "E-INTROUVABLE-$($Tool.Command.ToUpper())" "$($Tool.Label) semble installé, mais Windows ne le trouve pas encore." 'Le PC doit peut-être prendre en compte le changement.' "Redémarre le PC, puis relance. Si tu l'as déjà fait, désinstalle $($Tool.Label) depuis Paramètres > Applications, puis relance.")
    }
    Stop-InstallFailed $Tool $code
}

function Install-Desktop {
    if ($script:State.desktopDone -or -not $script:WingetReady) { return }
    if ($null -eq $script:State.desktopChoice) {
        $script:State.desktopChoice = Read-YesNo 'Installer aussi GitHub Desktop (interface graphique, facultative) ?' $false
        Save-State
    }
    if (-not $script:State.desktopChoice) { return }
    Write-Info 'Installation de GitHub Desktop...'
    $result = Invoke-Native 'winget' (Get-WingetCommandLine 'install' 'GitHub.GitHubDesktop' @())
    if ($result.ExitCode -in $script:WingetSuccessCodes) {
        Write-Ok 'GitHub Desktop est prêt.'
        $script:State.desktopDone = $true
        Save-State
    } else {
        $why, $fix = Get-WingetExplanation $result.ExitCode
        Write-Warn "GitHub Desktop n'a pas été installé : $why $fix Ce n'est pas bloquant, la suite continue."
    }
}

# --- Étape 2 : compte GitHub --------------------------------------------------

# Format --json : seul moyen fiable de distinguer une panne réseau d'une connexion expirée,
# car le texte de gh dit « token invalide » dans les deux cas.
function Read-GhStatusJson($Status, [string]$Json) {
    try {
        $entries = @(($Json | ConvertFrom-Json).hosts.'github.com')
    } catch {
        Write-Log 'INFO' "Statut gh illisible : $($_.Exception.Message)"
        return
    }
    $entry = $entries | Where-Object { $_ -and $_.active } | Select-Object -First 1
    if (-not $entry) { $Status.State = 'NotLoggedIn'; return }
    $Status.Login = $entry.login
    $Status.Storage = $entry.tokenSource
    if ($entry.scopes) { $Status.Scopes = @("$($entry.scopes)" -split ',\s*' | Where-Object { $_ }) }
    if ($entry.state -eq 'success' -and $entry.login) { $Status.State = 'LoggedIn' }
    elseif ($entry.state -eq 'refresh-expired') { $Status.State = 'Expired' }
    elseif ($entry.state -eq 'error' -and $entry.error -match 'HTTP 401|Bad credentials') { $Status.State = 'Expired' }
    else { $Status.State = 'Network' }
}

function Get-GhStatus {
    # --active : un autre compte en panne sur ce PC ne doit pas faire échouer la vérification.
    # Les anciennes versions de gh ne connaissent ni --active ni --json.
    if ($null -eq $script:GhStatusHelp) {
        $script:GhStatusHelp = (Invoke-Native 'gh' @('auth', 'status', '--help')).Text
    }
    $arguments = @('auth', 'status', '--hostname', 'github.com')
    if ($script:GhStatusHelp -match '--active') { $arguments += '--active' }
    $status = [pscustomobject]@{ State = 'Unknown'; Login = $null; Storage = $null; Scopes = $null }
    if ($script:GhStatusHelp -match '--json') {
        Read-GhStatusJson $status (Invoke-Native 'gh' ($arguments + @('--json', 'hosts'))).Output
        return $status
    }
    $result = Invoke-Native 'gh' $arguments
    if ($result.Text -match 'Logged in to github\.com (?:account|as) (\S+) \((.+?)\)') {
        $status.Login = $Matches[1]
        $status.Storage = $Matches[2]
    }
    if ($result.Text -match 'Token scopes: (.+)') {
        $status.Scopes = @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
    }
    if ($result.ExitCode -eq 0 -and $status.Login) { $status.State = 'LoggedIn' }
    elseif ($result.Text -match 'not logged in') { $status.State = 'NotLoggedIn' }
    elseif ($result.Text -match '(?i)timeout|timed out|no such host|dial tcp|connection') { $status.State = 'Network' }
    elseif ($result.Text -match '(?i)invalid|Failed to log in') { $status.State = 'Expired' }
    return $status
}

# Vérifié sur le vrai gh : question sur Git, code copié, Entrée, navigateur.
function Show-BrowserSteps {
    Write-Host ''
    Write-Info 'Des lignes en anglais vont s''afficher, c''est normal. Tu n''as aucun mot de passe à taper dans cette fenêtre.'
    Write-Info '  1. Si la question « Authenticate Git with your GitHub credentials? » s''affiche, appuie sur Entrée.'
    Write-Info '  2. Quand « Press Enter to open... » s''affiche, appuie sur Entrée : le navigateur s''ouvre.'
    Write-Info '  3. Connecte-toi à GitHub si besoin, puis colle le code avec Ctrl+V (s''il n''est pas copié, recopie celui affiché ici).'
    Write-Info '  4. Clique sur « Continue », puis sur « Authorize », et reviens dans cette fenêtre.'
    Write-Host ''
}

function Get-GhClipboardOption([string]$Verb) {
    if ((Invoke-Native 'gh' @('auth', $Verb, '--help')).Text -match '--clipboard') { return @('--clipboard') }
    return @()
}

function Invoke-GhLogin {
    Show-BrowserSteps
    $arguments = @('auth', 'login', '--web', '--git-protocol', 'https', '--hostname', 'github.com', '--scopes', ($script:GitHubScopes -join ','))
    [void](Invoke-Interactive 'gh' ($arguments + @(Get-GhClipboardOption 'login')))
}

function Connect-Loop {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Invoke-GhLogin
        $status = Get-GhStatus
        if ($status.State -eq 'LoggedIn') { return $status }
        Write-Warn 'La connexion à GitHub n''a pas abouti.'
        if ($attempt -lt 3 -and -not (Read-YesNo 'Réessayer maintenant ?' $true)) { break }
    }
    throw (New-SetupError 'E-GH-CONNEXION' 'La connexion à ton compte GitHub n''a pas abouti.' 'La page du navigateur a peut-être été fermée, ou le code a expiré (il dure 15 minutes).' 'Relance le script et valide la page d''autorisation jusqu''au bout.')
}

function Invoke-ScopeRefresh($Status) {
    if ($null -eq $Status.Scopes) { return }
    $missing = @($script:GitHubScopes | Where-Object { $Status.Scopes -notcontains $_ })
    if (-not $missing.Count) { return }
    Write-Info "Ta connexion GitHub a besoin d'une autorisation de plus : lire ton e-mail, et envoyer des projets qui contiennent des tâches automatiques."
    Show-BrowserSteps
    $code = Invoke-Interactive 'gh' (@('auth', 'refresh', '--hostname', 'github.com', '--scopes', ($missing -join ',')) + @(Get-GhClipboardOption 'refresh'))
    if ($code -ne 0) {
        Write-Warn 'Autorisation non ajoutée. Ce n''est pas bloquant, mais ton e-mail principal ne sera peut-être pas proposé et certains envois vers GitHub pourront être refusés.'
    }
}

function Connect-GitHub {
    $status = Get-GhStatus
    switch ($status.State) {
        'Network' {
            throw (New-SetupError 'E-GH-RESEAU' 'GitHub ne répond pas.' 'Ta connexion GitHub n''a pas pu être vérifiée. Le détail est dans le journal.' 'Vérifie ta connexion internet, puis relance.')
        }
        'Expired' {
            Write-Warn 'Ta connexion GitHub sur ce PC a expiré : il faut simplement te reconnecter.'
            $status = Connect-Loop
        }
        'LoggedIn' {
            if ($script:State.login -ne $status.Login) {
                Write-Info "Ce PC est déjà connecté au compte GitHub « $($status.Login) »."
                if (-not (Read-YesNo 'Utiliser ce compte ?' $true)) {
                    Write-Info 'Si le navigateur est connecté à un autre compte, déconnecte-toi d''abord sur github.com.'
                    $status = Connect-Loop
                }
            }
        }
        default {
            if ($status.State -ne 'NotLoggedIn') {
                Write-Log 'INFO' 'État de connexion non reconnu : voir la sortie de gh ci-dessus.'
            }
            if (-not (Read-YesNo 'As-tu déjà un compte GitHub ?' $true)) {
                Write-Host ''
                Write-Info 'GitHub demande qu''une personne crée le compte elle-même : je t''ouvre la page officielle.'
                Write-Info '  - Choisis un e-mail, un mot de passe et un nom d''utilisateur.'
                Write-Info '  - Valide le code reçu par e-mail.'
                Write-Info '  - GitHub autorise un seul compte gratuit par personne.'
                Open-Url 'https://github.com/signup'
                Clear-TypedKeys
                [void](Read-Host 'Appuie sur Entrée quand le compte est créé et ton e-mail validé')
            }
            $status = Connect-Loop
        }
    }

    Invoke-ScopeRefresh $status
    if ($status.Storage -and $status.Storage -ne 'keyring') {
        Write-Warn "Ta connexion GitHub est enregistrée dans un fichier non chiffré ($($status.Storage)), car le coffre de Windows n'est pas disponible. Ne partage pas ce fichier."
    }
    Write-Ok "Connecté à GitHub : $($status.Login)"
    if ($script:State.login -ne $status.Login) {
        # Autre compte : les réponses précédentes ne valent plus. Sinon, ne pas redemander à la reprise.
        $script:State.login = $status.Login
        $script:State.name = $null
        $script:State.email = $null
        Save-State
    }
    return $status.Login
}

# --- Étape 3 : infos du compte ------------------------------------------------

function Get-GitHubAccount {
    # Ces réponses contiennent toutes les adresses du compte : elles restent hors du journal.
    $result = Invoke-Native 'gh' @('api', 'user') -Private
    if ($result.ExitCode -ne 0) {
        throw (New-SetupError 'E-GH-COMPTE' 'Impossible de lire les informations de ton compte GitHub.' 'GitHub n''a pas répondu ou a refusé la demande. Le détail est dans le journal.' 'Vérifie ta connexion internet, puis relance.')
    }
    # Sans ces champs, l'adresse des commits serait fausse : mieux vaut s'arrêter.
    $user = $null
    try { $user = $result.Output | ConvertFrom-Json } catch { Write-Log 'INFO' "Réponse de GitHub illisible : $($_.Exception.Message)" }
    if (-not $user -or -not $user.login -or -not $user.id) {
        throw (New-SetupError 'E-GH-COMPTE' 'Impossible de lire les informations de ton compte GitHub.' 'La réponse de GitHub est incomplète.' 'Relance le script. Si cela continue, envoie le journal à la personne qui t''aide.')
    }

    $primaryEmail = $null
    $mails = Invoke-Native 'gh' @('api', 'user/emails') -Private
    if ($mails.ExitCode -eq 0) {
        $list = $mails.Output | ConvertFrom-Json
        $primaryEmail = $list | Where-Object { $_.primary -and $_.verified } | Select-Object -First 1 -ExpandProperty email
    } else {
        Write-Log 'INFO' 'E-mail principal non lisible (autorisation user:email absente)'
    }

    # GitHub : les comptes créés avant le 18 juillet 2017 n'ont pas forcément cette adresse anonyme.
    $isOld = $false
    if ($user.created_at) {
        try { $isOld = ([datetime]$user.created_at -lt [datetime]'2017-07-18') } catch { }
    }

    return [pscustomobject]@{
        Login = $user.login; Id = $user.id; Name = $user.name; Url = $user.html_url
        PrimaryEmail = $primaryEmail
        NoReplyEmail = "$($user.id)+$($user.login)@users.noreply.github.com"
        IsOldAccount = $isOld
    }
}

# Les réglages lus (nom, e-mail) ne vont pas dans le journal : seule la réponse retenue y figure.
function Get-GitValue([string[]]$Arguments) {
    $result = Invoke-Native 'git' (@('config') + $Arguments) -Private
    if ($result.ExitCode -eq 0) { return $result.Output.Trim() }
    return ''
}

function Get-JjValue([string]$Key) {
    $result = Invoke-Native 'jj' @('config', 'get', $Key) -Private
    if ($result.ExitCode -eq 0) { return $result.Output.Trim() }
    return ''
}

function Select-CommitEmail($Account) {
    $options = New-Object System.Collections.Generic.List[string]
    $options.Add($Account.NoReplyEmail)
    foreach ($candidate in @($Account.PrimaryEmail, (Get-GitValue @('--global', '--get', 'user.email')))) {
        if ($candidate -and -not $options.Contains($candidate)) { $options.Add($candidate) }
    }
    if ($options.Count -eq 1) {
        Write-Info "Adresse affichée avec tes modifications : $($options[0]) (adresse anonyme fournie par GitHub : ton vrai e-mail reste privé)."
        return $options[0]
    }
    Write-Info 'Quelle adresse afficher avec tes modifications ?'
    for ($i = 0; $i -lt $options.Count; $i++) {
        $note = if ($i -eq 0) { '  (recommandé : adresse anonyme fournie par GitHub, ton vrai e-mail reste privé)' } else { '  (visible par tout le monde)' }
        # Write-Host : les adresses non retenues ne doivent pas aller dans le journal.
        Write-Host "       $($i + 1). $($options[$i])$note"
    }
    while ($true) {
        $choice = Read-WithDefault 'Ton choix' '1'
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $options.Count) {
            return $options[$number - 1]
        }
        Write-Host "Tape un chiffre entre 1 et $($options.Count)."
    }
}

function Save-AccountInfo($Account, [string]$Email) {
    $path = Join-Path $HOME 'github-compte.json'
    $json = [ordered]@{
        login = $Account.Login; id = $Account.Id; name = $Account.Name
        url = $Account.Url; commit_email = $Email
    } | ConvertTo-Json
    [IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function Set-Identity {
    $account = Get-GitHubAccount
    Write-Ok "Compte : $($account.Login) ($($account.Url))"

    $ask = $true
    if ($script:State.completed -and $script:State.name -and $script:State.email) {
        Write-Log 'INFO' 'Installation déjà terminée : aucune question sur le nom et l''e-mail.'
        $ask = $false
    } elseif ($script:State.name -and $script:State.email) {
        Write-Info "Tes réponses précédentes : $($script:State.name) <$($script:State.email)>"
        $ask = -not (Read-YesNo 'Garder ces réponses ?' $true)
    }
    if ($ask) {
        $default = Get-GitValue @('--global', '--get', 'user.name')
        if (-not $default) { $default = $account.Name }
        if (-not $default) { $default = $account.Login }
        $script:State.name = Read-CommitName $default
        $script:State.email = Select-CommitEmail $account
        $script:State.completed = $false
        Save-State
        if ($account.IsOldAccount -and $script:State.email -eq $account.NoReplyEmail) {
            Write-Warn 'Ton compte date d''avant juillet 2017 : pour que cette adresse anonyme fonctionne, va sur https://github.com/settings/emails et coche à nouveau « Keep my email addresses private ».'
        }
    }
    $commitEmail = $script:State.email
    if ($script:State.completed) {
        $current = Get-GitValue @('--global', '--get', 'user.email')
        if ($current) { $commitEmail = $current }
    }
    $path = Save-AccountInfo $account $commitEmail
    Write-Ok "Infos du compte enregistrées (sans ta clé d'accès) : $path"
}

# --- Étape 4 : configuration --------------------------------------------------

# jj analyse la valeur en TOML : la forme ''' garde un nom comme 12345 ou [Acme] en texte.
function ConvertTo-TomlLiteral([string]$Value) { return "'''$Value'''" }

function Get-JjEolValue {
    # Le réglage de Git n'est pas modifié : jj s'aligne dessus, comme sa doc le demande.
    switch ((Get-GitValue @('--get', 'core.autocrlf')).ToLower()) {
        'true'  { return 'input-output' }
        'input' { return 'input' }
        default { return 'none' }
    }
}

# Une fois l'installation terminée, un réglage changé à la main depuis est respecté.
function Test-KeepValue([string]$Current, [string]$Wanted) {
    if ($Current -ceq $Wanted) { return $true }
    if ($script:State.completed -and $Current) {
        Write-Log 'INFO' 'Réglage déjà présent et différent : conservé, car l''installation était terminée.'
        return $true
    }
    return $false
}

function Set-GitIdentity([string]$Key, [string]$Value, [string]$Purpose) {
    if (Test-KeepValue (Get-GitValue @('--global', '--get', $Key)) $Value) { return }
    # --replace-all : une ancienne configuration peut contenir plusieurs valeurs.
    Invoke-Checked 'git' @('config', '--global', '--replace-all', $Key, $Value) $Purpose
}

function Set-JjValue([string]$Key, [string]$Value, [string]$Purpose) {
    if (Test-KeepValue (Get-JjValue $Key) $Value) { return }
    Invoke-Checked 'jj' @('config', 'set', '--user', $Key, (ConvertTo-TomlLiteral $Value)) $Purpose
}

function Set-ToolConfig {
    $name = $script:State.name
    $email = $script:State.email
    Set-GitIdentity 'user.name' $name 'Impossible d''enregistrer ton nom dans Git.'
    Set-GitIdentity 'user.email' $email 'Impossible d''enregistrer ton e-mail dans Git.'

    $branch = Get-GitValue @('--global', '--get', 'init.defaultBranch')
    if (-not $branch) {
        Invoke-Checked 'git' @('config', '--global', 'init.defaultBranch', 'main') 'Impossible de régler la branche par défaut de Git.'
    } elseif ($branch -ne 'main') {
        Write-Info "Ta branche par défaut est « $branch » : je la laisse telle quelle."
    }

    Invoke-Checked 'gh' @('auth', 'setup-git', '--hostname', 'github.com') 'Impossible de relier Git à ta connexion GitHub.'

    Set-JjValue 'user.name' $name 'Impossible d''enregistrer ton nom dans Jujutsu.'
    Set-JjValue 'user.email' $email 'Impossible d''enregistrer ton e-mail dans Jujutsu.'
    Set-JjValue 'working-copy.eol-conversion' (Get-JjEolValue) 'Impossible d''aligner les fins de ligne de Jujutsu sur Git.'
    Write-Ok 'Git, GitHub CLI et Jujutsu sont configurés.'
}

# --- Étape 5 : vérification de bout en bout -----------------------------------

function Test-EndToEnd {
    $problems = New-Object System.Collections.Generic.List[string]
    $fixes = New-Object System.Collections.Generic.List[string]
    $network = 'Vérifie ta connexion internet, puis relance.'
    $retry = 'Relance le script. Si cela continue, envoie le journal à la personne qui t''aide.'

    if ((Get-GhStatus).State -ne 'LoggedIn') { $problems.Add('la connexion de GitHub CLI ne fonctionne pas'); $fixes.Add($network) }

    $env:GIT_TERMINAL_PROMPT = '0'
    $remote = Invoke-Native 'git' @('ls-remote', 'https://github.com/git/git.git', 'HEAD')
    if ($remote.ExitCode -ne 0) { $problems.Add('Git n''arrive pas à joindre GitHub'); $fixes.Add($network) }
    Remove-Item Env:\GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue

    # ls-remote sur un dépôt public marche sans compte : le lien avec gh se vérifie à part.
    $helper = Get-GitValue @('--global', '--get-all', 'credential.https://github.com.helper')
    if ($helper -notmatch 'auth git-credential') { $problems.Add('Git n''est pas relié à ta connexion GitHub'); $fixes.Add($retry) }

    # Find-Tool peut avoir ajouté un dossier pour cette session seulement.
    $stored = @(Get-StoredPathEntries | ForEach-Object { $_.TrimEnd('\') })
    foreach ($tool in $script:Tools) {
        $found = Get-Command $tool.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found -and $stored -notcontains (Split-Path $found.Source)) {
            $problems.Add("$($tool.Label) ne sera pas trouvé dans une nouvelle fenêtre")
            $fixes.Add("Désinstalle $($tool.Label) depuis Paramètres > Applications, puis relance : le script le réinstallera correctement.")
        }
    }

    # Nom court : jj crée des chemins très longs, et Windows limite souvent à 260 caractères.
    $temp = Join-Path $env:TEMP ('vjj' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        $init = Invoke-Native 'jj' @('git', 'init', $temp)
        if ($init.ExitCode -ne 0) {
            $problems.Add('Jujutsu n''arrive pas à créer un dépôt de test')
            $fixes.Add('Redémarre le PC, puis relance. Si cela continue, envoie le journal à la personne qui t''aide.')
        } else {
            $expected = if ($script:State.completed) { Get-JjValue 'user.email' } else { $script:State.email }
            $log = Invoke-Native 'jj' @('-R', $temp, 'log', '-r', '@', '--no-graph', '-T', 'author.email()')
            if ($log.ExitCode -ne 0 -or $log.Output.Trim() -ne $expected) {
                $problems.Add('Jujutsu n''utilise pas le bon e-mail')
                $fixes.Add($retry)
            }
        }
    } finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($problems.Count) {
        throw (New-SetupError 'E-VERIFICATION' 'La vérification finale a trouvé un problème.' ($problems -join ' ; ') (@($fixes | Select-Object -Unique) -join ' '))
    }
    Write-Ok 'Tout fonctionne : GitHub CLI, Git et Jujutsu ont passé leur test.'
}

# --- Essai à blanc ------------------------------------------------------------

function Show-DryRunPlan {
    Write-Step 'Ce qu''un vrai lancement ferait'
    if ($script:WingetToActivate) {
        Write-Plan 'Après ton accord : demande à Windows d''activer winget (Add-AppxPackage), puis installation avec winget'
    }
    foreach ($tool in $script:Tools) {
        switch (Get-ToolCondition $tool) {
            'Missing' { Write-Plan "winget $((Get-WingetCommandLine 'install' $tool.Id @(Get-InstallScope)) -join ' ')" }
            'Broken'  { Write-Plan "winget $((Get-WingetCommandLine 'install' $tool.Id (@(Get-InstallScope) + '--force')) -join ' ')" }
            'TooOld'  { Write-Plan "winget $((Get-WingetCommandLine 'upgrade' $tool.Id @()) -join ' ')" }
            default   { Write-Plan "$($tool.Label) : rien à faire" }
        }
    }
    if ($script:WingetReady -and -not $script:State.desktopDone) {
        Write-Plan "Question : installer GitHub Desktop ? Si oui : winget $((Get-WingetCommandLine 'install' 'GitHub.GitHubDesktop' @()) -join ' ')"
    }

    $scopeList = $script:GitHubScopes -join ','
    if (Test-Tool 'gh') {
        $status = Get-GhStatus
        if ($status.State -eq 'LoggedIn') {
            Write-Plan "Déjà connecté à GitHub : $($status.Login). Question : utiliser ce compte ?"
        } else {
            Write-Plan "Connexion : gh auth login --web --git-protocol https --hostname github.com --scopes $scopeList"
        }
    } else {
        Write-Plan 'Question : as-tu déjà un compte GitHub ? Si non : ouverture de https://github.com/signup'
        Write-Plan "Connexion : gh auth login --web --git-protocol https --hostname github.com --scopes $scopeList"
    }
    Write-Plan 'Lecture : gh api user ; gh api user/emails ; écriture de ~\github-compte.json'
    Write-Plan 'Questions : nom et e-mail à afficher dans les commits'
    Write-Plan 'git config --global : user.name, user.email, init.defaultBranch=main si absent'
    Write-Plan 'gh auth setup-git --hostname github.com'
    Write-Plan 'jj config set --user : user.name, user.email, working-copy.eol-conversion aligné sur core.autocrlf'
    Write-Plan 'Test final : gh auth status ; git ls-remote ; lien Git-GitHub ; PATH enregistré ; dépôt jj temporaire'
    Write-Host "`nEssai à blanc terminé : rien n'a été installé ni configuré." -ForegroundColor Green
    if ($script:LogPath) { Write-Host "Journal : $script:LogPath" }
}

# --- Programme principal ------------------------------------------------------

function Initialize-Files {
    New-Item -ItemType Directory -Force -Path $script:LogDir -ErrorAction Stop | Out-Null
    $script:LogPath = Join-Path $script:LogDir ('installation-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))
    Get-ChildItem $script:LogDir -Filter '*.log' | Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 19 | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log 'INFO' "Démarrage. DryRun=$DryRun Reset=$Reset Script=$PSCommandPath"
    Write-Log 'INFO' "Windows $([Environment]::OSVersion.Version) PowerShell $($PSVersionTable.PSVersion) Utilisateur=$env:USERNAME"
}

# Deux lancements en même temps se disputeraient la progression et winget.
function Enter-SingleRun {
    $script:RunLock = New-Object System.Threading.Mutex($false, 'Local\InstallationGitHubJJ')
    try {
        return $script:RunLock.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        return $true   # Le lancement précédent a été coupé brutalement : la place est libre.
    }
}

# Pour Installer.cmd : Ctrl+C peut rendre le code 0, seul ce fichier prouve que le script est allé au bout.
function Write-EndMarker {
    try { [IO.File]::WriteAllText((Join-Path $script:AppDir 'fin-du-script.txt'), "$script:ExitCode") } catch { }
}

function Invoke-Main {
    Initialize-Files
    if (-not (Enter-SingleRun)) {
        $script:ExitCode = 20
        Show-Failure 'E-DEJA-OUVERT' 'Le script est déjà ouvert dans une autre fenêtre.' 'Un seul lancement à la fois est possible.' 'Termine ou ferme l''autre fenêtre, puis relance.'
        return
    }
    if ($Reset -and -not $DryRun -and (Test-Path $script:StatePath)) {
        Remove-Item $script:StatePath -Force -ErrorAction Stop
        Write-Info 'Réponses enregistrées oubliées.'
    }
    $script:State = Read-State

    if ($DryRun) { Write-Plan 'Aucune installation ni configuration ne sera faite.' }
    if (-not (Invoke-Preflight)) {
        $script:ExitCode = 20
        return
    }
    if ($DryRun) {
        Show-DryRunPlan
        return
    }
    if (-not (Confirm-Start)) { return }
    if ($script:WingetToActivate -and -not (Invoke-WingetActivation)) {
        $script:ExitCode = 20
        return
    }
    if ($script:StateUnreadable) { Move-Item $script:StatePath "$script:StatePath.illisible" -Force -ErrorAction SilentlyContinue }

    Write-Step '1/5 - Installation des logiciels'
    foreach ($tool in $script:Tools) { Install-Tool $tool }
    Install-Desktop
    Complete-Step 'installation'

    Write-Step '2/5 - Compte GitHub'
    $login = Connect-GitHub
    Complete-Step 'compte'

    Write-Step '3/5 - Tes informations'
    Set-Identity
    Complete-Step 'informations'

    Write-Step '4/5 - Configuration'
    Set-ToolConfig
    Complete-Step 'configuration'

    Write-Step '5/5 - Vérification'
    Test-EndToEnd
    $script:State.completed = $true
    Complete-Step 'verification'

    Write-Host "`n=========== TERMINÉ ===========" -ForegroundColor Green
    Write-Host "Compte GitHub : $login"
    Write-Host "Tes commits   : $(Get-GitValue @('--global', '--get', 'user.name')) <$(Get-GitValue @('--global', '--get', 'user.email'))>"
    Write-Host 'Ouvre une nouvelle fenêtre de terminal avant d''utiliser git, gh ou jj.'
    Write-Host "Journal       : $script:LogPath"
}

try {
    Invoke-Main
} catch {
    $script:ExitCode = 10
    $failure = $_.Exception
    Write-Log 'TRACE' "$($_ | Out-String) $($_.ScriptStackTrace)"
    if ($failure.Data.Contains('Code')) {
        Show-Failure $failure.Data['Code'] $failure.Message $failure.Data['Why'] $failure.Data['Fix']
    } else {
        Show-Failure 'E-INATTENDU' 'Un problème imprévu est survenu.' 'Le détail technique est dans le journal.' 'Relance le script. Si cela continue, envoie le journal à la personne qui t''aide.'
    }
}
Write-EndMarker
Write-Log 'INFO' "Fin. Code de sortie $script:ExitCode"
exit $script:ExitCode
