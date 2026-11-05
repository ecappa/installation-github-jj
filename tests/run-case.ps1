# Lance le script dans un processus isole, avec des reponses scriptees et des pannes simulees.
param([string]$Target)
$Answers = $env:STUB_ANSWERS
$ScriptArgs = "$env:STUB_SCRIPTARGS"
$global:queue = New-Object Collections.Queue
if ($Answers) { foreach ($x in ($Answers -split '\|')) { $global:queue.Enqueue($x) } }
function global:Read-Host($p) {
    if (-not $global:queue.Count) { Write-Host "QUESTION-EN-TROP: $p"; throw "Question non prevue : $p" }
    $a = $global:queue.Dequeue(); Write-Host "$p > '$a'"; $a
}
function global:Start-Process($u) {
    if ($env:STUB_NO_BROWSER -eq '1') { throw 'Pas de navigateur' }
    Write-Host "OPEN $u"; Add-Content (Join-Path $env:STUB_DIR 'opened.log') $u
}
function global:Invoke-WebRequest {
    param($Uri, $Method, [switch]$UseBasicParsing, $TimeoutSec, $ErrorAction)
    if ($env:STUB_NET_FAIL -eq '1') { throw (New-Object Net.WebException('Echec simule')) }
}
# Le vrai PATH du registre n'est jamais lu : il donnerait acces au vrai winget de ce PC.
function global:Get-ItemProperty { param($Path, $Name, $ErrorAction)
    if ($Path -like 'HKLM:*') { return [pscustomobject]@{ Path = 'C:\Windows\System32;C:\Windows' } }
    if ($env:STUB_BIN_NOT_STORED -eq '1') { return [pscustomobject]@{ Path = "$env:STUB_DIR\fixed" } }
    [pscustomobject]@{ Path = "$env:STUB_DIR\bin;$env:STUB_DIR\fixed\" }
}
function global:Add-AppxPackage { param([switch]$RegisterByFamilyName, $MainPackage, $ErrorAction)
    Add-Content (Join-Path $env:STUB_DIR 'appx.log') 'register'
    if ($env:STUB_APPX_FAIL -eq '1') { throw 'Refus simule' }
    Copy-Item (Join-Path $env:STUB_DIR 'winget-activable.cmd') (Join-Path $env:STUB_DIR 'fixed\winget.cmd')
}
function global:Get-PSDrive { param($Name, $ErrorAction)
    $free = if ($env:STUB_FREE_GB) { [double]$env:STUB_FREE_GB } else { 100 }
    [pscustomobject]@{ Free = [double]($free * 1GB) }
}
if ($env:STUB_OTHER_OWNER) {
    function global:Invoke-CimMethod { param($InputObject, $MethodName, $ErrorAction) [pscustomobject]@{ User = $env:STUB_OTHER_OWNER } }
}
$splat = @{}
foreach ($s in ($ScriptArgs -split ' ')) { if ($s) { $splat[$s] = $true } }
& $Target @splat
exit $LASTEXITCODE
