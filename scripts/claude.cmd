@echo off
setlocal
set "_ps=powershell"
where /q pwsh.exe && set "_ps=pwsh"
%_ps% -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-wrapper.ps1" %*
endlocal & exit /b %ERRORLEVEL%
