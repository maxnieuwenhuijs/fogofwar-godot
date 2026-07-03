@echo off
rem ============================================================
rem  Fog of War — PARALLEL trainen (voor veel cores)
rem
rem  Start 6 aparte trainingsprocessen, één per factie. Elk proces
rem  schrijft naar zijn eigen bestand (data\ai_weights_f*.json);
rem  het spel voegt alles automatisch samen bij het laden.
rem
rem  Gebruik:  dubbelklik              = 480 min (nachtje), alle facties
rem            train_ai_parallel.bat 60 = 60 minuten
rem
rem  Stoppen: de vensters sluiten (of alles tegelijk: taskkill in dit
rem  venster met Ctrl+C beeindigt alleen dit venster; de werkers draaien
rem  door tot hun tijd om is). Elke verbetering is direct opgeslagen.
rem ============================================================
setlocal
set MIN=%1
if "%MIN%"=="" set MIN=480
set GODOT=%GODOT_PATH%
if "%GODOT%"=="" set GODOT=C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe
echo Start 6 parallelle trainers (%MIN% minuten elk)...
for %%F in (mens muis leeuw beer wolf vos) do (
    start "Train %%F" /min "%GODOT%" --headless --path "%~dp0." res://tools/capture.tscn -- train %MIN% 6 6 %%F
)
echo.
echo 6 trainingsvensters gestart (geminimaliseerd). Elk traint 1 factie.
echo Voortgang bekijken: klik een "Train ..."-venster in de taakbalk open.
echo Dit venster mag dicht.
pause
