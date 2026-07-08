@echo off
rem ============================================================
rem  Fog of War - Model rechtdraaien (kwartslag-fix)
rem
rem  Sleep een .glb-model OP dit bestand, of:
rem     fix_model.bat assets\models\mouse\infantry_spd.glb
rem
rem  Draait de kwartslag-detector over alle clips: wat ~90/180 graden
rem  gedraaid staat (bayonet/hit/ready) wordt teruggedraaid, bedoelde
rem  poses (fire/idle-aanslag) blijven. Overschrijft het model zelf.
rem  Daarna in Godot 1x importeren (editor openen of --import).
rem ============================================================
setlocal
set MODEL=%~1
if "%MODEL%"=="" (
    echo Sleep een .glb-model op dit bestand, of geef het pad als argument.
    pause
    exit /b
)
set BLENDER=%BLENDER_PATH%
if "%BLENDER%"=="" set BLENDER=C:\Program Files\Blender Foundation\Blender 5.1\blender.exe
echo Rechtdraaien: %MODEL%
"%BLENDER%" --background --python "%~dp0tools\blender_merge_character.py" -- --base "%MODEL%" --gibs
echo.
echo Klaar. Vergeet niet in Godot te importeren (editor openen).
pause
