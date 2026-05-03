@echo off

REM ═══════════════════════════════════════════════════════
REM  1. Yonetici Yetki Kontrolu (UAC Elevation)
REM    Cift tiklamada otomatik UAC penceresi acar.
REM    Zaten admin ise direkt devam eder.
REM ═══════════════════════════════════════════════════════
net session >nul 2>&1
if %errorlevel% equ 0 goto :ADMIN_OK

echo [!] Yonetici yetkisi gerekiyor, UAC isteniyor...
echo Start-Process -FilePath 'cmd.exe' -ArgumentList '/c "%~f0" %*' -Verb RunAs > "%TEMP%\_elevate.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\_elevate.ps1"
del "%TEMP%\_elevate.ps1" >nul 2>&1
exit /b

:ADMIN_OK
setlocal
title MrClean Sistem Bakim Araci

REM ═══════════════════════════════════════════════════════
REM  2. Dosya Varlik Kontrolu
REM ═══════════════════════════════════════════════════════
if not exist "%~dp0TemizlikAsistani.ps1" (
    echo [HATA] TemizlikAsistani.ps1 bulunamadi!
    echo Aranan konum: %~dp0TemizlikAsistani.ps1
    pause
    exit /b 1
)

REM ═══════════════════════════════════════════════════════
REM  3. Coklu Calisma Onleme (Process Kontrolu)
REM    Lock dosyasi yerine canli process kontrolu yapar.
REM    Crash durumunda process oldugu icin sorun olmaz.
REM ═══════════════════════════════════════════════════════
powershell -NoProfile -Command "if(Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" -EA 0 | Where-Object{$_.CommandLine -like '*TemizlikAsistani.ps1*' -and $_.ProcessId -ne $PID}){exit 1}else{exit 0}"
if %errorlevel% equ 1 (
    echo [!] Uygulama zaten calisiyor.
    pause
    exit /b 1
)

REM ═══════════════════════════════════════════════════════
REM  4. Calistirma
REM ═══════════════════════════════════════════════════════
if /I "%1"=="debug" goto :DEBUG_MODE

REM Normal mod: gizli pencere
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0TemizlikAsistani.ps1"
exit /b

:DEBUG_MODE
echo [DEBUG] TemizlikAsistani baslatiliyor...
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "%~dp0TemizlikAsistani.ps1"
echo.
echo [DEBUG] Islem tamamlandi. Cikis kodu: %errorlevel%
pause
exit /b
