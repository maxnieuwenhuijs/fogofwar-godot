@echo off
rem ============================================================
rem  Fog of War — Arena: "wie wint tegen wie"
rem
rem  Speelt elke doctrine-matchup met het huidige (getrainde)
rem  profiel en print een winrate-matrix + ranglijst.
rem  Resultaat ook in data\arena_results.txt.
rem
rem  Gebruik:  dubbelklik              = 20 potjes/richting, medium
rem            arena.bat 40            = 40 potjes/richting
rem            arena.bat 20 hard       = 20 potjes/richting, Hard-AI
rem ============================================================
setlocal
set PER=%1
if "%PER%"=="" set PER=20
set LVL=%2
if "%LVL%"=="" set LVL=medium
set GODOT=%GODOT_PATH%
if "%GODOT%"=="" set GODOT=C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe
"%GODOT%" --headless --path "%~dp0." res://tools/capture.tscn -- arena %PER% %LVL%
pause
