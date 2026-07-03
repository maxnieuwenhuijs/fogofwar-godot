@echo off
rem ============================================================
rem  Fog of War — Train de AI (headless, geen dashboard nodig)
rem
rem  Gebruik:  dubbelklik            = 60 minuten trainen
rem            train_ai.bat 480      = 8 uur (nachtje) trainen
rem
rem  Stoppen mag altijd (Ctrl+C of venster sluiten): elke
rem  verbetering is dan al opgeslagen in data\ai_weights.json.
rem  Het spel gebruikt dat bestand automatisch.
rem ============================================================
setlocal
set MIN=%1
if "%MIN%"=="" set MIN=60
set GODOT=%GODOT_PATH%
if "%GODOT%"=="" set GODOT=C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe
echo Training gestart voor %MIN% minuten... (Ctrl+C = stoppen, voortgang blijft bewaard)
"%GODOT%" --headless --path "%~dp0." res://tools/capture.tscn -- train %MIN%
pause
