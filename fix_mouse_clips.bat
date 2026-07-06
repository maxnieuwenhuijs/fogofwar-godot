@echo off
rem ============================================================
rem  Fog of War - muis-clips herstellen na een Blender-export
rem
rem  Jouw mouse1.blend mist de attack/die-clips; elke export van
rem  infantry_base.glb wist ze dus. Dubbelklik dit bestand na
rem  ELKE export en ze worden er weer op gezet (uit je Downloads:
rem  Firing Rifle (3) / Rifle Death (1) / Death From Front
rem  Headshot (1)). Daarna is het spel meteen weer compleet.
rem ============================================================
setlocal
set BLENDER=C:\Program Files\Blender Foundation\Blender 5.1\blender.exe
set DL=C:\Users\maxni\Downloads
"%BLENDER%" --background --python "%~dp0tools\blender_merge_character.py" -- ^
  --base "%~dp0assets\models\mouse\infantry_base.glb" ^
  "attack=%DL%\Firing Rifle (3).fbx" ^
  "die=%DL%\Rifle Death (1).fbx" ^
  "die2=%DL%\Death From Front Headshot (1).fbx"
echo.
echo Klaar - attack/die/die2 staan er weer op.
pause
