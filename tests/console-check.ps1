# Verifie dans une VRAIE console ce que les tests simules ne peuvent pas voir.
#   -Mode Tty  : Invoke-Interactive donne bien la console au programme lance (aucun reseau).
#   -Mode Gh   : le vrai gh ouvre-t-il le navigateur ? Demande un code a GitHub (jamais valide) et
#                touche au presse-papiers (le texte est remis ensuite). Aucun compte, config isolee.
param([ValidateSet('Tty', 'Gh')][string]$Mode = 'Tty', [string]$Inner = '')
$base = Split-Path $PSScriptRoot
$work = Join-Path $base 'boxes\console'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

if (-not $Inner) {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $work | Out-Null
    $saved = $null
    if ($Mode -eq 'Gh') { $saved = Get-Clipboard -Raw -ErrorAction SilentlyContinue }
    # -WindowStyle Hidden : une console propre existe, sans fenetre visible.
    Start-Process $ps -WindowStyle Hidden -Wait -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Mode', $Mode, '-Inner', 'run'
    if ($Mode -eq 'Gh') {
        if ($saved) { Set-Clipboard -Value $saved }
    }
    Get-ChildItem $work -File | ForEach-Object { "--- $($_.Name)"; Get-Content $_.FullName -Encoding UTF8 }
    return
}

# Charge seulement les fonctions utiles depuis le script final.
$target = Join-Path $base 'build\setup-github-jj.ps1'
$ast = [Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$null)
foreach ($name in 'Invoke-Interactive') {
    . ([scriptblock]::Create($ast.Find({ param($x) $x -is [Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $name }, $true).Extent.Text))
}
function Write-Log { }

if ($Mode -eq 'Tty') {
    $probe = Join-Path $work 'probe.ps1'
    Set-Content $probe @"
"stdin_redirige=`$([Console]::IsInputRedirected) stdout_redirige=`$([Console]::IsOutputRedirected) stderr_redirige=`$([Console]::IsErrorRedirected)" | Set-Content '$work\handles.txt'
exit 7
"@
    # Meme forme d'appel que le script : resultat capture par une variable.
    $code = Invoke-Interactive 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $probe)
    "code=$code type=$($code.GetType().Name)" | Set-Content "$work\result.txt"
    return
}

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public static class Con {
  [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)] public struct KEY {
    [FieldOffset(0)] public short EventType; [FieldOffset(4)] public int Down; [FieldOffset(8)] public short Repeat;
    [FieldOffset(10)] public short Vk; [FieldOffset(12)] public short Scan; [FieldOffset(14)] public char Ch; [FieldOffset(16)] public int Ctrl; }
  [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr CreateFile(string n, uint a, uint s, IntPtr p, uint d, uint f, IntPtr t);
  [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool WriteConsoleInput(IntPtr h, KEY[] b, int n, out int w);
  [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool ReadConsoleOutputCharacter(IntPtr h, StringBuilder b, int n, int coord, out int r);
  public static void Enter() {
    IntPtr h = CreateFile("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    KEY d = new KEY(); d.EventType = 1; d.Down = 1; d.Repeat = 1; d.Vk = 13; d.Scan = 28; d.Ch = '\r';
    KEY u = d; u.Down = 0; int w; WriteConsoleInput(h, new KEY[]{d,u}, 2, out w);
  }
  public static string Screen() {
    IntPtr h = CreateFile("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    StringBuilder all = new StringBuilder();
    for (int y = 0; y < 60; y++) { StringBuilder b = new StringBuilder(120); int r; ReadConsoleOutputCharacter(h, b, 120, y << 16, out r); string s = b.ToString().TrimEnd(); if (s.Length > 0) all.AppendLine(s); }
    return all.ToString();
  }
}
'@

# Config isolee : aucun effet sur un eventuel vrai compte. Le faux navigateur note juste l'adresse.
$env:GH_CONFIG_DIR = Join-Path $work 'ghconfig'
$env:GIT_CONFIG_GLOBAL = Join-Path $work 'gitconfig'
$opened = Join-Path $work 'navigateur-ouvert.txt'
$browser = Join-Path $work 'browser.cmd'
Set-Content $browser "@echo %1 > `"$opened`"" -Encoding Ascii
# gh decoupe cette valeur comme un shell : les barres obliques inverses seraient avalees.
$env:GH_BROWSER = $browser -replace '\\', '/'
$env:Path = "$base\tools\gh\bin;$base\tools\mingit\cmd;$env:Path"

$observer = [PowerShell]::Create()
[void]$observer.AddScript({
    param($Opened, $Work)
    $journal = New-Object Collections.ArrayList
    for ($i = 0; $i -lt 40 -and -not (Test-Path $Opened); $i++) {
        Start-Sleep -Seconds 3
        [void]$journal.Add("--- ecran a $(($i + 1) * 3) s, puis Entree ---")
        [void]$journal.Add([Con]::Screen())
        [Con]::Enter()
    }
    Start-Sleep -Seconds 2
    [void]$journal.Add('--- ecran final ---')
    [void]$journal.Add([Con]::Screen())
    $journal | Set-Content (Join-Path $Work 'ecran.txt') -Encoding UTF8
    Get-Process gh -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$(Split-Path $Work -Parent | Split-Path -Parent)*" } | Stop-Process -Force
}).AddArgument($opened).AddArgument($work)
$handle = $observer.BeginInvoke()
# Exactement les arguments du script.
$code = Invoke-Interactive 'gh' @('auth', 'login', '--web', '--git-protocol', 'https', '--hostname', 'github.com', '--scopes', 'user:email,workflow', '--clipboard')
[void]$observer.EndInvoke($handle)
"code_gh=$code navigateur_ouvert=$(Test-Path $opened)" | Set-Content "$work\result.txt"
