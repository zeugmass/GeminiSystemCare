# =========================================================
# MRCLEAN - LOCAL BUILD SCRIPT
# =========================================================
# Bu script GitHub Actions workflow ile birebir ayni PS2EXE compile yapar.
# Kullanim: PowerShell penceresinde:
#   cd C:\Users\zeugmass\Desktop\MrClean
#   .\Build-Local.ps1
#
# Cikti: TemizlikAsistani.exe (script klasorunde)
# Test akisi:
#   1. PS1'de degisiklik yap
#   2. .\Build-Local.ps1 (15-30 saniye)
#   3. .\TemizlikAsistani.exe (test et)
#   4. Sorun yoksa: git commit + tag + push (workflow tetiklenir)
# =========================================================

param(
    [switch]$Run,        # Compile sonrasi EXE'yi otomatik calistir
    [switch]$NoIcon,     # mrclean.ico kullanma (debug icin)
    [switch]$KeepOld     # Eski EXE'yi .old olarak yedekle (default sil)
)

$ErrorActionPreference = 'Stop'

# Script klasoru
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
Set-Location $scriptDir

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  MRCLEAN - LOCAL BUILD" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Gerekli dosyalar var mi?
$ps1Path = Join-Path $scriptDir "TemizlikAsistani.ps1"
if (-not (Test-Path $ps1Path)) {
    Write-Host "  HATA: TemizlikAsistani.ps1 bulunamadi: $ps1Path" -ForegroundColor Red
    exit 1
}
$icoPath = Join-Path $scriptDir "mrclean.ico"
$useIcon = (-not $NoIcon) -and (Test-Path $icoPath)

# 2. Versiyonu PS1'den oku
$ps1Content = Get-Content $ps1Path -Raw -Encoding UTF8
$verMatch = [regex]::Match($ps1Content, '\$global:AppVersion\s*=\s*"([^"]+)"')
if (-not $verMatch.Success) {
    Write-Host "  HATA: AppVersion bulunamadi PS1 icinde" -ForegroundColor Red
    exit 1
}
$version = $verMatch.Groups[1].Value
Write-Host "  Surum:   v$version"
$ps1Size = [Math]::Round((Get-Item $ps1Path).Length/1KB, 1)
Write-Host "  Kaynak:  TemizlikAsistani.ps1 ($ps1Size KB)"
$iconLabel = if ($useIcon) { 'mrclean.ico' } else { 'YOK (default)' }
Write-Host "  Ikon:    $iconLabel"
Write-Host ""

# 3. PS2EXE module yuklu mu?
$ps2exeModule = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
if (-not $ps2exeModule) {
    Write-Host "  PS2EXE modulu yuklu degil. Simdi yuklemek ister misin? (CurrentUser)" -ForegroundColor Yellow
    $ans = Read-Host "  [E]vet / [H]ayir"
    if ($ans -match '^(e|y|yes)') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name ps2exe -Scope CurrentUser -Force -SkipPublisherCheck
        Write-Host "  OK PS2EXE yuklendi" -ForegroundColor Green
    } else {
        Write-Host "  Iptal." -ForegroundColor Red
        exit 1
    }
}

# 4. Sentaks check (compile etmeden once)
Write-Host "  [1/4] Sentaks kontrolu..." -NoNewline
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($ps1Path, [ref]$null, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    Write-Host " HATA" -ForegroundColor Red
    $errors | Select-Object -First 5 | ForEach-Object {
        Write-Host "    L$($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
    }
    exit 1
}
Write-Host " OK" -ForegroundColor Green

# 5. Eski EXE varsa yedekle/sil
$exePath = Join-Path $scriptDir "TemizlikAsistani.exe"
if (Test-Path $exePath) {
    if ($KeepOld) {
        $bakPath = "$exePath.old"
        Move-Item $exePath $bakPath -Force
        Write-Host "  [2/4] Eski EXE yedeklendi: $bakPath"
    } else {
        # Calismiyor olduguna emin ol
        $proc = Get-Process -Name "TemizlikAsistani" -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "  HATA: TemizlikAsistani.exe calisiyor. Once kapat." -ForegroundColor Red
            exit 1
        }
        Remove-Item $exePath -Force
        Write-Host "  [2/4] Eski EXE silindi"
    }
} else {
    Write-Host "  [2/4] Eski EXE yok (ilk build)"
}

# 6. PS2EXE compile
Write-Host "  [3/4] PS2EXE compile (15-30 saniye beklenir)..." -NoNewline

$ps2exeArgs = @{
    InputFile    = $ps1Path
    OutputFile   = $exePath
    Title        = "MrClean Sistem Bakim Araci"
    Description  = "Windows icin kapsamli sistem bakim araci"
    Company      = "MrClean"
    Product      = "MrClean"
    Copyright    = "(c) 2026"
    Version      = $version
    RequireAdmin = $true
    Sta          = $true
}
if ($useIcon) { $ps2exeArgs.IconFile = $icoPath }

$compileStart = Get-Date
try {
    Invoke-PS2EXE @ps2exeArgs *>&1 | Out-Null
} catch {
    Write-Host " HATA" -ForegroundColor Red
    Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
$compileSec = [int]((Get-Date) - $compileStart).TotalSeconds

if (-not (Test-Path $exePath)) {
    Write-Host " HATA: EXE olusmadi" -ForegroundColor Red
    exit 1
}
$exeSizeMB = [Math]::Round((Get-Item $exePath).Length / 1MB, 2)
Write-Host " OK ($compileSec saniye, $exeSizeMB MB)" -ForegroundColor Green

# 7. SHA256
Write-Host "  [4/4] SHA256: " -NoNewline
$hash = (Get-FileHash $exePath -Algorithm SHA256).Hash
Write-Host "$hash" -ForegroundColor DarkGray

# Ozet
Write-Host ""
Write-Host "  OK Build tamamlandi!" -ForegroundColor Green
Write-Host "    EXE:     $exePath"
Write-Host "    Surum:   v$version"
Write-Host "    Boyut:   $exeSizeMB MB"
Write-Host ""

# Otomatik calistir?
if ($Run) {
    Write-Host "  EXE calistiriliyor..." -ForegroundColor Yellow
    Start-Process $exePath
} else {
    Write-Host "  Calistirmak icin: .\TemizlikAsistani.exe" -ForegroundColor DarkGray
    Write-Host "  veya:             .\Build-Local.ps1 -Run" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  GitHub'a yayinlamak icin (test basarili ise):" -ForegroundColor DarkGray
    Write-Host "    git add TemizlikAsistani.ps1" -ForegroundColor DarkGray
    Write-Host "    git commit -m `"...`"" -ForegroundColor DarkGray
    Write-Host "    git push" -ForegroundColor DarkGray
    Write-Host "    git tag -a v$version -m `"v$version`"" -ForegroundColor DarkGray
    Write-Host "    git push origin v$version" -ForegroundColor DarkGray
}
Write-Host ""
