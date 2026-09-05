<#
.SYNOPSIS
    Make a plain `claude` start inside psmux (agent teams in split panes). Reversible with -Uninstall.

.DESCRIPTION
    Installs the wrapper (claude-wrapper.ps1, claude.cmd, claude, claude-team.cmd) into <config-dir>\bin,
    puts that folder at the front of the user PATH, and adds a `claude` function to the PowerShell profiles
    (Windows PowerShell 5.1 and PowerShell 7, all hosts) and to ~/.bashrc for Git Bash. The function is what
    takes precedence in interactive shells; the PATH entry covers cmd.exe and anything that resolves `claude`
    through PATH, as long as the real claude.exe is not on the *machine* PATH ahead of it (the script tells you).

    Nothing is written to settings.json. Each profile edit is a marked block between
    "# >>> claude-code-starter claude wrapper >>>" and "# <<< ... <<<" so -Uninstall can remove exactly that.
    Profile files keep their encoding and line endings; a file the installer created is deleted again by
    -Uninstall when nothing else was added to it.

.PARAMETER Source
    Folder holding claude-wrapper.ps1, claude.cmd, claude and Start-ClaudeTeam.ps1. Default: this script's folder.

.PARAMETER ConfigDir
    Claude Code config directory. Default: $env:CLAUDE_CONFIG_DIR, else ~\.claude.

.PARAMETER NoProfiles
    Only install the files and the PATH entry; do not touch PowerShell profiles or the bash files.

.PARAMETER Uninstall
    Remove the files, the PATH entry and the profile blocks.

.EXAMPLE
    .\Install-ClaudeWrapper.ps1
.EXAMPLE
    .\Install-ClaudeWrapper.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string]$Source = $PSScriptRoot,
    [string]$ConfigDir = $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }),
    [switch]$NoProfiles,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$MARK_START = '# >>> claude-code-starter claude wrapper >>>'
$MARK_END   = '# <<< claude-code-starter claude wrapper <<<'
$ConfigDir  = [IO.Path]::GetFullPath($ConfigDir)
$Source     = [IO.Path]::GetFullPath($Source)
$binDir     = Join-Path $ConfigDir 'bin'
$scriptsDir = Join-Path $ConfigDir 'scripts'
$docs       = [Environment]::GetFolderPath('MyDocuments')
$psProfiles = @((Join-Path $docs 'WindowsPowerShell\profile.ps1'), (Join-Path $docs 'PowerShell\profile.ps1'))
$utf8Bom    = New-Object System.Text.UTF8Encoding $true
$utf8NoBom  = New-Object System.Text.UTF8Encoding $false
$ansi       = try { [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage) } catch { [Text.Encoding]::Default }

