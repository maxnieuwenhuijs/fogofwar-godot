@echo off
rem ============================================================
rem  Fog of War - Model rechtdraaien EN gibs genereren
rem
rem  Sleep een .glb-model OP dit bestand, of:
rem     fix_model_gibs.bat assets\models\mouse\infantry_mix.glb
rem
rem  Zelfde als fix_model.bat, maar genereert daarna ook
rem  <model>_gibs.glb uit de losse mesh-delen (statisch, zonder
rem  armature). Je hoeft dus GEEN aparte gibs-export uit Blender
rem  te doen - die zou toch skinned zijn en werkt niet.
rem  LET OP: overschrijft een bestaande <model>_gibs.glb!
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
echo Rechtdraaien + gibs: %MODEL%
"%BLENDER%" --background --python "%~dp0tools\blender_merge_character.py" -- --base "%MODEL%" --gibs
echo.
echo Klaar. Vergeet niet in Godot te importeren (editor openen).
pause
