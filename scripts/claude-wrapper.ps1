# claude-wrapper.ps1 - makes a plain `claude` start inside a psmux session so agent teams open in split panes.
# Everything that must not run in a pane falls through to the real claude.exe unchanged.
#
# Entry points that call this file: bin\claude.cmd (cmd.exe / PowerShell via PATH), bin\claude (Git Bash via PATH),
# and the `claude` function that Install-ClaudeWrapper.ps1 adds to the PowerShell profiles.
#
# No param() block on purpose: every argument lands in $args untouched, including ones that start with '-'.
#
# Environment knobs (a value of 0 / false / no / off counts as unset):
#   CLAUDE_NO_PSMUX=1           always run the real claude.exe (escape hatch)
#   CLAUDE_REAL_EXE=<path>      use this claude.exe instead of the first one found on PATH
#   CLAUDE_WRAPPER_NEWWINDOW=1  open the psmux session in a new terminal window (the Git Bash shim sets it under
#                               mintty, which is not a Windows console)
#   CLAUDE_WRAPPER_DRYRUN=1     print the decision and exit without running anything
#   CLAUDE_WRAPPER_LOG=<file>   append one line per invocation with the inputs and the decision (troubleshooting)
#   CLAUDE_WRAPPER_CLEAR_ENV    space-separated variable names a shim exported for its own use; they are removed from
#                               the environment before claude starts so they do not leak into its session

$ErrorActionPreference = 'Stop'
$argv = @($args)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { [IO.Path]::Combine($HOME, '.claude') }

# The launcher is looked up next to this file first (<config-dir>\bin -> <config-dir>\scripts), so an installation
# made with -ConfigDir keeps working even when CLAUDE_CONFIG_DIR is not set in this shell.
$launcher = $null
foreach ($cand in @(
        [IO.Path]::Combine($here, 'Start-ClaudeTeam.ps1'),
        [IO.Path]::Combine((Split-Path -Parent $here), 'scripts', 'Start-ClaudeTeam.ps1'),
        [IO.Path]::Combine($configDir, 'scripts', 'Start-ClaudeTeam.ps1'))) {
    if (Test-Path -LiteralPath $cand) { $launcher = $cand; break }
}
if (-not $launcher) { $launcher = [IO.Path]::Combine($configDir, 'scripts', 'Start-ClaudeTeam.ps1') }

# Subcommands: never interactive, never in a pane. (claude 2.1.261 `--help`, plus the hidden sandbox / remote-control.)
$SUBCOMMANDS = @('agents','attach','auth','auto-mode','doctor','gateway','import','install','logs','mcp','plugin',
    'plugins','project','respawn','rm','sandbox','setup-token','stop','kill','ultrareview','update','upgrade',
    'remote-control','rc')
# Flags that mean "not a normal interactive session", "the caller already decided the teammate mode", or
# "claude manages its own tmux session / runs the work remotely".
$PASSTHROUGH_FLAGS = @('-p','--print','-h','--help','-v','-V','--version','--teammate-mode','--agent-id',
    '--agent-name','--team-name','--bare','--output-format','--input-format','--sdk-url','--bg','--background',
    '--tmux','--cloud','--environment')

function Test-EnvFlag([string]$name) {
    $v = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($v)) { return $false }
    return (@('0','false','no','off') -notcontains $v.Trim())
}

function Find-RealClaude {
    if ($env:CLAUDE_REAL_EXE -and (Test-Path -LiteralPath $env:CLAUDE_REAL_EXE)) { return $env:CLAUDE_REAL_EXE }
    $found = @(Get-Command claude.exe -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
    foreach ($f in $found) {
        if (-not $f.StartsWith($here, [StringComparison]::OrdinalIgnoreCase)) { return $f }
    }
    $fallback = [IO.Path]::Combine($HOME, '.local', 'bin', 'claude.exe')
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    return $null
}

function Get-TeammateMode([string]$cwd) {
    # Same precedence Claude Code uses for these files: project local > project > user. First value found wins.
    $files = @(
        [IO.Path]::Combine($cwd, '.claude', 'settings.local.json'),
        [IO.Path]::Combine($cwd, '.claude', 'settings.json'),
        [IO.Path]::Combine($configDir, 'settings.json'))
    foreach ($f in $files) {
        if (-not (Test-Path -LiteralPath $f)) { continue }
        try {
            $j = Get-Content -LiteralPath $f -Raw | ConvertFrom-Json
            if ($j.PSObject.Properties['teammateMode'] -and $j.teammateMode) { return [string]$j.teammateMode }
        } catch { }
    }
    return 'in-process'
}

function Get-PassthroughReason([string]$cwd) {
    if (Test-EnvFlag 'CLAUDE_NO_PSMUX') { return 'CLAUDE_NO_PSMUX is set' }
    if ($env:TMUX) { return 'already inside psmux/tmux' }
    if ($env:CLAUDECODE) { return 'running inside another Claude Code session' }
    # The Git Bash shim sets CLAUDE_WRAPPER_NEWWINDOW after checking its own tty; under mintty this process
    # only sees pipes, so the console test below would be wrong there.
    if (-not (Test-EnvFlag 'CLAUDE_WRAPPER_NEWWINDOW')) {
        try {
            if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return 'stdin/stdout is not a terminal' }
        } catch { }
    }
    # commander accepts global options before the subcommand (`claude --verbose mcp list`), so any bare word that
    # equals a subcommand name counts. Quote prompts that contain such a word.
    foreach ($a in $argv) {
        $s = [string]$a
        if ($s.StartsWith('-')) { continue }
        if ($SUBCOMMANDS -ccontains $s) { return "subcommand '$s'" }
    }
    foreach ($a in $argv) {
        $name = ([string]$a).Split('=')[0]
        if ($PASSTHROUGH_FLAGS -ccontains $name) { return "flag '$name'" }
    }
    if (-not $cwd) { return 'the current location is not a file system folder' }
    if (-not (Get-Command tmux -CommandType Application -ErrorAction SilentlyContinue)) {
        return 'psmux is not installed (winget install --id marlocarlo.psmux --exact)'
    }
    if (-not (Test-Path -LiteralPath $launcher)) { return "launcher not found: $launcher" }
    $mode = Get-TeammateMode $cwd
    if ($mode -ne 'tmux' -and $mode -ne 'auto') {
        return "teammateMode is '$mode' (set ""teammateMode"": ""tmux"" in settings.json for split panes)"
    }
    return $null
}

