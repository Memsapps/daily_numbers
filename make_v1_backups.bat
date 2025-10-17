@echo off
setlocal ENABLEDELAYEDEXPANSION

REM === Daily Numbers - V1 backup helper ===
REM Place this file inside your Flutter project folder (e.g., C:\Users\mehme\daily_numbers)
REM Then double-click it. It will create:
REM   1) ..\%PROJECT%-v1.0.0.zip
REM   2) ..\%PROJECT%-v1.0.0.bundle   (only if Git is installed)

REM Go to the folder that contains this script.
pushd "%~dp0"
set "PROJDIR=%CD%"

for %%F in ("%CD%") do set "PROJNAME=%%~nF"
for /f %%a in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd')"') do set "YYYYMMDD=%%a"

set "ZIP=..\%PROJNAME%-v1.0.0.zip"
set "BUNDLE=..\%PROJNAME%-v1.0.0.bundle"

echo.
echo ===========================================
echo   Backing up: %PROJNAME%   [%PROJDIR%]
echo   Date: %YYYYMMDD%
echo ===========================================
echo.

REM --- Create ZIP (always) ---
echo [1/2] Creating ZIP: %ZIP%
powershell -NoProfile -Command "Compress-Archive -Path '%PROJDIR%\*' -DestinationPath '%ZIP%' -Force -CompressionLevel Optimal"
if errorlevel 1 (
  echo [!] ZIP creation failed. You can also right-click the folder in Explorer and "Compress to ZIP".
) else (
  echo [OK] ZIP created: %ZIP%
)

REM --- Create Git bundle (if git available) ---
where git >nul 2>&1
if errorlevel 1 (
  echo [i] Git not found on PATH. Skipping git bundle.
) else (
  echo.
  echo [2/2] Creating Git bundle: %BUNDLE%
  git init >nul 2>&1
  git add -A >nul 2>&1
  git commit -m "v1.0.0: First playable build (3-8, up/down only, no persistence)" >nul 2>&1
  git tag -f v1.0.0 >nul 2>&1
  git bundle create "%BUNDLE%" --all
  if errorlevel 1 (
    echo [!] Git bundle failed. Ensure you have write permissions.
  ) else (
    echo [OK] Git bundle created: %BUNDLE%
  )
)

echo.
echo === Done ===
echo Files (if no errors):
echo   %ZIP%
echo   %BUNDLE%
echo.
echo To restore from the bundle on any machine:
echo   1) mkdir restore ^& cd restore
echo   2) git clone --bundle "..\%PROJNAME%-v1.0.0.bundle" .
echo   3) git checkout v1.0.0
echo.
echo Press any key to close...
pause >nul

popd
endlocal
