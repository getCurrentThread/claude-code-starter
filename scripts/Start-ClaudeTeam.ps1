<#
.SYNOPSIS
    Start Claude Code inside a psmux session so Agent Teams teammates open in split panes (native Windows, no WSL).

.DESCRIPTION
    Claude Code only splits panes when (a) it was started inside a tmux-compatible session ($env:TMUX set),
    (b) a `tmux` executable is on PATH, and (c) teammateMode is "tmux" (or "auto") in settings.json.
    psmux (winget: marlocarlo.psmux) provides (a) and (b) on Windows. This script checks the prerequisites,
    creates or re-attaches a psmux session that starts in the project directory, and launches `claude`
    in the first pane.

.PARAMETER Dir
    Project directory for the session. Default: current directory.

.PARAMETER Session
    psmux session name. Default: the project folder's name (dots and colons replaced). If a session with that name
    already exists *in the same folder* and no claude arguments were given, you are re-attached to it; otherwise a
    new session named <name>-2, -3, ... is created. Keep exactly one psmux session while a team is running.

.PARAMETER NoClaude
    Open the psmux session only; do not start claude automatically.

.PARAMETER KeepPane
    Leave the pane's shell open after claude exits. Default: the pane closes and the session ends, like a plain
    `claude` would (if claude exited with an error the pane waits for Enter so you can read it).

.PARAMETER DebugLog
    Start claude with --debug-file %TEMP%\claude_debug.log (grep it for TeammateModeSnapshot / BackendRegistry).

.PARAMETER Quiet
    Suppress the informational lines (warnings are still shown). Used by the claude wrapper.

.PARAMETER ClaudeArgs
    Extra arguments passed to claude, e.g. -ClaudeArgs '--model','opus'.

.EXAMPLE
    Start-ClaudeTeam.ps1
.EXAMPLE
    Start-ClaudeTeam.ps1 -Dir C:\src\myrepo -Session myrepo -DebugLog
#>
[CmdletBinding()]
param(
    [string]$Dir = (Get-Location).ProviderPath,
    [string]$Session = '',
    [switch]$NoClaude,
    [switch]$KeepPane,
    [switch]$DebugLog,
    [switch]$Quiet,
    [string[]]$ClaudeArgs = @()
)

$ErrorActionPreference = 'Stop'

function Fail([string]$msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Warn([string]$msg) { Write-Host "WARN:  $msg" -ForegroundColor Yellow }
function Info([string]$msg) { if (-not $Quiet) { Write-Host "       $msg" -ForegroundColor DarkGray } }

# 1. Never nest: Claude Code snapshots TMUX at startup and a nested psmux confuses pane targeting.
if ($env:TMUX) { Fail "This shell is already inside psmux/tmux (TMUX=$env:TMUX). Open a fresh terminal tab and run again." }

# 2. Tools on PATH. psmux ships psmux.exe, pmux.exe and tmux.exe; Claude Code looks up `tmux` by name.
#    Always take the first hit: under PowerShell 7, Get-Command can return several (pwsh lists its own package
#    folder and the Store alias), and an array where one path is expected ends up as extra arguments.
$psmux = Get-Command psmux -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $psmux) { Fail "psmux not found on PATH. Install it:  winget install --id marlocarlo.psmux --exact   (then open a new terminal)" }
$tmux = Get-Command tmux -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $tmux) { Fail "tmux alias not found on PATH (psmux normally installs it next to psmux.exe). Reinstall psmux or add its folder to PATH." }

# The real claude.exe: CLAUDE_REAL_EXE, else the first claude.exe on PATH outside the wrapper's bin folder.
$realExe = $null
if ($env:CLAUDE_REAL_EXE -and (Test-Path -LiteralPath $env:CLAUDE_REAL_EXE)) { $realExe = $env:CLAUDE_REAL_EXE }
if (-not $realExe) {
    $configBin = Join-Path (Split-Path -Parent $PSScriptRoot) 'bin'
    $realExe = Get-Command claude.exe -CommandType Application -All -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Source } |
        Where-Object { -not $_.StartsWith($configBin, [StringComparison]::OrdinalIgnoreCase) } |
        Select-Object -First 1
}
if (-not $realExe) {
    $fallback = Join-Path $HOME '.local\bin\claude.exe'
    if (Test-Path -LiteralPath $fallback) { $realExe = $fallback }
}
if (-not $realExe) { Fail "claude.exe not found on PATH. Install Claude Code first." }

# Query commands only: their stderr ("no server running") is discarded and must not become a terminating error
# (Windows PowerShell 5.1 + ErrorActionPreference Stop). Never use this for new-session: the server it spawns
# inherits the client's redirected stderr pipe and dies with it as soon as the client exits.
function Invoke-Psmux {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $psmux.Source @args 2>$null } finally { $ErrorActionPreference = $old }
}

# 3. Settings sanity (read-only; nothing is written here). teammateMode follows Claude Code's precedence:
#    <project>\.claude\settings.local.json > <project>\.claude\settings.json > <config-dir>\settings.json.
$Dir = (Resolve-Path -LiteralPath $Dir).ProviderPath
$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$settingsPath = Join-Path $configDir 'settings.json'
$teamsEnabled = ($env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -eq '1')
$mode = $null; $modeSource = $settingsPath
foreach ($f in @((Join-Path $Dir '.claude\settings.local.json'), (Join-Path $Dir '.claude\settings.json'), $settingsPath)) {
    if (-not (Test-Path -LiteralPath $f)) { continue }
    try {
        $s = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
        if ($s.env -and $s.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -eq '1') { $teamsEnabled = $true }
        if (-not $mode -and $s.PSObject.Properties['teammateMode'] -and $s.teammateMode) { $mode = [string]$s.teammateMode; $modeSource = $f }
    } catch { Warn "Could not parse $f ($($_.Exception.Message)); skipping it." }
}
if (-not $teamsEnabled) { Warn "Agent teams are not enabled. Add to settings.json:  ""env"": { ""CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"": ""1"" }" }
if ($mode -ne 'tmux' -and $mode -ne 'auto') {
    Warn "teammateMode is '$mode' (default in-process). Split panes need ""teammateMode"": ""tmux"" in $settingsPath (top-level key)."
}

