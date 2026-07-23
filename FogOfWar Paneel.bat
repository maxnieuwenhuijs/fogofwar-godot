@echo off
rem Fog of War - controlepaneel starten (dubbelklik dit bestand).
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0paneel.ps1"
