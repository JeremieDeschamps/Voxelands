@echo off
title Voxelands
cd /d Z:\
echo ========================================================
echo   Lancement de Voxelands...
echo ========================================================
echo.
"C:\Users\re_wa\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERREUR] Code de sortie : %ERRORLEVEL%
    pause
)
