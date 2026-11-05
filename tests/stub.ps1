# Faux winget / gh / whoami. Tout est pilote par des variables STUB_* et des fichiers dans STUB_DIR.
param([Parameter(Position = 0)][string]$Tool, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$dir = $env:STUB_DIR
Add-Content (Join-Path $dir 'calls.log') "$Tool $($Rest -join ' ')" -Encoding UTF8

# Coupure brutale : tue le script (stub -> cmd -> PowerShell du script) a la commande demandee, une seule fois.
if ($env:STUB_KILL_ON -and "$Tool $($Rest -join ' ')" -like $env:STUB_KILL_ON -and -not (Test-Path (Join-Path $dir 'killed'))) {
    Set-Content (Join-Path $dir 'killed') 'x'
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
    $script = (Get-CimInstance Win32_Process -Filter "ProcessId=$cmd").ParentProcessId
    Stop-Process -Id $script -Force
    exit 1
}
function Out-Text([string]$t) { [Console]::Out.WriteLine($t) }
$line = $Rest -join ' '

switch ($Tool) {
    'whoami' {
        if ($env:STUB_STANDARD -eq '1') { Out-Text '"BUILTIN\Utilisateurs","Alias","S-1-5-32-545","x"' }
        else { Out-Text '"BUILTIN\Administrateurs","Alias","S-1-5-32-544","x"' }
        if ($env:STUB_ELEVATED -eq '1') { Out-Text '"Mandatory Label\High Mandatory Level","Nom","S-1-16-12288",""' }
        exit 0
    }
    'winget' {
        if ($line -eq '--version') { Out-Text $(if ($env:STUB_WINGET_VER) { $env:STUB_WINGET_VER } else { 'v1.29.380' }); exit 0 }
        if ($Rest[0] -eq 'error') { Out-Text 'Texte explicatif de winget'; exit 0 }
        $id = $Rest[$Rest.IndexOf('--id') + 1]
        Out-Text "Installation de $id"
        if ($env:STUB_FAIL_ID -eq $id) {
            $once = Join-Path $dir "failed-$id"
            $retryAllowed = ($env:STUB_FAIL_MODE -eq 'noscope' -and $Rest -contains '--scope')
            $firstOnly = ($env:STUB_FAIL_MODE -eq 'once' -and (Test-Path $once))
            if (-not $retryAllowed -and -not $firstOnly) {
                Set-Content $once 'x'
                exit ([int]$env:STUB_FAIL_CODE)
            }
        }
        $map = @{ 'Git.Git' = 'git'; 'GitHub.cli' = 'gh'; 'jj-vcs.jj' = 'jj' }
        if ($map[$id]) { Copy-Item (Join-Path $dir "bundle\$($map[$id]).cmd") (Join-Path $dir 'bin') }
        exit 0
    }
    'gh' {
        # Ce que voit le programme : c'est ce qui decide si gh ouvre le navigateur.
        if ($line -match '^auth (login|refresh) --' -and $line -notmatch '--help') {
            Add-Content (Join-Path $dir 'gh-tty.log') "$($Rest[1]) stdin=$([Console]::IsInputRedirected) stdout=$([Console]::IsOutputRedirected) stderr=$([Console]::IsErrorRedirected)"
        }
        $stateFile = Join-Path $dir 'gh-state'
        $state = if (Test-Path $stateFile) { (Get-Content $stateFile -Raw).Trim() } else { 'none' }
        if ($line -eq '--version') { Out-Text 'gh version 2.103.3 (2026-10-26)'; exit 0 }
        if ($line -like 'auth login --help*') { Out-Text '  -c, --clipboard  Copy code'; exit 0 }
        if ($line -like 'auth login*') {
            if ($env:STUB_LOGIN_FAIL -eq '1') { exit 1 }
            Set-Content $stateFile 'ok'
            Set-Content (Join-Path $dir 'gh-scopes') "'gist', 'read:org', 'repo', 'user:email', 'workflow'"
            exit 0
        }
        if ($line -eq 'auth refresh --help') { Out-Text '  -c, --clipboard  Copy code'; exit 0 }
        if ($line -like 'auth refresh*') {
            Set-Content (Join-Path $dir 'gh-scopes') "'gist', 'read:org', 'repo', 'user:email', 'workflow'"
            exit 0
        }
        if ($line -eq 'auth status --help') {
            if ($env:STUB_GH_OLD -ne '1') { Out-Text '  -a, --active  Display the active account only'; Out-Text '      --json fields  Output JSON' }
            exit 0
        }
        # Formats copies du vrai gh 2.103.3 (exit 0 dans tous les cas).
        if ($line -like 'auth status*' -and $line -match '--json') {
            if ($state -eq 'none') {
                [Console]::Error.WriteLine('You are not logged into any GitHub hosts. To log in, run: gh auth login')
                Out-Text '{"hosts":{}}'
                exit 0
            }
            $storage = if ($env:STUB_GH_STORAGE) { $env:STUB_GH_STORAGE } else { 'keyring' }
            $login = if ($env:STUB_GH_LOGIN) { $env:STUB_GH_LOGIN } else { 'octotest' }
            $common = '"active":true,"host":"github.com","login":"' + $login + '","tokenSource":"' + ($storage -replace '\\', '\\') + '","gitProtocol":"https"'
            $head = switch ($state) {
                'expired' { '"state":"error","error":"HTTP 401: Bad credentials (https://api.github.com/)"' }
                'network' { '"state":"error","error":"Get \"https://api.github.com/\": proxyconnect tcp: dial tcp 127.0.0.1:9: connectex: refused."' }
                'timeout' { '"state":"timeout","error":"timeout"' }
                'refreshexpired' { '"state":"refresh-expired","error":"expired"' }
                default {
                    $scopesFile = Join-Path $dir 'gh-scopes'
                    $scopes = if (Test-Path $scopesFile) { (Get-Content $scopesFile -Raw).Trim() } else { "'gist', 'read:org', 'repo'" }
                    '"state":"success","error":"","scopes":"' + ($scopes -replace "'", '') + '"'
                }
            }
            Out-Text ('{"hosts":{"github.com":[{' + $head + ',' + $common + '}]}}')
            exit 0
        }
        if ($line -like 'auth status*') {
            if ($state -eq 'none') { [Console]::Error.WriteLine('You are not logged into any GitHub hosts. To log in, run: gh auth login'); exit 1 }
            if ($state -eq 'expired') {
                Out-Text 'github.com'; Out-Text '  X Failed to log in to github.com account octotest (keyring)'; Out-Text '  - The token in keyring is invalid.'; exit 1
            }
            if ($state -eq 'network') { Out-Text '  X Timeout trying to log in to github.com account octotest (keyring)'; exit 1 }
            $storage = if ($env:STUB_GH_STORAGE) { $env:STUB_GH_STORAGE } else { 'keyring' }
            $login = if ($env:STUB_GH_LOGIN) { $env:STUB_GH_LOGIN } else { 'octotest' }
            $scopesFile = Join-Path $dir 'gh-scopes'
            $scopes = if (Test-Path $scopesFile) { (Get-Content $scopesFile -Raw).Trim() } else { "'gist', 'read:org', 'repo'" }
            Out-Text 'github.com'
            Out-Text "  v Logged in to github.com account $login ($storage)"
            Out-Text '  - Active account: true'
            Out-Text '  - Git operations protocol: https'
            Out-Text '  - Token: gho_SECRETSECRETSECRETSECRET'
            Out-Text '  - Autre: github_pat_SECRETPATSECRETPAT'
            Out-Text "  - Token scopes: $scopes"
            exit 0
        }
        if ($line -eq 'api user') {
            if ($env:STUB_API_FAIL -eq '1' -and -not (Test-Path (Join-Path $dir 'api-failed'))) {
                Set-Content (Join-Path $dir 'api-failed') 'x'
                [Console]::Error.WriteLine('HTTP 502: Bad Gateway'); exit 1
            }
            $name = if ($env:STUB_GH_NAME -eq 'NULL') { 'null' } elseif ($env:STUB_GH_NAME) { '"' + $env:STUB_GH_NAME + '"' } else { '"Jean Test"' }
            if ($env:STUB_API_EMPTY -eq '1') { Out-Text '{}'; exit 0 }
            if ($env:STUB_API_WARN -eq '1') { [Console]::Error.WriteLine('warning: something on stderr'); [Console]::Error.WriteLine('') }
            $created = if ($env:STUB_GH_CREATED) { $env:STUB_GH_CREATED } else { '2020-01-01T00:00:00Z' }
            Out-Text ('{"login":"octotest","id":12345,"name":' + $name + ',"html_url":"https://github.com/octotest","email":null,"created_at":"' + $created + '"}')
            exit 0
        }
        if ($line -eq 'api user/emails') {
            if ($env:STUB_EMAILS_FAIL -eq '1') { [Console]::Error.WriteLine('HTTP 403: scope'); exit 1 }
            Out-Text '[{"email":"jean@example.com","primary":true,"verified":true},{"email":"autre@example.com","primary":false,"verified":true}]'
            exit 0
        }
        if ($line -like 'auth setup-git*') {
            if ($env:STUB_SETUPGIT_NOOP -ne '1') { & git config --global --replace-all 'credential.https://github.com.helper' '!gh auth git-credential' }
            exit 0
        }
        [Console]::Error.WriteLine("stub gh: commande inconnue: $line"); exit 99
    }
}