# Git Bash resolves ~ from a HOME variable when one is set (MSYS nsswitch: env first), else from the profile folder.
$bashHome = $HOME
if ($env:HOME) {
    $h = $env:HOME
    if ($h -match '^/([A-Za-z])(/.*)?$') { $h = $Matches[1].ToUpper() + ':' + $(if ($Matches[2]) { $Matches[2] -replace '/', '\' } else { '\' }) }
    $bashHome = $h
}
$bashrc = Join-Path $bashHome '.bashrc'
# A login shell reads only the first of these that exists; the .bashrc sourcing line goes into that one.
$bashLoginFiles = @('.bash_profile', '.bash_login', '.profile') | ForEach-Object { Join-Path $bashHome $_ }

function Say([string]$m) { Write-Host $m }
function Warn([string]$m) { Write-Host "WARN:  $m" -ForegroundColor Yellow }

function ToPosixPath([string]$p) {
    $x = $p -replace '\\', '/'
    if ($x -match '^([A-Za-z]):/(.*)$') { return '/' + $Matches[1].ToLower() + '/' + $Matches[2] }
    return $x
}

# ---- text files: keep encoding and newline style ---------------------------------------------------------------
function Get-FileEncoding([byte[]]$b) {
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { return $utf8Bom }
    if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { return [Text.Encoding]::Unicode }
    if ($b.Length -ge 2 -and $b[0] -eq 0xFE -and $b[1] -eq 0xFF) { return [Text.Encoding]::BigEndianUnicode }
    try { [void](New-Object System.Text.UTF8Encoding $false, $true).GetString($b); return $utf8NoBom } catch { }
    return $ansi
}

function Read-TextFile([string]$path) {
    $b = [IO.File]::ReadAllBytes($path)
    $enc = Get-FileEncoding $b
    $pre = $enc.GetPreamble()
    $skip = 0
    if ($pre.Length -gt 0 -and $b.Length -ge $pre.Length) {
        $skip = $pre.Length
        for ($i = 0; $i -lt $pre.Length; $i++) { if ($b[$i] -ne $pre[$i]) { $skip = 0; break } }
    }
    $text = $enc.GetString($b, $skip, $b.Length - $skip)
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    return @{ Text = $text; Encoding = $enc; NewLine = $nl }
}

function Get-BlockSpan([string[]]$lines, [string]$path) {
    $starts = @(); $ends = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if ($t -eq $MARK_START) { $starts += $i } elseif ($t -eq $MARK_END) { $ends += $i }
    }
    if ($starts.Count -eq 0 -and $ends.Count -eq 0) { return $null }
    if ($starts.Count -ne 1 -or $ends.Count -ne 1 -or $ends[0] -lt $starts[0]) {
        throw "The wrapper markers in $path are damaged ($($starts.Count) start line(s), $($ends.Count) end line(s)). Remove everything from '$MARK_START' to '$MARK_END' by hand, then run this script again."
    }
    return @($starts[0], $ends[0])
}

function Remove-BlockText([string[]]$lines, [int[]]$span) {
    $s = $span[0]; $e = $span[1]
    if ($s -gt 0 -and $lines[$s - 1].Trim() -eq '') { $s-- }   # the blank separator line Add-Block inserted
    $keep = @()
    if ($s -gt 0) { $keep += $lines[0..($s - 1)] }
    if ($e -lt $lines.Count - 1) { $keep += $lines[($e + 1)..($lines.Count - 1)] }
    return $keep
}

# Returns 'removed', 'deleted' (the file held nothing else) or $false (no block / no file).
function Remove-Block([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $f = Read-TextFile $path
    $lines = $f.Text -split "`r?`n"
    $span = Get-BlockSpan $lines $path
    if (-not $span) { return $false }
    $new = (Remove-BlockText $lines $span) -join $f.NewLine
    if ($new.Trim().Length -eq 0) { Remove-Item -LiteralPath $path -Force; return 'deleted' }
    [IO.File]::WriteAllText($path, $new, $f.Encoding)
    return 'removed'
}

function Add-Block([string]$path, [string]$body, [string]$defaultNl, [System.Text.Encoding]$defaultEnc) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $text = ''; $nl = $defaultNl; $enc = $defaultEnc
    if (Test-Path -LiteralPath $path) {
        $f = Read-TextFile $path
        $text = $f.Text; $nl = $f.NewLine; $enc = $f.Encoding
        $lines = $text -split "`r?`n"
        $span = Get-BlockSpan $lines $path
        if ($span) { $text = (Remove-BlockText $lines $span) -join $nl }   # refresh an older block in place
    }
    $body = $body -replace "`r?`n", $nl
    $block = $MARK_START + $nl + $body + $nl + $MARK_END + $nl
    $text = $text.TrimEnd("`r", "`n")
    if ($text.Length -gt 0) { $text = $text + $nl + $nl + $block } else { $text = $block }
    # Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI: non-ASCII in the block (a Korean user name) needs the BOM.
    if ($path -like '*.ps1' -and $enc.GetPreamble().Length -eq 0 -and ($block -match '[^\x00-\x7F]')) { $enc = $utf8Bom }
    [IO.File]::WriteAllText($path, $text, $enc)
}

# ---- user PATH: edit the registry value directly so REG_EXPAND_SZ entries (%USERPROFILE%\...) stay unexpanded ---
function Send-EnvironmentChange {
    try {
        if (-not ('ClaudeWrapperInstaller.Native' -as [type])) {
            Add-Type -Namespace ClaudeWrapperInstaller -Name Native -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
'@
        }
        $r = [UIntPtr]::Zero
        [void][ClaudeWrapperInstaller.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
    } catch { }
}

function Set-UserPathEntry([string]$entry, [bool]$present) {
    $target = $entry.TrimEnd('\')
    $isTarget = { param($p) ($p -ne '') -and (([Environment]::ExpandEnvironmentVariables($p)).TrimEnd('\') -ieq $target) }
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try {
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        $raw = ''
        if ($key.GetValueNames() -contains 'Path') {
            $kind = $key.GetValueKind('Path')
            $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
        $items = @($raw -split ';')
        $found = @($items | Where-Object { & $isTarget $_ }).Count -gt 0
        $changed = $true
        if ($present -and $found -and (& $isTarget $items[0])) { $changed = $false }
        if (-not $present -and -not $found) { $changed = $false }
        if ($changed) {
            $rest = @($items | Where-Object { $_ -ne '' -and -not (& $isTarget $_) })
            $new = if ($present) { (@($entry) + $rest) -join ';' } else { $rest -join ';' }
            $key.SetValue('Path', $new, $kind)
            Send-EnvironmentChange
        }
    } finally { $key.Close() }
    # current process too
    $pp = @($env:Path -split ';' | Where-Object { $_ -ne '' -and -not (& $isTarget $_) })
    if ($present) { $pp = @($entry) + $pp }
    $env:Path = ($pp -join ';')
}

# The policy that applies to a normal shell, ignoring the Process scope (running this script with
# `-ExecutionPolicy Bypass` must not hide a Restricted machine).
function Get-PersistentExecutionPolicy([string]$shell) {
    $script = 'Get-ExecutionPolicy -List | ForEach-Object { "{0}={1}" -f $_.Scope, $_.ExecutionPolicy }'
    $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $lines = @(& $shell -NoProfile -NonInteractive -EncodedCommand $b64 2>$null) } finally { $ErrorActionPreference = $old }
    $map = @{}
    foreach ($l in $lines) { if ($l -match '^(\w+)=(\w+)$') { $map[$Matches[1]] = $Matches[2] } }
    foreach ($scope in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') {
        if ($map[$scope] -and $map[$scope] -ne 'Undefined') { return $map[$scope] }
    }
    return 'Restricted'   # every scope Undefined = the Windows client default
}

# ---------------------------------------------------------------------------------------------------------------
if ($Uninstall) {
    foreach ($f in 'claude-wrapper.ps1', 'claude.cmd', 'claude', 'claude-team.cmd') {
        $p = Join-Path $binDir $f
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Say "removed  $p" }
    }
    if ((Test-Path -LiteralPath $binDir) -and -not (Get-ChildItem -LiteralPath $binDir -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $binDir -Force; Say "removed  $binDir"
    }
    Set-UserPathEntry $binDir $false; Say "PATH     $binDir is no longer on the user PATH"
    foreach ($p in $psProfiles + @($bashrc) + $bashLoginFiles) {
        switch (Remove-Block $p) {
            'removed' { Say "profile  removed the block from $p" }
            'deleted' { Say "profile  deleted $p (it held nothing but the block)" }
        }
    }
    Say ''
    Say 'Done. Open a new terminal; `claude` is the real claude.exe again. Start-ClaudeTeam.ps1 was left in place.'
    exit 0
}

# ---- install files ----------------------------------------------------------------------------------------------
$needed = 'claude-wrapper.ps1', 'claude.cmd', 'claude'
foreach ($f in $needed) {
    if (-not (Test-Path -LiteralPath (Join-Path $Source $f))) { throw "missing in -Source ($Source): $f" }
}
if (-not (Test-Path -LiteralPath $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
foreach ($f in $needed) {
    Copy-Item -LiteralPath (Join-Path $Source $f) -Destination (Join-Path $binDir $f) -Force
    Say "installed $(Join-Path $binDir $f)"
}
# claude.cmd must be CRLF for cmd.exe; the sh shim must be LF for bash.
$cmdPath = Join-Path $binDir 'claude.cmd'
[IO.File]::WriteAllText($cmdPath, (([IO.File]::ReadAllText($cmdPath) -replace "`r?`n", "`r`n")), $utf8NoBom)
$shPath = Join-Path $binDir 'claude'
[IO.File]::WriteAllText($shPath, (([IO.File]::ReadAllText($shPath) -replace "`r`n", "`n")), $utf8NoBom)

# The launcher and this installer live in <config-dir>\scripts (the rollback command below points there).
if (-not (Test-Path -LiteralPath $scriptsDir)) { New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null }
foreach ($f in 'Start-ClaudeTeam.ps1', 'Install-ClaudeWrapper.ps1') {
    $src = Join-Path $Source $f
    $dst = Join-Path $scriptsDir $f
    if (Test-Path -LiteralPath $src) {
        if ([IO.Path]::GetFullPath($src) -ine [IO.Path]::GetFullPath($dst)) { Copy-Item -LiteralPath $src -Destination $dst -Force }
        Say "installed $dst"
    } elseif (-not (Test-Path -LiteralPath $dst)) {
        Warn "$f not found in -Source and not present at $dst."
        if ($f -eq 'Start-ClaudeTeam.ps1') { Warn 'Without the launcher the wrapper falls back to plain claude.' }
    }
}
$installedSelf = Join-Path $scriptsDir 'Install-ClaudeWrapper.ps1'
if (-not (Test-Path -LiteralPath $installedSelf)) { $installedSelf = $PSCommandPath }

# claude-team.cmd: explicit launcher entry point. %~dp0-relative so the path never has to be encoded for cmd.exe.
$teamCmd = Join-Path $binDir 'claude-team.cmd'
[IO.File]::WriteAllText($teamCmd, "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0..\scripts\Start-ClaudeTeam.ps1`" %*`r`n", $utf8NoBom)
Say "installed $teamCmd"

# ---- PATH -------------------------------------------------------------------------------------------------------
Set-UserPathEntry $binDir $true
Say "PATH      $binDir is first on the user PATH"

$real = Get-Command claude.exe -CommandType Application -All -ErrorAction SilentlyContinue |
    Where-Object { -not $_.Source.StartsWith($binDir, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
if ($real) {
    $realDir = (Split-Path -Parent $real.Source).TrimEnd('\')
    $machine = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | ForEach-Object { $_.TrimEnd('\') })
    if ($machine -icontains $realDir) {
        Warn "$realDir is on the MACHINE PATH, which Windows searches before the user PATH. In cmd.exe `claude` will still be"
        Warn "the real claude.exe; PowerShell and Git Bash use the profile function below, so they are covered."
    }
} else {
    Warn 'No claude.exe found on PATH. Install Claude Code (native build), then run this script again.'
}

# ---- shell profiles ---------------------------------------------------------------------------------------------
if (-not $NoProfiles) {
    $wrapperPath = Join-Path $binDir 'claude-wrapper.ps1'
    $psQuoted = "'" + ($wrapperPath -replace "'", "''") + "'"
    $psBody = "function claude { if (`$MyInvocation.ExpectingInput) { `$input | & $psQuoted @args } else { & $psQuoted @args } }"
    foreach ($p in $psProfiles) {
        Add-Block $p $psBody "`r`n" $utf8Bom
        Say "profile   $p"
    }
    $shQuoted = "'" + ((ToPosixPath $shPath) -replace "'", "'\''") + "'"
    $shBody = "claude() { $shQuoted `"`$@`"; }"
    Add-Block $bashrc $shBody "`n" $utf8NoBom
    Say "profile   $bashrc"
    # Git Bash opens a login shell, which reads ~/.bash_profile, else ~/.bash_login, else ~/.profile - not ~/.bashrc.
    $loginFile = $bashLoginFiles | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($loginFile) {
        if ((Read-TextFile $loginFile).Text -notmatch '\.bashrc') {
            Add-Block $loginFile '[ -f ~/.bashrc ] && . ~/.bashrc' "`n" $utf8NoBom
            Say "profile   $loginFile (now sources ~/.bashrc)"
        }
    } else {
        # Same content Git for Windows generates, so an existing ~/.profile keeps being read.
        Add-Block $bashLoginFiles[0] "[ -f ~/.profile ] && . ~/.profile`n[ -f ~/.bashrc ] && . ~/.bashrc" "`n" $utf8NoBom
        Say "profile   $($bashLoginFiles[0]) (created; sources ~/.profile and ~/.bashrc)"
    }
    foreach ($shell in 'powershell', 'pwsh') {
        if (-not (Get-Command $shell -CommandType Application -ErrorAction SilentlyContinue)) { continue }
        $pol = Get-PersistentExecutionPolicy $shell
        if ($pol -eq 'Restricted' -or $pol -eq 'AllSigned') {
            Warn "$shell execution policy is '$pol', so profile scripts do not load there and the claude function will not exist."
            Warn "Fix (once, current user only):  $shell -NoProfile -Command Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        }
    }
}

Say ''
Say 'Done. Open a NEW terminal, then:'
Say '  claude              -> starts inside a psmux session (teammates open in split panes)'
Say '  claude -p ... / claude mcp ... / claude --version -> the real claude.exe, unchanged'
Say '  CLAUDE_NO_PSMUX=1   -> escape hatch for one command'
Say '  CLAUDE_WRAPPER_DRYRUN=1 claude ...  -> prints which path would be taken'
Say "Rollback:  & `"$installedSelf`" -Uninstall"