function Clear-ShimEnv {
    # Variables a shim exported only to get this far (MSYS path-conversion switches, the new-window flag) must not
    # reach claude.exe, or Claude Code's own Bash tool would inherit them for the whole session.
    $names = @()
    if ($env:CLAUDE_WRAPPER_CLEAR_ENV) { $names += @($env:CLAUDE_WRAPPER_CLEAR_ENV -split '\s+' | Where-Object { $_ }) }
    $names += 'CLAUDE_WRAPPER_CLEAR_ENV'
    foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $null, 'Process') }
}

function Write-WrapperLog([string]$m) {
    if ($env:CLAUDE_WRAPPER_LOG) {
        try { Add-Content -LiteralPath $env:CLAUDE_WRAPPER_LOG -Value ("{0} ps  {1}" -f (Get-Date -Format HH:mm:ss), $m) } catch { }
    }
}

$loc = Get-Location
$dir = if ($loc.Provider.Name -eq 'FileSystem') { $loc.ProviderPath } else { $null }
$real = Find-RealClaude
$reason = Get-PassthroughReason $dir
$dryRun = Test-EnvFlag 'CLAUDE_WRAPPER_DRYRUN'
$newWindow = Test-EnvFlag 'CLAUDE_WRAPPER_NEWWINDOW'
$redir = try { "$([Console]::IsInputRedirected)/$([Console]::IsOutputRedirected)" } catch { '?' }
Write-WrapperLog "argv: $($argv -join ' ') | real=$real | redirected(in/out)=$redir TERM_PROGRAM=$env:TERM_PROGRAM NEWWINDOW=$env:CLAUDE_WRAPPER_NEWWINDOW CLEAR_ENV=$env:CLAUDE_WRAPPER_CLEAR_ENV | decision: $(if ($reason) { "PASSTHROUGH ($reason)" } else { 'PSMUX' })"

if ($reason) {
    if ($dryRun) { Write-Output "PASSTHROUGH ($reason) -> $real $($argv -join ' ')"; exit 0 }
    if (-not $real) { [Console]::Error.WriteLine('claude wrapper: the real claude.exe was not found on PATH.'); exit 127 }
    if ($reason -like 'psmux is not installed*' -or $reason -like 'teammateMode is*' -or $reason -like 'launcher not found*') {
        [Console]::Error.WriteLine("claude wrapper: $reason - starting claude without split panes.")
    }
    Clear-ShimEnv
    # A native command's stderr must not become a terminating error when the caller redirects it (PowerShell 5.1).
    $ErrorActionPreference = 'Continue'
    if ($MyInvocation.ExpectingInput) { $input | & $real @argv } else { & $real @argv }
    exit $LASTEXITCODE
}

if ($dryRun) {
    $where = if ($newWindow) { 'new terminal window' } else { 'this terminal' }
    Write-Output "PSMUX ($where) -> $launcher -Dir $dir -ClaudeArgs $($argv -join ' ')"
    exit 0
}

Clear-ShimEnv
# From here on a Windows console is guaranteed (this one, or the new window below). An inherited TERM_PROGRAM=mintty
# (Windows Terminal started from Git Bash keeps it) is wrong for that console and breaks psmux's server startup.
if ($env:TERM_PROGRAM -eq 'mintty') { [Environment]::SetEnvironmentVariable('TERM_PROGRAM', $null, 'Process') }

if (-not $newWindow) {
    & $launcher -Dir $dir -Quiet -ClaudeArgs $argv
    exit $LASTEXITCODE
}

# New window: mintty (Git Bash's own terminal) has no Windows console, which the psmux client needs.
# Pass everything through -EncodedCommand so no quoting survives the trip through wt.exe / cmd.
$q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
$argList = if ($argv.Count) { '@(' + (($argv | ForEach-Object { & $q $_ }) -join ',') + ')' } else { '@()' }
$cmd = "& $(& $q $launcher) -Dir $(& $q $dir) -Quiet -ClaudeArgs $argList"
$b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
$psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$b64)
$wt = Get-Command wt.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wt) {
    # A trailing backslash would escape the closing quote on the wt.exe command line (drive roots such as C:\).
    $dirArg = $dir; if ($dirArg.EndsWith('\')) { $dirArg += '\' }
    Start-Process -FilePath $wt.Source -ArgumentList (@('-w','new','-d',('"' + $dirArg + '"'),'powershell') + $psArgs)
} else {
    Start-Process -FilePath 'powershell' -ArgumentList $psArgs -WorkingDirectory $dir
}
[Console]::Error.WriteLine('claude wrapper: opened the psmux session in a new terminal window (this terminal has no Windows console).')
exit 0
