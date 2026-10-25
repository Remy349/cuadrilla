@echo off
rem cuadrilla - runs cuadrilla.ps1 next to this file (see: cuadrilla help)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cuadrilla.ps1" %*
exit /b %ERRORLEVEL%
