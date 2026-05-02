# =========================================================
# GEMINI SYSTEM CARE - LAUNCHER (BAŞLATICI)
# =========================================================
# NOT: Asıl auto-update mantığı ana programın (TemizlikAsistani.ps1) içine
# entegre edilmiştir. Bu launcher dosyası eskiden GitHub'dan PS1 indiriyordu;
# yeni mimaride GitHub Releases üzerinden EXE indirme + SHA256 doğrulama +
# updater script ile self-replace yapılır.
#
# Bu dosya artık sadece eski kullanıcılar için minimal bir köprü olarak
# tutulmuştur. Yeni kullanım: Baslat.cmd → TemizlikAsistani.exe (veya .ps1)
# =========================================================

$localFolder = "$env:APPDATA\GeminiCare"
if (-not (Test-Path $localFolder)) { New-Item -Path $localFolder -ItemType Directory -Force | Out-Null }

# Ana dosyayı bul ve çalıştır (öncelik: EXE → PS1)
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

$exePath = Join-Path $scriptDir "TemizlikAsistani.exe"
$ps1Path = Join-Path $scriptDir "TemizlikAsistani.ps1"

if (Test-Path $exePath) {
    Unblock-File $exePath -ErrorAction SilentlyContinue
    Start-Process -FilePath $exePath -Verb RunAs
} elseif (Test-Path $ps1Path) {
    Unblock-File $ps1Path -ErrorAction SilentlyContinue
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`"" -Verb RunAs
} else {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Ana program dosyası bulunamadı.`n`nAranan: TemizlikAsistani.exe veya TemizlikAsistani.ps1`nKlasör: $scriptDir",
        "Gemini System Care - Hata",
        "OK", "Error"
    ) | Out-Null
}

exit
