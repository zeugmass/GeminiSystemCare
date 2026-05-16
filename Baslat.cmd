@echo off

REM ═══════════════════════════════════════════════════════
REM  MrClean Launcher (v1.2.7 — EXE oncelikli)
REM
REM  Akis:
REM   1. UAC elevation
REM   2. Coklu calisma kontrolu (process tarama)
REM   3. EXE varsa onu baslat (production), yoksa PS1'i baslat (development fallback)
REM
REM  GUNLUK KULLANIM ICIN: bu dosyayi cift tiklamak yerine
REM  dogrudan TemizlikAsistani.exe'yi cift tiklamaniz daha temizdir.
REM  EXE icinde -RequireAdmin flag'i var, UAC otomatik acilir.
REM  Bu Baslat.cmd ek olarak "zaten calisiyor mu" kontrolu yapar.
REM ═══════════════════════════════════════════════════════

REM 1. UAC kontrolu
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

REM 2. Dosya varlik kontrolu — EXE varsa onu kullan, yoksa PS1'e fallback
set "EXEPATH=%~dp0TemizlikAsistani.exe"
set "PS1PATH=%~dp0TemizlikAsistani.ps1"
set "TARGET="

if exist "%EXEPATH%" (
    set "TARGET=EXE"
) else if exist "%PS1PATH%" (
    set "TARGET=PS1"
) else (
    echo [HATA] Ne TemizlikAsistani.exe ne de TemizlikAsistani.ps1 bulundu!
    echo Aranan konum: %~dp0
    pause
    exit /b 1
)

REM 3. Coklu calisma kontrolu — EXE veya PS1 zaten calisiyor mu?
powershell -NoProfile -Command "$exe = Get-Process -Name TemizlikAsistani -ErrorAction SilentlyContinue; $ps1 = Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" -EA 0 | Where-Object{$_.CommandLine -like '*TemizlikAsistani.ps1*' -and $_.ProcessId -ne $PID}; if ($exe -or $ps1) { exit 1 } else { exit 0 }"
if %errorlevel% equ 1 (
    echo [!] MrClean zaten calisiyor (gorev cubugu/system tray'de kontrol edin).
    pause
    exit /b 1
)

REM 4. Calistir
if /I "%1"=="debug" goto :DEBUG_MODE

if "%TARGET%"=="EXE" (
    start "" "%EXEPATH%"
    exit /b
) else (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS1PATH%"
    exit /b
)

:DEBUG_MODE
echo [DEBUG] MrClean baslatiliyor...
if "%TARGET%"=="EXE" (
    "%EXEPATH%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "%PS1PATH%"
)
echo.
echo [DEBUG] Islem tamamlandi. Cikis kodu: %errorlevel%
pause
exit /b
