@echo off
rem ============================================================
rem  Fog of War - Arena v1 (F1.2): standalone runner + metrics
rem  Gebruik:  arena.bat [configpad]
rem  Multi-proces: gebruik arena.ps1 (1 proces per core + merge).
rem  Het oude capture-arena-pad blijft bestaan als
rem  "capture.tscn -- arena <n> <level>" (zie arena.bat.oud).
rem ============================================================
setlocal
set CONFIG=%~1
if "%CONFIG%"=="" set CONFIG=arena/arena_configs/quick_l1.json
set GODOT=%GODOT_PATH%
if "%GODOT%"=="" set GODOT=C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe
"%GODOT%" --headless --path . res://arena/arena.tscn -- --config %CONFIG% --out results/losse_run
if "%FOW_NOPAUSE%"=="" pause
