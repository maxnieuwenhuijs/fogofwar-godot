@echo off
rem ============================================================
rem  Fog of War - AI-training (parallel: 1 proces per factie)
rem
rem  Gebruik:  dubbelklik           = 480 min (8 uur, nachtrun)
rem            train_ai.bat 60      = 60 minuten
rem            train_ai.bat test    = 4 min proefrun + automatische controle
rem
rem  Elk proces schrijft bij ELKE verbetering direct naar zijn eigen
rem  data\ai_weights_f*.json (het spel merget die automatisch) en
rem  schrijft aan het einde zijn rapport naar data\matchup_*.txt.
rem  Stoppen mag altijd (vensters sluiten): voortgang blijft bewaard.
rem ============================================================
setlocal
set MIN=%1
set TESTMODE=0
if "%MIN%"=="" set MIN=480
if /i "%MIN%"=="test" set MIN=4
if /i "%1"=="test" set TESTMODE=1
set GODOT=%GODOT_PATH%
if "%GODOT%"=="" set GODOT=C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe

rem Slaapstand op netstroom UIT: een slapende pc bevroor de nachtrun van
rem 7 juli (nul resultaten). Terugzetten kan later met bv.:
rem    powercfg /change standby-timeout-ac 30
powercfg /change standby-timeout-ac 0 >nul 2>&1
echo Slaapstand (netstroom) staat uit zodat de run niet bevriest.
echo.

echo Start 6 parallelle trainers (%MIN% minuten elk)...
for %%F in (mens muis leeuw beer wolf vos) do (
    start "Train %%F" /min "%GODOT%" --headless --path "%~dp0." res://tools/capture.tscn -- train %MIN% 6 6 %%F
)
echo.
echo 6 trainingsvensters gestart (geminimaliseerd), 1 per factie.

if "%TESTMODE%"=="0" (
    echo Voortgang bekijken: open een "Train ..."-venster via de taakbalk.
    echo Dit venster mag dicht.
    pause
    exit /b
)

echo.
echo PROEFRUN: wacht ~8 minuten en controleer dan of alle 6 trainers
echo hun rapport hebben weggeschreven...
set /a WACHT=%MIN%*60+420
timeout /t %WACHT% /nobreak
powershell -NoProfile -Command "$sinds=(Get-Date).AddMinutes(-(%MIN%+15)); $m=@(Get-ChildItem 'data\matchup_*.txt' | Where-Object {$_.LastWriteTime -gt $sinds}); $w=@(Get-ChildItem 'data\ai_weights_f*.json' | Where-Object {$_.LastWriteTime -gt $sinds}); Write-Host ''; Write-Host ('Rapporten vers geschreven : ' + $m.Count + ' van 6'); Write-Host ('Gewichten bijgewerkt      : ' + $w.Count + ' van 6  (0 kan bij zo een korte run: geen adoptie gevonden)'); if ($m.Count -eq 6) { Write-Host 'RESULTAAT: OK - de parallelle training werkt.' -ForegroundColor Green } else { Write-Host 'RESULTAAT: FOUT - niet alle trainers schreven hun rapport. Open een Train-venster voor details.' -ForegroundColor Red }"
pause
