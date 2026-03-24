@ECHO OFF
SETLOCAL
powershell -NoProfile -ExecutionPolicy Bypass -Sta -File "%USERPROFILE%\.agent-hooks\agent-notify.ps1" %*
EXIT /B %ERRORLEVEL%