# 4. Directory checks and default session name.
if ($Dir.TrimEnd('\') -ieq $HOME.TrimEnd('\')) {
    Warn "Starting from the user profile folder: Claude Code rejects executables located under its working directory, and psmux lives under %LOCALAPPDATA%. Use a project folder."
}
if (-not $Session) {
    # tmux target syntax uses ':' and '.', so they cannot appear in a session name.
    $Session = ([IO.Path]::GetFileName($Dir.TrimEnd('\')) -replace '[^A-Za-z0-9_\-]', '-').Trim('-')
    if (-not $Session) { $Session = 'claude' }
}

# 5. Re-attach or pick a free name. Attaching silently would drop -ClaudeArgs and could land in another project
#    that happens to have the same folder name, so only attach when the folder matches and nothing else was asked.
$base = $Session
$n = 1
while ($true) {
    Invoke-Psmux has-session -t $Session
    if ($LASTEXITCODE -ne 0) { break }
    $panePath = [string](Invoke-Psmux display-message -p -t $Session '#{pane_current_path}' | Select-Object -First 1)
    $sameDir = (-not $panePath) -or ($panePath.TrimEnd('\') -ieq $Dir.TrimEnd('\'))
    if ($sameDir -and $ClaudeArgs.Count -eq 0 -and -not $DebugLog -and -not $NoClaude) {
        Write-Host "psmux session '$Session' already exists in this folder - attaching to it (claude is not restarted; Ctrl+b d detaches)."
        & $psmux.Source attach -t $Session
        exit $LASTEXITCODE
    }
    if ($sameDir) {
        Warn "psmux session '$Session' already exists in this folder; starting a new one because arguments were given. Re-attach to the old one with:  psmux attach -t $Session"
    } else {
        Warn "psmux session '$Session' already exists but runs in '$panePath'; using another name."
    }
    $n++
    $Session = "$base-$n"
}

$others = @()
try { $others = @(Invoke-Psmux ls | Where-Object { $_ -match '\S' }) } catch { $others = @() }
if ($others.Count -gt 0) {
    Warn "Other psmux sessions are running; teammate pane targets (%N) can be misrouted with more than one session:"
    $others | ForEach-Object { Warn "  $_" }
    Warn "Stop them with:  psmux kill-server   (after /exit in any Claude session inside them)"
}

$psmuxVersion = @(Invoke-Psmux -V)
Info "psmux  : $($psmux.Source)  ($(if ($psmuxVersion.Count) { $psmuxVersion[0] } else { '?' }))"
Info "claude : $realExe"
Info "dir    : $Dir"
Info "session: $Session"

if ($NoClaude) {
    & $psmux.Source new-session -d -s $Session -c $Dir
    if ($LASTEXITCODE -ne 0) { Fail "psmux new-session failed (exit $LASTEXITCODE)." }
} else {
    # The pane's first process is a PowerShell that runs claude.exe directly (psmux still sets TMUX/TMUX_PANE on
    # it). -EncodedCommand carries the whole command line as base64, so quotes, spaces, '$' and non-ASCII in the
    # arguments survive PowerShell 5.1's native-argument quoting. When claude exits the shell exits with it and the
    # pane closes, unless -KeepPane asked for an interactive shell to remain (-NoExit).
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $argv = @()
    if ($DebugLog) { $argv += '--debug-file'; $argv += (Join-Path $env:TEMP 'claude_debug.log') }
    $argv += $ClaudeArgs
    $inner = "& $(& $q $realExe)"
    if ($argv.Count) { $inner += ' ' + (($argv | ForEach-Object { & $q $_ }) -join ' ') }
    if (-not $KeepPane) {
        $inner += "; if (`$LASTEXITCODE) { Read-Host ('claude exited with code ' + `$LASTEXITCODE + ' - press Enter to close') }"
    }
    $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner))
    $shell = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $shell) { $shell = Get-Command powershell -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $shell) { Fail 'Neither pwsh nor powershell was found on PATH.' }
    $shellArgs = @('-NoLogo', '-NoProfile')
    if ($KeepPane) { $shellArgs += '-NoExit' }
    $shellArgs += @('-EncodedCommand', $b64)
    # Plain call on purpose (no stderr redirect): see Invoke-Psmux.
    & $psmux.Source new-session -d -s $Session -c $Dir -- $shell.Source @shellArgs
    if ($LASTEXITCODE -ne 0) { Fail "psmux new-session failed (exit $LASTEXITCODE)." }
    Info "Started: $inner"
}

# Wait for the session to be registered before attaching.
$ready = $false
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 200
    Invoke-Psmux has-session -t $Session
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
}
if (-not $ready) { Fail "Session '$Session' is not running. If claude exited at once, run again with -KeepPane to read its output." }

Info "Keys: Ctrl+b then Arrow = move between panes | Ctrl+b z = zoom | Ctrl+b d = detach | Ctrl+b Ctrl+b = send Ctrl+B to Claude"
& $psmux.Source attach -t $Session
$rc = $LASTEXITCODE
if (-not $Quiet) {
    Write-Host ""
    Info "Detached or session ended. Sessions:  psmux ls   |  stop everything:  psmux kill-server"
}
exit $rc
