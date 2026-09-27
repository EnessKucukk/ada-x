@echo off
if not exist "%~dp0medya-tuslari.ps1" (
  echo Once ZIP dosyasini bir klasore cikart: sag tikla, Tumunu ayikla.
  pause
  exit /b
)
start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0medya-tuslari.ps1"
