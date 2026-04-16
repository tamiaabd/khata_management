@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if not %errorlevel%==0 (
  echo Please run this file as Administrator.
  pause
  exit /b 1
)

set "CERT_FILE=KhataManagement.cer"
set "MSIX_FILE=KhataManagement.msix"

if not exist "%CERT_FILE%" (
  echo Certificate file not found: %CERT_FILE%
  pause
  exit /b 1
)

if not exist "%MSIX_FILE%" (
  echo MSIX file not found: %MSIX_FILE%
  pause
  exit /b 1
)

echo Installing certificate to Trusted Root Certification Authorities...
certutil -addstore "Root" "%CERT_FILE%"
if errorlevel 1 (
  echo Root certificate installation failed.
  pause
  exit /b 1
)

echo Installing certificate to Trusted People...
certutil -addstore "TrustedPeople" "%CERT_FILE%"
if errorlevel 1 (
  echo Certificate installation failed.
  pause
  exit /b 1
)

echo Installing MSIX package...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-AppxPackage -Path '%~dp0%MSIX_FILE%'"
if errorlevel 1 (
  echo MSIX installation failed.
  pause
  exit /b 1
)

echo Installation completed successfully.
pause
