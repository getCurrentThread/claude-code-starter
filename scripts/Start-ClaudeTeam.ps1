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
    psmux session name. Default: work. Keep exactly one psmux session while a team is running.

.PARAMETER NoClaude
    Open the psmux session only; do not start claude automatically.

.PARAMETER DebugLog
    Start claude with --debug-file %TEMP%\claude_debug.log (grep it for TeammateModeSnapshot / BackendRegistry).

.PARAMETER ClaudeArgs
    Extra arguments passed to claude, e.g. -ClaudeArgs '--model','opus'.

.EXAMPLE
    Start-ClaudeTeam.ps1
.EXAMPLE
    Start-ClaudeTeam.ps1 -Dir C:\src\myrepo -Session myrepo -DebugLog
#>
[CmdletBinding()]
param(
    [string]$Dir = (Get-Location).Path,
    [string]$Session = 'work',
    [switch]$NoClaude,
    [switch]$DebugLog,
    [string[]]$ClaudeArgs = @()
)

$ErrorActionPreference = 'Stop'

function Fail([string]$msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Warn([string]$msg) { Write-Host "WARN:  $msg" -ForegroundColor Yellow }
function Info([string]$msg) { Write-Host "       $msg" -ForegroundColor DarkGray }

# 1. Never nest: Claude Code snapshots TMUX at startup and a nested psmux confuses pane targeting.
if ($env:TMUX) { Fail "This shell is already inside psmux/tmux (TMUX=$env:TMUX). Open a fresh terminal tab and run again." }

# 2. Tools on PATH. psmux ships psmux.exe, pmux.exe and tmux.exe; Claude Code looks up `tmux` by name.
$psmux = Get-Command psmux -CommandType Application -ErrorAction SilentlyContinue
if (-not $psmux) { Fail "psmux not found on PATH. Install it:  winget install --id marlocarlo.psmux --exact   (then open a new terminal)" }
$tmux = Get-Command tmux -CommandType Application -ErrorAction SilentlyContinue
if (-not $tmux) { Fail "tmux alias not found on PATH (psmux normally installs it next to psmux.exe). Reinstall psmux or add its folder to PATH." }
$claude = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue
if (-not $claude) { Fail "claude not found on PATH. Install Claude Code first." }

# 3. Settings sanity (read-only; nothing is written here).
$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$settingsPath = Join-Path $configDir 'settings.json'
$teamsEnabled = ($env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -eq '1')
$mode = $null
if (Test-Path -LiteralPath $settingsPath) {
    try {
        $s = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        if ($s.env -and $s.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -eq '1') { $teamsEnabled = $true }
        $mode = $s.teammateMode
    } catch { Warn "Could not parse $settingsPath ($($_.Exception.Message)); skipping settings checks." }
}
if (-not $teamsEnabled) { Warn "Agent teams are not enabled. Add to settings.json:  ""env"": { ""CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"": ""1"" }" }
if ($mode -ne 'tmux' -and $mode -ne 'auto') {
    Warn "teammateMode is '$mode' (default in-process). Split panes need ""teammateMode"": ""tmux"" in $settingsPath (top-level key)."
}

# 4. Directory checks.
$Dir = (Resolve-Path -LiteralPath $Dir).Path
if ($Dir.TrimEnd('\') -ieq $HOME.TrimEnd('\')) {
    Warn "Starting from the user profile folder: Claude Code rejects executables located under its working directory, and psmux lives under %LOCALAPPDATA%. Use a project folder."
}

# 5. Create or re-attach.
& $psmux.Source has-session -t $Session 2>$null
$exists = ($LASTEXITCODE -eq 0)
if ($exists) {
    Info "Session '$Session' exists - attaching (claude is not restarted)."
    & $psmux.Source attach -t $Session
    exit $LASTEXITCODE
}

$others = @()
try { $others = @(& $psmux.Source ls 2>$null | Where-Object { $_ -match '\S' }) } catch { $others = @() }
if ($others.Count -gt 0) {
    Warn "Other psmux sessions are running; teammate pane targets (%N) can be misrouted with more than one session:"
    $others | ForEach-Object { Info $_ }
    Info "Stop them with:  psmux kill-server   (after /exit in any Claude session inside them)"
}

Info "psmux  : $($psmux.Source)  ($((& $psmux.Source -V | Select-Object -First 1)))"
Info "claude : $($claude.Source)"
Info "dir    : $Dir"
Info "session: $Session"

& $psmux.Source new-session -d -s $Session -c $Dir
if ($LASTEXITCODE -ne 0) { Fail "psmux new-session failed (exit $LASTEXITCODE)." }

# Wait for the pane shell to be ready before typing into it.
$ready = $false
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 200
    & $psmux.Source has-session -t $Session 2>$null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
}
if (-not $ready) { Fail "Session '$Session' did not come up." }

if (-not $NoClaude) {
    $cmd = 'claude'
    if ($DebugLog) { $cmd += ' --debug-file "$env:TEMP\claude_debug.log"' }
    foreach ($a in $ClaudeArgs) {
        if ($a -match '[\s"]') { $cmd += " '" + ($a -replace "'", "''") + "'" } else { $cmd += " $a" }
    }
    # The pane runs psmux's default shell (pwsh). Give the shell a moment to print its prompt, then type the command.
    Start-Sleep -Milliseconds 800
    & $psmux.Source send-keys -t "${Session}:0.0" -l $cmd
    & $psmux.Source send-keys -t "${Session}:0.0" Enter
    Info "Started: $cmd"
}

Info "Keys: Ctrl+b then Arrow = move between panes | Ctrl+b z = zoom | Ctrl+b d = detach | Ctrl+b Ctrl+b = send Ctrl+B to Claude"
& $psmux.Source attach -t $Session
$rc = $LASTEXITCODE
Write-Host ""
Info "Detached or session ended. Sessions:  psmux ls   |  stop everything:  psmux kill-server"
exit $rc
