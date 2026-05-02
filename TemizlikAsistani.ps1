# =============================================================================
# GEMINI SISTEM BAKIM ARACI (ULTIMATE V9.8)
# =============================================================================
# DOSYA YAPISI (ICINDEKILER)
# -----------------------------------------------------------------------------
#   #region 01  C# INTEROP ............................. Native methods, SecureWiper, RamCleaner
#   #region 02  YONETICI KONTROL, RUNSPACE POOL, TEMA ... Admin check, GeminiPool, theme/wallpaper
#   #region 03  GLOBAL DEGISKENLER & DOSYA YOLLARI ...... AppData paths, $global:* flagleri
#   #region 04  VARSAYILAN VERILER ...................... Get-Default-Tweaks, Winget DB, Repair tree
#   #region 05  XAML TANIMLARI .......................... Ana pencere + 21 alt pencere heredoc
#   #region 06  XAML YUKLEME & FINDNAME BAGLAMALARI ..... $Win = XamlReader.Load + $btn*/$tv* vb.
#   #region 07  CEKIRDEK HELPERLAR ...................... Do-Events, WpfLog, Format-Size
#   #region 08  AYAR YONETIMI ........................... Save/Load/Restore user config
#   #region 09  TWEAK SISTEMI ........................... Apply-System-Tweaks, Check-Tweak-Status, vb.
#   #region 10  TEMIZLIK MOTORU ......................... Winapp2, Resolve-ComplexPath, Process-Tree
#   #region 11  WORKER & KOMUT CALISTIRMA ............... Start-Worker-Process (async+timeout+stop)
#   #region 12  BASLANGIC YONETICISI .................... Refresh-StartupView (registry+WMI+klasor)
#   #region 13  UI / MODAL FONKSIYONLARI ................ Tools, Profiller, Dashboard, Dialog'lar
#   #region 14  EVENT HANDLERS .......................... Buton click'leri, context menus, tab degis
#   #region 15  PENCERE YASAM DONGUSU ................... Add_Closing, Add_Loaded, ShowDialog
# -----------------------------------------------------------------------------
# NAVIGASYON: VS Code / PowerShell ISE'de Ctrl+Shift+O veya outline panelinden
# region'lari katlayabilirsin. Her region acik yorum + --- ayrac cizgileriyle belli.
# =============================================================================


# =========================================================================
# #region 1 -- C# INTEROP (Native Methods, SecureWiper, RamCleaner, vb.)
# =========================================================================

$nativeCode = @"
using System;
using System.Runtime.InteropServices;
using System.IO;
using System.Security.Cryptography;
using System.Diagnostics;

public class NativeMethods {
    [DllImport("user32.dll")] 
    public static extern bool ShowWindow(int handle, int state);
    [DllImport("kernel32.dll")] 
    public static extern int GetConsoleWindow();
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
}

public class FileSelector {
    [DllImport("shell32.dll", ExactSpelling = true)]
    public static extern void ILFree(IntPtr pidlList);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    public static extern IntPtr ILCreateFromPathW(string pszPath);
    [DllImport("shell32.dll", ExactSpelling = true)]
    public static extern int SHOpenFolderAndSelectItems(IntPtr pidlFolder, uint cidl, IntPtr[] apidl, uint dwFlags);

    public static void Select(string path) {
        IntPtr pidl = ILCreateFromPathW(path);
        if(pidl != IntPtr.Zero) {
            try {
                SHOpenFolderAndSelectItems(pidl, 0, null, 0);
            } finally {
                ILFree(pidl);
            }
        }
    }
}

public class SecureWiper {
    public static bool WipeFile(string filePath, int passes) {
        try {
            if (!File.Exists(filePath)) return true;
            FileInfo fi = new FileInfo(filePath);
            if (fi.IsReadOnly) fi.IsReadOnly = false;
            
            long length = fi.Length;
            using (FileStream fs = new FileStream(filePath, FileMode.Open, FileAccess.Write, FileShare.None)) {
                // Güvenli rastgele veri üretici
                using (var rng = new RNGCryptoServiceProvider()) {
                    byte[] buffer = new byte[1024 * 1024]; // 1MB tampon
                    for (int p = 0; p < passes; p++) {
                        fs.Position = 0;
                        long written = 0;
                        while (written < length) {
                            rng.GetBytes(buffer);
                            int toWrite = (int)Math.Min(buffer.Length, length - written);
                            fs.Write(buffer, 0, toWrite);
                            written += toWrite;
                        }
                        fs.Flush();
                    }
                }
            }
            File.Delete(filePath);
            return true;
        } catch { return false; }
    }
}

public class RamCleaner {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);

    public static int CleanAll() {
        int count = 0;
        foreach (Process p in Process.GetProcesses()) {
            try { EmptyWorkingSet(p.Handle); count++; } catch {}
        }
        return count;
    }
}

public struct MEMORYSTATUSEX {
    public uint dwLength;
    public uint dwMemoryLoad;
    public ulong ullTotalPhys;
    public ulong ullAvailPhys;
    public ulong ullTotalPageFile;
    public ulong ullAvailPageFile;
    public ulong ullTotalVirtual;
    public ulong ullAvailVirtual;
    public ulong ullAvailExtendedVirtual;
}

public class RamInfo {[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    public static double[] GetRamUsageGB() {
        MEMORYSTATUSEX memStatus = new MEMORYSTATUSEX();
        memStatus.dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
        if (GlobalMemoryStatusEx(ref memStatus)) {
            // Bayt değerini GB'a çeviriyoruz
            double total = memStatus.ullTotalPhys / 1073741824.0;
            double avail = memStatus.ullAvailPhys / 1073741824.0;
            double used = total - avail;
            
            // Windows'un tahmini "dwMemoryLoad" değeri yerine KESİN matematik hesabı:
            double percent = (used / total) * 100.0;
            
            return new double[] { total, used, percent };
        }
        return new double[] { 0, 0, 0 };
    }
}
public struct IO_COUNTERS {
    public ulong ReadOperationCount;
    public ulong WriteOperationCount;
    public ulong OtherOperationCount;
    public ulong ReadTransferCount;
    public ulong WriteTransferCount;
    public ulong OtherTransferCount;
}

public class ProcessMonitor {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetProcessIoCounters(IntPtr hProcess, out IO_COUNTERS lpIoCounters);

    public static long GetProcessTotalIo(int processId) {
        try {
            Process p = Process.GetProcessById(processId);
            IO_COUNTERS counters;
            if (GetProcessIoCounters(p.Handle, out counters)) {
                // Okuma ve Yazma baytlarının toplamını döndürür
                return (long)(counters.ReadTransferCount + counters.WriteTransferCount);
            }
        } catch { }
        return -1; // Process kapandıysa veya okunamıyorsa -1 döner
    }
}
"@
# Derleyici sadece 1 kez çalışır
Add-Type -TypeDefinition $nativeCode -Language CSharp

# --- KONSOL PENCERESİNİ GİZLEME VE DEBUG SWITCH İÇİN GLOBAL HANDLE ---
$global:ConsoleHandle = [NativeMethods]::GetConsoleWindow()
[NativeMethods]::ShowWindow($global:ConsoleHandle, 0)

# --- YARDIMCI FONKSİYONLAR ---

# #endregion 1 -- C# INTEROP (Native Methods, SecureWiper, RamCleaner, vb.)


# =========================================================================
# #region 2 -- YONETICI KONTROL, RUNSPACE POOL, TEMA
# =========================================================================

function Refresh-WindowsTheme {
    $null = [NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "ImmersiveColorSet", 2, 2000, [ref][UIntPtr]::Zero)
    $null =[NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 2, 2000, [ref][UIntPtr]::Zero)
}

function Refresh-Wallpaper {
    [NativeMethods]::SystemParametersInfo(20, 0, $null, 3)
}

# --- YÖNETİCİ KONTROLÜ (GÜNCELLENDİ) ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Eğer yönetici değilse, kendini yönetici olarak yeniden başlatır
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# PS2EXE -NoConsole modunda Console nesnesi olmaz — try/catch ile sarmal
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# PS2EXE -NoConsole modunda console yok — Write-Host'lar MessageBox'a donusur
# Ana process'te console yoksa tum Write-Host'lari sessize al (runspace'ler etkilenmez)
$script:HasConsole = $true
try { $null = $Host.UI.RawUI.WindowSize.Width } catch { $script:HasConsole = $false }
if (-not $script:HasConsole) {
    # PS2EXE -NoConsole detected — Write-Host override (sadece ana process scope'unda)
    function global:Write-Host {
        param(
            [Parameter(ValueFromPipeline=$true, Position=0)] $Object,
            [Parameter(ValueFromRemainingArguments=$true)] $Rest
        )
        # Sessizce yut — console yok, gosterecek yer yok. Loglamak istersen WpfLog kullan.
    }
    # Out-Default'u da koru — implicit output'lari (pipeline'a dusen $true/$false vs.) yut
    function global:Out-Default {
        param([Parameter(ValueFromPipeline=$true)] $InputObject)
        process { }
    }
}

# --- GLOBAL RUNSPACE POOL (HIZ VE VERİMLİLİK İÇİN) ---
if (-not $global:GeminiPool) {
    $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    # En az 1, en fazla 5 paralel iş yapabilen havuz
    $global:GeminiPool = [runspacefactory]::CreateRunspacePool(1, 5, $sessionState, $Host)
    $global:GeminiPool.Open()
}

# --- YAPILANDIRMA ---

# #endregion 2 -- YONETICI KONTROL, RUNSPACE POOL, TEMA


# =========================================================================
# #region 3 -- GLOBAL DEGISKENLER & DOSYA YOLLARI
# =========================================================================

$AppDataPath = "$env:APPDATA\GeminiCare"
if (-not (Test-Path $AppDataPath)) { New-Item -Path $AppDataPath -ItemType Directory -Force | Out-Null }

$Winapp2Path = "$AppDataPath\Winapp2.ini"
$UserConfigPath = "$AppDataPath\user_config.json"
$AppStatePath   = "$AppDataPath\app_state.json"
$CachePath      = "$AppDataPath\app_cache.json"
# Auto-update: kullanicinin atladigi surumler ve guncelleme staging klasoru
$global:UpdateSkippedFile = "$AppDataPath\update_skipped_versions.txt"
$global:UpdateStagingDir  = "$AppDataPath\update_staging"

# --- MEVCUT TANIMLAMALARIN ALTINA EKLE ---
# =============================================================
# DEĞİŞKEN KAPSAM KURALLARI (Scope Convention)
# $global: → Birden fazla fonksiyon/event arasında paylaşılan, oturum boyunca yaşayan veriler
# $script: → Yalnızca bu script dosyası içinde geçerli, runspace'e geçmeyen kısa ömürlü durum
# Kural: UI kontrollerine ($Win.*) erişim gerektiren her şey $global: veya $script: olabilir.
#         Ama kapanış event'inden erişilenler $global: olmalıdır.
# =============================================================
$NoCacheFlag = "$AppDataPath\no_cache.flag"
$global:IsCacheDisabled = (Test-Path $NoCacheFlag)

$Winapp2Sources = @(
    "https://cdn.jsdelivr.net/gh/MoscaDotTo/Winapp2@master/Winapp2.ini",
    "https://raw.githubusercontent.com/MoscaDotTo/Winapp2/master/Winapp2.ini"
)

$global:Winapp2Rules = @{}
$global:ShowPrivacyWarning = $true # Varsayılan olarak göster
$global:Blacklist = @()
$global:PathOverrides = @{} 
$global:CustomRules = @()
$global:AppLayout = "Left" # Varsayılan: Sol Menü
$global:CustomAppx = [ordered]@{}
$global:MyProfile = @()
$global:AppCounter = 0
$global:StopOperation = $false   # script: → global: (btnRun.Add_Click ve Process-Tree farklı scope)
$global:TweaksLoaded = $false    # script: → global: (tab handler ile Load-Tweak-Tree arası)
$global:CustomTools = @()
$global:RestorePointMode = "Ask" # "Ask" | "Auto" | "Never" — Tweak uygulamadan önce Sistem Geri Yükleme davranışı
$global:LastTweakOperation = $null # Sprint 4.3: Quick undo icin son apply'in snapshot'i { Applied = @(...); Undone = @(...); Time = ... }
$global:ConfigDirty = $false     # Dirty flag: true olduğunda Mark-ConfigDirty diske yazar
$global:DashResult  = $null      # Dashboard WMI verisi (Show-HardwareDetail erişiyor)
$global:DashCache   = $null      # 5 dakika önbellek
$global:DashCacheTime = $null
# --- RUNSPACE TAKİP LİSTESİ (BELLEK SIZINTISI ÖNLEYİCİ) ---
$global:ActiveRunspaces = New-Object System.Collections.Generic.List[System.Management.Automation.PowerShell]
# --- GÖMÜLÜ GITHUB ARAÇLARI ---
$global:EmbeddedTools = [ordered]@{
    "NVIDIA Profile Inspector" = "Orbmu2k/nvidiaProfileInspector"
}
# --- GPU VENDOR CACHE (Vendor-aware tweak'ler icin) ---
# Lazy-loaded: ilk cagrida WMI sorgulanir, sonra cache'lenir. Apply uyumsuzluk uyarisi icin.
# Hibrit sistemler destekli: @("Intel","NVIDIA") gibi cogul deger donebilir.
$global:DetectedGpuVendors = $null

# --- AUTO-UPDATE ALTYAPISI ---
# AppVersion: Mevcut programin SemVer numarasi. Her release'de elle artirilir + GitHub'a tag olarak push edilir.
# GitHub Actions tag'i alir, PS2EXE ile EXE compile eder, Release olusturur, SHA256SUMS yazar.
# Program acilis kontrolu bu sayiyi GitHub'taki en son release tag'i ile karsilastirir.
$global:AppVersion = "1.0.2"

# AppRepo: GitHub kullanici/repo formatinda. README'de "burayi kendi repo'na gore degistir" talimati.
$global:AppRepo = "zeugmass/GeminiSystemCare"

# Update check sonucu: yeni surum varsa @{ Tag, Notes, ExeUrl, Ps1Url, HashUrl, ExeHash, Ps1Hash } doldurulur.
# Add_Loaded async check tamamlandiginda set edilir, UI status bar'da notification gosterir.
$global:UpdateAvailable = $null

# Atla edilen surumler: kullanici "Bu surumu atla" derse buraya yazilir, ayni surum icin tekrar uyari gosterilmez.
$global:UpdateSkippedFile = $null  # AppDataPath set edildikten sonra dolacak (asagida)

# --- NVIDIA PROFILE INSPECTOR .NIP (Optimize Profil Icerigi) ---
# FR33THY tweak guide tabanli optimize NVIDIA Control Panel ayarlari.
# Uygulanacak: GSYNC modlari, Ultra Low Latency, V-Sync, Antialiasing, Texture Filtering,
# Power Mode, Shader Cache, Threaded Optimization, CUDA P2 State, Frame Rate Limiter.
# NOT: "Preferred OpenGL GPU" satiri RTX 4090 icin sabit — farkli NVIDIA GPU'larda surucu
# genelde otomatik secime geri doner (resmi belge yok, ampirik).
$global:NvidiaInspectorOptimizedNip = @'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executables/>
    <Settings>
      <ProfileSetting><SettingNameInfo>Frame Rate Limiter V3</SettingNameInfo><SettingID>277041154</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Application Mode</SettingNameInfo><SettingID>294973784</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Application State</SettingNameInfo><SettingID>279476687</SettingID><SettingValue>4</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Global Feature</SettingNameInfo><SettingID>278196567</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Global Mode</SettingNameInfo><SettingID>278196727</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Indicator Overlay</SettingNameInfo><SettingID>268604728</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Maximum Pre-Rendered Frames</SettingNameInfo><SettingID>8102046</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Preferred Refresh Rate</SettingNameInfo><SettingID>6600001</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Ultra Low Latency - CPL State</SettingNameInfo><SettingID>390467</SettingID><SettingValue>2</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Ultra Low Latency - Enabled</SettingNameInfo><SettingID>277041152</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync</SettingNameInfo><SettingID>11041231</SettingID><SettingValue>138504007</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync - Smooth AFR Behavior</SettingNameInfo><SettingID>270198627</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync - Tear Control</SettingNameInfo><SettingID>5912412</SettingID><SettingValue>2525368439</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vulkan/OpenGL Present Method</SettingNameInfo><SettingID>550932728</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Gamma Correction</SettingNameInfo><SettingID>276652957</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Mode</SettingNameInfo><SettingID>276757595</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Setting</SettingNameInfo><SettingID>282555346</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filter - Optimization</SettingNameInfo><SettingID>8703344</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filter - Sample Optimization</SettingNameInfo><SettingID>15151633</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filtering - Mode</SettingNameInfo><SettingID>282245910</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filtering - Setting</SettingNameInfo><SettingID>270426537</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Negative LOD Bias</SettingNameInfo><SettingID>1686376</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Quality</SettingNameInfo><SettingID>13510289</SettingID><SettingValue>20</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Trilinear Optimization</SettingNameInfo><SettingID>3066610</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>CUDA - Force P2 State</SettingNameInfo><SettingID>1343646814</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>CUDA - Sysmem Fallback Policy</SettingNameInfo><SettingID>283962569</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Power Management - Mode</SettingNameInfo><SettingID>274197361</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Shader Cache - Cache Size</SettingNameInfo><SettingID>11306135</SettingID><SettingValue>4294967295</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Threaded Optimization</SettingNameInfo><SettingID>549528094</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>OpenGL GDI Compatibility</SettingNameInfo><SettingID>544392611</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Preferred OpenGL GPU</SettingNameInfo><SettingID>550564838</SettingID><SettingValue>id,2.0:268410DE,00000100,GF - (400,2,161,24564) @ (0)</SettingValue><ValueType>String</ValueType></ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
'@

# Bos profil — Undo'da backup yoksa fallback olarak kullanilir (FR33THY orijinal davranisi)
$global:NvidiaInspectorEmptyNip = @'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executables/>
    <Settings/>
  </Profile>
</ArrayOfProfile>
'@

# --- WIN11 START2.BIN BASE64 BLOB (FR33THY birebir — temiz Win11 start menu) ---
# certutil -decode ile binary dosyaya cevrilir, sonra %LocalAppData%\Packages\
# Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin'e kopyalanir
$global:Win11Start2BinBase64 = @'
-----BEGIN CERTIFICATE-----
4nrhSwH8TRucAIEL3m5RhU5aX0cAW7FJilySr5CE+V40mv9utV7aAZARAABc9u55
LN8F4borYyXEGl8Q5+RZ+qERszeqUhhZXDvcjTF6rgdprauITLqPgMVMbSZbRsLN
/O5uMjSLEr6nWYIwsMJkZMnZyZrhR3PugUhUKOYDqwySCY6/CPkL/Ooz/5j2R2hw
WRGqc7ZsJxDFM1DWofjUiGjDUny+Y8UjowknQVaPYao0PC4bygKEbeZqCqRvSgPa
lSc53OFqCh2FHydzl09fChaos385QvF40EDEgSO8U9/dntAeNULwuuZBi7BkWSIO
mWN1l4e+TZbtSJXwn+EINAJhRHyCSNeku21dsw+cMoLorMKnRmhJMLvE+CCdgNKI
aPo/Krizva1+bMsI8bSkV/CxaCTLXodb/NuBYCsIHY1sTvbwSBRNMPvccw43RJCU
KZRkBLkCVfW24ANbLfHXofHDMLxxFNUpBPSgzGHnueHknECcf6J4HCFBqzvSH1Tj
Q3S6J8tq2yaQ+jFNkxGRMushdXNNiTNjDFYMJNvgRL2lu606PZeypEjvPg7SkGR2
7a42GDSJ8n6HQJXFkOQPJ1mkU4qpA78U+ZAo9ccw8XQPPqE1eG7wzMGihTWfEMVs
K1nsKyEZCLYFmKwYqdIF0somFBXaL/qmEHxwlPCjwRKpwLOue0Y8fgA06xk+DMti
zWahOZNeZ54MN3N14S22D75riYEccVe3CtkDoL+4Oc2MhVdYEVtQcqtKqZ+DmmoI
5BqkECeSHZ4OCguheFckK5Eq5Yf0CKRN+RY2OJ0ZCPUyxQnWdnOi9oBcZsz2NGzY
g8ifO5s5UGscSDMQWUxPJQePDh8nPUittzJ+iplQqJYQ/9p5nKoDukzHHkSwfGms
1GiSYMUZvaze7VSWOHrgZ6dp5qc1SQy0FSacBaEu4ziwx1H7w5NZj+zj2ZbxAZhr
7Wfvt9K1xp58H66U4YT8Su7oq5JGDxuwOEbkltA7PzbFUtq65m4P4LvS4QUIBUqU
0+JRyppVN5HPe11cCPaDdWhcr3LsibWXQ7f0mK8xTtPkOUb5pA2OUIkwNlzmwwS1
Nn69/13u7HmPSyofLck77zGjjqhSV22oHhBSGEr+KagMLZlvt9pnD/3I1R1BqItW
KF3woyb/QizAqScEBsOKj7fmGA7f0KKQkpSpenF1Q/LNdyyOc77wbu2aywLGLN7H
BCdwwjjMQ43FHSQPCA3+5mQDcfhmsFtORnRZWqVKwcKWuUJ7zLEIxlANZ7rDcC30
FKmeUJuKk0Upvhsz7UXzDtNmqYmtg6vY/yPtG5Cc7XXGJxY2QJcbg1uqYI6gKtue
00Mfpjw7XpUMQbIW9rXMA9PSWX6h2ln2TwlbrRikqdQXACZyhtuzSNLK7ifSqw4O
JcZ8JrQ/xePmSd0z6O/MCTiUTFwG0E6WS1XBV1owOYi6jVif1zg75DTbXQGTNRvK
KarodfnpYg3sgTe/8OAI1YSwProuGNNh4hxK+SmljqrYmEj8BNK3MNCyIskCcQ4u
cyoJJHmsNaGFyiKp1543PktIgcs8kpF/SN86/SoB/oI7KECCCKtHNdFV8p9HO3t8
5OsgGUYgvh7Z/Z+P7UGgN1iaYn7El9XopQ/XwK9zc9FBr73+xzE5Hh4aehNVIQdM
Mb+Rfm11R0Jc4WhqBLCC3/uBRzesyKUzPoRJ9IOxCwzeFwGQ202XVlPvklXQwgHx
BfEAWZY1gaX6femNGDkRldzImxF87Sncnt9Y9uQty8u0IY3lLYNcAFoTobZmFkAQ
vuNcXxObmHk3rZNAbRLFsXnWUKGjuK5oP2TyTNlm9fMmnf/E8deez3d8KOXW9YMZ
DkA/iElnxcCKUFpwI+tWqHQ0FT96sgIP/EyhhCq6o/RnNtZvch9zW8sIGD7Lg0cq
SzPYghZuNVYwr90qt7UDekEei4CHTzgWwlSWGGCrP6Oxjk1Fe+KvH4OYwEiDwyRc
l7NRJseqpW1ODv8c3VLnTJJ4o3QPlAO6tOvon7vA1STKtXylbjWARNcWuxT41jtC
CzrAroK2r9bCij4VbwHjmpQnhYbF/hCE1r71Z5eHdWXqpSgIWeS/1avQTStsehwD
2+NGFRXI8mwLBLQN/qi8rqmKPi+fPVBjFoYDyDc35elpdzvqtN/mEp+xDrnAbwXU
yfhkZvyo2+LXFMGFLdYtWTK/+T/4n03OJH1gr6j3zkoosewKTiZeClnK/qfc8YLw
bCdwBm4uHsZ9I14OFCepfHzmXp9nN6a3u0sKi4GZpnAIjSreY4rMK8c+0FNNDLi5
DKuck7+WuGkcRrB/1G9qSdpXqVe86uNojXk9P6TlpXyL/noudwmUhUNTZyOGcmhJ
EBiaNbT2Awx5QNssAlZFuEfvPEAixBz476U8/UPb9ObHbsdcZjXNV89WhfYX04DM
9qcMhCnGq25sJPc5VC6XnNHpFeWhvV/edYESdeEVwxEcExKEAwmEZlGJdxzoAH+K
Y+xAZdgWjPPL5FaYzpXc5erALUfyT+n0UTLcjaR4AKxLnpbRqlNzrWa6xqJN9NwA
+xa38I6EXbQ5Q2kLcK6qbJAbkEL76WiFlkc5mXrGouukDvsjYdxG5Rx6OYxb41Ep
1jEtinaNfXwt/JiDZxuXCMHdKHSH40aZCRlwdAI1C5fqoUkgiDdsxkEq+mGWxMVE
Zd0Ch9zgQLlA6gYlK3gt8+dr1+OSZ0dQdp3ABqb1+0oP8xpozFc2bK3OsJvucpYB
OdmS+rfScY+N0PByGJoKbdNUHIeXv2xdhXnVjM5G3G6nxa3x8WFMJsJs2ma1xRT1
8HKqjX9Ha072PD8Zviu/bWdf5c4RrphVqvzfr9wNRpfmnGOoOcbkRE4QrL5CqrPb
VRujOBMPGAxNlvwq0w1XDOBDawZgK7660yd4MQFZk7iyZgUSXIo3ikleRSmBs+Mt
r+3Og54Cg9QLPHbQQPmiMsu21IJUh0rTgxMVBxNUNbUaPJI1lmbkTcc7HeIk0Wtg
RxwYc8aUn0f/V//c+2ZAlM6xmXmj6jIkOcfkSBd0B5z63N4trypD3m+w34bZkV1I
cQ8h7SaUUqYO5RkjStZbvk2IDFSPUExvqhCstnJf7PZGilbsFPN8lYqcIvDZdaAU
MunNh6f/RnhFwKHXoyWtNI6yK6dm1mhwy+DgPlA2nAevO+FC7Vv98Sl9zaVjaPPy
3BRyQ6kISCL065AKVPEY0ULHqtIyfU5gMvBeUa5+xbU+tUx4ZeP/BdB48/LodyYV
kkgqTafVxCvz4vgmPbnPjm/dlRbVGbyygN0Noq8vo2Ea8Z5zwO32coY2309AC7wv
Pp2wJZn6LKRmzoLWJMFm1A1Oa4RUIkEpA3AAL+5TauxfawpdtTjicoWGQ5gGNwum
+evTnGEpDimE5kUU6uiJ0rotjNpB52I+8qmbgIPkY0Fwwal5Z5yvZJ8eepQjvdZ2
UcdvlTS8oA5YayGi+ASmnJSbsr/v1OOcLmnpwPI+hRgPP+Hwu5rWkOT+SDomF1TO
n/k7NkJ967X0kPx6XtxTPgcG1aKJwZBNQDKDP17/dlZ869W3o6JdgCEvt1nIOPty
lGgvGERC0jCNRJpGml4/py7AtP0WOxrs+YS60sPKMATtiGzp34++dAmHyVEmelhK
apQBuxFl6LQN33+2NNn6L5twI4IQfnm6Cvly9r3VBO0Bi+rpjdftr60scRQM1qw+
9dEz4xL9VEL6wrnyAERLY58wmS9Zp73xXQ1mdDB+yKkGOHeIiA7tCwnNZqClQ8Mf
RnZIAeL1jcqrIsmkQNs4RTuE+ApcnE5DMcvJMgEd1fU3JDRJbaUv+w7kxj4/+G5b
IU2bfh52jUQ5gOftGEFs1LOLj4Bny2XlCiP0L7XLJTKSf0t1zj2ohQWDT5BLo0EV
5rye4hckB4QCiNyiZfavwB6ymStjwnuaS8qwjaRLw4JEeNDjSs/JC0G2ewulUyHt
kEobZO/mQLlhso2lnEaRtK1LyoD1b4IEDbTYmjaWKLR7J64iHKUpiQYPSPxcWyei
o4kcyGw+QvgmxGaKsqSBVGogOV6YuEyoaM0jlfUmi2UmQkju2iY5tzCObNQ41nsL
dKwraDrcjrn4CAKPMMfeUSvYWP559EFfDhDSK6Os6Sbo8R6Zoa7C2NdAicA1jPbt
5ENSrVKf7TOrthvNH9vb1mZC1X2RBmriowa/iT+LEbmQnAkA6Y1tCbpzvrL+cX8K
pUTOAovaiPbab0xzFP7QXc1uK0XA+M1wQ9OF3XGp8PS5QRgSTwMpQXW2iMqihYPv
Hu6U1hhkyfzYZzoJCjVsY2xghJmjKiKEfX0w3RaxfrJkF8ePY9SexnVUNXJ1654/
PQzDKsW58Au9QpIH9VSwKNpv003PksOpobM6G52ouCFOk6HFzSLfnlGZW0yyUQL3
RRyEE2PP0LwQEuk2gxrW8eVy9elqn43S8CG2h2NUtmQULc/IeX63tmCOmOS0emW9
66EljNdMk/e5dTo5XplTJRxRydXcQpgy9bQuntFwPPoo0fXfXlirKsav2rPSWayw
KQK4NxinT+yQh//COeQDYkK01urc2G7SxZ6H0k6uo8xVp9tDCYqHk/lbvukoN0RF
tUI4aLWuKet1O1s1uUAxjd50ELks5iwoqLJ/1bzSmTRMifehP07sbK/N1f4hLae+
jykYgzDWNfNvmPEiz0DwO/rCQTP6x69g+NJaFlmPFwGsKfxP8HqiNWQ6D3irZYcQ
R5Mt2Iwzz2ZWA7B2WLYZWndRCosRVWyPdGhs7gkmLPZ+WWo/Yb7O1kIiWGfVuPNA
MKmgPPjZy8DhZfq5kX20KF6uA0JOZOciXhc0PPAUEy/iQAtzSDYjmJ8HR7l4mYsT
O3Mg3QibMK8MGGa4tEM8OPGktAV5B2J2QOe0f1r3vi3QmM+yukBaabwlJ+dUDQGm
+Ll/1mO5TS+BlWMEAi13cB5bPRsxkzpabxq5kyQwh4vcMuLI0BOIfE2pDKny5jhW
0C4zzv3avYaJh2ts6kvlvTKiSMeXcnK6onKHT89fWQ7Hzr/W8QbR/GnIWBbJMoTc
WcgmW4fO3AC+YlnLVK4kBmnBmsLzLh6M2LOabhxKN8+0Oeoouww7g0HgHkDyt+MS
97po6SETwrdqEFslylLo8+GifFI1bb68H79iEwjXojxQXcD5qqJPxdHsA32eWV0b
qXAVojyAk7kQJfDIK+Y1q9T6KI4ew4t6iauJ8iVJyClnHt8z/4cXdMX37EvJ+2BS
YKHv5OAfS7/9ZpKgILT8NxghgvguLB7G9sWNHntExPtuRLL4/asYFYSAJxUPm7U2
xnp35Zx5jCXesd5OlKNdmhXq519cLl0RGZfH2ZIAEf1hNZqDuKesZ2enykjFlIec
hZsLvEW/pJQnW0+LFz9N3x3vJwxbC7oDgd7A2u0I69Tkdzlc6FFJcfGabT5C3eF2
EAC+toIobJY9hpxdkeukSuxVwin9zuBoUM4X9x/FvgfIE0dKLpzsFyMNlO4taCLc
v1zbgUk2sR91JmbiCbqHglTzQaVMLhPwd8GU55AvYCGMOsSg3p952UkeoxRSeZRp
jQHr4bLN90cqNcrD3h5knmC61nDKf8e+vRZO8CVYR1eb3LsMz12vhTJGaQ4jd0Kz
QyosjcB73wnE9b/rxfG1dRactg7zRU2BfBK/CHpIFJH+XztwMJxn27foSvCY6ktd
uJorJvkGJOgwg0f+oHKDvOTWFO1GSqEZ5BwXKGH0t0udZyXQGgZWvF5s/ojZVcK3
IXz4tKhwrI1ZKnZwL9R2zrpMJ4w6smQgipP0yzzi0ZvsOXRksQJNCn4UPLBhbu+C
eFBbpfe9wJFLD+8F9EY6GlY2W9AKD5/zNUCj6ws8lBn3aRfNPE+Cxy+IKC1NdKLw
eFdOGZr2y1K2IkdefmN9cLZQ/CVXkw8Qw2nOr/ntwuFV/tvJoPW2EOzRmF2XO8mQ
DQv51k5/v4ZE2VL0dIIvj1M+KPw0nSs271QgJanYwK3CpFluK/1ilEi7JKDikT8X
TSz1QZdkum5Y3uC7wc7paXh1rm11nwluCC7jiA==
-----END CERTIFICATE-----
'@
# --- TWEAK VERİTABANI ---
$global:TweakList = [ordered]@{}

# Varsayılan Ayarları Getiren Fonksiyon

# #endregion 3 -- GLOBAL DEGISKENLER & DOSYA YOLLARI


# =========================================================================
# #region 4 -- VARSAYILAN VERILER (Tweak DB, Winget DB, Repair Tree)
# =========================================================================

function Get-Default-Tweaks {
    return [ordered]@{
        # --- 1. GÖRSEL PERFORMANS (PROCESS MONITOR VERİLERİNE GÖRE) ---
        "Görsel Performans" = @(
            @{ 
                Name="Görsel Efektler: Özel (Yazı Tipi + Küçük Resimler Açık)";
                RestartExplorer="Hard";
                Batch=@(
                    # 1. Modu "Özel" (Custom) yap
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; ValueName="VisualFXSetting"; Type="DWord"; Data=3; Undo=0 },
                    
                    # 2. Maskeyi Ayarla (ProcMon: 90 12 03 80 10 00 00 00)
                    @{ Key="HKCU:\Control Panel\Desktop"; ValueName="UserPreferencesMask"; Type="Binary"; Data=[byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00); Undo=[byte[]](0x9E,0x1E,0x07,0x80,0x12,0x00,0x00,0x00) },

                    # 3. Yazı Tipi Düzeltme (ProcMon: 2)
                    @{ Key="HKCU:\Control Panel\Desktop"; ValueName="FontSmoothing"; Type="String"; Data="2"; Undo="2" },
                    
                    # 4. Görev Çubuğu Animasyonları (ProcMon: 0)
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="TaskbarAnimations"; Type="DWord"; Data=0; Undo=1 },
                    
                    # 5. Liste Gölgeleri (ProcMon: 0)
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="ListviewShadow"; Type="DWord"; Data=0; Undo=1 },
                    
                    # 6. Aero Peek (ProcMon: 0)
                    @{ Key="HKCU:\Software\Microsoft\Windows\DWM"; ValueName="EnableAeroPeek"; Type="DWord"; Data=0; Undo=1 },
                    
                    # 7. Sürüklerken İçeriği Göster (ProcMon: 0)
                    @{ Key="HKCU:\Control Panel\Desktop"; ValueName="DragFullWindows"; Type="String"; Data="0"; Undo="1" },
                    
                    # 8. Seçim Dikdörtgeni Saydamlığı (ProcMon: 0)
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="ListviewAlphaSelect"; Type="DWord"; Data=0; Undo=1 },

                    # 9. Küçük Resimler (Senin İsteğin - IconsOnly=0)
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="IconsOnly"; Type="DWord"; Data=0; Undo=0 }
                )
            }

        )
		# --- 2. GÖREV ÇUBUĞU VE BAŞLAT ---
        "Kişiselleştirme" = @(
             # WINDOWS SPOTLIGHT
            @{ 
                Name="Windows Spotlight Kapat (Düz Renk/Resim)";
				SubCategory="Arka Plan";
                Command='
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Value 1 -Type DWord -Force;
                    $ds = "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings"
                    if (-not (Test-Path $ds)) { New-Item -Path $ds -Force | Out-Null }
                    Set-ItemProperty -Path $ds -Name "EnabledState" -Value 0 -Type DWord -Force;
                    Set-ItemProperty -Path $ds -Name "SpotlightDisabledReason" -Value 100 -Type DWord -Force;
                    Refresh-Wallpaper; Refresh-WindowsTheme
                ';
                UndoCommand='
                    $ds = "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings"
					Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Value 3 -Type DWord -Force;
					Set-ItemProperty -Path $ds -Name "SpotlightDisabledReason" -Value 100 -Type DWord -Force;
                    Set-ItemProperty -Path $ds -Name "EnabledState" -Value 1 -Type DWord -Force;
                    $rootDS = "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight"
                    Set-ItemProperty -Path $rootDS -Name "ImagesUsed" -Value 2 -Type DWord -Force;
                    $creat = "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Creatives"
                    if (-not (Test-Path $creat)) { New-Item -Path $creat -Force | Out-Null }
                    Set-ItemProperty -Path $creat -Name "ImageIndex" -Value 1 -Type DWord -Force;
                    if (Get-Service "AppXSvc" -ErrorAction SilentlyContinue) { Restart-Service "AppXSvc" -Force -ErrorAction SilentlyContinue }
                    Refresh-Wallpaper; Refresh-WindowsTheme
                ';
                RestartExplorer=$false 
            },
			@{ Name="Kilit Ekranında Eğlenceli Bilgileri Kapat"; SubCategory="Arka Plan"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; ValueName="RotatingLockScreenEnabled"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			
			# KARANLIK MOD — TAM PAKET (FR33THY 5 Theme Black.ps1 + 6 Signout Lockscreen Wallpaper Black.ps1 BIRLESTIRILMIS)
            @{
                Name="Karanlık Modu Aç (Sistem + Wallpaper + Kilit Ekranı)";
				SubCategory="Renkler";
                Description="Komple koyu tema paketi — FR33THY 2 scriptin birlesimi. Tek tikla:`n`n• Sistem & uygulamalar koyu tema (AppsUseLightTheme=0, SystemUsesLightTheme=0)`n• Saydamlik kapali (EnableTransparency=0)`n• Renkli baslik cubuklari (ColorPrevalence=1)`n• DWM accent rengi siyah (0xff191919) — pencere kenarlari, taskbar`n• Accent palette gri tonlari (Win11 'Renkler' bolumunde gorunur)`n• Klasik kontrol paneli arka plani siyah`n• Masaustu duvar kagidi: ekran cozunurlugunde siyah JPG (C:\\Windows\\Black.jpg)`n• Kilit ekrani arka plani: ayni siyah JPG (Spotlight kapanir)`n`nTum 'siyah' yuzeyleri tek tweak ile yonetir.";
                RestartExplorer=$false;
                Command='
                    # === BOLUM 1: SISTEM TEMASI ===
                    # Personalize: Apps + System koyu, ColorPrevalence (renkli baslik cubuklari), saydamlik off
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme"     -Value 0 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "ColorPrevalence"      -Value 1 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency"   -Value 0 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force

                    # HKLM Personalize (sistem geneli)
                    if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize")) {
                        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

                    # Accent Palette (gri tonlari) — FR33THY hex degeri
                    if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent")) {
                        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    $palette = [byte[]](0x64,0x64,0x64,0x00, 0x6b,0x6b,0x6b,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00)
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentPalette"      -Value $palette -Type Binary -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "StartColorMenu"     -Value 0        -Type DWord  -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentColorMenu"    -Value 0        -Type DWord  -Force

                    # DWM (window borders, taskbar accent)
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableWindowColorization" -Value 1          -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor"             -Value 0xff191919 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorizationColor"        -Value 0xc4191919 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorizationAfterglow"    -Value 0xc4191919 -Type DWord -Force

                    # Klasik Kontrol Paneli arka planlari (eski uygulamalar icin)
                    Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value "0 0 0" -Force

                    # === BOLUM 2: SIYAH WALLPAPER + KILIT EKRANI ===
                    Write-Host "[Karanlik] Siyah JPG olusturuluyor..."
                    Add-Type -AssemblyName System.Windows.Forms
                    Add-Type -AssemblyName System.Drawing
                    $w = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
                    $h = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height
                    $file = "C:\Windows\Black.jpg"
                    $bmp = New-Object System.Drawing.Bitmap $w, $h
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $g.FillRectangle([System.Drawing.Brushes]::Black, 0, 0, $bmp.Width, $bmp.Height)
                    $g.Dispose()
                    $bmp.Save($file)
                    $bmp.Dispose()
                    Write-Host "[Karanlik] Black.jpg ${w}x${h} olusturuldu."

                    # Kilit ekrani (PersonalizationCSP)
                    if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP")) {
                        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImagePath"   -Value $file -Type String -Force
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageStatus" -Value 1     -Type DWord  -Force

                    # Masaustu duvar kagidi
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $file -Type String -Force
                    rundll32.exe user32.dll, UpdatePerUserSystemParameters

                    Refresh-WindowsTheme
                    Write-Host "[Karanlik] Tum siyah yuzeyler uygulandi."
                ';
                UndoCommand='
                    # === BOLUM 1: SISTEM TEMASI -> Light defaults ===
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme"     -Value 1 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "ColorPrevalence"      -Value 0 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency"   -Value 1 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 1 -Type DWord -Force

                    # HKLM Personalize key sil (FR33THY: [-HKLM\...] ile siliniyor)
                    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Recurse -Force -ErrorAction SilentlyContinue

                    # Accent Palette default (mavi tonlari — FR33THY default)
                    if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent")) {
                        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    $defaultPalette = [byte[]](0x99,0xeb,0xff,0x00, 0x4c,0xc2,0xff,0x00, 0x00,0x91,0xf8,0x00, 0x00,0x78,0xd4,0x00, 0x00,0x67,0xc0,0x00, 0x00,0x3e,0x92,0x00, 0x00,0x1a,0x68,0x00, 0xf7,0x63,0x0c,0x00)
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentPalette"   -Value $defaultPalette -Type Binary -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "StartColorMenu"  -Value 0xffc06700      -Type DWord  -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentColorMenu" -Value 0xffd47800      -Type DWord  -Force

                    # DWM defaults (mavi accent)
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableWindowColorization" -Value 0          -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor"             -Value 0xffd47800 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorizationColor"        -Value 0xc40078d4 -Type DWord -Force
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorizationAfterglow"    -Value 0xc40078d4 -Type DWord -Force

                    Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value "0 0 0" -Force

                    # === BOLUM 2: WALLPAPER + KILIT EKRANI -> defaults ===
                    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Recurse -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value "C:\Windows\Web\Wallpaper\Windows\img0.jpg" -Type String -Force -ErrorAction SilentlyContinue
                    rundll32.exe user32.dll, UpdatePerUserSystemParameters
                    Remove-Item -Path "C:\Windows\Black.jpg" -Force -ErrorAction SilentlyContinue

                    Refresh-WindowsTheme
                    Write-Host "[Karanlik] Tum siyah yuzeyler default (light) gore donduruldu."
                '
            },

			@{ Name="Başlat Menüsü: Layout"; SubCategory="Başlat"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="Start_Layout"; Type="DWord"; Data=1; Undo=0; RestartExplorer=$false },
            @{ Name="Başlat Menüsü: En son Eklenen Kapat"; SubCategory="Başlat"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; ValueName="ShowRecentList"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ Name="Başlat Menüsü: Atlama listesi Kapat"; SubCategory="Başlat"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="Start_TrackDocs"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ Name="Gözatma Geçmişi Kapat"; SubCategory="Başlat"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="Start_RecoPersonalizedSites"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ Name="İpuçları, kısayollar için Önerileri Kapat"; SubCategory="Başlat"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="Start_IrisRecommendations"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ Name="Hesapla İlgili Bildirimleri Kapat"; SubCategory="Başlat"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="Start_AccountNotifications"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ Name="Başlatta Web Arama Sonuçlarını Kapat"; SubCategory="Başlat"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; ValueName="BingSearchEnabled"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{  
                Name="Başlat Önerilenler Bölümünü Kapat";
				SubCategory="Başlat";
				RestartExplorer="Hard";
				Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; ValueName="HideRecommendedSection"; Type="DWord"; Data=1; Undo=0 },
					@{ Key="HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education"; ValueName="IsEducationEnvironment"; Type="DWord"; Data=1; Undo=0 },
					@{ Key="HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"; ValueName="HideRecommendedSection"; Type="DWord"; Data=1; Undo=0 }
                ) 
			},
			@{ Name="Arama Butonunu Gizle"; SubCategory="Görev Çubuğu"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; ValueName="SearchboxTaskbarMode"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
            @{ Name="Görev Görünümü Butonunu Gizle"; SubCategory="Görev Çubuğu"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="ShowTaskViewButton"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
            @{
                Name="Pencere Öğelerini (Widget) Kapat";
				SubCategory="Görev Çubuğu";
				RestartExplorer=$false;
				Batch=@(
                    # 1. Kullanıcı Ayarı (Erişim hatası verse bile önemli değil)
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="TaskbarDa"; Type="DWord"; Data=0; Undo=1 },

                    # 2. Grup İlkesi (GPO) - ASIL İŞİ YAPAN BU
                    # Bu ayar 0 olduğunda sistem widgetları tamamen devre dışı bırakır.
					@{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; ValueName="AllowNewsAndInterests"; Type="DWord"; Data=0; Undo=1 }
                )
			},

			# === GÖREV ÇUBUĞU EK TWEAK'LERİ (FR33THY 1 Start Menu Taskbar.ps1 birebir) ===
			@{
				Name="Görev Çubuğunu Ortala (Win11)";
				SubCategory="Görev Çubuğu";
				Description="Win11 görev çubuğunu ortaya hizalar (varsayılan davranış). TaskbarAl: 0=Sol, 1=Orta. Sol-aligned bir kurulumdan ortaya çevirmek için. Win11 default kurulumda TaskbarAl yazılı olmadığı halde merkez davranışı vardır — bu durum da 'aktif' sayılır.";
				Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="TaskbarAl"; Type="DWord"; Data=1; Undo=0; RestartExplorer="Soft";
				DetectScript='
					# Value yoksa Win11 default = ortali (1) sayilir
					$v = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -ErrorAction SilentlyContinue).TaskbarAl
					return ($null -eq $v -or "$v" -eq "1")
				'
			},
			@{
				Name="Chat Butonunu Gizle";
				SubCategory="Görev Çubuğu";
				Description="Görev çubuğundaki Microsoft Teams Chat butonunu kaldırır. Win11 23H2+ varsayılan kurulumda Chat butonu zaten yok — TaskbarMn yazılı olmasa bile 'aktif' sayılır.";
				Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="TaskbarMn"; Type="DWord"; Data=0; Undo="DELETE_VALUE"; RestartExplorer="Soft";
				DetectScript='
					# Value yoksa veya 0 ise Chat butonu yok (her iki durumda da aktif)
					$v = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -ErrorAction SilentlyContinue).TaskbarMn
					return ($null -eq $v -or "$v" -eq "0")
				'
			},
			@{
				Name="Copilot Butonunu Gizle";
				SubCategory="Görev Çubuğu";
				Description="Görev çubuğundaki Copilot butonunu kaldırır. Copilot iconu Win11'in bazi versiyonlarinda varsayilan olarak yok — value yazılı olmasa bile aktif sayılır.";
				Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="ShowCopilotButton"; Type="DWord"; Data=0; Undo="DELETE_VALUE"; RestartExplorer="Soft";
				DetectScript='
					$v = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -ErrorAction SilentlyContinue).ShowCopilotButton
					return ($null -eq $v -or "$v" -eq "0")
				'
			},
			@{
				Name="Meet Now Butonunu Gizle";
				SubCategory="Görev Çubuğu";
				Description="Sistem tepsisindeki Skype Meet Now ikonunu gizler. Win11 versiyonlarinda Meet Now zaten kaldirilmis durumda olabilir — value yazılı olmasa bile aktif sayılır.";
				Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; ValueName="HideSCAMeetNow"; Type="DWord"; Data=1; Undo="DELETE_VALUE"; RestartExplorer="Soft";
				DetectScript='
					$v = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -ErrorAction SilentlyContinue).HideSCAMeetNow
					return ($null -eq $v -or "$v" -eq "1")
				'
			},
			@{
				Name="Tüm Tray İkonlarını Göster";
				SubCategory="Görev Çubuğu";
				Description="Sistem tepsisindeki tüm gizli ikonları görünür yapar (taşma menüsü kapatır). Ek olarak NotifyIconSettings altındaki tüm ikon kayıtlarını 'IsPromoted=1' yapar.";
				RestartExplorer="Soft";
				DetectScript='
					$v = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -ErrorAction SilentlyContinue).EnableAutoTray
					return ("$v" -eq "0")
				';
				Command='
					Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWord -Force
					$nip = Get-ChildItem -Path "registry::HKEY_CURRENT_USER\Control Panel\NotifyIconSettings" -Recurse -Force -ErrorAction SilentlyContinue
					foreach ($k in $nip) {
						$cur = (Get-ItemProperty -Path "registry::$k" -Name "IsPromoted" -ErrorAction SilentlyContinue).IsPromoted
						if ($cur -ne 0 -and $cur -ne $null) {
							Set-ItemProperty -Path "registry::$k" -Name "IsPromoted" -Value 1 -Force -ErrorAction SilentlyContinue
						}
					}
				';
				UndoCommand='
					Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Force -ErrorAction SilentlyContinue
					$nip = Get-ChildItem -Path "registry::HKEY_CURRENT_USER\Control Panel\NotifyIconSettings" -Recurse -Force -ErrorAction SilentlyContinue
					foreach ($k in $nip) {
						$cur = (Get-ItemProperty -Path "registry::$k" -Name "IsPromoted" -ErrorAction SilentlyContinue).IsPromoted
						if ($cur -ne 0 -and $cur -ne $null) {
							Set-ItemProperty -Path "registry::$k" -Name "IsPromoted" -Value 0 -Force -ErrorAction SilentlyContinue
						}
					}
				'
			},

			# === BAŞLAT MENÜSÜ TEMIZ DUZEN (FR33THY 1 Start Menu Taskbar.ps1 birebir, BIRLESTIRILMIS) ===
			# 3 ayri tweak (Liste Gorunumu, Yeni Start Menu, Layout Import) tek kompozit tweak'te birlestirildi.
			@{
				Name="Başlat Menüsü: Format Sonrası Temiz Düzen (FR33THY)";
				SubCategory="Başlat";
				Risk="Medium";
				RestartExplorer="Hard";
				Description="Format sonrasi tek tikla temiz Baslat menusu — FR33THY birebir kompozit. Uc isi tek seferde yapar:`n`n1) **Liste Gorunumu** — Tum Uygulamalar bolumunu kategoriden duz listeye cevirir (AllAppsViewMode=2)`n2) **Yeni Start Menu Duzeni** — Win11 22H2+ 'Daha Fazla Sabitleme/Oneri' duzeni (4 FeatureManagement Override 14 key)`n3) **Layout Import** — Win10 icin bos LayoutModificationTemplate XML, Win11 icin FR33THY'nin clean start2.bin dosyasi`n`n⚠️ DIKKAT: Mevcut sabit kayitlariniz (pinned tiles) silinir. Sifirdan baslamak icin uygundur.`n⚠️ Explorer 5 sn icinde 2 kez restart olur (Win10 layout flow gerekli).";
				DetectScript='
					# Aktif sayilma kriteri: tum bilesenler uygulanmis olmali
					# 1) start2.bin dosyasi var (Win11) VEYA Win10 ise bu kontrol atlanir
					# 2) AllAppsViewMode = 2
					# 3) En az bir FeatureManagement Override 14 key uygulanmis (EnabledState=2)
					$avm = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "AllAppsViewMode" -ErrorAction SilentlyContinue).AllAppsViewMode
					if ("$avm" -ne "2") { return $false }

					$fm = (Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\14\2792562829" -Name "EnabledState" -ErrorAction SilentlyContinue).EnabledState
					if ("$fm" -ne "2") { return $false }

					# Win11 ise start2.bin de olmali; Win10 ise (LocalState klasoru yok) bu kontrolu atla
					$localState = "$env:USERPROFILE\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
					if (Test-Path $localState) {
						$start2 = "$localState\start2.bin"
						if (-not (Test-Path $start2)) { return $false }
					}
					return $true
				';
				Command='
					Write-Host "[StartMenu] Format sonrasi temiz duzen uygulaniyor..."

					# 1. AllAppsViewMode = Liste
					Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "AllAppsViewMode" -Value 2 -Type DWord -Force

					# 2. FeatureManagement Override 14 (4 key) — Yeni Win11 22H2+ duzeni
					$fmKeys = @("2792562829","3036241548","734731404","762256525")
					foreach ($id in $fmKeys) {
						$p = "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\14\$id"
						if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction SilentlyContinue | Out-Null }
						Set-ItemProperty -Path $p -Name "EnabledState" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
					}

					# 3. Win10 LayoutModificationTemplate XML + Win11 start2.bin import
					Invoke-StartMenuLayoutImport -Mode Clean
				';
				UndoCommand='
					Write-Host "[StartMenu] Geri aliniyor..."

					# 1. AllAppsViewMode = Kategori (default)
					Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "AllAppsViewMode" -Value 0 -Type DWord -Force

					# 2. FeatureManagement Override 14 sil
					$fmKeys = @("2792562829","3036241548","734731404","762256525")
					foreach ($id in $fmKeys) {
						$p = "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\14\$id"
						Remove-ItemProperty -Path $p -Name "EnabledState" -Force -ErrorAction SilentlyContinue
					}

					# 3. Win10 default layout + Win11 start2.bin sil
					Invoke-StartMenuLayoutImport -Mode Default
				'
			}
        )
		"Oyun" = @(
			@{ Name="Gamebar Kapat"; Key="HKCU:\Software\Microsoft\GameBar"; ValueName="UseNexusForGameBarEnabled"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ Name="Oyun Modunu Aç"; Key="HKCU:\Software\Microsoft\GameBar"; ValueName="AutoGameModeEnabled"; Type="DWord"; Data=1; Undo=0; RestartExplorer=$false }
		)

       "Gizlilik ve Telemetri" = @(
            @{  Name="Reklam Kimliğini Kapat";
				SubCategory="Genel";
				RestartExplorer=$false;
				Batch=@(
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\AdvertisingInfo"; ValueName="Value"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; ValueName="Enabled"; Type="DWord"; Data=0; Undo=1 }
                ) 
			},
			@{  
				Name="Yerel olarak uygun içerik Kapat";
				SubCategory="Genel";
				RestartExplorer=$false; # Bu ayar için explorer gerekmez, Settings uygulamasını kapatıp açmak yeterlidir.
				Batch=@(
					# 1. Dil Listesine Erişimi Kapat (Switch'i Kapalı konuma getirir)
					# 1 = Opt-Out (Kapalı), 0 = Opt-In (Açık)
					@{ Key="HKCU:\Control Panel\International\User Profile"; ValueName="HttpAcceptLanguageOptOut"; Type="DWord"; Data=1; Undo=0 },

					# 2. İnternet Explorer/Edge tarafındaki dil bilgisini temizle (İsteğe bağlı)
					@{ Key="HKCU:\Software\Microsoft\Internet Explorer\International"; ValueName="AcceptLanguage"; Type="String"; Data=""; Undo="tr" }
				) 
			},
			@{ Name="Başlatma ve Arama Sonuçlarını Geliştir Kapat"; SubCategory="Genel"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="Start_TrackProgs"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ 
                Name="Ayarlar ve Windows Genelinde Önerileri Gizle"; 
                SubCategory="Genel";
                RestartExplorer=$false;
                Batch=@(
                    # --- 1. KULLANICI AYARLARI (HKCU) ---
                    # Kapatırken 0, Açarken 1 yapıyoruz.
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; ValueName="SystemPaneSuggestionsEnabled"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; ValueName="SubscribedContent-338393Enabled"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; ValueName="SubscribedContent-353694Enabled"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; ValueName="SubscribedContent-353696Enabled"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; ValueName="SubscribedContent-338389Enabled"; Type="DWord"; Data=0; Undo=1 },

                    # --- 2. POLICY KİLİTLERİ (HKLM) - SORUNU ÇÖZEN KISIM ---
                    # Bu anahtarlar varsa, kullanıcı HKCU'dan açsa bile Windows geri kapatır.
                    # Uygula (Kapat): Değeri 1 yapıyoruz (Engelle).
                    # Geri Al (Aç): Değeri 0 yapıyoruz (Engeli Kaldır).
                    
                    # Windows İpuçları (Soft Landing)
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; ValueName="DisableSoftLanding"; Type="DWord"; Data=1; Undo=0 },
                    
                    # Tüketici Özellikleri (Consumer Features)
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; ValueName="DisableWindowsConsumerFeatures"; Type="DWord"; Data=1; Undo=0 }
                )
            },
            @{ Name="Bildirimleri Ayarlar Uygulamasında Göster Kapat"; SubCategory="Genel"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications"; ValueName="EnableAccountNotifications"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
			@{ 
                Name="Windows Tanılama Verileri Kapat"; 
                SubCategory="Genel"; 
                RestartExplorer=$false;
                # Command kullanıyoruz çünkü önce izinleri (ACL) düzeltmemiz lazım.
                Command='
					$key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
					if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
					
					# İzinlerle oynamak yerine sadece policy degerlerini atiyoruz
					try {
						Set-ItemProperty -Path $key -Name "AllowTelemetry" -Value 0 -Type DWord -Force
						Set-ItemProperty -Path $key -Name "MaxTelemetryAllowed" -Value 0 -Type DWord -Force
						Set-ItemProperty -Path $key -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord -Force
						Stop-Service "DiagTrack" -Force -ErrorAction SilentlyContinue
						Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
					} catch {
						Write-Warning "Telemetri kapatılırken erişim engellendi. GPO kullanılıyor."
					}
				';
                
                # Geri Alma: Değerleri silerek varsayılana döndür
                UndoCommand='
                    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue;
                    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "MaxTelemetryAllowed" -ErrorAction SilentlyContinue;
                    Start-Service "DiagTrack" -ErrorAction SilentlyContinue;
                ';
            },
            # --- KONUM (ÖZEL POLICY) ---
            @{ 
                Name="Konum Hizmetlerini Tamamen Kapat";
				SubCategory="Uygulama İzinleri";
                RestartExplorer=$false;
                Batch=@(
                    # 1. Windows Konum Sensörünü Zorla Kapat (Policy)
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; ValueName="DisableLocation"; Type="DWord"; Data=1; Undo="DELETE_VALUE" },
                    # 2. Donanım Sensörünü Devre Dışı Bırak
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"; ValueName="SensorPermissionState"; Type="DWord"; Data=0; Undo=1 },
                    # 3. İzinler
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; ValueName="Value"; Type="String"; Data="Deny"; Undo="DELETE_VALUE" }
                )
            },

            # --- KAMERA (ZATEN ÇALIŞIYORDU - AYNI KALDI) ---
            @{ 
                Name="Kamera (Webcam) Erişimini Tamamen Kapat";
				SubCategory="Uygulama İzinleri";
                RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"; ValueName="Value"; Type="String"; Data="Deny"; Undo="DELETE_VALUE" },
                    @{ Key="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"; ValueName="Value"; Type="String"; Data="Deny"; Undo="DELETE_VALUE" },
                    @{ Key="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E5323777-F976-4f5b-9B55-B94699C46E44}"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" },
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessCamera"; Type="DWord"; Data=2; Undo="DELETE_VALUE" }
                )
            },

            @{ Name="Sesle Etkinleştirme Kapat"; SubCategory="Uygulama İzinleri"; Key="HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps"; ValueName="AgentActivationEnabled"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },

            # --- AŞAĞIDAKİLERİN HEPSİNE "POLICY" EKLENDİ ---
            # Data=2 (Force Deny), Undo="DELETE_VALUE" (Varsayılana Dön)

            @{ 
                Name="Bildirim Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessNotifications"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },
            
            @{ 
                Name="Hesap Bilgileri Erişimi Kapat"; SubCategory="Uygulama İzinleri"; Batch=@( 
                @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessAccountInfo"; Type="DWord"; Data=2; Undo="DELETE_VALUE" }, 
                @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
				) 
			},

            @{ 
				Name="Kişilere (Contacts) Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
				Batch=@(
                    # 1. POLICY (Kilit)
                    # Kapatırken: 2 (Zorla Kapat)
                    # Geri Alırken: DELETE_VALUE (Kilidi Kaldır)
					@{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessContacts"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
					
                    # 2. HKLM CONSENT (Ana Şalter - Senin Gözlemlediğin Yer)
                    # Kapatırken: Deny
                    # Geri Alırken: Allow (Açıkça İzin Ver)
					@{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }

				)
			},

            @{ 
                Name="Takvim Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessCalendar"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{ 
                Name="Telefon Araması Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessPhone"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{ 
                Name="Arama Geçmişi Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessCallHistory"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{ 
                Name="E-posta Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessEmail"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{ 
                Name="Görevler (Tasks) Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessTasks"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{ 
                Name="Mesajlaşma (Chat) Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessMessaging"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{ 
                Name="Radyo (Bluetooth vb.) Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsAccessRadios"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{
                Name="Uygulama Tanılama (Diagnostics) Erişimi Kapat";
				SubCategory="Uygulama İzinleri";
				RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"; ValueName="LetAppsGetDiagnosticInfo"; Type="DWord"; Data=2; Undo="DELETE_VALUE" },
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics"; ValueName="Value"; Type="String"; Data="Deny"; Undo="Allow" }
                )
            },

            @{
                Name="Arka Plan Uygulamalarını Kapat (Sistem Politikası)";
                SubCategory="Uygulama İzinleri";
                Description="Microsoft Store uygulamalarinin arka planda calismasini engeller — Group Policy seviyesinde sistem-wide. Tum kullanicilara uygulanir, kullanicinin user-level secimini override eder. RAM ve pil tasarrufu, telemetri trafigi azaltma. Bildirim/saat/posta gibi sistem ozellikleri etkilenmez. Klasik Win32 uygulamalari etkilenmez.`n`nApply/Undo sonrasinda Windows Ayarlar > Gizlilik > Arka Plan Uygulamalari paneli otomatik acilir (gorsel dogrulama).";
                DetectScript='
                    $v = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -ErrorAction SilentlyContinue).LetAppsRunInBackground
                    return ("$v" -eq "2")
                ';
                Command='
                    $key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
                    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
                    Set-ItemProperty -Path $key -Name "LetAppsRunInBackground" -Value 2 -Type DWord -Force
                    Start-Process "ms-settings:privacy-backgroundapps" -ErrorAction SilentlyContinue
                ';
                UndoCommand='
                    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Force -ErrorAction SilentlyContinue
                    Start-Process "ms-settings:privacy-backgroundapps" -ErrorAction SilentlyContinue
                ';
                RestartExplorer=$false
            }
        )

        # --- 4. WINDOWS GEZGİNİ ---
        "Windows Gezgini" = @(
            @{ Name="Dosya Uzantılarını Göster"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="HideFileExt"; Type="DWord"; Data=0; Undo=1; RestartExplorer="Soft" },
            @{ Name="Gizli Dosyaları Göster"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName="Hidden"; Type="DWord"; Data=1; Undo=2; RestartExplorer="Soft" },
            @{ Name="Bu Bilgisayar Simgesini Masaüstüne Koy"; Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"; ValueName="{20D04FE0-3AEA-1069-A2D8-08002B30309D}"; Type="DWord"; Data=0; Undo=1; RestartExplorer="Soft" },
            @{ Name="Klasik Sağ Tık Menüsü (Win 11)"; Key="HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"; ValueName=""; Type="String"; Data=""; UndoCommand="Remove-Item -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue"; RestartExplorer="Hard"; Risk="High" }
        )

        # --- 5. SİSTEM VE OYUN ---
        "Sistem ve Oyun" = @(

            @{ Name="Yapışkan Tuşları Kapat"; Key="HKCU:\Control Panel\Accessibility\StickyKeys"; ValueName="Flags"; Type="String"; Data="506"; Undo="510"; RestartExplorer=$false },
            @{ Name="Xbox Game DVR Kapat"; Key="HKCU:\System\GameConfigStore"; ValueName="GameDVR_Enabled"; Type="DWord"; Data=0; Undo=1; RestartExplorer=$false },
            @{ Name="Hazırda Bekletmeyi Kapat (Hibernate)"; Command="powercfg -h off"; UndoCommand="powercfg -h on"; RestartExplorer=$false },

            # === UAC TAMAMEN KAPAT (FR33THY 31 UAC.ps1 birebir) ===
            @{
                Name="UAC (Kullanıcı Hesabı Denetimi) Kapat";
                Description="Windows User Account Control (UAC) prompt'larini tamamen devre disi birakir. EnableLUA=0 ile sistem 'Yonetici olarak calistir' sorulari sormaz.`n`n⚠️ YUKSEK RISK ⚠️ UAC sistemin temel guvenlik katmanlarindan biridir. Kapatildiginda:`n• Tum uygulamalar otomatik olarak yonetici yetkisiyle calisir`n• Kotu amacli yazilim sistem dosyalarini kolayca degistirebilir`n• Microsoft Store + bazi UWP uygulamalar calismaz`n• Edge IE Mode bozulabilir`n`nFormat sonrasi 'kullanim kolayligi' icin onerilse de kotu amacli yazilim ihtimali artar. Kullanmadan once duzgun antivirus + dikkatli internet aliskanliklari kazanin.";
                Risk="High"; RestartExplorer=$false;
                Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System";
                ValueName="EnableLUA"; Type="DWord"; Data=0; Undo=1
            },

            # === LOUDNESS EQ AKTIF ET (FR33THY 24 Loudness EQ.ps1 birebir) ===
            @{
                Name="Ses: Loudness EQ Aktif Et (Enhancements Tab Unhide)";
                Description="Tum ses cikis cihazlarinin (Render) FxProperties altina Loudness Equalization PKEY yazar — Ses ozellikleri penceresinde 'Enhancements' (Iyilestirmeler) sekmesini gorunur yapar ve Loudness EQ ile dinamik ses seviyesi normalizasyonu aktif olur. Sessiz dialoglari yukseltir, gurultulu sahneleri kisar.`n`n⚠️ Audio servisleri yeniden baslatilir (anlik kesinti olabilir).`n💡 Calismiyorsa: ses surucusunu yeniden yukleyin veya farkli bir cihaz deneyin.";
                Risk="Low"; RestartExplorer=$false;
                DetectScript='
                    # Marker: Render altinda en az bir cihazda FxProperties\{d04e05a6-...},3 mevcut
                    $base = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
                    $any = $false
                    Get-ChildItem -Path $base -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        $fx = "$($_.PSPath)\FxProperties"
                        if (Test-Path $fx) {
                            $v = (Get-ItemProperty -Path $fx -Name "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3" -ErrorAction SilentlyContinue)."{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3"
                            if ($v -and $v -match "5860E1C5") { $any = $true }
                        }
                    }
                    return $any
                ';
                Command='
                    Write-Host "[LoudnessEQ] Audio servisleri durduruluyor..."
                    Stop-Service audiosrv -Force -ErrorAction SilentlyContinue
                    Stop-Service AudioEndpointBuilder -Force -ErrorAction SilentlyContinue

                    $base = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
                    $regContent = "Windows Registry Editor Version 5.00`n"
                    $count = 0
                    Get-ChildItem -Path $base -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        $regPath = $_.Name
                        $regContent += "`n[$regPath\FxProperties]`n"
                        $regContent += "`"{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3`"=`"{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}`"`n"
                        $count++
                    }

                    $regFile = "$env:SystemRoot\Temp\loudnesseq.reg"
                    Set-Content -Path $regFile -Value $regContent -Force
                    Write-Host "[LoudnessEQ] $count cihaz icin reg dosyasi yazildi: $regFile"

                    & regedit /s $regFile
                    Start-Sleep -Milliseconds 500
                    Remove-Item $regFile -Force -ErrorAction SilentlyContinue

                    Write-Host "[LoudnessEQ] Audio servisleri baslatiliyor..."
                    Start-Service audiosrv -ErrorAction SilentlyContinue
                    Start-Service AudioEndpointBuilder -ErrorAction SilentlyContinue

                    # Ses kontrol panelini ac (gorsel dogrulama, FR33THY birebir)
                    Start-Process mmsys.cpl -ErrorAction SilentlyContinue
                    Write-Host "[LoudnessEQ] Tamamlandi. Enhancements sekmesi acilmis olmali."
                ';
                UndoCommand='
                    Write-Host "[LoudnessEQ] Geri aliniyor..."
                    Stop-Service audiosrv -Force -ErrorAction SilentlyContinue
                    Stop-Service AudioEndpointBuilder -Force -ErrorAction SilentlyContinue

                    $base = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
                    Get-ChildItem -Path $base -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        $fx = "$($_.PSPath)\FxProperties"
                        if (Test-Path $fx) {
                            Remove-ItemProperty -Path $fx -Name "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3" -Force -ErrorAction SilentlyContinue
                        }
                    }

                    Start-Service audiosrv -ErrorAction SilentlyContinue
                    Start-Service AudioEndpointBuilder -ErrorAction SilentlyContinue
                    Write-Host "[LoudnessEQ] FxProperties degerleri silindi (default)."
                '
            },

            # --- YENİ EKLENEN GÜVENLİ PERFORMANS / INPUT LAG TWEAK'LERİ (Intel/AMD agnostik) ---

            @{
                Name="Power Throttling Kapat (CPU Tam Frekans)";
                Description="Win10/11 Modern Standby sistemlerde Windows'un işlemci frekansını ön plan uygulamaları için kısıtlamasını engeller. Oyunlarda %2-5 FPS stabilizesi. Masaüstü ve dizüstüde güvenli; dizüstüde batarya süresine ~%5 etki edebilir.";
                Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Power\PowerThrottling";
                ValueName="PowerThrottlingOff"; Type="DWord"; Data=1; Undo=0;
                Risk="Low"; RestartExplorer=$false
            },
            @{
                Name="Fullscreen Optimizations (FSO) Kapat";
                Description="DirectX 11/12 oyunlarda Windows'un 'fullscreen optimizations' katmanını devre dışı bırakır — gerçek exclusive fullscreen modu kullanılır. Input lag %1-3 azalır, görsel artifact yaratmaz.";
                Risk="Low"; RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKCU:\System\GameConfigStore"; ValueName="GameDVR_FSEBehavior"; Type="DWord"; Data=2; Undo=0 },
                    @{ Key="HKCU:\System\GameConfigStore"; ValueName="GameDVR_HonorUserFSEBehaviorMode"; Type="DWord"; Data=1; Undo=0 },
                    @{ Key="HKCU:\System\GameConfigStore"; ValueName="GameDVR_DXGIHonorFSEWindowsCompatible"; Type="DWord"; Data=1; Undo=0 }
                )
            },
            @{
                Name="Menu Açılma Gecikmesini Sıfırla (MenuShowDelay=0)";
                Description="Sağ tık, Başlat menüsü ve diğer Windows context menüleri ANINDA açılır (varsayılan 400ms gecikme kalkar). Sadece UI hızlanması — sistem performansına etkisi yok.";
                Key="HKCU:\Control Panel\Desktop"; ValueName="MenuShowDelay"; Type="String"; Data="0"; Undo="400";
                Risk="Low"; RestartExplorer=$false
            },
            @{
                Name="NDU Servisini Kapat (Network Polling)";
                Description="Network Diagnostics Usage servisi sürekli ağ trafiği polling yapar (~30-50 MB RAM, az CPU). Kapatınca network monitoring durur ama günlük kullanımda fark yaratmaz. Pi-hole/QoS gibi araçlar etkilenmez.`nServis adı: NDU";
                Command="Set-Service -Name Ndu -StartupType Disabled -ErrorAction SilentlyContinue";
                UndoCommand="Set-Service -Name Ndu -StartupType Manual -ErrorAction SilentlyContinue";
                # Detection: Get-Service ile StartType — Set-Service gecikmesinden bagimsiz, dil bagimsiz (servis name'e bakar)
                DetectScript="(Get-Service -Name Ndu -ErrorAction SilentlyContinue).StartType -eq 'Disabled'";
                Risk="Low"; RestartExplorer=$false
            },
            @{
                Name="Memory Compression Kapat (16GB+ RAM için)";
                Description="Windows'un boş RAM'i sıkıştırma mekanizmasını kapatır. 16GB+ RAM'i olanlarda CPU yükü azalır (compression yok), erişim daha hızlı. ⚠️ 8GB altı RAM'de YAPMA — RAM yetmez, swap'a düşer.";
                Command="Disable-MMAgent -MemoryCompression";
                UndoCommand="Enable-MMAgent -MemoryCompression";
                # Detection: Get-MMAgent state'ten oku — registry tabanlı bir tweak değil
                DetectScript="(Get-MMAgent).MemoryCompression -eq `$false";
                Risk="Medium"; RestartExplorer=$false
            },
            @{
                Name="Arka Plan Uygulamalarını Kapat (UWP)";
                Description="Mail, Calendar, Photos gibi UWP (Mağaza) uygulamalarının arka planda çalışmasını engeller. RAM ve network tasarrufu. Bildirim almıyorsan dert değil; e-posta canlı bildirim isteyenler dikkat.";
                Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications";
                ValueName="GlobalUserDisabled"; Type="DWord"; Data=1; Undo=0;
                Risk="Low"; RestartExplorer=$false
            },
            @{
                Name="AppInstaller Deneysel Özellikleri Kapat";
                Description="Microsoft Store AppInstaller'ın deneysel/telemetri özelliklerini kapatır. Az network ve CPU tasarrufu.";
                Key="HKLM:\Software\Policies\Microsoft\Windows\AppInstaller";
                ValueName="EnableExperimentalFeatures"; Type="DWord"; Data=0; Undo=1;
                Risk="Low"; RestartExplorer=$false
            },
            @{
                Name="DPS (Tanılama) Servisini Manuele Al";
                Description="Diagnostic Policy Service'i 'Otomatik' yerine 'Manuel' başlatma'ya alır. Boot'ta otomatik başlamaz, sadece istenince çalışır. CPU/RAM tasarrufu.`nNot: Türkçe Windows'ta services.msc'de bu servis 'Tanılayıcı İlkesi Hizmeti' olarak görünür. ('Diagnostic Execution Service' AYRI bir servistir, karıştırma — Get-Service DPS ile doğrula.)";
                Command="Set-Service -Name DPS -StartupType Manual -ErrorAction SilentlyContinue";
                UndoCommand="Set-Service -Name DPS -StartupType Automatic -ErrorAction SilentlyContinue";
                # Detection: Get-Service StartType — dil bagimsiz, registry erisimi gerekmez
                DetectScript="(Get-Service -Name DPS -ErrorAction SilentlyContinue).StartType -eq 'Manual'";
                Risk="Low"; RestartExplorer=$false
            }
        )
        
        # --- 6. GÜÇ PLANLARI ---
        "Güç Planı" = @(
            @{ 
                Name="Nihai Performans Güç Planını Aktif Et";
				Group="PowerPlan";
                Command='$p = @(powercfg /list | Select-String "(Nihai|Ultimate) Performan") | Select-Object -First 1; if ($p) { $id = $p.ToString().Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)[3]; powercfg -setactive $id } else { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; $p = @(powercfg /list | Select-String "(Nihai|Ultimate) Performan") | Select-Object -First 1; if ($p) { $id = $p.ToString().Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)[3]; powercfg -setactive $id } }';
                UndoCommand="powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e"; 
                RestartExplorer=$false 
            },
            @{ Name="Yüksek Performans Güç Planını Aktif Et"; Group="PowerPlan"; Command="powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; UndoCommand="powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e"; RestartExplorer=$false }
        )
        
        # --- 7. UYGULAMA KALDIRMA ---
        "Uygulama Kaldırma" = @(
            @{
                Name="OneDrive'ı Sistemden Tamamen Kaldır";
                Command='taskkill /f /im OneDrive.exe 2>$null; if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait } elseif (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") { Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait } else { Write-Host "OneDrive Setup bulunamadi" }';
                UndoCommand="";
                RestartExplorer=$false
            },

            # === FR33THY 13 Bloatware.ps1 birebir — 5 ek uygulama kaldirma ===
            @{
                Name="Microsoft GameInput Kaldır";
                Description="Microsoft GameInput, 2022'de cikan yeni nesil oyun girisi (controller/joystick) SDK'sidir — XInput ve DirectInput'un halefi. Bazi yeni Xbox / Game Pass oyunlarinda kullanilir.`n`n📋 KIM ICIN GEREKSIZ:`n• Sadece Steam/Epic/eski oyun oynayan veya hic oyun oynamayan kullanicilar`n• Game Pass kullanmayanlar`n`n⚠️ KIM ICIN GEREKLI:`n• Yeni Xbox titles + controller kullananlar (input sorunu yasanabilir)`n`n📊 TWEAK DURUM IPUCU:`n• Tweak 'pasif' goruluyorsa → GameInput sistemde **YUKLU** (Apply edilirse kaldirilir)`n• Tweak 'aktif' goruluyorsa → GameInput sistemde **YUKLU DEGIL** (yapacak is yok, zaten temiz)";
                Risk="Low"; RestartExplorer=$false;
                DetectScript='
                    $f = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Microsoft GameInput*" }
                    return ($null -eq $f)
                ';
                Command='
                    $f = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Microsoft GameInput*" }
                    if ($f) {
                        $guid = $f.PSChildName
                        Write-Host "[GameInput] Kaldiriliyor: $guid"
                        Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
                    } else {
                        Write-Host "[GameInput] Yuklu degil — atlandi."
                    }
                ';
                UndoCommand=""
            },

            @{
                Name="Remote Desktop Connection (mstsc) Kaldır";
                Description="Klasik Uzak Masaustu Baglantisi (mstsc) uygulamasini kaldirir. Win10'da `mstsc /Uninstall` komutuyla program kaldirilir. Win11'de mstsc.exe sistem bileseni oldugu icin /Uninstall etkisiz olabilir — bu durumda tweak marker olarak Apply edildigini kaydeder.";
                Risk="Low"; RestartExplorer=$false;
                DetectScript='
                    # Iki kosul: ya mstsc.exe gercekten silinmis ya da bizim marker registry key set edilmis
                    if (-not (Test-Path "$env:SystemRoot\System32\mstsc.exe")) { return $true }
                    $m = (Get-ItemProperty -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Name "RdcUninstall" -ErrorAction SilentlyContinue).RdcUninstall
                    return ("$m" -eq "1")
                ';
                Command='
                    if (Test-Path "$env:SystemRoot\System32\mstsc.exe") {
                        Write-Host "[mstsc] Uninstall baslatiliyor..."
                        try { Start-Process "mstsc" -ArgumentList "/Uninstall" -ErrorAction SilentlyContinue } catch { }
                        $running = $true; $timeout = 0
                        while ($running) {
                            $p = Get-Process -Name mstsc -ErrorAction SilentlyContinue
                            if ($p -and $p.MainWindowHandle -ne 0) {
                                Stop-Process -Force -Name mstsc -ErrorAction SilentlyContinue | Out-Null
                                $running = $false
                            }
                            Start-Sleep -Milliseconds 100
                            $timeout++
                            if ($timeout -gt 100) { Stop-Process -Name mstsc -Force -ErrorAction SilentlyContinue; $running = $false }
                        }
                        Write-Host "[mstsc] Kaldirma komutu tamamlandi."
                    } else {
                        Write-Host "[mstsc] Yuklu degil — atlandi."
                    }
                    # Marker — Win11 sistem bileseni olarak kaldirilmasa bile kullanici tweak uyguladigini bilsin
                    if (-not (Test-Path "HKCU:\Software\GeminiCare\AppliedMarkers")) {
                        New-Item -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Set-ItemProperty -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Name "RdcUninstall" -Value 1 -Type DWord -Force
                ';
                UndoCommand='
                    Remove-ItemProperty -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Name "RdcUninstall" -Force -ErrorAction SilentlyContinue
                    Write-Host "[mstsc] Marker silindi. NOT: mstsc.exe Win11 sistem bileseni olarak otomatik geri yuklenmiyor — gerekirse manuel olarak winget/Optional Features ile yukleyin."
                '
            },

            @{
                Name="Eski Snipping Tool (Win10) Kaldır";
                Description="Klasik Win10 Ekran Alintisi aracini (SnippingTool.exe) kaldirir. Win11 modern Snipping Tool etkilenmez. Win11'de eski araç zaten yok olabilir — marker ile Apply edildigi kaydedilir.";
                Risk="Low"; RestartExplorer=$false;
                DetectScript='
                    if (-not (Test-Path "$env:SystemRoot\System32\SnippingTool.exe")) { return $true }
                    $m = (Get-ItemProperty -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Name "OldSnippingUninstall" -ErrorAction SilentlyContinue).OldSnippingUninstall
                    return ("$m" -eq "1")
                ';
                Command='
                    if (Test-Path "$env:SystemRoot\System32\SnippingTool.exe") {
                        Write-Host "[SnippingTool] Uninstall baslatiliyor..."
                        try { Start-Process "$env:SystemRoot\System32\SnippingTool.exe" -ArgumentList "/Uninstall" -ErrorAction SilentlyContinue } catch { }
                        $running = $true; $timeout = 0
                        while ($running) {
                            $p = Get-Process -Name SnippingTool -ErrorAction SilentlyContinue
                            if ($p -and $p.MainWindowHandle -ne 0) {
                                Stop-Process -Force -Name SnippingTool -ErrorAction SilentlyContinue | Out-Null
                                $running = $false
                            }
                            Start-Sleep -Milliseconds 100
                            $timeout++
                            if ($timeout -gt 100) { Stop-Process -Name SnippingTool -Force -ErrorAction SilentlyContinue; $running = $false }
                        }
                        Write-Host "[SnippingTool] Kaldirma komutu tamamlandi."
                    } else {
                        Write-Host "[SnippingTool] Yuklu degil — atlandi."
                    }
                    if (-not (Test-Path "HKCU:\Software\GeminiCare\AppliedMarkers")) {
                        New-Item -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Set-ItemProperty -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Name "OldSnippingUninstall" -Value 1 -Type DWord -Force
                ';
                UndoCommand='
                    Remove-ItemProperty -Path "HKCU:\Software\GeminiCare\AppliedMarkers" -Name "OldSnippingUninstall" -Force -ErrorAction SilentlyContinue
                    Write-Host "[SnippingTool] Marker silindi."
                '
            },

            @{
                Name="Microsoft Update Health Tools Kaldır";
                Description="Microsoft Update Health Tools (telemetri ve uhssvc servisi) kaldirir. PLUGScheduler scheduled task'ini da siler.";
                Risk="Low"; RestartExplorer=$false;
                DetectScript='
                    $f = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Microsoft Update Health Tools*" }
                    $svc = Get-Service -Name uhssvc -ErrorAction SilentlyContinue
                    return ($null -eq $f -and $null -eq $svc)
                ';
                Command='
                    $f = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Microsoft Update Health Tools*" }
                    if ($f) {
                        $guid = $f.PSChildName
                        Write-Host "[UpdateHealth] Kaldiriliyor: $guid"
                        Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
                    }
                    cmd /c "reg delete `"HKLM\SYSTEM\ControlSet001\Services\uhssvc`" /f >nul 2>&1"
                    Unregister-ScheduledTask -TaskName PLUGScheduler -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                    Write-Host "[UpdateHealth] uhssvc + PLUGScheduler temizlendi."
                ';
                UndoCommand=""
            },

            @{
                Name="Şifresiz Giriş Devre Dışı (Klasik Şifre Açık)";
                Description="Win11'in 'sifresiz giris' (passwordless sign-in) varsayilanini kapatir. Klasik sifre/PIN ile giris yapilmasini saglar. Microsoft Hesabi ve yerel hesap icin gecerli.";
                Risk="Low"; RestartExplorer=$false;
                Key="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device";
                ValueName="DevicePasswordLessBuildVersion"; Type="DWord"; Data=0; Undo=2
            }
        )
        
        # --- 8. AĞ VE DNS ---
        "Ağ ve DNS Ayarları" = @(
            @{ 
                Name="DNS: Google (Hız ve Kararlılık)";
                Group="DNS";
                Command="Get-NetAdapter | Where Status -eq Up | Set-DnsClientServerAddress -ServerAddresses ('8.8.8.8', '8.8.4.4', '2001:4860:4860::8888', '2001:4860:4860::8844') -ErrorAction SilentlyContinue; ipconfig /flushdns > `$null"; 
                UndoCommand="Get-NetAdapter | Where Status -eq Up | Set-DnsClientServerAddress -ResetServerAddresses -ErrorAction SilentlyContinue; ipconfig /flushdns > `$null"; 
                RestartExplorer=$false 
            },
            @{ 
                Name="DNS: Cloudflare (Gizlilik ve Hız)";
                Group="DNS";
                Command="Get-NetAdapter | Where Status -eq Up | Set-DnsClientServerAddress -ServerAddresses ('1.1.1.1', '1.0.0.1', '2606:4700:4700::1111', '2606:4700:4700::1001') -ErrorAction SilentlyContinue; ipconfig /flushdns > `$null"; 
                UndoCommand="Get-NetAdapter | Where Status -eq Up | Set-DnsClientServerAddress -ResetServerAddresses -ErrorAction SilentlyContinue; ipconfig /flushdns > `$null"; 
                RestartExplorer=$false 
            },
            @{ 
                Name="DNS: Otomatik (Varsayılan / İSS)";
                Group="DNS";
                Command="Get-NetAdapter | Where Status -eq Up | Set-DnsClientServerAddress -ResetServerAddresses -ErrorAction SilentlyContinue; ipconfig /flushdns > `$null"; 
                UndoCommand=""; 
                RestartExplorer=$false 
            }
        )

        # --- 9. GELİŞMİŞ SİSTEM (BATCH) ---
        "Gelişmiş Sistem (Batch)" = @(
            @{
                Name="Cortana ve Cloud Aramayı Tamamen Kapat";
                RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; ValueName="AllowCloudSearch"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; ValueName="AllowCortana"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; ValueName="AllowCortanaAboveLock"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; ValueName="CortanaEnabled"; Type="DWord"; Data=0; Undo=1 },
                    @{ Key="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; ValueName="CortanaConsent"; Type="DWord"; Data=0; Undo=1 }
                )
            },

            # === COPILOT TAMAMEN KAPAT (FR33THY 9 Copilot.ps1 birebir) ===
            @{
                Name="Copilot Tamamen Kapat (Uninstall + Policy)";
                Description="Windows Copilot'i tamamen kapatir: AppX paketini kaldirir + HKCU/HKLM TurnOffWindowsCopilot policy etkinlestirir + edge/copilot/widgets/runtime broker process'lerini durdurur. Yeniden gorunmez.";
                Risk="Low"; RestartExplorer=$false;
                DetectScript='
                    $hku = (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
                    $hlm = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue).TurnOffWindowsCopilot
                    return ("$hku" -eq "1" -or "$hlm" -eq "1")
                ';
                Command='
                    Write-Host "[Copilot] Edge/Copilot/Widgets process kapatiliyor..."
                    $stop = "backgroundTaskHost", "Copilot", "CrossDeviceResume", "GameBar", "MicrosoftEdgeUpdate", "msedge", "msedgewebview2", "OneDrive", "OneDrive.Sync.Service", "OneDriveStandaloneUpdater", "Resume", "RuntimeBroker", "Search", "SearchHost", "Setup", "StoreDesktopExtension", "WidgetService", "Widgets"
                    foreach ($p in $stop) { Stop-Process -Name $p -Force -ErrorAction SilentlyContinue }
                    Get-Process | Where-Object { $_.ProcessName -like "*edge*" } | Stop-Process -Force -ErrorAction SilentlyContinue

                    Write-Host "[Copilot] AppX paketi kaldiriliyor..."
                    Get-AppXPackage -AllUsers | Where-Object { $_.Name -like "*Copilot*" } | Remove-AppxPackage -ErrorAction SilentlyContinue

                    Write-Host "[Copilot] Policy etkinlestiriliyor (HKCU + HKLM)..."
                    if (-not (Test-Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot")) {
                        New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
                    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot")) {
                        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
                    Write-Host "[Copilot] Tamamen kapatildi."
                ';
                UndoCommand='
                    Write-Host "[Copilot] Geri aliniyor..."
                    Get-AppXPackage -AllUsers | Where-Object { $_.Name -like "*Copilot*" } | ForEach-Object {
                        Add-AppxPackage -DisableDevelopmentMode -Register -ErrorAction SilentlyContinue "$($_.InstallLocation)\AppXManifest.xml"
                    }
                    Remove-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "[Copilot] Policy silindi (uygulama yeniden register edildi)."
                '
            },
            @{ 
                Name="Windows Update'i Kısıtla (Otomatik Yüklemeyi Kapat)"; 
                RestartExplorer=$false;
                Batch=@(
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName="DisableOSUpgrade"; Type="DWord"; Data=1; Undo=0 },
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; ValueName="SetDisableUXWUAccess"; Type="DWord"; Data=1; Undo=0 },
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; ValueName="NoAutoUpdate"; Type="DWord"; Data=1; Undo=0 },
                    @{ Key="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; ValueName="AUOptions"; Type="DWord"; Data=2; Undo=4 }, 
                    @{ Key="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"; ValueName="SearchOrderConfig"; Type="DWord"; Data=0; Undo=1 }
                )
            }
        )
		# --- 10. LOW LATENCY / ESPOR PAKETİ ---
        "🎮 Low Latency (Espor)" = @(
            # --- A: FARE VE KLAVYE (INPUT) ---
            @{ 
                Name="Win32 Öncelik Ayırma (CPU Oyuna Odaklanır)"; 
                SubCategory="Giriş ve İşlemci";
				Description="İşlemci (CPU) döngülerinin dağıtım mantığını değiştirir. Gücü arka plan servisleri yerine doğrudan ön plandaki uygulamaya (oyuna) odaklayarak FPS kararlılığı sağlar. (Değer: 26 - Anti-Cheat uyumlu güvenli mod. 38 bazı anti-cheat sistemlerinde sorun çıkarır.)";
                # GÜVENLI DEGER: 26 (0x1A hex) - Kısa aralıklı, değişken öncelik.
                # 38 (0x26) KULLANILMAZ - EAC ve BattlEye bu değeri işaretleyebilir.
                # 2  = Windows varsayılanı (uzun aralıklı, sabit)
                Key="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; ValueName="Win32PrioritySeparation"; Type="DWord"; Data=26; Undo=2; RestartExplorer=$false 
            },
            @{ 
                Name="Fare İvmesini (Acceleration) Tamamen Kapat"; 
                SubCategory="Giriş ve İşlemci";
				Description="Windows'un 'İşaretçi hassasiyetini artır' özelliğini ve gizli ivme eğrilerini devre dışı bırakır. Farenin fiziksel hareketi ile ekrandaki imleç hareketini 1-e-1 eşitler (Kas hafızası için kritiktir).";
                Batch=@(
                    # MouseSpeed=0 ivmeyi kapatır. Threshold'lar 0 olmalı.
                    @{ Key="HKCU:\Control Panel\Mouse"; ValueName="MouseSpeed"; Type="String"; Data="0"; Undo="1" },
                    @{ Key="HKCU:\Control Panel\Mouse"; ValueName="MouseThreshold1"; Type="String"; Data="0"; Undo="6" },
                    @{ Key="HKCU:\Control Panel\Mouse"; ValueName="MouseThreshold2"; Type="String"; Data="0"; Undo="10" }
                );
                RestartExplorer=$false
            },
            @{
                Name="Mouse Sürücü Önceliği (Thread Priority: High)";
                SubCategory="Giriş ve İşlemci";
                Description="Fare sürücüsünün işlemci sırasındaki önceliğini yüksek seviyeye taşır. Yoğun çatışma anlarında CPU kullanımı artsa bile farenin takılmasını engeller.`n(Değer: 26 — Anti-Cheat uyumlu güvenli mod. 31 max değeri 'input spoofing' olarak işaretlenebilir.)`n`n✅ BattlEye / EAC / FACEIT: %100 uyumlu`n⚠️ Vanguard (Valorant) / Ricochet (CoD): %1-2 false positive ihtimali — sorun yaşarsanız geri alın.";
                # GÜVENLİ DEĞER: 26 = Yüksek öncelik, anti-cheat uyumlu.
                # 31 (REAL-TIME/MAX) kullanılmaz — BattlEye bu değeri izleyebilir.
                Key="HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"; ValueName="ThreadPriority"; Type="DWord"; Data=26; Undo="DELETE_VALUE"; RestartExplorer=$false
            },
            @{
                Name="Mouse Data Queue Size (Tamponu Artır)";
                Description="Farenin gönderdiği veri paketleri için ayrılan tampon belleği 256'ya çıkarır (varsayılan 100). 4000Hz/8000Hz polling rate fareler (Razer Viper, Logitech G Pro X SuperLight 2 vb.) için gerçek paket kaybı koruması. Anti-cheat uyumlu.";
                SubCategory="Giriş ve İşlemci";
                Key="HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"; ValueName="MouseDataQueueSize"; Type="DWord"; Data=256; Undo=100; RestartExplorer=$false
            },
            @{
                Name="Keyboard Sürücü Önceliği (Thread Priority: High)";
                Description="Klavye sürücüsünü işlemci kuyruğunda öncelikli hale getirir. Tuş basışlarının oyuna iletilme süresindeki milisaniyelik gecikmeleri (input lag) minimize eder.`n(Değer: 26 — Anti-Cheat uyumlu güvenli değer.)`n`n✅ BattlEye / EAC / FACEIT: %100 uyumlu`n⚠️ Vanguard (Valorant) / Ricochet (CoD): %1-2 false positive ihtimali — sorun yaşarsanız geri alın.";
                SubCategory="Giriş ve İşlemci";
                # GÜVENLİ DEĞER: 26 = Yüksek öncelik, anti-cheat uyumlu.
                Key="HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"; ValueName="ThreadPriority"; Type="DWord"; Data=26; Undo="DELETE_VALUE"; RestartExplorer=$false
            },
            @{
                Name="Keyboard Data Queue Size (Tamponu Artır)";
                Description="Klavye veri kuyruğunu 256'ya çıkarır (varsayılan 100). Aynı anda birden fazla tuşa basıldığında (N-Key Rollover) takılma riskini azaltır. Mekanik klavye + makro kullananlar için fayda. Anti-cheat uyumlu.";
                SubCategory="Giriş ve İşlemci";
                Key="HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"; ValueName="KeyboardDataQueueSize"; Type="DWord"; Data=256; Undo=100; RestartExplorer=$false
            },
            @{
                Name="MSI Mode (GPU Interrupt) Aç";
                SubCategory="Giriş ve İşlemci";
                Description="Tum ekran kartlari icin Message Signaled Interrupts (MSI) modunu acar. Klasik IRQ yerine direkt CPU'ya kesme sinyali gonderir — DPC latency azalir, oyun stutter'i ve ses takılmaları iyilesir. Anti-cheat uyumlu. Reboot gerekir.`n`n💡 Aygıt-bazlı ince kontrol icin Tools menusundeki MSI Utility V3 araci kullanılabilir (USB controller, ses karti, NVMe vs. icin).";
                Risk="Low"; RestartExplorer=$false;
                Command='
                    # Display class GPU aygitlarinin Interrupt Management registry yolunu bul ve MSISupported=1 yaz.
                    Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | ForEach-Object {
                        $instId = $_.InstanceId
                        if (-not $instId) { return }
                        $key = "HKLM:\SYSTEM\ControlSet001\Enum\$instId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                        if (-not (Test-Path $key)) { New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null }
                        Set-ItemProperty -Path $key -Name "MSISupported" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                ';
                UndoCommand='
                    # MSISupported degerini sil — sistem default davranisina (0/IRQ) doner
                    Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | ForEach-Object {
                        $instId = $_.InstanceId
                        if (-not $instId) { return }
                        $key = "HKLM:\SYSTEM\ControlSet001\Enum\$instId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                        if (Test-Path $key) {
                            Remove-ItemProperty -Path $key -Name "MSISupported" -Force -ErrorAction SilentlyContinue
                        }
                    }
                '
            },

            # --- B: AĞ VE PİNG (NETWORK) ---
            @{
                Name="Network Throttling Kapat (Ağ Kısıtlamasını Kaldır)";
                SubCategory="Ağ ve Ping";
				Description="Windows'un multimedya (müzik/video) açıkken oyun dışı ağ trafiğini kısıtlayan mekanizmasını kapatır. Arka planda müzik dinlerken oyunun laglanmasını önler.";
                Key="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; ValueName="NetworkThrottlingIndex"; Type="DWord"; Data=0xffffffff; Undo=10; RestartExplorer=$false
            },

            # === NETWORK ADAPTER POWER SAVINGS & WAKE (FR33THY 26 birebir kompozit) ===
            @{
                Name="Ağ Kartı Güç Tasarrufu ve Uyandırma Kapat (Tümü)";
                SubCategory="Ağ ve Ping";
                Risk="Low"; RestartExplorer=$false;
                Description="Tum ag kartlarindaki Energy Efficient Ethernet (EEE), Green Ethernet, Power Saving Mode, Gigabit Lite, Ultra Low Power, System Idle Power Saver, ve TUM Wake-on-LAN/Magic Packet/Modern Standby/Pattern uyandirma davranislarini KAPATIR. PnPCapabilities=24 (cihaz manager 'Power Management' tab'inda 3 secenegi de kapali tutar).`n`n12 ayri registry value 4d36e972 GUID altindaki tum adapter subkey'lerine yazilir.`n`n💡 Mevcut TCP NoDelay/AckFrequency tweak'leri ile birlikte cok iyi calisir — paket onceligi + power saving kapali = en dusuk gecikme.";
                DetectScript='
                    $base = "HKLM:\System\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
                    $any = $false
                    Get-ChildItem -Path $base -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match "^\d{4}$" } | ForEach-Object {
                        $v = (Get-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -ErrorAction SilentlyContinue).PnPCapabilities
                        if ("$v" -eq "24") { $any = $true }
                    }
                    return $any
                ';
                Command='
                    $base = "HKLM:\System\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
                    $count = 0
                    Get-ChildItem -Path $base -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match "^\d{4}$" } | ForEach-Object {
                        $p = $_.PSPath
                        # Power Management & Wake (PnPCapabilities=24 = "Allow computer to turn off this device" + WakeOnLAN tum kapali)
                        Set-ItemProperty -Path $p -Name "PnPCapabilities" -Value 24 -Type DWord -Force -ErrorAction SilentlyContinue
                        # Energy Efficient Ethernet
                        Set-ItemProperty -Path $p -Name "AdvancedEEE"          -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "*EEE"                  -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "EEELinkAdvertisement"  -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        # System Idle / Ultra Low Power / Gigabit Lite / Green Ethernet / Power Saving
                        Set-ItemProperty -Path $p -Name "SipsEnabled"           -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "ULPMode"               -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "GigaLite"              -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "EnableGreenEthernet"   -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "PowerSavingMode"       -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        # Wake on LAN / Magic Packet / Pattern / Modern Standby
                        Set-ItemProperty -Path $p -Name "S5WakeOnLan"                  -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "*WakeOnMagicPacket"           -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "*ModernStandbyWoLMagicPacket" -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "*WakeOnPattern"               -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $p -Name "WakeOnLink"                   -Value "0" -Type String -Force -ErrorAction SilentlyContinue
                        $count++
                    }
                    Write-Host "[NetAdapter] $count adapter icin power saving + wake kapatildi."
                ';
                UndoCommand='
                    $base = "HKLM:\System\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
                    $count = 0
                    Get-ChildItem -Path $base -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match "^\d{4}$" } | ForEach-Object {
                        $p = $_.PSPath
                        foreach ($n in @("PnPCapabilities","AdvancedEEE","*EEE","EEELinkAdvertisement","SipsEnabled","ULPMode","GigaLite","EnableGreenEthernet","PowerSavingMode","S5WakeOnLan","*WakeOnMagicPacket","*ModernStandbyWoLMagicPacket","*WakeOnPattern","WakeOnLink")) {
                            Remove-ItemProperty -Path $p -Name $n -Force -ErrorAction SilentlyContinue
                        }
                        $count++
                    }
                    Write-Host "[NetAdapter] $count adapter icin tum power/wake degerleri silindi (default)."
                '
            },
            @{ 
                Name="TCP NoDelay ve AckFrequency (Nagle Algoritmasını Kapat)";
				Description="Veri paketlerinin birikmesini bekleyen Nagle algoritmasını kapatır. Küçük paketleri biriktirmeden anında sunucuya gönderir. Mermi gidişatını (Hitreg) ve tepkiselliği ciddi oranda artırır.";
                SubCategory="Ağ ve Ping";
                Command='
                    # Sadece fiziksel Ethernet/Wi-Fi adaptörlerine uygula (VPN/Loopback/Tunnel hariç)
                    $nics = Get-NetAdapter | Where-Object {
                        $_.Status -eq "Up" -and
                        $_.InterfaceType -in @(6, 71) -and          # 6=Ethernet, 71=Wi-Fi
                        $_.PhysicalMediaType -ne "Unspecified" -and
                        $_.InterfaceDescription -notmatch "(?i)VPN|Virtual|Tunnel|Loopback|TAP|WAN Miniport|Hyper-V|Bluetooth"
                    }
                    foreach ($nic in $nics) {
                        $guid = $nic.InterfaceGuid
                        $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                        if (Test-Path $path) {
                            New-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
                            New-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
                            New-ItemProperty -Path $path -Name "TcpDelAckTicks" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue
                        }
                    }
                ';
                UndoCommand='
                    $nics = Get-NetAdapter | Where-Object {
                        $_.Status -eq "Up" -and
                        $_.InterfaceType -in @(6, 71) -and
                        $_.PhysicalMediaType -ne "Unspecified" -and
                        $_.InterfaceDescription -notmatch "(?i)VPN|Virtual|Tunnel|Loopback|TAP|WAN Miniport|Hyper-V|Bluetooth"
                    }
                    foreach ($nic in $nics) {
                        $guid = $nic.InterfaceGuid
                        $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                        if (Test-Path $path) {
                            Remove-ItemProperty -Path $path -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path $path -Name "TCPNoDelay" -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path $path -Name "TcpDelAckTicks" -ErrorAction SilentlyContinue
                        }
                    }
                ';
                RestartExplorer=$false 
            },

            # --- C: ZAMANLAYICI (TIMER & BCDEDIT) ---
            # ⚠️ UYARI: Bu üç ayar birbirini etkiler. Grup mantığı ile sadece biri aktif olabilir.
            # Valorant/Ricochet oynuyorsanız SADECE "Dinamik Tık Kapat" kullanın.
            # "HPET Kapat" + "Platform Tick Zorla" kombinasyonu Ricochet'te sorun çıkarabilir.
            @{ 
                Name="Dinamik Tık (Dynamic Tick) Kapat"; 
                SubCategory="Zamanlayıcı (Timer)";
                Group="TimerMode";
				Description="İşlemcinin güç tasarrufu için zamanlayıcıyı durdurmasını engeller. CPU'nun sürekli uyanık kalmasını sağlayarak oyun içi anlık takılmaları (stutter) önler. ✅ Tüm anti-cheat sistemleriyle uyumludur.";
                Command='bcdedit /set disabledynamictick yes'; 
                UndoCommand='bcdedit /deletevalue disabledynamictick'; 
                RestartExplorer=$false 
            },
            @{ 
                Name="HPET (Platform Clock) Kapat"; 
                SubCategory="Zamanlayıcı (Timer)";
                Group="TimerMode";
				Description="Eski nesil yüksek hassasiyetli olay zamanlayıcısını kapatır. Modern işlemcilerde (Ryzen/Core) HPET'in kapalı olması DPC gecikmesini düşürür ve FPS'i stabilize eder. ⚠️ Valorant/Ricochet ile 'Platform Tick Zorla' ayarıyla BİRLİKTE kullanmayın.";
                Command='bcdedit /deletevalue useplatformclock'; 
                UndoCommand='bcdedit /set useplatformclock yes'; 
                RestartExplorer=$false 
            },
            @{ 
                Name="Platform Tick Zorla (Stabilite)";
				Description="Tüm sistem zamanlayıcılarını tek bir kaynakta (Platform) eşitler. Zamanlayıcılar arası kaymaları önleyerek oyunlarda daha akıcı bir görüntü sunar. ⚠️ Valorant/Ricochet ile 'HPET Kapat' ayarıyla BİRLİKTE kullanmayın — timer manipulation olarak işaretlenebilir.";
                SubCategory="Zamanlayıcı (Timer)";
                Group="TimerMode";
                Command='bcdedit /set useplatformtick yes'; 
                UndoCommand='bcdedit /deletevalue useplatformtick'; 
                RestartExplorer=$false 
            }
        )
		# --- 11. BUFFERBLOAT VE AĞ PROFİLLERİ ---
		"🌐 Bufferbloat ve Ağ Profilleri" = @(

			@{
				Name        = "[PROFİL] Düşük Gecikme + Tam Hız (Üniversal)"
				SubCategory = "Profil Seçimi (Sadece Birini Seçin)"
				Group       = "NetProfile"
				Description = "100 Mbit'ten 2 Gbit+'a kadar TÜM internet hızlarında çalışır. Düşük gecikme için CTCP, MinRto=300, MMCSS off, RSC off; tam hız için autotune=normal (Windows BDP'yi otomatik adapte eder) + donanım offload (LSO, Checksum) açık. BattlEye/EAC/Vanguard/Ricochet %100 anti-cheat uyumlu. Hız kaybı yok."
				Command     = '
					$pathTCP = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
					$pathMM  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

					# --- TCP GLOBAL: latency-friendly + her hıza adaptif ---
					# autotuninglevel=normal → Windows TCP window u her hıza otomatik adapte eder
					# congestionprovider=ctcp → Compound TCP, düşük gecikme + iyi throughput
					# rsc=disabled → Receive Segment Coalescing (paket birleştirme) latency artırır, kapatılır
					# timestamps=disabled → RTT overhead azaltır
					netsh int tcp set global autotuninglevel=normal           | Out-Null
					netsh int tcp set global congestionprovider=ctcp          | Out-Null
					netsh int tcp set global ecncapability=enabled            | Out-Null
					netsh int tcp set global rss=enabled                      | Out-Null
					netsh int tcp set global rsc=disabled                     | Out-Null
					netsh int tcp set global timestamps=disabled              | Out-Null
					netsh int tcp set global nonsackrttresiliency=disabled    | Out-Null
					netsh int tcp set global maxsynretransmissions=2          | Out-Null

					# --- TCP REGISTRY: bağlantı parametreleri ---
					Set-ItemProperty -Path $pathTCP -Name "MaxUserPort"       -Value 65534 -Type DWord -Force
					Set-ItemProperty -Path $pathTCP -Name "TcpTimedWaitDelay" -Value 30    -Type DWord -Force
					Set-ItemProperty -Path $pathTCP -Name "DefaultTTL"        -Value 64    -Type DWord -Force
					# MinRto=300 → paket kaybı sonrası 300ms içinde retransmit (default 3000ms çok yavaş)
					Set-ItemProperty -Path $pathTCP -Name "MinRto"            -Value 300   -Type DWord -Force

					# TcpWindowSize SİLİNMİŞ KALSIN — autotune=normal her hıza dinamik adapte eder.
					# Manuel set etmek gereksiz ve internet değişiminde stale kalır.
					Remove-ItemProperty -Path $pathTCP -Name "TcpWindowSize"          -ErrorAction SilentlyContinue
					Remove-ItemProperty -Path $pathTCP -Name "GlobalMaxTcpWindowSize" -ErrorAction SilentlyContinue

					# --- MMCSS: multimedya kısıtlaması kapalı, ön plan priority ---
					Set-ItemProperty -Path $pathMM -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
					Set-ItemProperty -Path $pathMM -Name "SystemResponsiveness"   -Value 10         -Type DWord -Force

					# --- DONANIM HIZLANDIRMA: AÇIK (modern NIC kartlarda her hizda fayda) ---
					# Eski "Saf Espor" profili bunlari KAPATIYORDU - 1Gbit hatti 400 Mbps a dusuruyordu.
					# Yeni profilde Checksum ve LSO acik (CPU yuku azalir, hiz korunur).
					# RSC kapali kalir (latency icin kritik - paket birlestirme zararli).
					Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
						Enable-NetAdapterChecksumOffload -Name $_.Name -IpIPv4 -NoRestart -ErrorAction SilentlyContinue
						Enable-NetAdapterLso -Name $_.Name -IPv4 -NoRestart -ErrorAction SilentlyContinue
						Disable-NetAdapterRsc -Name $_.Name -IPv4 -NoRestart -ErrorAction SilentlyContinue
					}
				'
				UndoCommand     = ""
				RestartExplorer = $false
			},

			@{
				Name        = "[SIFIRLA] Windows Varsayılanları"
				SubCategory = "Profil Seçimi (Sadece Birini Seçin)"
				Group       = "NetProfile"
				Description = "Tüm ağ yığınını, TCP algoritmalarını ve kısıtlamaları Windows'un orijinal kurulum ayarlarına geri döndürür.";
				Command     = '
					# ✅ Önce disabled/restricted modunu kır, sonra normal yap
					netsh int tcp set global autotuninglevel=disabled  | Out-Null
					Start-Sleep -Milliseconds 200
					netsh int tcp set global autotuninglevel=normal    | Out-Null

					netsh int tcp set global congestionprovider=default | Out-Null
					netsh int tcp set global ecncapability=default      | Out-Null
					netsh int tcp set global rss=enabled                | Out-Null
					netsh int tcp set global rsc=enabled                | Out-Null
					netsh int tcp set global timestamps=disabled        | Out-Null
					netsh int tcp set global maxsynretransmissions=2    | Out-Null
					netsh int tcp set global nonsackrttresiliency=disabled | Out-Null

					$pathTCP = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
					@(
						"MaxUserPort","TcpTimedWaitDelay","DefaultTTL",
						"InitialRto","MinRto","TcpWindowSize","GlobalMaxTcpWindowSize"
					) | ForEach-Object {
						Remove-ItemProperty -Path $pathTCP -Name $_ -ErrorAction SilentlyContinue
					}

					$pathMM = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
					Set-ItemProperty -Path $pathMM -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force
					Set-ItemProperty -Path $pathMM -Name "SystemResponsiveness"   -Value 20 -Type DWord -Force

					Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
						Enable-NetAdapterChecksumOffload -Name $_.Name -IpIPv4 -NoRestart -ErrorAction SilentlyContinue
						Enable-NetAdapterLso -Name $_.Name -IPv4 -NoRestart -ErrorAction SilentlyContinue
						Enable-NetAdapterRsc -Name $_.Name -IPv4 -NoRestart -ErrorAction SilentlyContinue
					}
				'
				UndoCommand     = ""
				RestartExplorer = $false
			}
		)

		# --- 12. GPU AYARLARI (MANUEL) ---
		# Vendor-spesifik tweak'ler. Recommended Profiles'a DAHIL DEGIL — kullanici kendi GPU'suna
		# gore manuel secer. Vendor="NVIDIA"|"AMD" tag'i ile Apply-System-Tweaks uyumsuzluk uyarisi verir.
		"🎮 GPU Ayarları (Manuel)" = @(

			@{
				Name="AMD Adrenalin Optimizasyonu (Reklam/Popup/Bildirim Kapat)";
				SubCategory="AMD";
				Vendor="AMD";
				Risk="Low";
				RestartExplorer=$false;
				Description="AMD Radeon Software Adrenalin Edition'in reklamlari, otomatik guncellemesi, sistem tepsisi menusu, oyun ici overlay'i, hata bildirim toolu ve bildirim spam'ini kapatir. Grafik profilini 'Custom' yapar (kullanicinin secimi: Standart/Esports/Gaming silinir).`n`n⚠️ Adrenalin yazilimi 30 saniyeligine acilip kapatilir — bu Adrenalin'in registry yazilarini commit etmesi icin ZORUNLU. Bekleme suresince log'da uyari gorunur.`n⚠️ Sadece AMD GPU + Adrenalin yazilimi yuklu sistemlerde anlamli.";
				DetectScript='
					# AutoUpdate=0 ana marker (apply tarafindan yazilan ilk ve ana key)
					$v = (Get-ItemProperty -Path "HKCU:\Software\AMD\CN" -Name "AutoUpdate" -ErrorAction SilentlyContinue).AutoUpdate
					return ("$v" -eq "0")
				';
				Command='
					$rsoft = "$env:SystemDrive\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
					if (Test-Path $rsoft) {
						Write-Host "[AMD] Adrenalin baslatiliyor (ayarlarin commit olmasi icin 30 sn bekleniyor)..."
						Start-Process $rsoft -ErrorAction SilentlyContinue
						Start-Sleep -Seconds 30
						Stop-Process -Name "RadeonSoftware" -Force -ErrorAction SilentlyContinue
						Start-Sleep -Seconds 2
					} else {
						Write-Host "[AMD] Adrenalin bulunamadi — registry tweakleri yine de uygulaniyor (yazilim yuklendiginde aktif olur)."
					}

					# --- SISTEM ---
					reg add "HKCU\Software\AMD\CN"  /v "AutoUpdate"     /t REG_DWORD /d "0" /f | Out-Null
					reg add "HKCU\Software\AMD\AIM" /v "LaunchBugTool"  /t REG_DWORD /d "0" /f | Out-Null

					# --- HOTKEYS ---
					reg add "HKCU\Software\AMD\DVR" /v "HotkeysDisabled" /t REG_DWORD /d "1" /f | Out-Null

					# --- TERCIHLER ---
					reg add "HKCU\Software\AMD\CN"  /v "SystemTray"               /t REG_SZ /d "false" /f | Out-Null
					reg add "HKCU\Software\AMD\DVR" /v "ShowRSOverlay"            /t REG_SZ /d "false" /f | Out-Null
					reg add "HKCU\Software\AMD\CN"  /v "RSXBrowserUnavailable"    /t REG_SZ /d "true"  /f | Out-Null
					reg add "HKCU\Software\AMD\CN"  /v "AllowWebContent"          /t REG_SZ /d "false" /f | Out-Null
					reg add "HKCU\Software\AMD\CN"  /v "CN_Hide_Toast_Notification" /t REG_SZ /d "true" /f | Out-Null
					reg add "HKCU\Software\AMD\CN"  /v "AnimationEffect"          /t REG_SZ /d "false" /f | Out-Null

					# --- GRAFIK PROFILI: Custom ---
					reg add "HKCU\Software\AMD\CN"  /v "WizardProfile"            /t REG_SZ /d "PROFILE_CUSTOM" /f | Out-Null

					# --- DISPLAY OVERRIDE EULA ---
					reg add "HKCU\Software\AMD\CN\CustomResolutions" /v "EulaAccepted" /t REG_SZ /d "true" /f | Out-Null
					reg add "HKCU\Software\AMD\CN\DisplayOverride"   /v "EulaAccepted" /t REG_SZ /d "true" /f | Out-Null

					# --- BILDIRIM SPAM KAPAT ---
					reg delete "HKCU\Software\AMD\CN\Notification" /f 2>$null | Out-Null
					reg add    "HKCU\Software\AMD\CN\Notification"            /f | Out-Null
					reg add    "HKCU\Software\AMD\CN\FreeSync"                /v "AlreadyNotified" /t REG_DWORD /d "1" /f | Out-Null
					reg add    "HKCU\Software\AMD\CN\OverlayNotification"     /v "AlreadyNotified" /t REG_DWORD /d "1" /f | Out-Null
					reg add    "HKCU\Software\AMD\CN\VirtualSuperResolution"  /v "AlreadyNotified" /t REG_DWORD /d "1" /f | Out-Null

					# --- HKLM Class GUID DISPLAY: VSync, TFQ, Tessellation, Vari-Bright, Tuning ---
					# FR33THY birebir: ControlSet001 (orig satir 63)
					$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"

					# UMD subkeyleri (VSyncControl=Always Off, TFQ=Performance, Tessellation=Off)
					$umdKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue |
						Where-Object { $_.PSChildName -eq "UMD" }
					foreach ($k in $umdKeys) {
						$p = $k.PSPath
						New-ItemProperty -Path $p -Name "VSyncControl"        -Value ([byte[]](0x30,0x00))                  -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
						New-ItemProperty -Path $p -Name "TFQ"                 -Value ([byte[]](0x32,0x00))                  -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
						New-ItemProperty -Path $p -Name "Tessellation"        -Value ([byte[]](0x31,0x00))                  -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
						New-ItemProperty -Path $p -Name "Tessellation_OPTION" -Value ([byte[]](0x32,0x00))                  -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
					}

					# power_v1 (Vari-Bright kapat)
					$pwrKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue |
						Where-Object { $_.PSChildName -eq "power_v1" }
					foreach ($k in $pwrKeys) {
						New-ItemProperty -Path $k.PSPath -Name "abmlevel" -Value ([byte[]](0x00,0x00,0x00,0x00)) -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
					}

					# Adapter klasorleri (4 haneli) — Manual Tuning + GPU/Fan/VRAM/Power kontrol
					$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue |
						Where-Object { $_.PSChildName -match "^\d{4}$" }
					foreach ($k in $adapterKeys) {
						New-ItemProperty -Path $k.PSPath -Name "IsAutoDefault"     -Value ([byte[]](0x00,0x00,0x00,0x00)) -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
						New-ItemProperty -Path $k.PSPath -Name "IsComponentControl" -Value ([byte[]](0x0F,0x00,0x00,0x00)) -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
					}
				';
				UndoCommand='
					# Adrenalin acmaya gerek yok — registry silindiginde Adrenalin bir sonraki acilista default e doner
					# --- SISTEM ---
					reg delete "HKCU\Software\AMD\CN"  /v "AutoUpdate"    /f 2>$null | Out-Null
					reg add    "HKCU\Software\AMD\AIM" /v "LaunchBugTool" /t REG_DWORD /d "1" /f | Out-Null

					# --- HOTKEYS / PREFS ---
					reg delete "HKCU\Software\AMD\DVR" /v "HotkeysDisabled"             /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN"  /v "SystemTray"                  /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\DVR" /v "ShowRSOverlay"               /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN"  /v "RSXBrowserUnavailable"       /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN"  /v "AllowWebContent"             /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN"  /v "CN_Hide_Toast_Notification"  /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN"  /v "AnimationEffect"             /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN"  /v "WizardProfile"               /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN\CustomResolutions"                 /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN\DisplayOverride"                   /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN\Notification"                      /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN\FreeSync"                          /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN\OverlayNotification"               /f 2>$null | Out-Null
					reg delete "HKCU\Software\AMD\CN\VirtualSuperResolution"            /f 2>$null | Out-Null

					# --- HKLM Class GUID Undo (FR33THY birebir: belirli default degerleri yaz, silme) ---
					$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"

					# UMD subkeyleri:
					#   VSyncControl       -> REG_BINARY 31000000 (Application Default — orig satir 187)
					#   TFQ                -> SIL (orig satir 196)
					#   Tessellation       -> REG_BINARY 360034000000 (orig satir 206 — 6 byte)
					#   Tessellation_OPTION -> REG_BINARY 30000000 (orig satir 207)
					$umdKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue |
						Where-Object { $_.PSChildName -eq "UMD" }
					foreach ($k in $umdKeys) {
						$p = $k.PSPath
						New-ItemProperty -Path $p -Name "VSyncControl"        -Value ([byte[]](0x31,0x00,0x00,0x00))                  -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
						Remove-ItemProperty -Path $p -Name "TFQ" -Force -ErrorAction SilentlyContinue
						New-ItemProperty -Path $p -Name "Tessellation"        -Value ([byte[]](0x36,0x00,0x34,0x00,0x00,0x00))        -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
						New-ItemProperty -Path $p -Name "Tessellation_OPTION" -Value ([byte[]](0x30,0x00,0x00,0x00))                  -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
					}

					# power_v1\abmlevel -> SIL (orig satir 223)
					$pwrKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue |
						Where-Object { $_.PSChildName -eq "power_v1" }
					foreach ($k in $pwrKeys) {
						Remove-ItemProperty -Path $k.PSPath -Name "abmlevel" -Force -ErrorAction SilentlyContinue
					}

					# Adapter (4 hane):
					#   IsAutoDefault      -> REG_DWORD 1     (orig satir 234 — DIKKAT: REG_DWORD, REG_BINARY degil)
					#   IsComponentControl -> REG_BINARY 00000000 (orig satir 247)
					$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue |
						Where-Object { $_.PSChildName -match "^\d{4}$" }
					foreach ($k in $adapterKeys) {
						$p = $k.PSPath
						# Once eski tip varsa sil ki tip cakismasin (REG_BINARY -> REG_DWORD gecisi icin)
						Remove-ItemProperty -Path $p -Name "IsAutoDefault" -Force -ErrorAction SilentlyContinue
						New-ItemProperty -Path $p -Name "IsAutoDefault"      -Value 1                                       -PropertyType DWord  -Force -ErrorAction SilentlyContinue | Out-Null
						New-ItemProperty -Path $p -Name "IsComponentControl" -Value ([byte[]](0x00,0x00,0x00,0x00))         -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
					}
				'
			},

			@{
				Name="NVIDIA Optimizasyonu (Kontrol Paneli + Registry)";
				SubCategory="NVIDIA";
				Vendor="NVIDIA";
				Risk="Low";
				RestartExplorer=$false;
				Description="Format sonrasi NVIDIA Control Panel ayarlarini tek tikla optimize eder. Iki bolum:`n`n1) REGISTRY: PhysX (GPU), Developer Tools, GPU Performance Counter erisim, Tray icon kapat, Legacy Sharpen aktif.`n`n2) NVIDIA INSPECTOR (otomatik indirilir, ~1 MB): Ultra Low Latency, V-Sync optimize, Antialiasing, Texture Filtering Quality, Power Mode, Threaded Optimization, CUDA P2 State, Shader Cache.`n`n💾 GUVENLI UNDO: Apply oncesi mevcut Inspector profili otomatik olarak yedeklenir (nvidia_profile_backup.nip). Geri al butonuna bastiginizda kendi olusturdugunuz custom NVIDIA profilleri korunur.`n`n⚠️ Profil RTX 4090 icin sabit bir 'Preferred OpenGL GPU' satiri icerir. Farkli NVIDIA GPU'da surucu genelde otomatik secime geri doner — OpenGL oyunda sorun yasarsaniz Quick Undo yapin.`n⚠️ Inspector indirilemezse registry tweakleri yine de uygulanir (graceful degradation).";
				DetectScript='
					# StartOnLogin=0 ana marker (apply tarafindan yazilan tray icon kapat keyi)
					$v = (Get-ItemProperty -Path "HKCU:\Software\NVIDIA Corporation\NvTray" -Name "StartOnLogin" -ErrorAction SilentlyContinue).StartOnLogin
					return ("$v" -eq "0")
				';
				Command='
					# === BOLUM 1: REGISTRY ===
					Write-Host "[NVIDIA] Registry tweakleri uygulaniyor..."

					# Drs (Driver settings) klasorunu unblock et — MoTW olabilir
					$drsPath = "$env:ProgramData\NVIDIA Corporation\Drs"
					if (Test-Path $drsPath) {
						Get-ChildItem -Path $drsPath -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
					}

					# PhysX -> GPU (FR33THY birebir: ControlSet001)
					reg add "HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak" /v "NvCplPhysxAuto" /t REG_DWORD /d "0" /f | Out-Null
					# Developer Tools acik (ControlSet001)
					reg add "HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak" /v "NvDevToolsVisible" /t REG_DWORD /d "1" /f | Out-Null

					# GPU Performance Counter erisimi tum kullanicilara (her display class subkey)
					# Orijinal subkey iterator CurrentControlSet kullaniyor (orig satir 56)
					$cls = "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
					Get-ChildItem -Path $cls -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -notmatch "Configuration" } | ForEach-Object {
						reg add "$($_.Name)" /v "RmProfilingAdminOnly" /t REG_DWORD /d "0" /f 2>$null | Out-Null
					}
					# nvlddmkm bazinda da RmProfilingAdminOnly (ControlSet001 — orig satir 62)
					reg add "HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak" /v "RmProfilingAdminOnly" /t REG_DWORD /d "0" /f | Out-Null

					# Tray icon kapat
					reg add "HKCU\Software\NVIDIA Corporation\NvTray" /v "StartOnLogin" /t REG_DWORD /d "0" /f | Out-Null

					# Legacy Sharpen aktif et (GR535=0) — FR33THY birebir 3 yola yazar (belt-and-suspenders)
					reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS"             /v "EnableGR535" /t REG_DWORD /d "0" /f | Out-Null
					reg add "HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS"      /v "EnableGR535" /t REG_DWORD /d "0" /f | Out-Null
					reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS" /v "EnableGR535" /t REG_DWORD /d "0" /f | Out-Null

					Write-Host "[NVIDIA] Registry OK."

					# === BOLUM 2: NVIDIA INSPECTOR ===
					$insp = Get-NvidiaInspectorPath
					if (-not $insp) {
						Write-Host "[NVIDIA] Inspector indirilemedi — registry tamamlandi, profil ayarlari atlandi."
						Write-Host "[NVIDIA] Eksik kalan: GSYNC, Ultra Low Latency, V-Sync, Texture Filtering optimize. Internet kontrol edip tekrar deneyin."
						return
					}

					# 2a. Mevcut profili backup (kullanicinin ozel profil ayarlarini koruma)
					$backupNip = Join-Path $AppDataPath "nvidia_profile_backup.nip"
					try {
						Write-Host "[NVIDIA] Mevcut profil yedekleniyor: $backupNip"
						Start-Process -FilePath $insp -ArgumentList "-export `"$backupNip`"" -Wait -WindowStyle Hidden -ErrorAction Stop
						if (Test-Path $backupNip) {
							$bkb = [Math]::Round((Get-Item $backupNip).Length / 1KB, 1)
							Write-Host "[NVIDIA] Yedek OK ($bkb KB)."
						} else {
							Write-Host "[NVIDIA] UYARI: Yedek dosyasi olusmadi — Undo bos profil yukleyecek."
						}
					} catch {
						Write-Host "[NVIDIA] Yedekleme hatasi: $($_.Exception.Message) — devam ediliyor."
					}

					# 2b. Optimize .nip yaz ve import et (FR33THY birebir: hem -silentImport hem -silent)
					$tmpNip = Join-Path $env:TEMP "geminicare_nv_optimized.nip"
					try {
						Set-Content -Path $tmpNip -Value $global:NvidiaInspectorOptimizedNip -Encoding Unicode -Force
						Write-Host "[NVIDIA] Optimize profil import ediliyor..."
						Start-Process -FilePath $insp -ArgumentList "-silentImport -silent `"$tmpNip`"" -Wait -WindowStyle Hidden -ErrorAction Stop
						Write-Host "[NVIDIA] Inspector profili uygulandi."
					} catch {
						Write-Host "[NVIDIA] Import hatasi: $($_.Exception.Message)"
					} finally {
						Remove-Item $tmpNip -Force -ErrorAction SilentlyContinue
					}

					# 2c. NVIDIA Control Panel ac (FR33THY birebir — gorsel dogrulama)
					Start-Process "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel" -ErrorAction SilentlyContinue
				';
				UndoCommand='
					Write-Host "[NVIDIA] Geri alma basliyor..."

					# === BOLUM 1: REGISTRY GERI AL ===
					reg delete "HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak" /v "NvCplPhysxAuto"      /f 2>$null | Out-Null
					reg delete "HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak" /v "NvDevToolsVisible"   /f 2>$null | Out-Null
					reg delete "HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak" /v "RmProfilingAdminOnly" /f 2>$null | Out-Null

					$cls = "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
					Get-ChildItem -Path $cls -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -notmatch "Configuration" } | ForEach-Object {
						reg delete "$($_.Name)" /v "RmProfilingAdminOnly" /f 2>$null | Out-Null
					}

					reg delete "HKCU\Software\NVIDIA Corporation\NvTray" /f 2>$null | Out-Null

					reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS"             /v "EnableGR535" /t REG_DWORD /d "1" /f | Out-Null
					reg add "HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS"      /v "EnableGR535" /t REG_DWORD /d "1" /f | Out-Null
					reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS" /v "EnableGR535" /t REG_DWORD /d "1" /f | Out-Null

					Write-Host "[NVIDIA] Registry geri alindi."

					# === BOLUM 2: INSPECTOR — backup varsa onu yukle, yoksa bos profil ===
					$insp = Get-NvidiaInspectorPath
					if (-not $insp) {
						Write-Host "[NVIDIA] Inspector erisilemedi — profil geri alinamadi. Manuel olarak NVIDIA Control Panel ayarlarini kontrol edin."
						return
					}

					$backupNip = Join-Path $AppDataPath "nvidia_profile_backup.nip"
					if (Test-Path $backupNip) {
						try {
							Write-Host "[NVIDIA] Yedek profil geri yukleniyor: $backupNip"
							Start-Process -FilePath $insp -ArgumentList "-silentImport -silent `"$backupNip`"" -Wait -WindowStyle Hidden -ErrorAction Stop
							Write-Host "[NVIDIA] Yedek profil restore edildi (kullanicinin ozel ayarlari korundu)."
						} catch {
							Write-Host "[NVIDIA] Yedek import hatasi: $($_.Exception.Message)"
						}
					} else {
						# Backup yok — bos profil yukle (orijinal FR33THY davranisi)
						$tmpEmpty = Join-Path $env:TEMP "geminicare_nv_empty.nip"
						try {
							Set-Content -Path $tmpEmpty -Value $global:NvidiaInspectorEmptyNip -Encoding Unicode -Force
							Start-Process -FilePath $insp -ArgumentList "-silentImport -silent `"$tmpEmpty`"" -Wait -WindowStyle Hidden -ErrorAction Stop
							Write-Host "[NVIDIA] Yedek bulunamadi — bos profil uygulandi (default davranis)."
						} catch {
							Write-Host "[NVIDIA] Bos profil hatasi: $($_.Exception.Message)"
						} finally {
							Remove-Item $tmpEmpty -Force -ErrorAction SilentlyContinue
						}
					}

					# NVIDIA Control Panel ac (FR33THY birebir — Undo tarafinda da gorsel dogrulama)
					Start-Process "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel" -ErrorAction SilentlyContinue
				'
			}
		)
    }
}

# =============================================================
# BOLUM 2 - POWERSHELL FONKSIYONLARI
# Global fonksiyon bolumune ekle
# =============================================================


function Get-SelectedTasks {
    $tasks = @()
    foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvShellBags)) {
        if ($null -eq $tree) { continue }
        
        # Ağaçtaki tüm öğeleri tara
        $stack = New-Object System.Collections.Generic.Stack[object]
        foreach ($item in $tree.Items) { $stack.Push($item) }

        while ($stack.Count -gt 0) {
            $current = $stack.Pop()
            $chk = Get-CheckFromItem $current
            if ($chk -and $chk.IsChecked -and $chk.Tag -ne "ROOT") {
                $tasks += @{ Name = $chk.Content.ToString(); Tag = $chk.Tag.ToString() }
            }
            # Alt öğeleri yığına ekle
            foreach ($child in $current.Items) { $stack.Push($child) }
        }
    }
    return $tasks
}

# --- WINGET VARSAYILAN ---
$global:WingetApps = [ordered]@{} 
function Get-Default-WingetApps {
    return [ordered]@{
        "7-Zip"             	 = "7zip.7zip"
        "Google Chrome"     	 = "Google.Chrome"
        "Mozilla Firefox"   	 = "Mozilla.Firefox"
        "Brave Browser"     	 = "Brave.Brave"
        "Steam"             	 = "Valve.Steam"
        "EA App"            	 = "ElectronicArts.EADesktop"
        "Discord"           	 = "Discord.Discord"
        "Notepad++"        		 = "Notepad++.Notepad++"
        "Python 3"         	 	 = "Python.Python.3"
        "Logitech G Hub"    	 = "Logitech.GHUB"
        "PotPlayer"         	 = "Daum.PotPlayer"
        "ProtonVPN"         	 = "Proton.ProtonVPN"
        "Visual Studio Code" 	 = "Microsoft.VisualStudioCode"
        "Yandex Browser"    	 = "Yandex.Browser"
        "AB Download Manager"    = "amir1376.ABDownloadManager"
        "GPU-Z"    				 = "TechPowerUp.GPU-Z"
        "LatencyMon"    		 = "Resplendence.LatencyMon"
        "NVCleanstall"    		 = "TechPowerUp.NVCleanstall"
        "AIDA64 Extreme"    	 = "FinalWire.AIDA64.Extreme"
    }
}

function Load-Repair-Tree {
    $tvRepair = $Win.FindName('tvRepair')
    $tvRepair.BeginInit()
    $tvRepair.Items.Clear()
    
    try {
        # 1. SİSTEM ONARIM
        $nodeSysRep = New-TreeItem 'Sistem Dosyası Onarımı' 'ROOT'
        $nodeSysRep.Items.Add((New-TreeItem 'DISM RestoreHealth (İmaj Onarımı)' 'CMD_REALTIME:Dism /Online /Cleanup-Image /RestoreHealth')) | Out-Null
        $nodeSysRep.IsExpanded = $true
        $tvRepair.Items.Add($nodeSysRep) | Out-Null

        # 2. AĞ ONARIM
        $nodeNet = New-TreeItem 'Ağ Onarım ve Yapılandırma' 'ROOT'
        $nodeNet.Items.Add((New-TreeItem 'DNS Önbelleğini Temizle (Flush DNS)' 'CMD_REALTIME:ipconfig /flushdns')) | Out-Null
        $nodeNet.Items.Add((New-TreeItem 'ARP ve NetBIOS Temizle (Önbellek)' 'CMD_REALTIME:arp -d * & nbtstat -R & nbtstat -RR')) | Out-Null
        $nodeNet.Items.Add((New-TreeItem 'Windows Güvenlik Duvarını Sıfırla' 'CMD_REALTIME:netsh advfirewall reset')) | Out-Null
        $nodeNet.Items.Add((New-TreeItem 'Ağ Sürücülerini Kaldır ve Sıfırla (Hard Reset / Netcfg)' 'CMD_REALTIME:netcfg -d')) | Out-Null
        $nodeNet.IsExpanded = $true
        $tvRepair.Items.Add($nodeNet) | Out-Null
    } catch {
        WpfLog "[HATA] Onarım ağacı yüklenirken sorun: $($_.Exception.Message)"
    } finally {
        $tvRepair.EndInit()
    }
}

# --- LOAD WPF ---

# #endregion 4 -- VARSAYILAN VERILER (Tweak DB, Winget DB, Repair Tree)


# =========================================================================
# #region 5 -- XAML TANIMLARI (Ana pencere + Alt pencereler)
# =========================================================================

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms

# --- XAML (MAIN WINDOW) ---
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Sistem Temizleme Aracı Ultimate (PRO V10 - Modern UI)" Height="950" Width="1280" 
        Background="#181818" WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI" UseLayoutRounding="True">
  
  <Window.Resources>
    <!-- RENK PALETİ -->
    <SolidColorBrush x:Key="AccentColor" Color="#007ACC"/>
    <SolidColorBrush x:Key="PanelBg" Color="#252526"/>
    <SolidColorBrush x:Key="BorderBrush" Color="#3E3E42"/>

    <!-- MENÜLER (KORUNDU) -->
    <ContextMenu x:Key="TweakItemMenu">
        <MenuItem Header="Bu Ayarı Düzenle" Name="ctxEditTweak" FontWeight="Bold"/>
        <MenuItem Header="Kayıt Defterinde Aç (Regedit)" Name="ctxOpenReg"/>
        <Separator/>
        <MenuItem Header="Listeden Sil" Name="ctxDeleteTweak" Foreground="#FF5555"/>
    </ContextMenu>
    <ContextMenu x:Key="ItemMenu">
        <MenuItem Header="Konumu Aç (İncele)" Name="ctxOpenLocation" />
        <MenuItem Header="Yolları Düzenle (Gelişmiş)" Name="ctxEditPaths" FontWeight="Bold" Foreground="#4CC2FF"/>
        <Separator/>
        <MenuItem Header="Listeden Gizle (Yoksay)" Name="ctxIgnoreApp" Foreground="#FF5555"/>
    </ContextMenu>
    <ContextMenu x:Key="CustomItemMenu">
        <MenuItem Header="Bu Kuralı Sil" Name="ctxDeleteCustomRule" Foreground="#FF5555" FontWeight="Bold"/>
    </ContextMenu>

    <!-- TOGGLE SWITCH -->
    <Style x:Key="ToggleSwitch" TargetType="CheckBox">
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="CheckBox">
                    <StackPanel Orientation="Horizontal" Margin="2">
                        <Grid Width="36" Height="20">
                            <Border x:Name="Border" CornerRadius="10" Background="#444" BorderThickness="1" BorderBrush="#555"/>
                            <Ellipse x:Name="Dot" Fill="White" Width="14" Height="14" HorizontalAlignment="Left" Margin="3,0,0,0">
                                <Ellipse.RenderTransform> <TranslateTransform X="0"/> </Ellipse.RenderTransform>
                            </Ellipse>
                        </Grid>
                        <ContentPresenter Margin="10,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsChecked" Value="True">
                            <Setter TargetName="Border" Property="Background" Value="{StaticResource AccentColor}"/>
                            <Setter TargetName="Border" Property="BorderBrush" Value="{StaticResource AccentColor}"/>
                            <Trigger.EnterActions>
                                <BeginStoryboard> <Storyboard> <DoubleAnimation Storyboard.TargetName="Dot" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="16" Duration="0:0:0.2"/> </Storyboard> </BeginStoryboard>
                            </Trigger.EnterActions>
                            <Trigger.ExitActions>
                                <BeginStoryboard> <Storyboard> <DoubleAnimation Storyboard.TargetName="Dot" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="0" Duration="0:0:0.2"/> </Storyboard> </BeginStoryboard>
                            </Trigger.ExitActions>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style TargetType="TabItem">
        <Setter Property="FontSize" Value="13"/>
        <Setter Property="Height" Value="40"/>
        <Setter Property="Width" Value="135"/>
        <Setter Property="Foreground" Value="#BBB"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="TabItem">
                    <Border x:Name="Border" Background="Transparent" CornerRadius="4" Margin="2,1">
                        <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Left" ContentSource="Header" Margin="15,0"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter TargetName="Border" Property="Background" Value="#3E3E42"/>
                            <Setter Property="Foreground" Value="{StaticResource AccentColor}"/>
                            <Setter Property="FontWeight" Value="Bold"/>
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="Border" Property="Background" Value="#3E3E42"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style TargetType="Button">
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="border" CornerRadius="4" Background="{TemplateBinding Background}" BorderThickness="0">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True"> <Setter TargetName="border" Property="Opacity" Value="0.9"/> </Trigger>
                        <Trigger Property="IsPressed" Value="True"> <Setter TargetName="border" Property="Opacity" Value="0.7"/> </Trigger>
                        <Trigger Property="IsEnabled" Value="False"> <Setter TargetName="border" Property="Opacity" Value="0.3"/> </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
	<ControlTemplate x:Key="ComboBoxToggleButton" TargetType="ToggleButton">
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition />
                <ColumnDefinition Width="20" />
            </Grid.ColumnDefinitions>
            <Border x:Name="Border" Grid.ColumnSpan="2" CornerRadius="2" Background="#2D2D30" BorderBrush="#555" BorderThickness="1" />
            <Path x:Name="Arrow" Grid.Column="1" Fill="White" HorizontalAlignment="Center" VerticalAlignment="Center" Data="M 0 0 L 4 4 L 8 0 Z"/>
        </Grid>
    </ControlTemplate>

    <Style TargetType="ComboBox">
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="Background" Value="#2D2D30"/>
        <Setter Property="BorderBrush" Value="#555"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="ComboBox">
                    <Grid>
                        <ToggleButton Name="ToggleButton" Template="{StaticResource ComboBoxToggleButton}" Grid.Column="2" Focusable="false" IsChecked="{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press"/>
                        <ContentPresenter Name="ContentSite" IsHitTestVisible="False"  Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="10,3,23,3" VerticalAlignment="Center" HorizontalAlignment="Left" />
                        <TextBox x:Name="PART_EditableTextBox" Style="{x:Null}" Template="{x:Null}" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="3,3,23,3" Focusable="True" Background="Transparent" Visibility="Hidden" IsReadOnly="{TemplateBinding IsReadOnly}"/>
                        <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                            <Grid Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                <Border x:Name="DropDownBorder" Background="#252526" BorderThickness="1" BorderBrush="#555"/>
                                <ScrollViewer Margin="4,6,4,6" SnapsToDevicePixels="True">
                                    <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" />
                                </ScrollViewer>
                            </Grid>
                        </Popup>
                    </Grid>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
	<Style TargetType="ComboBoxItem">
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="Padding" Value="5"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="ComboBoxItem">
                    <Border x:Name="Border" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                        <ContentPresenter />
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="Border" Property="Background" Value="#3E3E42"/>
                        </Trigger>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter TargetName="Border" Property="Background" Value="#007ACC"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
	<!-- BAŞLANGIÇ YÖNETİCİSİ SAĞ TIK MENÜSÜ -->
    <ContextMenu x:Key="StartupItemMenu">
        <MenuItem Header="Durumu Değiştir (Aç / Kapat)" Name="ctxToggleStartup" FontWeight="Bold" Foreground="#4CC2FF"/>
        <MenuItem Header="Dosya Konumunu Aç (Dosyayı Seç)" Name="ctxOpenStartupLoc"/>
        <MenuItem Header="Dosya Yolunu Kopyala" Name="ctxCopyStartupPath" Foreground="#00CC00"/>
        <MenuItem Header="Kayıt Defterinde Aç" Name="ctxOpenStartupReg"/>
        <Separator/>
        <MenuItem Header="Kalıcı Olarak SİL" Name="ctxDeleteStartup" Foreground="#FF5555" FontWeight="Bold"/>
    </ContextMenu>

    <!-- MODERN LISTVIEW VE SÜTUN BAŞLIKLARI TASARIMI -->
    <Style TargetType="GridViewColumnHeader">
        <Setter Property="Background" Value="#252526"/>
        <Setter Property="Foreground" Value="#AAA"/>
        <Setter Property="Padding" Value="10,5"/>
        <Setter Property="FontWeight" Value="Bold"/>
        <Setter Property="BorderThickness" Value="0,0,1,1"/>
        <Setter Property="BorderBrush" Value="#3E3E42"/>
        <Setter Property="HorizontalContentAlignment" Value="Left"/>
    </Style>
    <Style TargetType="ListViewItem">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="BorderThickness" Value="0,0,0,1"/>
        <Setter Property="BorderBrush" Value="#333"/>
        <Setter Property="Margin" Value="0"/>
        <Setter Property="Padding" Value="5,8"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="ListViewItem">
                    <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                        <GridViewRowPresenter Content="{TemplateBinding Content}" Margin="{TemplateBinding Padding}"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#2D2D30"/>
                        </Trigger>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter Property="Background" Value="#007ACC"/>
                            <Setter Property="Foreground" Value="White"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
  </Window.Resources>

  <Grid Margin="15">
	<Grid.RowDefinitions>
        <RowDefinition Height="60"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- HEADER -->
    <Grid Grid.Row="0">
        <Grid.ColumnDefinitions> <ColumnDefinition Width="Auto"/> <ColumnDefinition Width="*"/> <ColumnDefinition Width="Auto"/> </Grid.ColumnDefinitions>
        <Image x:Name="Logo" Grid.Column="0" Width="160" Height="50" Stretch="Uniform" HorizontalAlignment="Left" VerticalAlignment="Center"/>
        <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
            <Button x:Name="btnRefreshApp" Content="♻ Güncelle" Height="32" Padding="15,0" Background="#4f0707" Margin="0,0,10,0"/>
            <Button x:Name="btnTools" Content="🛠 Araçlar ▾" Height="32" Padding="15,0" Background="#E68A00" Margin="0,0,10,0">
                  <Button.ContextMenu> <ContextMenu Name="ctxToolsMenu"/> </Button.ContextMenu>
            </Button>
			<!-- YENİ EKLENEN GECE MODU BUTONU -->
            <Button x:Name="btnNightMode" Content="🌙 Shutdown" Height="32" Padding="15,0" Background="#1A1A4A" Foreground="#4CC2FF" Margin="0,0,10,0" ToolTip="Akıllı Otomatik Kapanma ve İndirme Takibi"/>
            <Button x:Name="btnSettings" Content="⚙ Ayarlar" Height="32" Padding="15,0" Background="#333"/>
        </StackPanel>
    </Grid>

    <!-- CONTENT -->
    <Grid Grid.Row="1" Margin="0,10">
        <Grid.ColumnDefinitions> <ColumnDefinition Width="2.5*"/> <ColumnDefinition Width="5"/> <ColumnDefinition Width="1*"/> </Grid.ColumnDefinitions>
        <Border Grid.Column="0" Background="{StaticResource PanelBg}" CornerRadius="8" Padding="2">
            <Grid>
                <Grid.RowDefinitions> <RowDefinition Height="Auto"/> <RowDefinition Height="*"/> </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="10,10,10,5">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="txtSearch" Grid.Column="0" Height="30" Padding="5" Background="#1E1E1E" BorderBrush="#444" Foreground="#EEE" Tag="Ara..." Text="Uygulama Ara..." Margin="0,0,10,0"/>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="btnSelectAll" Content="Tümünü Seç" Width="100" Height="30" Background="#006600" Foreground="White" FontSize="11" Margin="0,0,5,0" BorderThickness="0"/>
                        <Button x:Name="btnSelectTab" Content="Sekme Seç" Width="100" Height="30" Background="#444" Foreground="White" FontSize="11" Margin="0,0,5,0" BorderThickness="0"/>
                        <Button x:Name="btnUnselectAll" Content="Tümünü Kaldır" Width="110" Height="30" Background="#A00" Foreground="White" FontSize="11" BorderThickness="0"/>
                    </StackPanel>
                </Grid>
                <TabControl x:Name="tabControl" Grid.Row="1" Background="Transparent" BorderThickness="0" TabStripPlacement="Left" Margin="0,0,0,5">
				<!-- ANA KONTROL PANELİ (DASHBOARD) -->
                    <TabItem Header="Genel Bakış" x:Name="tabDashboard">
                        <Grid Margin="15,5,15,15">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            
                           <!-- BAŞLIK -->
                            <Grid Grid.Row="0" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="SİSTEM ÖZETİ" Foreground="#007ACC" FontSize="26" FontWeight="Bold"/>
                                    <TextBlock x:Name="txtDashSubHeader" Text="Donanım ve sağlık durumu taranıyor..." Foreground="#888" FontSize="13" Margin="0,2,0,0"/>
                                </StackPanel>
                                <Button x:Name="btnHardwareDetail" Grid.Column="1" Content="🔍 Daha Fazla Detay" 
                                        Height="35" Padding="15,0" Background="#007ACC" Foreground="White"
                                        FontWeight="Bold" VerticalAlignment="Center" IsEnabled="False"/>
                            </Grid>

                            <!-- PİNG PANELİ VE AKTİF DNS -->
                            <Border Grid.Row="1" Background="#1A1A2A" CornerRadius="6" Padding="10,6" Margin="0,0,0,8" BorderBrush="#2E2E5E" BorderThickness="1">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- 1. Satır: Ping Değerleri -->
                                    <StackPanel Grid.Row="0" Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,0,4">
                                        <TextBlock Text="🌐 Ping:" Foreground="#888" FontSize="11" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                        <TextBlock x:Name="txtPingGoogle" Text="Google —" Foreground="#666" FontSize="11" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="txtPingCF" Text="Cloudflare —" Foreground="#666" FontSize="11" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                        <TextBlock x:Name="txtPingGW" Text="Ağ Geçidi —" Foreground="#666" FontSize="11" VerticalAlignment="Center"/>
                                    </StackPanel>
                                    
                                    <!-- 2. Satır: Aktif DNS Göstergesi -->
                                    <StackPanel Grid.Row="1" Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                                        <TextBlock Text="🛡️ Aktif DNS:" Foreground="#888" FontSize="11" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                        <TextBlock x:Name="txtDashDNS" Text="Yükleniyor..." Foreground="#4CC2FF" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    </StackPanel>

                                    <Button x:Name="btnPingTest" Grid.Row="0" Grid.RowSpan="2" Grid.Column="1" Content="📡 Test Et" Height="32" Padding="15,0" Background="#1E3A5C" Foreground="#4CC2FF" FontSize="11" FontWeight="Bold" VerticalAlignment="Center" Margin="10,0,0,0"/>
                                </Grid>
                            </Border>

                            <!-- BİLGİ KARTLARI (CARDS) -->
                            <UniformGrid Grid.Row="2" Columns="2" Rows="3">
                                
                                <!-- İŞLETİM SİSTEMİ -->
                                <Border Background="#222" CornerRadius="8" Padding="15" Margin="5" BorderBrush="#333" BorderThickness="1">
                                    <StackPanel>
                                        <TextBlock Text="🖥️ İşletim Sistemi" Foreground="#4CC2FF" FontSize="15" FontWeight="Bold" Margin="0,0,0,8"/>
                                        <TextBlock x:Name="txtDashOS" Text="Yükleniyor..." Foreground="White" FontSize="13" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </Border>

                                <!-- İŞLEMCİ (CPU) -->
                                <Border Background="#222" CornerRadius="8" Padding="15" Margin="5" BorderBrush="#333" BorderThickness="1">
                                    <StackPanel>
                                        <TextBlock Text="⚙️ İşlemci (CPU)" Foreground="#E68A00" FontSize="15" FontWeight="Bold" Margin="0,0,0,8"/>
                                        <TextBlock x:Name="txtDashCPU" Text="Yükleniyor..." Foreground="White" FontSize="13" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </Border>

                                <!-- BELLEK (RAM) -->
                                <Border Background="#222" CornerRadius="8" Padding="15" Margin="5" BorderBrush="#333" BorderThickness="1">
									<Grid>
										<StackPanel VerticalAlignment="Top">
											<TextBlock Text="🧠 Bellek (RAM)" Foreground="#00CC00" FontSize="15" FontWeight="Bold" Margin="0,0,0,8"/>
											<TextBlock x:Name="txtDashRAM" Text="Yükleniyor..." Foreground="White" FontSize="13" TextWrapping="Wrap"/>
											<ProgressBar x:Name="pbDashRAM" Height="6" Margin="0,10,0,0" Background="#333" Foreground="#00CC00" BorderThickness="0" Maximum="100"/>
										</StackPanel>

										<Button x:Name="btnCleanRAM" 
												Content="🧠 Clean RAM" 
												Height="35" 
												Background="#1A3A5C"
												Padding="10"
												Foreground="White" 
												FontWeight="Bold"
												VerticalAlignment="Bottom" 
												HorizontalAlignment="Right"
												ToolTip="Çalışan süreçlerin Working Set belleğini boşaltır. Anlık RAM kullanımını düşürür."/>
									</Grid>
								</Border>

                                <!-- GRAFİK KARTI (GPU) -->
                                <Border Background="#222" CornerRadius="8" Padding="15" Margin="5" BorderBrush="#333" BorderThickness="1">
                                    <StackPanel>
                                        <TextBlock Text="🎮 Grafik Kartı (GPU)" Foreground="#FFCC00" FontSize="15" FontWeight="Bold" Margin="0,0,0,8"/>
                                        <TextBlock x:Name="txtDashGPU" Text="Yükleniyor..." Foreground="White" FontSize="13" TextWrapping="Wrap" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
                                    </StackPanel>
                                </Border>

                                <!-- DEPOLAMA (DİSK) VE SAĞLIK -->
                                <Border Background="#222" CornerRadius="8" Padding="15" Margin="5" BorderBrush="#333" BorderThickness="1">
                                    <StackPanel>
                                        <TextBlock Text="💾 C: Diski ve Sağlık" Foreground="#A020F0" FontSize="15" FontWeight="Bold" Margin="0,0,0,8"/>
                                        <TextBlock x:Name="txtDashDisk" Text="Yükleniyor..." Foreground="White" FontSize="13" TextWrapping="Wrap"/>
                                        <ProgressBar x:Name="pbDashDisk" Height="6" Margin="0,10,0,0" Background="#333" Foreground="#A020F0" BorderThickness="0" Maximum="100"/>
                                    </StackPanel>
                                </Border>

                            </UniformGrid>
                        </Grid>
                    </TabItem>
                    <TabItem Header="Tarayıcılar" x:Name="tabBrowsers"> <TreeView x:Name="tvBrowser" BorderThickness="0" Background="Transparent" Margin="5" VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling"/> </TabItem>
                    <TabItem Header="Uygulamalar" x:Name="tabApps"> <TreeView x:Name="tvApps" BorderThickness="0" Background="Transparent" Margin="5" VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling"/> </TabItem>
                    <TabItem Header="Sistem" x:Name="tabSystem"> <TreeView x:Name="tvSystem" BorderThickness="0" Background="Transparent" Margin="5" VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling"/> </TabItem>
                    <TabItem Header="ShellBags" x:Name="tabShellBags">
                            <TabItem.Background>
                                <LinearGradientBrush EndPoint="0,1">
                                    <GradientStop Color="#FFF0F0F0"/>
                                    <GradientStop Color="#FF007ACC" Offset="1"/>
                                </LinearGradientBrush>
                            </TabItem.Background>
                            <TreeView x:Name="tvShellBags" BorderThickness="0" Background="Transparent" Margin="5" VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling"/> </TabItem>
                    <!-- ONARIM SEKMESİ (GÜNCELLENDİ) -->
                    <TabItem Header="Onarım" x:Name="tabRepair">
                        <Grid Margin="10,0,5,5">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            
                            <!-- Ağaç Listesi -->
                            <TreeView x:Name="tvRepair" Grid.Row="0" BorderThickness="0" Background="Transparent" VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling"/>
                            
                            <!-- Alt Butonlar -->
                            <Border Grid.Row="1" Background="#222" CornerRadius="5" Padding="5" Margin="0,10,0,0">
                                <UniformGrid Rows="1">
                                    <Button x:Name="btnFixUpdate" Content="🛠️ Windows Update Onar" Background="#E68A00" Foreground="White" Height="35" Margin="0,0,5,0" FontWeight="Bold"/>
                                    <Button x:Name="btnResetNet" Content="🌐 Ağ Ayarlarını Sıfırla" Background="#333" Foreground="White" Height="35" Margin="0,0,5,0"/>
                                    <Button x:Name="btnSfcScan" Content="🔍 SFC / Scannow" Background="#006600" Foreground="White" Height="35" FontWeight="Bold"/>
                                </UniformGrid>
                            </Border>
                        </Grid>
                    </TabItem>
                    <TabItem Header="Winget" x:Name="tabWinget">
                        <Grid Margin="10,0,5,5">
                            <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <TreeView x:Name="tvWinget" Grid.Row="0" BorderThickness="0" Background="Transparent" VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling"/>
                            <UniformGrid Grid.Row="1" Rows="1" Margin="0,10,0,0">
                                <Button x:Name="btnRefreshWinget" Content="♻ Denetle" Background="#007ACC" Margin="0,0,5,0" Height="35"/>
                                <Button x:Name="btnWingetUpdateAll" Content="🚀 Winget Update" Background="#E68A00" Margin="0,0,5,0" Height="35" FontSize="11" FontWeight="Bold"/>
                                <Button x:Name="btnManageWinget" Content="⚙ Yönet" Background="#444" Margin="0,0,5,0" Height="35"/>
                                <Button x:Name="btnUninstallWinget" Content="KALDIR" Background="#A00" Margin="0,0,5,0" Height="35"/>
                                <Button x:Name="btnInstallWinget" Content="KUR" Background="#006600" Margin="0,0,5,0" Height="35"/>
								<Button x:Name="btnBloatware" Content="🗑️ Bloatware" Background="#A00" Margin="0,0,5,0" Height="35" FontWeight="Bold"/>
                            </UniformGrid>
                        </Grid>
                    </TabItem>
                    <TabItem Header="Tweaks" x:Name="tabTweaks">
                         <Grid Margin="10,0,5,5">
                            <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                            <TreeView x:Name="tvTweaks" Grid.Row="0" BorderThickness="0" Background="Transparent" VirtualizingStackPanel.IsVirtualizing="True" VirtualizingStackPanel.VirtualizationMode="Recycling">
                                <TreeView.ItemContainerStyle>
                                    <Style TargetType="{x:Type TreeViewItem}">
                                        <Setter Property="IsExpanded" Value="True"/>
                                        <Setter Property="Foreground" Value="White"/>
                                        <Setter Property="Padding" Value="5,2"/>
                                    </Style>
                                </TreeView.ItemContainerStyle>
                            </TreeView>
                            <UniformGrid Grid.Row="1" Rows="1" Margin="0,10,0,0">
                                <Button x:Name="btnCheckTweaks" Content="♻ Denetle" Background="#007ACC" Margin="0,0,5,0" Height="35"/>
                                <Button x:Name="btnProfile"     Content="★ Önerilen" Background="#6600CC" Margin="0,0,5,0" Height="35"/>
                                <Button x:Name="btnSaveProfile" Content="💾 Profil"  Background="#2E5E2E" Margin="0,0,5,0" Height="35"/>
                                <Button x:Name="btnQuickUndo"   Content="↶ Geri Al"  Background="#A00"    Margin="0,0,5,0" Height="35" IsEnabled="False" ToolTip="Son uygulanan tweak setini tersine çevirir."/>
                                <Button x:Name="btnManageTweaks" Content="⚙ Yönet"  Background="#444"    Margin="0,0,5,0" Height="35"/>
                                <Button x:Name="btnApplyTweaks"  Content="UYGULA"    Background="#E68A00" FontWeight="Bold" Height="35"/>
                            </UniformGrid>
                        </Grid>
                    </TabItem>
					<TabItem Header="Başlangıç" x:Name="tabStartup">
                        <Grid Margin="10,0,5,5">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            
                            <!-- ÜST KONTROL PANELİ -->
                            <Border Grid.Row="0" Background="#222" CornerRadius="5" Padding="10" Margin="0,0,0,10">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <RadioButton x:Name="rbStartupWin" Content="Windows Başlangıcı (Kayıt Defteri &amp; Klasör)" Foreground="White" FontSize="13" FontWeight="SemiBold" IsChecked="True" Margin="0,0,20,0"/>
                                        <RadioButton x:Name="rbStartupTask" Content="Zamanlanmış Görevler (Gereksiz Updaters)" Foreground="#E68A00" FontSize="13" FontWeight="SemiBold"/>
                                    </StackPanel>
                                    <Button x:Name="btnRefreshStartup" Grid.Column="1" Content="♻ Yenile" Background="#007ACC" Foreground="White" Width="90" Height="30"/>
                                </Grid>
                            </Border>

                            <!-- TABLO (LISTVIEW) -->
                            <ListView x:Name="lvStartup" Grid.Row="1" Background="#1E1E1E" BorderThickness="1" BorderBrush="#444" ContextMenu="{StaticResource StartupItemMenu}">
                                <ListView.View>
                                    <GridView>
                                        <!-- RENKLİ VE DAİRELİ YENİ DURUM SÜTUNU -->
                                        <GridViewColumn Header="DURUM" Width="90">
                                            <GridViewColumn.CellTemplate>
                                                <DataTemplate>
                                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                                        <Ellipse Width="10" Height="10" Fill="{Binding StatusColor}" Margin="0,0,6,0"/>
                                                        <TextBlock Text="{Binding StatusText}" Foreground="{Binding StatusColor}" FontWeight="Bold"/>
                                                    </StackPanel>
                                                </DataTemplate>
                                            </GridViewColumn.CellTemplate>
                                        </GridViewColumn>
                                        <GridViewColumn Header="İSİM" Width="180" DisplayMemberBinding="{Binding Name}"/>
                                        <GridViewColumn Header="TÜR" Width="120" DisplayMemberBinding="{Binding Type}"/>
                                        <GridViewColumn Header="GECİKME" Width="80">
                                            <GridViewColumn.CellTemplate>
                                                <DataTemplate>
                                                    <TextBlock Text="{Binding DelayStr}" Foreground="{Binding DelayColor}" FontSize="11" FontWeight="SemiBold"/>
                                                </DataTemplate>
                                            </GridViewColumn.CellTemplate>
                                        </GridViewColumn>
                                        <GridViewColumn Header="DOSYA YOLU / KOMUT" Width="380" DisplayMemberBinding="{Binding Path}"/>
                                    </GridView>
                                </ListView.View>
                            </ListView>
                        </Grid>
                    </TabItem>
					<!-- BÜYÜK DOSYA AVCISI -->
                    <TabItem Header="Dosya Boyutu" x:Name="tabLargeFiles">
                        <Grid Margin="10,0,5,5">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <!-- ÜST KONTROL PANELİ -->
                            <Border Grid.Row="0" Background="#222" CornerRadius="5" Padding="10" Margin="0,0,0,10">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="150"/>
                                        <ColumnDefinition Width="15"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="120"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    
                                    <TextBlock Text="Hedef:" Foreground="#AAA" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    <ComboBox x:Name="cbScanTarget" Grid.Column="1" Height="28" VerticalContentAlignment="Center" SelectedIndex="0">
                                        <ComboBoxItem Content="Kullanıcı Klasörleri"/>
                                        <ComboBoxItem Content="C: Diski (Sistem)"/>
                                        <ComboBoxItem Content="Özel Klasör Seç..."/>
                                    </ComboBox>

                                    <TextBlock Grid.Column="3" Text="Min. Boyut:" Foreground="#AAA" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    <ComboBox x:Name="cbMinSize" Grid.Column="4" Height="28" VerticalContentAlignment="Center" SelectedIndex="1">
                                        <ComboBoxItem Content="> 50 MB" Tag="52428800"/>
                                        <ComboBoxItem Content="> 100 MB" Tag="104857600"/>
                                        <ComboBoxItem Content="> 500 MB" Tag="524288000"/>
                                        <ComboBoxItem Content="> 1 GB" Tag="1073741824"/>
                                    </ComboBox>

                                    <Button x:Name="btnScanFiles" Grid.Column="6" Content="🔍 TARA" Background="#007ACC" Foreground="White" FontWeight="Bold" Width="100" Height="30"/>
                                </Grid>
                            </Border>

                            <!-- TABLO -->
                            <ListView x:Name="lvLargeFiles" Grid.Row="1" Background="#1E1E1E" BorderThickness="1" BorderBrush="#444">
                                <ListView.ContextMenu>
                                    <ContextMenu>
                                        <MenuItem Header="Dosya Konumunu Aç (Seç)" Name="ctxOpenLargeFile" FontWeight="Bold" Foreground="#4CC2FF"/>
                                        <MenuItem Header="Yolu Kopyala" Name="ctxCopyLargePath"/>
                                        <Separator/>
                                        <MenuItem Header="Kalıcı Olarak SİL" Name="ctxDeleteLargeFile" Foreground="#FF5555" FontWeight="Bold"/>
                                    </ContextMenu>
                                </ListView.ContextMenu>
                                <ListView.View>
                                    <GridView>
                                        <GridViewColumn Header="DOSYA ADI" Width="250" DisplayMemberBinding="{Binding Name}"/>
                                        <GridViewColumn Header="BOYUT" Width="100" DisplayMemberBinding="{Binding SizeStr}"/>
                                        <GridViewColumn Header="TÜR" Width="80" DisplayMemberBinding="{Binding Extension}"/>
                                        <GridViewColumn Header="KONUM" Width="350" DisplayMemberBinding="{Binding Folder}"/>
                                        <GridViewColumn Header="TARİH" Width="140" DisplayMemberBinding="{Binding Date}"/>
                                    </GridView>
                                </ListView.View>
                            </ListView>
                            
                            <!-- DURUM ÇUBUĞU -->
                            <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,5,0,0">
                                <TextBlock x:Name="txtLargeStatus" Text="Hazır." Foreground="#888" FontSize="11" VerticalAlignment="Center"/>
                                <ProgressBar x:Name="pbLargeScan" Width="150" Height="10" Margin="10,0,0,0" Background="#333" Foreground="#007ACC" Visibility="Collapsed" IsIndeterminate="True"/>
                            </StackPanel>
                        </Grid>
                    </TabItem>
					<!-- ÇÖKME VE HATA DEDEKTİFİ (KARA KUTU) -->
                    <TabItem Header="Çökme Analizi" x:Name="tabCrash">
                        <Grid Margin="10,0,5,5">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <!-- ÜST: KARA KUTU DURUM PANELİ (DÜZELTİLDİ) -->
                            <Border Grid.Row="0" Background="#252526" CornerRadius="5" Padding="10" Margin="0,0,0,10" BorderBrush="#3E3E42" BorderThickness="1">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/> <!-- Başlık -->
                                        <ColumnDefinition Width="Auto"/> <!-- İkon -->
                                        <ColumnDefinition Width="*"/>    <!-- Metin (Esnek) -->
                                        <ColumnDefinition Width="Auto"/> <!-- Buton -->
                                    </Grid.ColumnDefinitions>
                                    
                                    <TextBlock Grid.Column="0" Text="🗃️ Sistem Kara Kutusu:" Foreground="#4CC2FF" FontSize="14" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                    
                                    <Ellipse x:Name="shpBlackBoxStatus" Grid.Column="1" Width="12" Height="12" Fill="#888" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                    
                                    <!-- TextWrapping="Wrap" eklendi, artık taşarsa alt satıra iner -->
                                    <TextBlock x:Name="txtBlackBoxStatus" Grid.Column="2" Text="Durum kontrol ediliyor..." Foreground="#CCC" FontSize="13" VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,10,0"/>

                                    <Button x:Name="btnFixBlackBox" Grid.Column="3" Content="🔧 Kara Kutuyu Aç" Background="#A00" Foreground="White" FontWeight="Bold" Padding="15,5" VerticalAlignment="Center" Visibility="Collapsed" Tag="off"/>
                                </Grid>
                            </Border>

                            <!-- ORTA: PROCESS WATCHER PANELİ -->
                            <Border Grid.Row="1" Background="#1A2A1A" CornerRadius="5" Padding="8,7" Margin="0,0,0,8" BorderBrush="#2D5A2D" BorderThickness="1">
                                <StackPanel>
                                    <!-- Satır 1: Seçimler ve butonlar -->
                                    <Grid>
                                        <Grid.ColumnDefinitions>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="8"/>
                                            <ColumnDefinition Width="170"/>
                                            <ColumnDefinition Width="8"/>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="8"/>
                                            <ColumnDefinition Width="170"/>
                                            <ColumnDefinition Width="8"/>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="*"/>
                                            <ColumnDefinition Width="Auto"/>
                                            <ColumnDefinition Width="5"/>
                                            <ColumnDefinition Width="Auto"/>
                                        </Grid.ColumnDefinitions>
                                        <TextBlock Text="🎯 İzle:" Foreground="#90EE90" FontWeight="Bold" VerticalAlignment="Center"/>
                                        <ComboBox x:Name="cbWatchProcess" Grid.Column="2" Height="26" VerticalContentAlignment="Center"/>
                                        <TextBlock Grid.Column="4" Text="+" Foreground="#90EE90" FontWeight="Bold" FontSize="16" VerticalAlignment="Center"/>
                                        <ComboBox x:Name="cbWatchProcess2" Grid.Column="6" Height="26" VerticalContentAlignment="Center"/>
                                        <TextBox x:Name="txtWatchCustom" Grid.Column="8" Width="130" Height="26" Background="#222" Foreground="#AAA" VerticalContentAlignment="Center" Padding="4,0" Text="process.exe" Visibility="Collapsed"/>
                                        <Button x:Name="btnWatchStart" Grid.Column="10" Content="▶ İzlemeyi Başlat" Background="#1E5C1E" Foreground="White" FontWeight="Bold" Padding="12,4" Height="26"/>
                                        <Button x:Name="btnWatchStop" Grid.Column="12" Content="⏹ Durdur" Background="#5C1E1E" Foreground="White" FontWeight="Bold" Padding="12,4" Height="26" IsEnabled="False"/>
                                    </Grid>
                                    <!-- Satır 2: Durum -->
                                    <TextBlock x:Name="txtWatchStatus" Text="İzleme kapalı — process seç, İzlemeyi Başlat'a bas." Foreground="#666" FontSize="11" Margin="0,5,0,0" FontStyle="Italic"/>
                                </StackPanel>
                            </Border>

                            <!-- FİLTRE VE TARAMA BUTONLARI -->
                            <Grid Grid.Row="2" Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="150"/>
                                    <ColumnDefinition Width="15"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>

                                <TextBlock Text="Zaman Aralığı:" Foreground="#AAA" VerticalAlignment="Center" Margin="0,0,10,0"/>
                                <ComboBox x:Name="cbCrashTime" Grid.Column="1" Height="28" VerticalContentAlignment="Center" SelectedIndex="0">
                                    <ComboBoxItem Content="Son 1 Saat (Tavsiye)" Tag="1"/>
                                    <ComboBoxItem Content="Son 4 Saat" Tag="4"/>
                                    <ComboBoxItem Content="Son 24 Saat" Tag="24"/>
                                    <ComboBoxItem Content="Son 3 Gün" Tag="72"/>
                                </ComboBox>

                                <TextBlock Grid.Column="3" Text="Oyun çöktükten veya sistem kapandıktan hemen sonra bu butona basınız." Foreground="#888" FontSize="11" VerticalAlignment="Center" FontStyle="Italic" TextWrapping="Wrap" Margin="0,0,10,0"/>

                                <Button x:Name="btnScanCrashes" Grid.Column="4" Content="🔍 NE OLDU BUL!" Background="#E68A00" Foreground="White" FontWeight="Bold" Width="140" Height="35">
                                    <Button.Effect>
                                        <DropShadowEffect Color="#E68A00" BlurRadius="10" ShadowDepth="0" Opacity="0.5"/>
                                    </Button.Effect>
                                </Button>
                            </Grid>

                            <!-- ALT: SONUÇ TABLOSU -->
                            <ListView x:Name="lvCrashes" Grid.Row="3" Background="#1E1E1E" BorderThickness="1" BorderBrush="#444">
                                <ListView.ContextMenu>
                                    <ContextMenu>
                                        <MenuItem Header="Hata Detayını Kopyala" Name="ctxCopyCrash" FontWeight="Bold" Foreground="#4CC2FF"/>
                                        <MenuItem Header="Google'da Çözüm Ara" Name="ctxSearchCrash" Foreground="#00CC00"/>
                                        <Separator/>
                                        <MenuItem Header="💾 Dump (Bellek Dökümü) Klasörünü Aç" Name="ctxOpenDump" Foreground="#FFCC00" FontWeight="Bold"/>
                                    </ContextMenu>
                                </ListView.ContextMenu>
                                <ListView.View>
                                    <GridView>
                                        <GridViewColumn Header="SAAT" Width="120" DisplayMemberBinding="{Binding Time}"/>
                                        <GridViewColumn Header="TÜR" Width="120">
                                            <GridViewColumn.CellTemplate>
                                                <DataTemplate>
                                                    <TextBlock Text="{Binding Category}" Foreground="{Binding Color}" FontWeight="Bold"/>
                                                </DataTemplate>
                                            </GridViewColumn.CellTemplate>
                                        </GridViewColumn>
                                        <GridViewColumn Header="SUÇLU DOSYA" Width="150" DisplayMemberBinding="{Binding FaultingModule}"/>
                                        <GridViewColumn Header="AÇIKLAMA" Width="500">
                                            <GridViewColumn.CellTemplate>
                                                <DataTemplate>
                                                    <TextBlock Text="{Binding Description}" TextWrapping="Wrap"/>
                                                </DataTemplate>
                                            </GridViewColumn.CellTemplate>
                                        </GridViewColumn>
                                    </GridView>
                                </ListView.View>
                            </ListView>

                        </Grid>
                    </TabItem>
                </TabControl>
            </Grid>
        </Border>
        <GridSplitter Grid.Column="1" Width="5" HorizontalAlignment="Center" Background="#181818"/>
        <Border Grid.Column="2" Background="{StaticResource PanelBg}" CornerRadius="8" Padding="10">
            <Grid>
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,5">
                    <TextBlock Text="İşlem Kayıtları" Foreground="#AAA" FontWeight="Bold" VerticalAlignment="Center"/>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="btnCopyLog" Content="Kopyala" Padding="10,4" Background="#333" FontSize="11" Margin="0,0,5,0"/>
                        <Button x:Name="btnClearLog" Content="Temizle" Padding="10,4" Background="#333" Foreground="#FF5555" FontSize="11"/>
                    </StackPanel>
                </Grid>
                <TextBox x:Name="txtLog" Grid.Row="1" Background="#1E1E1E" Foreground="#CCC" BorderThickness="0" VerticalScrollBarVisibility="Auto" IsReadOnly="True" TextWrapping="Wrap" FontFamily="Consolas" Padding="5"/>
            </Grid>
        </Border>
    </Grid>

    <!-- FOOTER (AUTO YÜKSEKLİK İLE KESİLME ÖNLENDİ) -->
    <Grid Grid.Row="2" Margin="0,10,0,10">
	
        <Grid.ColumnDefinitions> <ColumnDefinition Width="*"/> <ColumnDefinition Width="Auto"/> </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" VerticalAlignment="Center">
            <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                <TextBlock x:Name="lblStatus" Text="Sistem Hazır" Foreground="White" FontWeight="Bold" FontSize="14" Margin="0,0,15,0"/>
                <TextBlock x:Name="txtWinappStatus" Text="Veritabanı bekleniyor..." Foreground="#888" VerticalAlignment="Center" FontSize="11"/>
            </StackPanel>
            <TextBlock x:Name="lblDetail" Text="İşlem bekleniyor..." Foreground="#AAA" FontSize="12" Margin="0,0,0,8" TextTrimming="CharacterEllipsis"/>
            <Grid> <Border Height="4" Background="#333" CornerRadius="2"/> <ProgressBar x:Name="pbMain" Height="4" Background="Transparent" Foreground="{StaticResource AccentColor}" BorderThickness="0" Value="0"/> </Grid>
            <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                <CheckBox x:Name="chkDebug" Content="Debug Mode" Foreground="#666" FontSize="10" Margin="0,0,15,0" Style="{StaticResource ToggleSwitch}"/>
                <Button x:Name="btnOpenData" Content="📂 Veri Klasörü" Background="Transparent" Foreground="#555" FontSize="10" BorderThickness="0" Padding="0" Margin="0,0,10,0"/>
            </StackPanel>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="0,0,10,5">
            <TextBlock Text="Silme Yöntemi:" Foreground="#888" FontSize="11" Margin="0,0,0,2"/>
            <ComboBox x:Name="cbSecureDelete" Width="180" Height="30" SelectedIndex="0" VerticalContentAlignment="Center">
                <ComboBoxItem Content="Hızlı Silme (Standart)"/>
                <ComboBoxItem Content="Güvenli (Sıfırla - Zeroes)"/>
                <ComboBoxItem Content="Güvenli (Random Data)"/>
            </ComboBox>
			</StackPanel>
            <Button x:Name="btnAnalyze" Content="ANALİZ ET" Width="110" Height="45" Background="#333" BorderThickness="1" BorderBrush="#555" Margin="0,0,10,0"/>
            <Button x:Name="btnRun" Content="BAŞLAT" Width="140" Height="45" Background="{StaticResource AccentColor}" FontWeight="Bold" FontSize="16">
                <Button.Effect> <DropShadowEffect Color="#007ACC" BlurRadius="20" ShadowDepth="0" Opacity="0.4"/> </Button.Effect>
            </Button>
        </StackPanel>
    </Grid>
  </Grid>
 
</Window>
"@

# --- DİĞER XAML DOSYALARI (AYNEN KORUNDU) ---
$xamlToolMgr = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Web Araçları Yöneticisi' Height='600' Width='600' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow'><Window.Resources><Style TargetType='TextBox'><Setter Property='Background' Value='#252526'/><Setter Property='Foreground' Value='White'/><Setter Property='Padding' Value='5'/></Style><Style TargetType='TextBlock'><Setter Property='Foreground' Value='#AAA'/><Setter Property='Margin' Value='0,0,0,5'/></Style></Window.Resources><Grid Margin='15'><Grid.ColumnDefinitions><ColumnDefinition Width='200'/><ColumnDefinition Width='20'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions><Grid Grid.Column='0'><Grid.RowDefinitions><RowDefinition Height='*'/><RowDefinition Height='Auto'/></Grid.RowDefinitions><ListBox x:Name='lstTools' Grid.Row='0' Background='#222' Foreground='White' BorderThickness='1' BorderBrush='#444'/><StackPanel Grid.Row='1' Orientation='Horizontal' Margin='0,10,0,0'><Button x:Name='btnNew' Content='Yeni' Width='60' Background='#006600' Foreground='White'/><Button x:Name='btnDel' Content='Sil' Width='60' Background='#A00' Foreground='White' Margin='5,0,0,0'/><Button x:Name='btnSaveAll' Content='Kaydet' Width='65' Background='#007ACC' Foreground='White' Margin='5,0,0,0'/></StackPanel></Grid><StackPanel Grid.Column='2'><TextBlock Text='Araç Adı:' Foreground='#4CC2FF' FontWeight='Bold'/><TextBox x:Name='txtName' Margin='0,0,0,15'/><TextBlock Text='URL:' Foreground='#4CC2FF' FontWeight='Bold'/><TextBox x:Name='txtUrl' Margin='0,0,0,5'/><TextBlock Text='Örn: https://site.com/tools/' FontSize='10' Margin='0,0,0,15'/><Border BorderBrush='#444' BorderThickness='1' Padding='10' CornerRadius='5' Background='#222' Margin='0,0,0,15'><StackPanel><TextBlock Text='🔍 Akıllı Arama' Foreground='#E68A00' FontWeight='Bold' Margin='0,0,0,5'/><TextBlock Text='Anahtar Kelime:' Foreground='White'/><TextBox x:Name='txtKeyword' Margin='0,5,0,5'/><TextBlock Text='Örn: Magician' FontSize='10' Foreground='#888'/></StackPanel></Border><Expander Header='Gelişmiş (Regex)' Foreground='#AAA' Margin='0,0,0,15'><StackPanel Margin='0,5,0,0'><TextBlock Text='Regex:'/><TextBox x:Name='txtRegex' Margin='0,0,0,5'/></StackPanel></Expander><TextBlock Text='İndirme Klasörü:' Foreground='#4CC2FF' FontWeight='Bold' Margin='0,0,0,5'/><Grid Margin='0,0,0,15'><Grid.ColumnDefinitions><ColumnDefinition Width='*'/><ColumnDefinition Width='35'/></Grid.ColumnDefinitions><TextBox x:Name='txtDownPath' IsReadOnly='True' Cursor='Hand'/><Button x:Name='btnPickPath' Grid.Column='1' Content='...' Background='#444' Foreground='White'/></Grid><Button x:Name='btnTest' Content='TEST ET' Height='35' Background='#E68A00' FontWeight='Bold' Margin='0,0,0,10'/><TextBlock Text='Sonuç:' FontWeight='Bold'/><TextBox x:Name='txtResult' Height='60' TextWrapping='Wrap' IsReadOnly='True' Background='#111' Foreground='#0F0'/></StackPanel></Grid>
</Window>
"@

$xamlSettings = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Program Ayarları" Height="720" Width="520"
        Background="#181818" WindowStartupLocation="CenterScreen" WindowStyle="ToolWindow" ResizeMode="NoResize">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="White"/> <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template"> <Setter.Value> <ControlTemplate TargetType="Button"> <Border x:Name="border" CornerRadius="4" Background="#333" Padding="10,5"> <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/> </Border> <ControlTemplate.Triggers> <Trigger Property="IsMouseOver" Value="True"> <Setter TargetName="border" Property="Background" Value="#555"/> </Trigger> </ControlTemplate.Triggers> </ControlTemplate> </Setter.Value> </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- 0: Görünüm -->
            <RowDefinition Height="Auto"/> <!-- 1: Geliştirici -->
            <RowDefinition Height="Auto"/> <!-- 2: LİSTE YÖNETİMİ -->
            <RowDefinition Height="Auto"/> <!-- 3: SİSTEM GERİ YÜKLEME (YENİ) -->
            <RowDefinition Height="*"/>    <!-- 4: Dosyalar -->
            <RowDefinition Height="Auto"/> <!-- 5: Alt Butonlar -->
        </Grid.RowDefinitions>

        <!-- 1. GÖRÜNÜM -->
        <Border Grid.Row="0" BorderBrush="#444" BorderThickness="1" CornerRadius="5" Padding="10" Margin="0,0,0,15" Background="#222">
            <StackPanel>
                <TextBlock Text="Görünüm Tercihi" Foreground="#007ACC" FontWeight="Bold" Margin="0,0,0,5"/>
                <StackPanel Orientation="Horizontal">
                    <RadioButton x:Name="rbLayoutLeft" Content="Modern (Sol Menü)" Foreground="White" Margin="0,0,15,0" IsChecked="True"/>
                    <RadioButton x:Name="rbLayoutTop" Content="Klasik (Üst Menü)" Foreground="White"/>
                </StackPanel>
            </StackPanel>
        </Border>

        <!-- 2. GELİŞTİRİCİ MODU -->
        <Border Grid.Row="1" BorderBrush="#444" BorderThickness="1" CornerRadius="5" Padding="10" Margin="0,0,0,15" Background="#222">
            <StackPanel>
                <TextBlock Text="Geliştirici Modu (Önbellek)" Foreground="#E68A00" FontWeight="Bold" Margin="0,0,0,5"/>
                <CheckBox x:Name="chkDisableCache" Content="Önbelleği ve Yapılandırmayı Devre Dışı Bırak" Foreground="White" FontSize="13"/>
            </StackPanel>
        </Border>

        <!-- 3. LİSTE YÖNETİMİ -->
        <Border Grid.Row="2" BorderBrush="#444" BorderThickness="1" CornerRadius="5" Padding="10" Margin="0,0,0,15" Background="#222">
            <StackPanel>
                <TextBlock Text="Liste ve Kural Yönetimi" Foreground="#4CC2FF" FontWeight="Bold" Margin="0,0,0,10"/>
                <StackPanel Orientation="Horizontal">
                    <Button x:Name="btnOpenBlacklist" Content="🚫 Yoksayılanlar" Width="120" Margin="0,0,10,0"/>
                    <Button x:Name="btnOpenCustom" Content="📂 Özel Kurallar" Width="120" Margin="0,0,10,0"/>
					<Button x:Name="btnEditWinapp2" Content="📝 Winapp2 Düzenle" Background="#E68A00" Foreground="White" Margin="0,0,10,0"/>
                </StackPanel>
            </StackPanel>
        </Border>

        <!-- 4. SİSTEM GERİ YÜKLEME (YENİ) -->
        <Border Grid.Row="3" BorderBrush="#444" BorderThickness="1" CornerRadius="5" Padding="10" Margin="0,0,0,15" Background="#222">
            <StackPanel>
                <TextBlock Text="Sistem Geri Yükleme (Tweak Uygulamadan Önce)" Foreground="#4CC2FF" FontWeight="Bold" Margin="0,0,0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <RadioButton x:Name="rbRPAsk"   Content="Her seferinde sor"  GroupName="RPMode" Foreground="White" Margin="0,0,12,0"/>
                    <RadioButton x:Name="rbRPAuto"  Content="Sormadan oluştur"   GroupName="RPMode" Foreground="White" Margin="0,0,12,0"/>
                    <RadioButton x:Name="rbRPNever" Content="Asla oluşturma"     GroupName="RPMode" Foreground="White"/>
                </StackPanel>
                <TextBlock x:Name="txtRPInfo" Text="Son nokta: -- • VSS servisi: --" Foreground="#888" FontSize="11" Margin="0,6,0,10"/>
                <StackPanel Orientation="Horizontal">
                    <Button x:Name="btnRPManualCreate" Content="🔄 Şimdi Manuel Oluştur" Width="180" Margin="0,0,10,0"/>
                    <Button x:Name="btnRPWindowsPanel" Content="📂 Windows Geri Yükleme Paneli" Width="230"/>
                </StackPanel>
            </StackPanel>
        </Border>

        <!-- 5. DOSYA YÖNETİMİ -->
        <TextBlock Grid.Row="4" Text="Veri Dosyaları" Foreground="#CCC" FontWeight="Bold" Margin="0,0,0,5"/>
        <ListBox x:Name="lstFiles" Grid.Row="4" Background="#1E1E1E" Foreground="White" BorderBrush="#444" SelectionMode="Extended" Margin="0,20,0,10"/>

        <!-- 6. ALT BUTONLAR -->
        <Grid Grid.Row="5">
            <Grid.ColumnDefinitions> <ColumnDefinition Width="Auto"/> <ColumnDefinition Width="*"/> <ColumnDefinition Width="Auto"/> </Grid.ColumnDefinitions>
            <Button x:Name="btnDeleteFiles" Grid.Column="0" Content="🗑 SEÇİLENLERİ SİL" Background="#A00" FontWeight="Bold"/>
            <StackPanel Grid.Column="2" Orientation="Horizontal">
                <Button x:Name="btnImportUI" Content="İçe Aktar" Background="#007ACC" Margin="0,0,5,0"/>
                <Button x:Name="btnExportUI" Content="Dışa Aktar" Background="#007ACC"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

$xamlNightMode = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='🌙 Akıllı Gece Modu' Height='450' Width='550' Background='#121212' WindowStartupLocation='CenterOwner' WindowStyle='ToolWindow' ResizeMode='NoResize'>
    
    <Window.Resources>
        <!-- BUTON STİLİ (Renk sorunu çözüldü) -->
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="4" Background="{TemplateBinding Background}" BorderThickness="0">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"> <Setter TargetName="border" Property="Opacity" Value="0.8"/> </Trigger>
                            <Trigger Property="IsPressed" Value="True"> <Setter TargetName="border" Property="Opacity" Value="0.6"/> </Trigger>
                            <!-- Pasif Butonun Rengi -->
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#333333"/>
                                <Setter Property="Foreground" Value="#777777"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin='20'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>

        <TextBlock Text='Otomatik Sistem Kapatma' Foreground='#4CC2FF' FontSize='20' FontWeight='Bold' HorizontalAlignment='Center'/>
        <TextBlock Grid.Row='1' Text='Bilgisayarınızın ne zaman kapatılacağını seçin.' Foreground='#888' FontSize='12' HorizontalAlignment='Center' Margin='0,5,0,20'/>

        <!-- SEKMELER -->
        <TabControl x:Name='tcNightMode' Grid.Row='2' Background='Transparent' BorderThickness='0'>
            <TabControl.Resources>
                <Style TargetType='TabItem'>
                    <Setter Property='Template'>
                        <Setter.Value>
                            <ControlTemplate TargetType='TabItem'>
                                <Border Name='Border' BorderThickness='1' BorderBrush='#333' Background='#222' Margin='0,0,5,0' Padding='15,8' CornerRadius='4'>
                                    <ContentPresenter x:Name='ContentSite' VerticalAlignment='Center' HorizontalAlignment='Center' ContentSource='Header' RecognizesAccessKey='True'/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property='IsSelected' Value='True'>
                                        <Setter TargetName='Border' Property='Background' Value='#1A3A5C'/>
                                        <Setter TargetName='Border' Property='BorderBrush' Value='#4CC2FF'/>
                                        <Setter Property='Foreground' Value='White'/>
                                    </Trigger>
                                    <Trigger Property='IsSelected' Value='False'>
                                        <Setter Property='Foreground' Value='#888'/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Style>
            </TabControl.Resources>

            <!-- 1. SÜRE MODU -->
            <TabItem Header='⏳ Süreye Göre'>
                <StackPanel Margin='0,20,0,0'>
                    <TextBlock Text='Sistem şu kadar zaman sonra kapatılsın:' Foreground='White' FontSize='14' Margin='0,0,0,10'/>
                    <StackPanel Orientation='Horizontal'>
                        <TextBox x:Name='txtHours' Width='50' Height='35' FontSize='16' TextAlignment='Center' VerticalContentAlignment='Center' Text='1'/>
                        <TextBlock Text='Saat' Foreground='#AAA' VerticalAlignment='Center' Margin='10,0,20,0'/>
                        <TextBox x:Name='txtMins' Width='50' Height='35' FontSize='16' TextAlignment='Center' VerticalContentAlignment='Center' Text='30'/>
                        <TextBlock Text='Dakika' Foreground='#AAA' VerticalAlignment='Center' Margin='10,0,0,0'/>
                    </StackPanel>
                </StackPanel>
            </TabItem>

            <!-- 2. AĞ MODU (Siyah zorlaması silindi, orjinal beyaz oldu) -->
            <TabItem Header='🌐 Genel Ağ Trafiği'>
                <StackPanel Margin='0,20,0,0'>
                    <TextBlock Text='İndirme hızı şu değerin altına düşerse kapat:' Foreground='White' FontSize='14' Margin='0,0,0,10'/>
                    <StackPanel Orientation='Horizontal' Margin='0,0,0,15'>
                        <ComboBox x:Name='cbNetSpeed' Width='120' Height='30' VerticalContentAlignment='Center'>
                            <ComboBoxItem Content='0.5 Mbps' Tag='0.5'/>
                            <ComboBoxItem Content='1 Mbps' Tag='1' IsSelected='True'/>
                            <ComboBoxItem Content='5 Mbps' Tag='5'/>
                        </ComboBox>
                    </StackPanel>
                    <TextBlock Text='Emin olmak için bekleme süresi:' Foreground='White' FontSize='14' Margin='0,0,0,10'/>
                    <ComboBox x:Name='cbNetWait' Width='120' Height='30' VerticalContentAlignment='Center'>
                        <ComboBoxItem Content='2 Dakika' Tag='2'/>
                        <ComboBoxItem Content='5 Dakika' Tag='5' IsSelected='True'/>
                        <ComboBoxItem Content='10 Dakika' Tag='10'/>
                    </ComboBox>
                </StackPanel>
            </TabItem>

            <!-- 3. UYGULAMA MODU (Siyah zorlaması silindi, orjinal beyaz oldu) -->
            <TabItem Header='🎯 Uygulama Takibi'>
                <StackPanel Margin='0,20,0,0'>
                    <TextBlock Text='İndirme yapan programı (Client) seçin:' Foreground='White' FontSize='14' Margin='0,0,0,10'/>
                    <ComboBox x:Name='cbProcess' Height='30' VerticalContentAlignment='Center' Margin='0,0,0,15'/>
                    <TextBlock Text='Olay:' Foreground='White' FontSize='14' Margin='0,0,0,10'/>
                    <TextBlock Text='Program kapatıldığında VEYA diske/ağa veri yazması 5 dakika boyunca durduğunda sistem kapatılır.' Foreground='#E68A00' FontSize='12' TextWrapping='Wrap'/>
                </StackPanel>
            </TabItem>
        </TabControl>

        <!-- ALT BUTONLAR VE DURUM -->
        <Grid Grid.Row='3' Margin='0,20,0,0'>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width='*'/>
                <ColumnDefinition Width='Auto'/>
                <ColumnDefinition Width='Auto'/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name='txtStatus' Grid.Column='0' Text='Gece Modu Kapalı.' Foreground='#888' VerticalAlignment='Center' TextWrapping='Wrap'/>
            
            <!-- Butonların kendi içindeki 'Foreground=White' kodu silindi. Artık en üstteki Stilden rengini çekecek. -->
            <Button x:Name='btnStop' Grid.Column='1' Content='DURDUR' Width='90' Height='35' Background='#A00' Margin='0,0,10,0' IsEnabled='False'/>
            <Button x:Name='btnStart' Grid.Column='2' Content='BAŞLAT' Width='120' Height='35' Background='#006600'/>
        </Grid>
    </Grid>
</Window>
"@

# --- GERİ SAYIM / UYANDIRMA EKRANI ---
$xamlCountdown = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Sistem Kapatılıyor' WindowStyle='None' WindowState='Maximized' Topmost='True' AllowsTransparency='True' Background='#E6000000'>
    <Window.Resources>
        <!-- İPTAL BUTONUNA ÖZEL KIRMIZI HOVER STİLİ -->
        <Style TargetType="Button">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="10" Background="#990000" BorderThickness="2" BorderBrush="#FF5555">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <!-- Üzerine gelince mavi değil, parlak kırmızı olacak -->
                                <Setter TargetName="border" Property="Background" Value="#FF3333"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#550000"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <StackPanel HorizontalAlignment='Center' VerticalAlignment='Center'>
            <TextBlock Text='🌙 Shutdown' Foreground='#4CC2FF' FontSize='36' FontWeight='Bold' HorizontalAlignment='Center' Margin='0,0,0,20'/>
            <TextBlock Text='Belirlenen hedefe ulaşıldı. Bilgisayar kapatılıyor...' Foreground='White' FontSize='24' HorizontalAlignment='Center' Margin='0,0,0,40'/>
            <TextBlock x:Name='txtSeconds' Text='60' Foreground='#FF4444' FontSize='120' FontWeight='Bold' HorizontalAlignment='Center' Margin='0,0,0,50'/>
            <Button x:Name='btnAbort' Content='İPTAL ET (DURDUR)' Width='300' Height='80' FontSize='24' FontWeight='Bold'>
                <Button.Effect> <DropShadowEffect Color='Red' BlurRadius='20' ShadowDepth='0' Opacity='0.6'/> </Button.Effect>
            </Button>
        </StackPanel>
    </Grid>
</Window>
"@

$xamlExport = @"

<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Dışa Aktar' Height='300' Width='400' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow' ResizeMode='NoResize'>
    <Grid Margin='20'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>
        <TextBlock Text='Neler yedeklensin?' Foreground='#4CC2FF' FontWeight='Bold' Margin='0,0,0,15'/>
        <StackPanel Grid.Row='1'>
            <CheckBox x:Name='chkBlacklist' Content='Yoksayılanlar' Foreground='White' IsChecked='True' Margin='0,0,0,8'/>
            <CheckBox x:Name='chkPathOverrides' Content='Özel Yollar' Foreground='White' IsChecked='True' Margin='0,0,0,8'/>
            <CheckBox x:Name='chkCustomRules' Content='Özel Kurallar' Foreground='White' IsChecked='True' Margin='0,0,0,8'/>
            <CheckBox x:Name='chkWinget' Content='Winget Listesi' Foreground='White' IsChecked='True' Margin='0,0,0,8'/>
            <CheckBox x:Name='chkTweaks' Content='Tweak Ayarları' Foreground='White' IsChecked='True' Margin='0,0,0,8'/>
            <CheckBox x:Name='chkTools' Content='Web Araçları' Foreground='White' IsChecked='True' Margin='0,0,0,8'/>
            <CheckBox x:Name='chkMyProfile' Content='Profilim' Foreground='White' IsChecked='True' Margin='0,0,0,8'/>
        </StackPanel>
        <Button x:Name='btnDoExport' Grid.Row='2' Content='DIŞA AKTAR' Height='35' Background='#007ACC' Foreground='White' FontWeight='Bold'/>
    </Grid>
</Window>
"@
$xamlWingetMgr = @"

<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Liste Yöneticisi' Height='480' Width='500' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow'>
    <Window.Resources>
        <Style TargetType='TextBox'>
            <Setter Property='Background' Value='#252526'/>
            <Setter Property='Foreground' Value='White'/>
            <Setter Property='Padding' Value='5'/>
        </Style>
        <Style TargetType='RadioButton'>
            <Setter Property='Foreground' Value='White'/>
            <Setter Property='Margin' Value='0,0,15,0'/>
            <Setter Property='FontSize' Value='14'/>
            <Setter Property='FontWeight' Value='SemiBold'/>
        </Style>
    </Window.Resources>
    <Grid Margin='15'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row='0' Orientation='Horizontal' HorizontalAlignment='Center' Margin='0,0,0,15'>
            <RadioButton Name='rbModeWinget' Content='Winget' IsChecked='True' GroupName='Mode'/>
            <RadioButton Name='rbModeAppx' Content='Windows' GroupName='Mode'/>
        </StackPanel>
        <TextBlock Name='lblTitle' Grid.Row='1' Text='Ekle:' Foreground='#4CC2FF' FontWeight='Bold' Margin='0,0,0,10'/>
        <Grid Grid.Row='2' Margin='0,0,0,15'>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width='*'/>
                <ColumnDefinition Width='*'/>
                <ColumnDefinition Width='80'/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column='0' Margin='0,0,5,0'>
                <TextBlock Text='Ad' Foreground='#888' FontSize='11'/>
                <TextBox x:Name='txtName'/>
            </StackPanel>
            <StackPanel Grid.Column='1' Margin='0,0,5,0'>
                <TextBlock x:Name='lblID' Text='ID' Foreground='#888' FontSize='11'/>
                <TextBox x:Name='txtID'/>
            </StackPanel>
            <Button x:Name='btnAddW' Grid.Column='2' Content='EKLE' Background='#006600' Foreground='White' Height='38' VerticalAlignment='Bottom'/>
        </Grid>
        <ListBox x:Name='lstWinget' Grid.Row='3' Background='#222' Foreground='White' BorderThickness='0' Margin='0,0,0,10'/>
        <StackPanel Grid.Row='4' Orientation='Horizontal' HorizontalAlignment='Right'>
            <Button x:Name='btnEditW' Content='Düzenle' Background='#444' Foreground='White' Width='80' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnDelW' Content='Sil' Background='#A00' Foreground='White' Width='100' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnCloseW' Content='Kaydet' Background='#007ACC' Foreground='White' Width='120' Height='30'/>
        </StackPanel>
    </Grid>
</Window>
"@
$xamlTweakMgr = @"
<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Ayar Yöneticisi' Height='900' Width='1100' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow'>
    <Window.Resources>
        <Style TargetType='TextBox'>
            <Setter Property='Background' Value='#252526'/>
            <Setter Property='Foreground' Value='White'/>
            <Setter Property='Padding' Value='5'/>
        </Style>
        <Style TargetType='TextBlock'>
            <Setter Property='Foreground' Value='#AAA'/>
            <Setter Property='VerticalAlignment' Value='Center'/>
            <Setter Property='Margin' Value='0,0,10,0'/>
        </Style>
        <Style TargetType='ComboBox'>
            <Setter Property='Height' Value='28'/>
        </Style>
    </Window.Resources>
    <Grid Margin='15'>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width='410'/>
            <ColumnDefinition Width='20'/>
            <ColumnDefinition Width='*'/>
        </Grid.ColumnDefinitions>
        <Grid Grid.Column='0'>
            <Grid.RowDefinitions>
                <RowDefinition Height='*'/>
                <RowDefinition Height='Auto'/>
            </Grid.RowDefinitions>
            <ListBox x:Name='lstTweaks' Grid.Row='0' Background='#222' Foreground='White' BorderThickness='1' BorderBrush='#444'/>
            <StackPanel Grid.Row='1' Orientation='Horizontal' HorizontalAlignment='Center' Margin='0,10,0,0'>
                <Button x:Name='btnNewTweak' Content='+ Yeni' Width='80' Height='30' Background='#006600' Foreground='White' Margin='0,0,5,0'/>
                <Button x:Name='btnCloneTweak' Content='🔁 Klonla' Width='90' Height='30' Background='#007ACC' Foreground='White' Margin='0,0,5,0' ToolTip='Seçili ayarı kopyalayarak yeni bir ayar oluşturur.'/>
                <Button x:Name='btnDelTweak' Content='Sil' Width='70' Height='30' Background='#A00' Foreground='White'/>
            </StackPanel>
        </Grid>
        <Border Grid.Column='2' Background='#222' CornerRadius='5' Padding='15'>
			<ScrollViewer VerticalScrollBarVisibility='Auto' HorizontalScrollBarVisibility='Disabled'>
				<Grid>
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width='*'/>
					</Grid.ColumnDefinitions>
					<StackPanel Grid.Column='0' HorizontalAlignment='Stretch'>
                    <TextBlock Text='AYAR DETAYLARI' Foreground='#4CC2FF' FontWeight='Bold' FontSize='16' Margin='0,0,0,15'/>
                    <Grid Margin='0,0,0,10'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='90'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text='Ad:' Grid.Column='0'/>
                        <TextBox x:Name='txtName' Grid.Column='1'/>
                    </Grid>
                    <Grid Margin='0,0,0,10'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='90'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text='Kategori:' Grid.Column='0'/>
                        <ComboBox x:Name='cbCategory' Grid.Column='1' IsEditable='True'/>
                    </Grid>
                    <Grid Margin='0,0,0,10'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='90'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text='Alt Kat:' Grid.Column='0'/>
                        <TextBox x:Name='txtSubCat' Grid.Column='1'/>
                    </Grid>
                    <Grid Margin='0,0,0,10'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='90'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text='Grup ID:' Grid.Column='0'/>
                        <TextBox x:Name='txtGroup' Grid.Column='1'/>
                    </Grid>
                    
                    <!-- YENİ EKLENEN AÇIKLAMA (TOOLTIP) KUTUSU -->
                    <Grid Margin='0,0,0,10'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='90'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text='Açıklama:' Grid.Column='0' VerticalAlignment='Top' Margin='0,5,0,0' Foreground='#E68A00' FontWeight='Bold'/>
                        <TextBox x:Name='txtTweakDesc' Grid.Column='1' Height='50' TextWrapping='Wrap' AcceptsReturn='True' BorderBrush='#E68A00' ToolTip='Bu metin, ayarın üzerine gelindiğinde ipucu (Tooltip) olarak gösterilir.'/>
                    </Grid>

                    <Grid Margin='0,0,0,10'>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width='90'/>
                            <ColumnDefinition Width='*'/>
                            <ColumnDefinition Width='90'/>
                            <ColumnDefinition Width='*'/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text='Restart:' Grid.Column='0'/>
                        <ComboBox x:Name='cbRestartMode' Grid.Column='1' SelectedIndex='0' ToolTip='Yok = hiçbir şey | Soft = açık Explorer pencereleri yenilenir | Hard = Explorer kill+restart'>
                            <ComboBoxItem Content='Yok'/>
                            <ComboBoxItem Content='Soft (Refresh)'/>
                            <ComboBoxItem Content='Hard (Restart)'/>
                        </ComboBox>
                        <TextBlock Text='Risk:' Grid.Column='2' Margin='10,0,10,0'/>
                        <ComboBox x:Name='cbRiskLevel' Grid.Column='3' SelectedIndex='0' ToolTip='Yüksek riskli ayarlar Apply sırasında ekstra onay ister.'>
                            <ComboBoxItem Content='🟢 Düşük'/>
                            <ComboBoxItem Content='🟡 Orta'/>
                            <ComboBoxItem Content='🔴 Yüksek'/>
                        </ComboBox>
                    </Grid>
                    <StackPanel Orientation='Horizontal' Margin='0,0,0,15'>
                        <TextBlock Text='Tür:' Width='90'/>
                        <RadioButton x:Name='rbReg' Content='Kayıt Defteri' Foreground='White' IsChecked='True' Margin='0,0,10,0'/>
                        <RadioButton x:Name='rbCmd' Content='Komut (CMD/PS)' Foreground='White' Margin='0,0,10,0'/>
                        <RadioButton x:Name='rbBatch' Content='Toplu İşlem (Batch/JSON)' Foreground='White' Margin='0,0,10,0'/>
                        <RadioButton x:Name='rbDns' Content='DNS' Foreground='White'/>
                    </StackPanel>
                    <StackPanel x:Name='pnlRegistry'>
                        <TextBlock Text='Registry Ayarları' Foreground='#4CC2FF' FontWeight='Bold' Margin='0,0,0,10'/>
                        <TextBlock Text='Key:'/>
                        <TextBox x:Name='txtKey' Margin='0,5,0,10'/>
                        <Grid Margin='0,0,0,10'>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width='*'/>
                                <ColumnDefinition Width='100'/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column='0' Margin='0,0,10,0'>
                                <TextBlock Text='ValueName:'/>
                                <TextBox x:Name='txtValueName' Margin='0,5,0,0'/>
                            </StackPanel>
                            <StackPanel Grid.Column='1'>
                                <TextBlock Text='Tipi:'/>
                                <ComboBox x:Name='cbType' Margin='0,5,0,0'>
                                    <ComboBoxItem Content='DWord'/>
                                    <ComboBoxItem Content='String'/>
                                    <ComboBoxItem Content='Binary'/>
                                </ComboBox>
                            </StackPanel>
                        </Grid>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width='*'/>
                                <ColumnDefinition Width='*'/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column='0' Margin='0,0,5,0'>
                                <TextBlock Text='Data:'/>
                                <TextBox x:Name='txtData' Margin='0,5,0,0'/>
                            </StackPanel>
                            <StackPanel Grid.Column='1' Margin='5,0,0,0'>
                                <TextBlock Text='Undo:'/>
                                <TextBox x:Name='txtUndo' Margin='0,5,0,0'/>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                    <StackPanel x:Name='pnlCommand' Visibility='Collapsed'>
                        <TextBlock Text='Komut' Foreground='#E68A00' FontWeight='Bold' Margin='0,0,0,10'/>
                        <TextBlock Text='Command:'/>
                        <TextBox x:Name='txtCommand' Height='60' TextWrapping='Wrap' AcceptsReturn='True' Margin='0,5,0,10'/>
                        <TextBlock Text='Undo:'/>
                        <TextBox x:Name='txtUndoCommand' Height='60' TextWrapping='Wrap' AcceptsReturn='True' Margin='0,5,0,0'/>
                    </StackPanel>
                    <StackPanel x:Name='pnlBatch' Visibility='Collapsed'>
                        <TextBlock Text='Batch Editör' Foreground='#FFCC00' FontWeight='Bold' Margin='0,0,0,5'/>
                        <TextBox x:Name='txtRawInput' Height='150' TextWrapping='Wrap' AcceptsReturn='True' FontFamily='Consolas' FontSize='11' Background='#1E1E1E' BorderBrush='#444' Margin='0,5,0,5'/>
                        <StackPanel Orientation='Horizontal' HorizontalAlignment='Right' Margin='0,0,0,10'>
                            <Button x:Name='btnConvert' Content='JSON Dönüştür' Background='#2D2D30' Foreground='#4CC2FF' Width='140' Height='25'/>
                            <Button x:Name="btnValidate" Content="✔ Yapıyı Kontrol Et" Background="#2D2D30" Foreground="#00AA00" Width="130" Height="25" FontWeight="Bold"/>
                        </StackPanel>
                        <TextBlock Text='Sonuç:' FontSize='11' Foreground='#AAA'/>
                        <TextBox x:Name='txtBatchInput' Height='200' TextWrapping='Wrap' AcceptsReturn='True' FontFamily='Consolas' FontSize='12' VerticalScrollBarVisibility='Auto' Background='#252526'/>
                    </StackPanel>
                    <StackPanel x:Name='pnlDns' Visibility='Collapsed'>
                        <TextBlock Text='DNS' Foreground='#00FF00' FontWeight='Bold' Margin='0,0,0,10'/>
                        <Grid Margin='0,0,0,10'>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width='*'/>
                                <ColumnDefinition Width='10'/>
                                <ColumnDefinition Width='*'/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column='0'>
                                <TextBlock Text='DNS 1:'/>
                                <TextBox x:Name='txtDns1' Margin='0,5,0,0'/>
                            </StackPanel>
                            <StackPanel Grid.Column='2'>
                                <TextBlock Text='DNS 2:'/>
                                <TextBox x:Name='txtDns2' Margin='0,5,0,0'/>
                            </StackPanel>
                        </Grid>
                        <CheckBox x:Name='chkDnsIPv6' Content='IPv6' Foreground='White' Margin='0,10,0,10'/>
                        <Grid x:Name='grdIPv6' IsEnabled='False' Opacity='0.5'>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width='*'/>
                                <ColumnDefinition Width='10'/>
                                <ColumnDefinition Width='*'/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column='0'>
                                <TextBlock Text='IPv6 1:'/>
                                <TextBox x:Name='txtDns6_1' Margin='0,5,0,0'/>
                            </StackPanel>
                            <StackPanel Grid.Column='2'>
                                <TextBlock Text='IPv6 2:'/>
                                <TextBox x:Name='txtDns6_2' Margin='0,5,0,0'/>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                    <!-- ÖNİZLEME PANELİ -->
                    <Border Background='#1A1A1A' BorderBrush='#444' BorderThickness='1' CornerRadius='4' Padding='10' Margin='0,15,0,10'>
                        <StackPanel>
                            <TextBlock Text='📋 ÖNİZLEME (Etkilenecek değerler)' Foreground='#4CC2FF' FontWeight='Bold' Margin='0,0,0,5'/>
                            <TextBox x:Name='txtPreview' IsReadOnly='True' Background='#0F0F0F' Foreground='#0F0' FontFamily='Consolas' FontSize='11' Height='100' TextWrapping='Wrap' VerticalScrollBarVisibility='Auto' BorderThickness='0' Text='Bir ayar seçin veya yeni ayar oluşturun...'/>
                        </StackPanel>
                    </Border>
                    <StackPanel Orientation='Horizontal' HorizontalAlignment='Right' Margin='0,5,0,0'>
                        <Button x:Name='btnPreviewRefresh' Content='🔄 Önizleme Yenile' Width='150' Height='35' Background='#444' Foreground='White' Margin='0,0,10,0'/>
                        <Button x:Name='btnSaveTweak' Content='KAYDET' Width='120' Height='35' Background='#007ACC' FontWeight='Bold' Foreground='White'/>
                    </StackPanel>
                </StackPanel>
			 </Grid>
            </ScrollViewer>
        </Border>
    </Grid>
</Window>
"@
$xamlPrivacyWarn = @"

<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Bilgilendirme' SizeToContent='Height' Width='450' MaxHeight='600' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow' ResizeMode='NoResize'>
    <Grid Margin='20'>
        <Grid.RowDefinitions>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>
        <ScrollViewer Grid.Row='0' VerticalScrollBarVisibility='Auto' Margin='0,0,0,10'>
            <StackPanel>
                <TextBlock Text='⚠️ Uygulama İzinleri' Foreground='#FFCC00' FontSize='16' FontWeight='Bold' Margin='0,0,0,15' HorizontalAlignment='Center'/>
                <TextBlock Text='Manuel müdahaleler (Ayarlar menüsünden kapatmak) programın yetkisini kısıtlayabilir. Bu program üzerinden yaptığınız değişiklikleri yine bu programla geri alabilirsiniz.' Foreground='White' TextWrapping='Wrap'/>
            </StackPanel>
        </ScrollViewer>
        <CheckBox x:Name='chkDontShowAgain' Grid.Row='1' Content='Bir daha gösterme' Foreground='White' Margin='0,5,0,15'/>
        <Button x:Name='btnOk' Grid.Row='2' Content='TAMAM' Background='#007ACC' Foreground='White' FontWeight='Bold' Height='35'/>
    </Grid>
</Window>
"@
$xamlBlacklist = @"

<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Yoksayılanlar' Height='400' Width='400' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow'>
    <Grid Margin='15'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>
        <TextBlock Text='Bu uygulamalar taranmaz:' Foreground='#AAA' Margin='0,0,0,10'/>
        <ListBox x:Name='lstBlacklist' Grid.Row='1' Background='#222' BorderThickness='0' Foreground='White' Margin='0,0,0,10' SelectionMode='Extended'/>
        <StackPanel Grid.Row='2' Orientation='Horizontal' HorizontalAlignment='Right'>
            <Button x:Name='btnRestore' Content='Çıkar' Background='#007ACC' Foreground='White' Width='80' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnClose' Content='Kapat' Background='#333' Foreground='White' Width='80' Height='30'/>
        </StackPanel>
    </Grid>
</Window>
"@
$xamlCustomMgr = @"

<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Özel Temizlik' Height='450' Width='600' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow'>
    <Grid Margin='15'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>
        <TextBlock Text='Özel Klasörler:' Foreground='#4CC2FF' FontWeight='Bold' Margin='0,0,0,10'/>
        <ListBox x:Name='lstCustomRules' Grid.Row='1' Background='#222' BorderThickness='1' BorderBrush='#444' Foreground='White' Margin='0,0,0,10' SelectionMode='Extended'/>
        <StackPanel Grid.Row='2' Orientation='Horizontal' HorizontalAlignment='Right'>
            <Button x:Name='btnEditCustom' Content='Düzenle' Background='#333' Foreground='White' Width='80' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnAddCustom' Content='Ekle' Background='#006600' Foreground='White' Width='80' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnDeleteCustom' Content='Sil' Background='#A00' Foreground='White' Width='80' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnCloseCustom' Content='Kapat' Background='#333' Foreground='White' Width='80' Height='30'/>
        </StackPanel>
    </Grid>
</Window>
"@
$xamlAddCustom = @"

<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Klasör Ekle/Düzenle' Height='330' Width='500' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow' ResizeMode='NoResize'>
    <Grid Margin='20'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
        </Grid.RowDefinitions>
        <TextBlock Text='Yol:' Foreground='White' Margin='0,0,0,5'/>
        <Grid Grid.Row='1' Margin='0,0,0,15'>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width='*'/>
                <ColumnDefinition Width='Auto'/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name='txtCustomPath' Height='28'/>
            <Button x:Name='btnBrowse' Grid.Column='1' Content='...' Width='35' Height='28' Margin='5,0,0,0' Background='#444' Foreground='White'/>
        </Grid>
        <TextBlock Grid.Row='2' Text='Filtre (*.*):' Foreground='White' Margin='0,0,0,5'/>
        <TextBox Grid.Row='3' x:Name='txtFilter' Text='*.*' Height='28' Margin='0,0,0,15'/>
        <StackPanel Grid.Row='4'>
            <CheckBox x:Name='chkRecurse' Content='Alt Klasörleri Dahil Et' Foreground='White' IsChecked='True' Margin='0,0,0,10'/>
            <CheckBox x:Name='chkDeleteFolder' Content='Klasörü de Sil' Foreground='#FF5555' IsChecked='False' Margin='0,0,0,20'/>
            <StackPanel Orientation='Horizontal' HorizontalAlignment='Right'>
                <Button x:Name='btnAdd' Content='Kaydet' Background='#006600' Foreground='White' Width='100' Height='30'/>
                <Button x:Name='btnCancel' Content='İptal' Background='#333' Foreground='White' Width='80' Height='30' Margin='10,0,0,0'/>
            </StackPanel>
        </StackPanel>
    </Grid>
</Window>
"@
$xamlPathEdit = @"

<Window
    xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Yolları Düzenle' Height='450' Width='600' Background='#181818' WindowStartupLocation='CenterScreen' WindowStyle='ToolWindow'>
    <Grid Margin='15'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row='0' Margin='0,0,0,10'>
            <TextBlock x:Name='lblAppName' Text='Uygulama' Foreground='#4CC2FF' FontSize='16' FontWeight='Bold'/>
            <TextBlock Text='Her satıra bir kural girin.' Foreground='#888' FontSize='12'/>
        </StackPanel>
        <TextBox x:Name='txtRules' Grid.Row='1' AcceptsReturn='True' VerticalScrollBarVisibility='Auto' Background='#222' Foreground='#EEE' FontFamily='Consolas' Padding='5'/>
        <StackPanel Grid.Row='2' Orientation='Horizontal' HorizontalAlignment='Right' Margin='0,15,0,0'>
            <Button x:Name='btnResetRules' Content='Sıfırla' Background='#A00' Foreground='White' Width='80' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnSaveRules' Content='Kaydet' Background='#007ACC' Foreground='White' Width='100' Height='30' Margin='0,0,10,0'/>
            <Button x:Name='btnCloseEdit' Content='İptal' Background='#333' Foreground='White' Width='80' Height='30'/>
        </StackPanel>
    </Grid>
</Window>
"@

# #endregion 5 -- XAML TANIMLARI (Ana pencere + Alt pencereler)


# =========================================================================
# #region 6 -- XAML YUKLEME & FINDNAME BAGLAMALARI
# =========================================================================

# --- XAML LOAD ---
try {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $Win = [Windows.Markup.XamlReader]::Load($reader)
} catch { Write-Error "XAML hatası: $($_.Exception.Message)"; exit 1 }


# --- 4. KONTROL TANIMLAMALARI ---
$tabControl = $Win.FindName('tabControl'); $txtSearch = $Win.FindName('txtSearch')
$btnApplyTweaks = $Win.FindName('btnApplyTweaks')
$btnProfile = $Win.FindName('btnProfile')
$btnSettings = $Win.FindName('btnSettings')
$btnNightMode = $Win.FindName('btnNightMode')
$btnOpenData = $Win.FindName('btnOpenData')
$btnCopyLog = $Win.FindName('btnCopyLog')
$btnClearLog = $Win.FindName('btnClearLog')
$btnManageTweaks = $Win.FindName('btnManageTweaks')
$btnCheckTweaks = $Win.FindName('btnCheckTweaks')
$btnManageWinget = $Win.FindName('btnManageWinget')
$btnTools = $Win.FindName('btnTools')
$ctxToolsMenu = $Win.FindName('ctxToolsMenu')
$btnBloatware = $Win.FindName('btnBloatware')



# =============================================================
# BÖLÜM 3 — WIRE-UP
# $Win.FindName() bloklarının yanına ekle
# =============================================================


$btnSaveProfile = $Win.FindName('btnSaveProfile')
if ($btnProfile)     { $btnProfile.Add_Click({ Show-RecommendedProfiles }) }
if ($btnSaveProfile) { $btnSaveProfile.Add_Click({ Show-ProfileManager }) }

# --- BÜYÜK DOSYA AVCISI KONTROLLERİ ---
$lvLargeFiles = $Win.FindName('lvLargeFiles')
$cbScanTarget = $Win.FindName('cbScanTarget')
$cbMinSize = $Win.FindName('cbMinSize')
$btnScanFiles = $Win.FindName('btnScanFiles')
$txtLargeStatus = $Win.FindName('txtLargeStatus')
$pbLargeScan = $Win.FindName('pbLargeScan')

# --- ÇÖKME ANALİZİ (DEDEKTİF) KONTROLLERİ ---
$tabCrash = $Win.FindName('tabCrash')
$shpBlackBoxStatus = $Win.FindName('shpBlackBoxStatus')
$txtBlackBoxStatus = $Win.FindName('txtBlackBoxStatus')
$btnFixBlackBox = $Win.FindName('btnFixBlackBox')
$cbCrashTime = $Win.FindName('cbCrashTime')
$btnScanCrashes = $Win.FindName('btnScanCrashes')
$lvCrashes = $Win.FindName('lvCrashes')
$cbWatchProcess = $Win.FindName('cbWatchProcess')
$cbWatchProcess2 = $Win.FindName('cbWatchProcess2')
$txtWatchCustom = $Win.FindName('txtWatchCustom')
$txtWatchStatus = $Win.FindName('txtWatchStatus')
$btnWatchStart = $Win.FindName('btnWatchStart')
$btnWatchStop = $Win.FindName('btnWatchStop')

# Dedektif Sağ Tık Menüsü
$ctxCopyCrash = $Win.FindName('ctxCopyCrash')
$ctxSearchCrash = $Win.FindName('ctxSearchCrash')
$ctxOpenDump = $Win.FindName('ctxOpenDump')

# Sağ Tık Menüsü
$ctxOpenLargeFile = $Win.FindName('ctxOpenLargeFile')
$ctxCopyLargePath = $Win.FindName('ctxCopyLargePath')
$ctxDeleteLargeFile = $Win.FindName('ctxDeleteLargeFile')

# --- KONTROL PANELİ (DASHBOARD) KONTROLLERİ ---
$tabDashboard = $Win.FindName('tabDashboard')
$txtDashSubHeader = $Win.FindName('txtDashSubHeader')
$txtDashOS = $Win.FindName('txtDashOS')
$txtDashCPU = $Win.FindName('txtDashCPU')
$txtDashRAM = $Win.FindName('txtDashRAM')
$pbDashRAM = $Win.FindName('pbDashRAM')
$txtDashGPU = $Win.FindName('txtDashGPU')
$txtDashDisk = $Win.FindName('txtDashDisk')
$pbDashDisk = $Win.FindName('pbDashDisk')

# --- BAŞLANGIÇ YÖNETİCİSİ KONTROLLERİ ---
$lvStartup = $Win.FindName('lvStartup')
$btnRefreshStartup = $Win.FindName('btnRefreshStartup')
$rbStartupWin = $Win.FindName('rbStartupWin')
$rbStartupTask = $Win.FindName('rbStartupTask')

# Sağ tık menüsü
$resStartupMenu = $Win.Resources["StartupItemMenu"]
$ctxToggleStartup = $resStartupMenu.Items | Where-Object { $_.Name -eq "ctxToggleStartup" }
$ctxOpenStartupLoc = $resStartupMenu.Items | Where-Object { $_.Name -eq "ctxOpenStartupLoc" }
$ctxCopyStartupPath = $resStartupMenu.Items | Where-Object { $_.Name -eq "ctxCopyStartupPath" } # YENİ EKLENDİ
$ctxOpenStartupReg = $resStartupMenu.Items | Where-Object { $_.Name -eq "ctxOpenStartupReg" }
$ctxDeleteStartup = $resStartupMenu.Items | Where-Object { $_.Name -eq "ctxDeleteStartup" }

$tvTweaks = $Win.FindName('tvTweaks')
$tvBrowser = $Win.FindName('tvBrowser'); $tvSystem = $Win.FindName('tvSystem')
$tvRepair = $Win.FindName('tvRepair'); $tvApps = $Win.FindName('tvApps')
$btnFixUpdate = $Win.FindName('btnFixUpdate')
$btnResetNet = $Win.FindName('btnResetNet')
$btnSfcScan = $Win.FindName('btnSfcScan')
$tvShellBags = $Win.FindName('tvShellBags'); $tvWinget = $Win.FindName('tvWinget')

$btnInstallWinget = $Win.FindName('btnInstallWinget')
$btnRefreshWinget = $Win.FindName('btnRefreshWinget')
$btnUninstallWinget = $Win.FindName('btnUninstallWinget')
$btnWinget = $Win.FindName('btnWinget')
$btnWingetUpdateAll = $Win.FindName('btnWingetUpdateAll')

$btnSelectAll = $Win.FindName('btnSelectAll')
$btnSelectTab = $Win.FindName('btnSelectTab')
$btnUnselectAll = $Win.FindName('btnUnselectAll')

$btnAnalyze = $Win.FindName('btnAnalyze')
$btnCleanRAM = $Win.FindName('btnCleanRAM')
$btnRun = $Win.FindName('btnRun')
$btnRefreshApp = $Win.FindName('btnRefreshApp')
$btnManageBlacklist = $Win.FindName('btnManageBlacklist')
$btnManageCustom = $Win.FindName('btnManageCustom')

$pbMain = $Win.FindName('pbMain')
$lblStatus = $Win.FindName('lblStatus')
$lblDetail = $Win.FindName('lblDetail')
$txtWinappStatus = $Win.FindName('txtWinappStatus')
$txtLog = $Win.FindName('txtLog')
$chkDebug = $Win.FindName('chkDebug')
$cbSecureDelete = $Win.FindName('cbSecureDelete')
$txtCbsPath = $Win.FindName('txtCbsPath')

# Sağ Tık Menülerini Resource'dan Bul
$resTweakMenu = $Win.Resources["TweakItemMenu"]
$ctxEditTweak = $resTweakMenu.Items | Where-Object { $_.Name -eq "ctxEditTweak" }
$ctxOpenReg   = $resTweakMenu.Items | Where-Object { $_.Name -eq "ctxOpenReg" }
$ctxDelTweak  = $resTweakMenu.Items | Where-Object { $_.Name -eq "ctxDeleteTweak" }

# --- 1. MENÜ ÖĞESİNİ OLUŞTUR ---
# Mevcut kaynaklardaki 'ItemMenu' içine dinamik olarak ekliyoruz
$resItemMenu = $Win.Resources["ItemMenu"]
# Eğer daha önce eklemediysek ekle
if (-not ($resItemMenu.Items | Where-Object Name -eq "ctxForceClean")) {
    $sep = New-Object System.Windows.Controls.Separator
    $resItemMenu.Items.Add($sep) | Out-Null
    
    $itmForce = New-Object System.Windows.Controls.MenuItem
    $itmForce.Name = "ctxForceClean"
    $itmForce.Header = "⚠ Bu Uygulamanın Verilerini KÖKTEN SİL"
    $itmForce.Foreground = [System.Windows.Media.Brushes]::Red
    $itmForce.FontWeight = "Bold"
    $resItemMenu.Items.Add($itmForce) | Out-Null
}

# Değişkeni tanımla
$ctxForceClean = $resItemMenu.Items | Where-Object { $_.Name -eq "ctxForceClean" }
$ctxOpenLocation = $resItemMenu.Items | Where-Object { $_.Name -eq "ctxOpenLocation" }
$ctxEditPaths    = $resItemMenu.Items | Where-Object { $_.Name -eq "ctxEditPaths" }
$ctxIgnoreApp    = $resItemMenu.Items | Where-Object { $_.Name -eq "ctxIgnoreApp" }

$resCustomMenu = $Win.Resources["CustomItemMenu"]
$ctxDeleteCustomRule = $resCustomMenu.Items | Where-Object { $_.Name -eq "ctxDeleteCustomRule" }
# --- LOGO VE İKON YÜKLEME (DİNAMİK YOL) ---
$Logo = $Win.FindName('Logo')

# Scriptin bulunduğu klasörü al
$ScriptDir = $PSScriptRoot 

# Yolları tanımla (Script ile aynı klasörde arar)
# NOT: Dosya isimlerini (mrclean.png / icon.ico) kendi dosyalarına göre düzenle.
$ResimDosyasi = "$ScriptDir\mrclean.png" 
$IkonDosyasi  = "$ScriptDir\mrclean.ico" 

# 1. İçerideki Büyük Resim (Logo)
if (Test-Path $ResimDosyasi) { 
    try { 
        $bmpLogo = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmpLogo.BeginInit()
        $bmpLogo.UriSource = (New-Object System.Uri($ResimDosyasi))
        $bmpLogo.EndInit()
        $Logo.Source = $bmpLogo
    } catch {} 
}

# 2. Pencere İkonu (Sol Üst ve Görev Çubuğu)
if (Test-Path $IkonDosyasi) {
    try {
        $bmpIcon = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmpIcon.BeginInit()
        $bmpIcon.UriSource = (New-Object System.Uri($IkonDosyasi))
        $bmpIcon.EndInit()
        
        $Win.Icon = $bmpIcon 
    } catch {}
}

# --- TEMEL FONKSİYONLAR (PERFORMANS ODAKLI) ---

# Saniyede binlerce kez UI tetiklenmesini engellemek için zamanlayıcı (Throttle)
$global:DoEventsTimer = [System.Diagnostics.Stopwatch]::StartNew()

# #endregion 6 -- XAML YUKLEME & FINDNAME BAGLAMALARI



# =========================================================================
# #region 7 -- CEKIRDEK HELPERLAR (Do-Events, WpfLog, Format-Size)
# =========================================================================

function Do-Events { 
    # UI sadece 20 milisaniyede bir yenilenir (Akıcı görünüm sağlar, CPU'yu yormaz)
    if ($global:DoEventsTimer.ElapsedMilliseconds -gt 20) {
        try {[System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                [System.Action]{}, 
                [System.Windows.Threading.DispatcherPriority]::Background
            ) 
        } catch {} 
        $global:DoEventsTimer.Restart()
    }
}

function WpfLog([string]$text) { 
    if (-not $text) { return }
    
    # UI henüz yüklenmediyse (pencere açılmadan log gelirse) hata vermesin
    if ($null -eq $txtLog -or $null -eq $Win) { return }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $msg = "[$timestamp] $text"
    
    try {
        $Win.Dispatcher.Invoke([Action]{ 
            # --- PERFORMANS KORUMASI: SATIR SAYISI BAZLI LOG BUDAMA ---
            $currentLines = $txtLog.LineCount
            if ($currentLines -gt 500) {
                $allText = $txtLog.Text
                $lines = $allText -split "`r`n"
                $kept = $lines | Select-Object -Last 200
                $txtLog.Text = "... [Bellek tasarrufu — eski kayıtlar temizlendi] ...`r`n" + ($kept -join "`r`n") + "`r`n"
            }
            $txtLog.AppendText("$msg`r`n")
            $txtLog.ScrollToEnd() 
        })
    } catch {
        # Dispatcher erişim hatası (kapatma esnasında olabilir) - sessizce yoksay
    }
}

function Format-Size($bytes) { 
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) } 
    elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) } 
    else { return "{0:N2} KB" -f ($bytes / 1KB) } 
}

# --- AYAR FONKSİYONLARI ---

# #endregion 7 -- CEKIRDEK HELPERLAR (Do-Events, WpfLog, Format-Size)


# =========================================================================
# #region 8 -- AYAR YONETIMI (Config Save/Load/Restore)
# =========================================================================

function Save-App-State {
    # --- CACHE KONTROLÜ (EKLENDİ) ---
    if ($global:IsCacheDisabled) { return }
    
    Mark-ConfigDirty
    $state = @{ 
        "SecureDelete" = $cbSecureDelete.SelectedIndex
        "CheckedItems" = @()
    }
    foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvShellBags)) { 
        foreach ($item in $tree.Items) {
            $chk = Get-CheckFromItem $item
            if ($chk.Content -notmatch "Kullanıcı Tanımlı") {
                if ($chk.IsChecked) { $state["CheckedItems"] += $chk.Content.ToString() }
            }
            foreach ($sub in $item.Items) {
                $subChk = Get-CheckFromItem $sub
                if ($subChk.IsChecked) { $state["CheckedItems"] += $subChk.Content.ToString() }
            }
        }
    }
    $state | ConvertTo-Json -Depth 5 | Set-Content $AppStatePath -Encoding UTF8
}

function Show-ConfigRecoveryDialog {
    param([string]$ErrorMsg)
    # Bozuk config tespit edildiginde kullaniciya secenek sun.
    # Donus: parse edilmis JSON objesi veya $null (varsayilan kullan)

    # PowerShell'in ConvertFrom-Json hata mesaji bazen tum dosya icerigini ekler
    # — kisalt ki MessageBox render edebilsin ve log'a dump etmesin.
    if ($ErrorMsg.Length -gt 250) {
        $ErrorMsg = $ErrorMsg.Substring(0, 250).Trim() + " ... [kesildi]"
    }

    $bakList = @()
    for ($i = 1; $i -le 5; $i++) {
        $bp = "$UserConfigPath.bak$i"
        if (Test-Path $bp) { $bakList += $bp }
    }
    $bakInfo = if ($bakList.Count -gt 0) {
        "$($bakList.Count) yedek bulundu (en yenisi: $(Split-Path -Leaf $bakList[0]))"
    } else { "Yedek bulunamadi" }

    $msg = "Config dosyasi okunamadi:`n  $ErrorMsg`n`n" +
           "$bakInfo`n`n" +
           "Ne yapilsin?`n" +
           "  EVET  → Yedekten geri yukle (en yenisi)`n" +
           "  HAYIR → Varsayilan ayarlarla devam et`n" +
           "  IPTAL → Programi kapat"
    $btn = if ($bakList.Count -gt 0) {
        [System.Windows.MessageBoxButton]::YesNoCancel
    } else {
        [System.Windows.MessageBoxButton]::OKCancel
    }
    # MessageBox'i ana pencere onunde + topmost garanti et (arkaya dusmesin)
    if ($Win) {
        try { $Win.Activate() | Out-Null } catch {}
        try { $Win.Topmost = $true } catch {}
    }
    $res = if ($Win) {
        [System.Windows.MessageBox]::Show($Win, $msg, "Config Kurtarma", $btn, [System.Windows.MessageBoxImage]::Warning)
    } else {
        [System.Windows.MessageBox]::Show($msg, "Config Kurtarma", $btn, [System.Windows.MessageBoxImage]::Warning)
    }
    if ($Win) { try { $Win.Topmost = $false } catch {} }

    if ($res -eq 'Cancel') {
        WpfLog "[CONFIG] Kullanici programi kapatti."
        $Win.Close()
        return $null
    }
    if ($res -eq 'Yes' -and $bakList.Count -gt 0) {
        # En yeni yedegi yukle
        try {
            $bakRaw = Get-Content $bakList[0] -Raw -ErrorAction Stop
            $bakJson = $bakRaw | ConvertFrom-Json -ErrorAction Stop
            WpfLog "[CONFIG] Yedekten geri yuklendi: $(Split-Path -Leaf $bakList[0])"
            return $bakJson
        } catch {
            WpfLog "[HATA] Yedek de bozuk: $($_.Exception.Message). Varsayilan kullanilacak."
            return $null
        }
    }
    # No / OK → varsayilan
    WpfLog "[CONFIG] Varsayilan ayarlarla devam ediliyor."
    return $null
}

function Load-All-Settings {
    # EĞER CACHE DEVRE DIŞI İSE HİÇBİR ŞEY YÜKLEME (Developer Mode)
    if ($global:IsCacheDisabled) {
        $global:WingetApps = Get-Default-WingetApps
        $global:TweakList = Get-Default-Tweaks
        WpfLog "[DEV] Önbellek ve Config dosyaları devre dışı (Developer Mode)."
        return
    }

    $wingetFromConfig = $null
    $tweaksFromConfig = $null

    if (Test-Path $UserConfigPath) {
        $json = $null
        $loadError = $null
        try {
            $raw = Get-Content $UserConfigPath -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($raw)) { throw "Bos config dosyasi" }
            $json = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            # PS ConvertFrom-Json hata mesaji bazen DOSYA ICERIGINI EKLER (devasa string).
            # WpfLog ekranini dump etmesini onlemek icin sadece ilk satira indirgeyelim.
            $loadError = $_.Exception.Message
            $shortErr  = ($loadError -split "`n")[0]
            if ($shortErr.Length -gt 200) { $shortErr = $shortErr.Substring(0, 200) + "..." }
            WpfLog "[UYARI] Config bozuk: $shortErr"
            $json = Show-ConfigRecoveryDialog -ErrorMsg $shortErr
        }

        if ($null -ne $json) {
            # Schema migration (ileride v2 → v3 vb. icin)
            $schemaVer = if ($json._schema) { [int]$json._schema } else { 1 }
            if ($schemaVer -lt 2) {
                WpfLog "[CONFIG] Eski schema (v$schemaVer) tespit edildi, v2 olarak yeniden kaydedilecek."
                # Suanki migration: sadece eksik alanlar yeni default ile, save'de yeni schema yazilir.
            }
        }

        if ($null -ne $json) {
        try {
            if ($json.Blacklist)     { $global:Blacklist = $json.Blacklist }
            if ($json.MyProfile) { $global:MyProfile = $json.MyProfile }
            if ($json.PSObject.Properties.Match("ShowPrivacyWarning").Count) {
                $global:ShowPrivacyWarning = $json.ShowPrivacyWarning
            }
            if ($json.RestorePointMode -and ($json.RestorePointMode -in @("Ask","Auto","Never"))) {
                $global:RestorePointMode = $json.RestorePointMode
            }
            if ($json.AppLayout) { $global:AppLayout = $json.AppLayout }
            if ($json.PathOverrides) { 
                $global:PathOverrides = @{}
                $json.PathOverrides.PSObject.Properties | ForEach-Object { $global:PathOverrides[$_.Name] = $_.Value }
            }
            if ($json.CustomRules)   { $global:CustomRules = @($json.CustomRules) }
            if ($json.CustomTools) { $global:CustomTools = @($json.CustomTools) }
            if ($json.ToolDownloadPath) { $global:ToolDownloadPath = $json.ToolDownloadPath }

            # ItemDescriptions: JSON'dan PSCustomObject olarak gelir, hashtable'a cevir
            # (BUG FIX: eskiden hic yuklenmiyordu, her acilista bos basliyordu)
            if ($json.ItemDescriptions) {
                $global:ItemDescriptions = @{}
                foreach ($p in $json.ItemDescriptions.PSObject.Properties) {
                    $global:ItemDescriptions[$p.Name] = "$($p.Value)"
                }
            }
            
            # Winget verisini al
            if ($json.WingetApps) { 
                $wingetFromConfig = [ordered]@{}
                $json.WingetApps.PSObject.Properties | ForEach-Object { $wingetFromConfig[$_.Name] = $_.Value }
            }
            if ($json.CustomAppx) { 
                $global:CustomAppx = [ordered]@{}
                $json.CustomAppx.PSObject.Properties | ForEach-Object { $global:CustomAppx[$_.Name] = $_.Value }
            }
            # Tweak verisini al
            if ($json.Tweaks) {
                $tweaksFromConfig = [ordered]@{}
                foreach ($prop in $json.Tweaks.PSObject.Properties) { $tweaksFromConfig[$prop.Name] = $prop.Value }
            }
        } catch {
            WpfLog "[UYARI] Config yuklenirken kismi hata: $($_.Exception.Message)"
        }
        }  # closes "if ($null -ne $json)"
    }      # closes "if (Test-Path $UserConfigPath)"

    # --- 1. WINGET AKILLI BİRLEŞTİRME ---
    $defaultWinget = Get-Default-WingetApps
    if ($wingetFromConfig) {
        $global:WingetApps = $wingetFromConfig
        foreach ($appName in $defaultWinget.Keys) {
            if (-not $global:WingetApps.Contains($appName)) {
                $global:WingetApps[$appName] = $defaultWinget[$appName]
            }
        }
    } else { 
        $global:WingetApps = $defaultWinget 
    }

    # --- 2. TWEAKS AKILLI TEMİZLİK VE BİRLEŞTİRME (DUPLICATE FIX) ---
    $defaults = Get-Default-Tweaks
    $global:TweakList = [ordered]@{}

    if ($tweaksFromConfig) {
        # Config dosyasındaki kategorileri tarıyoruz
        foreach ($catName in $tweaksFromConfig.Keys) {
            # EĞER BU KATEGORİ ORİJİNAL KODDA VARSA (Örn: Bufferbloat, Gizlilik vb.)
            if ($defaults.Contains($catName)) {
                # Config dosyasındaki eski listeyi GÖRMEZDEN GEL ve Koddaki güncel listeyi kullan.
                # Bu sayede isim değişiklikleri (Rename) anında yansır, eskiler silinir.
                $global:TweakList[$catName] = $defaults[$catName]
            } 
            else {
                # Eğer kodda olmayan (Kullanıcının kendi oluşturduğu) bir kategoriyse, onu olduğu gibi al.
                $global:TweakList[$catName] = $tweaksFromConfig[$catName]
            }
        }
        
        # Kodda olup Config'de hiç olmayan yeni kategorileri de ekle
        foreach ($catName in $defaults.Keys) {
            if (-not $global:TweakList.Contains($catName)) {
                $global:TweakList[$catName] = $defaults[$catName]
            }
        }
    } else { 
        $global:TweakList = $defaults 
    }

    # --- 3. CHECKBOX DURUMLARINI YÜKLE ---
    if (Test-Path $AppStatePath) {
        try {
            $jsonState = Get-Content $AppStatePath -Raw | ConvertFrom-Json
            if ($jsonState.SecureDelete -ne $null) { $cbSecureDelete.SelectedIndex = $jsonState.SecureDelete }
            if ($jsonState.CustomChecks -and $global:CustomRules) {
                for ($i=0; $i -lt $global:CustomRules.Count; $i++) {
                    $name = $global:CustomRules[$i].Name
                    if ($jsonState.CustomChecks.$name -eq $true) { $global:CustomRules[$i].IsChecked = $true }
                }
            }
            $checkedList = $jsonState.CheckedItems
            if ($checkedList) {
                foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvShellBags)) {
                    foreach ($item in $tree.Items) {
                        $chk = Get-CheckFromItem $item
                        if ($chk.Content -notmatch "Kullanıcı Tanımlı") {
                            if ($checkedList -contains $chk.Content.ToString()) { $chk.IsChecked = $true; Sync-Children $item $true }
                        }
                        foreach ($sub in $item.Items) {
                            $subChk = Get-CheckFromItem $sub
                            if ($checkedList -contains $subChk.Content.ToString()) { $subChk.IsChecked = $true }
                        }
                    }
                }
            }
        } catch { }
    }
}

$global:ItemDescriptions = @{} # Açıklamaları tutacak global sözlük

function Save-User-Config {
    if ($global:IsCacheDisabled) { return }
    # Dirty flag: Gerçek bir değişiklik olmadıkça dosyaya yazma (disk I/O tasarrufu)
    if (-not $global:ConfigDirty) { return }

    if ($tvSystem.Items.Count -gt 0) {
        foreach ($item in $tvSystem.Items) {
            if ((Get-CheckFromItem $item).Content -match "Kullanıcı Tanımlı") {
                foreach ($sub in $item.Items) {
                    $uiName = (Get-CheckFromItem $sub).Content.ToString()
                    $uiState = (Get-CheckFromItem $sub).IsChecked
                    for ($i=0; $i -lt $global:CustomRules.Count; $i++) { if ($global:CustomRules[$i].Name -eq $uiName) { $global:CustomRules[$i].IsChecked = $uiState } }
                }
            }
        }
    }

    # Schema versiyon: ileride migration icin sabit alan
    $config = [ordered]@{
        "_schema"            = 2
        "_savedAt"           = (Get-Date).ToString("o")
        "Blacklist"          = $global:Blacklist
        "PathOverrides"      = $global:PathOverrides
        "CustomRules"        = $global:CustomRules
        "WingetApps"         = $global:WingetApps
        "Tweaks"             = $global:TweakList
        "CustomAppx"         = $global:CustomAppx
        "CustomTools"        = $global:CustomTools
        "ToolDownloadPath"   = $global:ToolDownloadPath
        "MyProfile"          = $global:MyProfile
        "ShowPrivacyWarning" = $global:ShowPrivacyWarning
        "RestorePointMode"   = $global:RestorePointMode
        "AppLayout"          = $global:AppLayout
        "ItemDescriptions"   = $global:ItemDescriptions
    }

    # ATOMIC WRITE + AUTO-BACKUP
    # 1) JSON'u bellekte uret
    # 1b) HASH CHECK: Yeni icerik mevcut config ile ozdes mi? (sadece _savedAt timestamp farkli olabilir)
    # 2) .tmp'ye yaz
    # 3) JSON parse et — bozuksa abort
    # 4) Eski yedekleri kaydir: bak4→bak5, bak3→bak4, ..., config→bak1
    # 5) .tmp → config.json (atomic rename)
    try {
        $json = $config | ConvertTo-Json -Depth 10
        $tmpPath = "$UserConfigPath.tmp"

        # 1b) HASH CHECK — gercek icerik ayni ise (sadece timestamp farkli) yazma!
        # Bu sayede Mark-ConfigDirty cagrildiginda gercek bir degisiklik yoksa diske yazmaz,
        # 5 seviyeli backup rotation gereksiz yere tetiklenmez (~190 KB x 5 file ops/save tasarrufu).
        if (Test-Path $UserConfigPath) {
            try {
                $oldContent = Get-Content $UserConfigPath -Raw -ErrorAction Stop
                # _savedAt'i normalize et — her save'de degisir, content compare icin disla
                $stripPattern = '"_savedAt":\s*"[^"]*"'
                $oldNorm = ($oldContent -replace $stripPattern, '"_savedAt":"X"').Trim()
                $newNorm = ($json        -replace $stripPattern, '"_savedAt":"X"').Trim()
                if ($oldNorm -eq $newNorm) {
                    # Gercek degisiklik yok — flag'i temizle, yazma
                    $global:ConfigDirty = $false
                    return
                }
            } catch {
                # Eski dosya bozuksa devam et, yine de yazalim
            }
        }

        # 1+2) Tmp dosyaya yaz
        Set-Content -Path $tmpPath -Value $json -Encoding UTF8 -ErrorAction Stop

        # 3) Yazilani dogrula (parse OK?)
        try {
            $verify = Get-Content $tmpPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if (-not $verify) { throw "Bos JSON" }
        } catch {
            Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
            throw "Yazilan config dogrulanamadi: $($_.Exception.Message)"
        }

        # 4) Yedekleri kaydir (bak4→bak5, ..., bak1→bak2, config→bak1)
        if (Test-Path $UserConfigPath) {
            for ($i = 4; $i -ge 1; $i--) {
                $src = "$UserConfigPath.bak$i"
                $dst = "$UserConfigPath.bak$($i+1)"
                if (Test-Path $src) { Move-Item -Path $src -Destination $dst -Force -ErrorAction SilentlyContinue }
            }
            Move-Item -Path $UserConfigPath -Destination "$UserConfigPath.bak1" -Force -ErrorAction SilentlyContinue
        }

        # 5) .tmp → config.json (atomic move)
        Move-Item -Path $tmpPath -Destination $UserConfigPath -Force -ErrorAction Stop

        $global:ConfigDirty = $false
    } catch {
        # Beklenmedik hata — log'la ama crash etme
        WpfLog "[HATA] Config kaydetme: $($_.Exception.Message)"
    }
}

# Yardımcı: Config'i kirli olarak işaretle ve kaydet
function Mark-ConfigDirty {
    $global:ConfigDirty = $true
    Save-User-Config
}

function Restore-Checkboxes {
    if (-not (Test-Path $AppStatePath)) { return }
    try {
        $json = Get-Content $AppStatePath -Raw | ConvertFrom-Json
        if ($json.SecureDelete -ne $null) { $cbSecureDelete.SelectedIndex = $json.SecureDelete }
        $checkedList = $json.CheckedItems
        if (-not $checkedList) { return }
        foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvShellBags)) {
            foreach ($item in $tree.Items) {
                $chk = Get-CheckFromItem $item
                if ($chk.Content -match "Kullanıcı Tanımlı") { continue }
                if ($checkedList -contains $chk.Content.ToString()) { $chk.IsChecked = $true; Sync-Children $item $true }
                foreach ($sub in $item.Items) {
                    $subChk = Get-CheckFromItem $sub
                    if ($checkedList -contains $subChk.Content.ToString()) { $subChk.IsChecked = $true }
                }
            }
        }
    } catch {}
}

# #endregion 8 -- AYAR YONETIMI (Config Save/Load/Restore)



# =========================================================================
# #region 9 -- TWEAK SISTEMI (IsActive, Apply, Check, Manager)
# =========================================================================

# =========================================================
# GPU VENDOR DETECTION (Vendor-aware tweak'ler icin)
# =========================================================
# Sistemin GPU vendor listesini dondurur: @("NVIDIA"), @("AMD"), @("Intel","NVIDIA"), vb.
# Lazy: ilk cagrida WMI sorgular, sonra cache'lenir ($global:DetectedGpuVendors).
# Apply-System-Tweaks icindeki vendor uyumsuzluk uyarisi bu helper'i kullanir.
function Get-System-Gpu-Vendors {
    if ($null -ne $global:DetectedGpuVendors) { return $global:DetectedGpuVendors }

    $vendors = New-Object System.Collections.Generic.HashSet[string]
    try {
        $cards = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($c in $cards) {
            $name = "$($c.Name)"
            if     ($name -match "NVIDIA|GeForce|RTX|GTX|Quadro|Tesla")     { [void]$vendors.Add("NVIDIA") }
            elseif ($name -match "Radeon|AMD\s|Vega|FirePro")               { [void]$vendors.Add("AMD")    }
            elseif ($name -match "Intel|Arc|Iris|UHD\s+Graphics|HD\s+Graphics") { [void]$vendors.Add("Intel")  }
        }
    } catch {}

    $global:DetectedGpuVendors = @($vendors)
    return $global:DetectedGpuVendors
}

# =========================================================
# NVIDIA PROFILE INSPECTOR — HEADLESS DOWNLOAD + CACHE
# =========================================================
# AppData\GeminiCare\nvidiaProfileInspector.exe path'ini dondurur. Cache yoksa indirir.
#
# 2 kademeli download:
#   1. ONCE: FR33THY raw URL (tek .exe, ~1 MB) — MSI Utility V3 ile ayni pattern, hizli
#   2. FALLBACK: GitHub Releases API (Orbmu2k/nvidiaProfileInspector) — .zip indir, extract et
#
# Sync olarak calisir (caller worker icindedir, blocking ok). Hata durumunda $null doner —
# caller registry tweak'lerini yine de uygulayabilir (graceful degradation).
function Get-NvidiaInspectorPath {
    $cacheExe = Join-Path $AppDataPath "nvidiaProfileInspector.exe"

    # CACHE HIT
    if (Test-Path $cacheExe) {
        $size = (Get-Item $cacheExe).Length
        if ($size -gt 100KB) { return $cacheExe }
        # Bozuk cache (0 byte vs.) — sil ve yeniden indir
        Remove-Item $cacheExe -Force -ErrorAction SilentlyContinue
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    # --- KADEME 1: FR33THY raw .exe ---
    $primaryUrl = "https://github.com/FR33THYFR33THY/Ultimate-Files/raw/refs/heads/main/inspector.exe"
    try {
        WpfLog "[NPI] Birincil kaynaktan indiriliyor (FR33THY)..."
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "GeminiCare-App")
        $wc.DownloadFile($primaryUrl, $cacheExe)
        if ((Test-Path $cacheExe) -and (Get-Item $cacheExe).Length -gt 100KB) {
            Unblock-File -Path $cacheExe -ErrorAction SilentlyContinue
            $kb = [Math]::Round((Get-Item $cacheExe).Length / 1KB, 1)
            WpfLog "[NPI] OK: $kb KB indirildi (birincil)."
            return $cacheExe
        }
    } catch {
        WpfLog "[NPI] Birincil kaynak basarisiz: $($_.Exception.Message)"
    }
    if (Test-Path $cacheExe) { Remove-Item $cacheExe -Force -ErrorAction SilentlyContinue }

    # --- KADEME 2: GitHub Releases API (Orbmu2k) ---
    try {
        WpfLog "[NPI] Yedek kaynaktan indiriliyor (Orbmu2k Releases API)..."
        $apiUrl = "https://api.github.com/repos/Orbmu2k/nvidiaProfileInspector/releases"
        $headers = @{ "User-Agent" = "GeminiCare-App" }
        $releases = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop

        # En son STABIL (prerelease=$false) sürümü sec
        $stable = $releases | Where-Object { -not $_.prerelease } | Select-Object -First 1
        if (-not $stable) { $stable = $releases | Select-Object -First 1 }
        if (-not $stable) { throw "Sürüm bulunamadı." }

        $asset = $stable.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
        if (-not $asset) { throw "ZIP asseti bulunamadı." }

        $zipPath = Join-Path $env:TEMP "npi_$([Guid]::NewGuid().ToString('N')).zip"
        $extractDir = Join-Path $AppDataPath "nvidiaProfileInspector"

        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "GeminiCare-App")
        $wc.DownloadFile($asset.browser_download_url, $zipPath)

        if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -le 0) { throw "ZIP indirilemedi." }
        Unblock-File -Path $zipPath -ErrorAction SilentlyContinue

        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force -ErrorAction Stop
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

        # Extract edilen klasorde inspector.exe ara (NVIDIA Profile Inspector zip yapisi)
        $exe = Get-ChildItem -Path $extractDir -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match "inspector" } |
               Select-Object -First 1
        if (-not $exe) { throw "Inspector exe extract klasorunde bulunamadi." }

        # Cache'e kopyala (tek dosya yeter — ihtiyac olursa Resources DLL'leri extract klasorunde kalsin)
        Copy-Item -Path $exe.FullName -Destination $cacheExe -Force
        Unblock-File -Path $cacheExe -ErrorAction SilentlyContinue

        $kb = [Math]::Round((Get-Item $cacheExe).Length / 1KB, 1)
        WpfLog "[NPI] OK: $kb KB indirildi (yedek, $($stable.tag_name))."
        return $cacheExe
    } catch {
        WpfLog "[NPI] Yedek kaynak da basarisiz: $($_.Exception.Message)"
    }

    return $null
}

# =========================================================
# START MENU LAYOUT IMPORT (FR33THY 1 Start Menu Taskbar.ps1 birebir)
# =========================================================
# Win10 ve Win11 icin temiz/default start menu layout uygular.
# -Mode Clean   : Win10 bos LayoutModificationTemplate + Win11 FR33THY start2.bin
# -Mode Default : Win10 FR33THY default layout (OneNote, Edge, Spotify vb gruplari) + Win11 start2.bin sil
function Invoke-StartMenuLayoutImport {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Clean","Default")]
        [string]$Mode
    )

    Write-Host "[StartMenu] Layout import: $Mode modu basliyor..."

    # --- WIN10 LAYOUT XML ---
    $win10Xml = if ($Mode -eq "Clean") {
@'
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
    <LayoutOptions StartTileGroupCellWidth="6" />
    <DefaultLayoutOverride>
        <StartLayoutCollection>
            <defaultlayout:StartLayout GroupCellWidth="6" />
        </StartLayoutCollection>
    </DefaultLayoutOverride>
</LayoutModificationTemplate>
'@
    } else {
@'
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6">
        <start:Group Name="Productivity">
          <start:Folder Name="" Size="2x2" Column="2" Row="0">
            <start:Tile Size="2x2" Column="4" Row="2" AppUserModelID="Microsoft.Office.OneNote_8wekyb3d8bbwe!microsoft.onenoteim" />
            <start:DesktopApplicationTile Size="2x2" Column="0" Row="2" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" />
            <start:Tile Size="2x2" Column="0" Row="4" AppUserModelID="Microsoft.SkypeApp_kzf8qxf38zg5c!App" />
          </start:Folder>
          <start:Tile Size="2x2" Column="0" Row="0" AppUserModelID="Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe!Microsoft.MicrosoftOfficeHub" />
          <start:DesktopApplicationTile Size="2x2" Column="0" Row="2" DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" />
          <start:Tile Size="2x2" Column="4" Row="2" AppUserModelID="7EE7776C.LinkedInforWindows_w1wdnht996qgy!App" />
          <start:Tile Size="2x2" Column="4" Row="0" AppUserModelID="microsoft.windowscommunicationsapps_8wekyb3d8bbwe!Microsoft.WindowsLive.Mail" />
          <start:Tile Size="2x2" Column="2" Row="2" AppUserModelID="Microsoft.Windows.Photos_8wekyb3d8bbwe!App" />
        </start:Group>
        <start:Group Name="Explore">
          <start:Folder Name="Play" Size="2x2" Column="4" Row="2">
            <start:Tile Size="2x2" Column="2" Row="0" AppUserModelID="Microsoft.WindowsCalculator_8wekyb3d8bbwe!App" />
            <start:Tile Size="2x2" Column="0" Row="0" AppUserModelID="Clipchamp.Clipchamp_yxz26nhyzhsrt!App" />
          </start:Folder>
          <start:Tile Size="2x2" Column="4" Row="0" AppUserModelID="Microsoft.Todos_8wekyb3d8bbwe!App" />
          <start:Tile Size="2x2" Column="2" Row="2" AppUserModelID="Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe!App" />
          <start:Tile Size="2x2" Column="2" Row="0" AppUserModelID="SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify" />
          <start:Tile Size="2x2" Column="0" Row="2" AppUserModelID="Microsoft.ZuneVideo_8wekyb3d8bbwe!Microsoft.ZuneVideo" />
          <start:Tile Size="2x2" Column="0" Row="0" AppUserModelID="Microsoft.WindowsStore_8wekyb3d8bbwe!App" />
        </start:Group>
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
</LayoutModificationTemplate>
'@
    }

    # --- WIN10 IMPORT FLOW (LockedStartLayout policy) ---
    $layoutFile = "C:\Windows\StartMenuLayout.xml"
    Remove-Item -Path $layoutFile -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    Set-Content -Path $layoutFile -Value $win10Xml -Force -Encoding ASCII

    $regAliases = @("HKLM", "HKCU")
    foreach ($alias in $regAliases) {
        $basePath = "${alias}:\SOFTWARE\Policies\Microsoft\Windows"
        $keyPath = "$basePath\Explorer"
        if (-not (Test-Path -Path $keyPath)) {
            New-Item -Path $basePath -Name "Explorer" -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $keyPath -Name "StartLayoutFile" -Value $layoutFile -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Host "[StartMenu] Win10 layout uygulandi, Explorer restart..."
    Stop-Process -Force -Name explorer -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 5

    # Policy'i kapat (kullanici elle degistirebilsin)
    foreach ($alias in $regAliases) {
        $keyPath = "${alias}:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
        if (Test-Path $keyPath) {
            Set-ItemProperty -Path $keyPath -Name "LockedStartLayout" -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Remove-Item -Path $layoutFile -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

    # --- WIN11 START2.BIN ---
    $localState = "$env:USERPROFILE\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    $start2Path = "$localState\start2.bin"

    # Once mevcut start2.bin'i sil
    Remove-Item -Path $start2Path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

    if ($Mode -eq "Clean") {
        # FR33THY base64 cert blob'unu decode et
        $tmpTxt = "$env:SystemRoot\Temp\start2.txt"
        $tmpBin = "$env:SystemRoot\Temp\start2.bin"
        New-Item -Path $tmpTxt -Value $global:Win11Start2BinBase64 -Force -ErrorAction SilentlyContinue | Out-Null
        try {
            certutil.exe -decode $tmpTxt $tmpBin > $null 2>&1
            if (Test-Path $tmpBin) {
                if (Test-Path $localState) {
                    Copy-Item -Path $tmpBin -Destination $localState -Force -ErrorAction SilentlyContinue | Out-Null
                    Write-Host "[StartMenu] Win11 start2.bin yuklendi (clean layout)."
                } else {
                    Write-Host "[StartMenu] LocalState klasoru yok (Win10 sistem) — start2.bin atlandi."
                }
            }
        } catch {
            Write-Host "[StartMenu] start2.bin decode hatasi: $($_.Exception.Message)"
        } finally {
            Remove-Item -Path $tmpTxt -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $tmpBin -Force -ErrorAction SilentlyContinue | Out-Null
        }

        # AllAppsViewMode = List
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "AllAppsViewMode" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    } else {
        # Default: start2.bin sadece silindi (Windows kendi default'unu olusturur)
        # AllAppsViewMode = Category (varsayilan)
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "AllAppsViewMode" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[StartMenu] Final restart..."
    Stop-Process -Force -Name explorer -ErrorAction SilentlyContinue | Out-Null
    Write-Host "[StartMenu] Tamamlandi: $Mode"
}

# =========================================================
# AUTO-UPDATE HELPER'LARI
# =========================================================
# Mimari: GitHub Releases API + SemVer + SHA256 + B+C hibrit self-update
# - Add_Loaded: Cleanup-OldUpdateFiles + Test-AppUpdate (async)
# - Yeni surum varsa: $global:UpdateAvailable doldurulur, status bar'da bildirim
# - Show-AppUpdateWindow: kullanici Guncelle butonuna basinca Invoke-AppUpdate cagrilir
# - Invoke-AppUpdate: indir + SHA256 dogrula + updater PS1 yaz + spawn + ana programi kapat
# - Updater PS1: ana programin kapanmasini bekle, eski dosyalari .old'a rename et, yeniyi yerlestir, tekrar baslat

# SemVer karsilastirma helper. "1.2.0" "1.10.3" gibi string'leri integer-bazinda compare eder.
# v prefix'i otomatik temizlenir. Donus: 1=lhs > rhs, 0=esit, -1=lhs < rhs
function Compare-Version {
    param([string]$Lhs, [string]$Rhs)
    $cleanL = ($Lhs -replace "^v","").Trim()
    $cleanR = ($Rhs -replace "^v","").Trim()
    try {
        $vL = [System.Version]$cleanL
        $vR = [System.Version]$cleanR
        return $vL.CompareTo($vR)
    } catch {
        # SemVer parse failure (orn. "1.2.0-beta") — string compare fallback
        if ($cleanL -gt $cleanR) { return 1 }
        elseif ($cleanL -lt $cleanR) { return -1 }
        else { return 0 }
    }
}

# Acilis sirasinda once .old dosyalari sil. Updater script ana dosyalari rename ederek update'liyor,
# program tekrar acildiginda artik kullanilmayan .old uzantili dosyalari temizler. Updater PS1'i de siler.
function Get-AppExeDirectory {
    # Hem PS1 modunda ($PSScriptRoot), hem PS2EXE -NoConsole modunda calisir.
    # PS2EXE'de $PSScriptRoot null olabilir, MainModule.FileName ile gercek EXE yolunu aliriz.
    $appDir = $null
    try {
        if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
            $appDir = $PSScriptRoot
        } else {
            $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            if ($exePath -and (Test-Path $exePath)) {
                $appDir = Split-Path -Parent $exePath
            }
        }
    } catch {}
    if (-not $appDir -or -not (Test-Path $appDir)) {
        try { $appDir = (Get-Location).Path } catch { $appDir = $null }
    }
    return $appDir
}

function Cleanup-OldUpdateFiles {
    try {
        $appDir = Get-AppExeDirectory
        if ($appDir -and (Test-Path $appDir)) {
            Get-ChildItem -Path $appDir -Filter "*.old" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
        # Eski updater PS1 ve staging klasoru
        if ($AppDataPath) {
            $updaterPath = Join-Path $AppDataPath "update_runner.ps1"
            if (Test-Path $updaterPath) { Remove-Item $updaterPath -Force -ErrorAction SilentlyContinue }
        }
        if ($global:UpdateStagingDir -and (Test-Path $global:UpdateStagingDir)) {
            Remove-Item $global:UpdateStagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Sessizce gec — cleanup hata bile aciklamadan acilis akisini bozmamali
    }
}

# Async update check — Add_Loaded'da cagrilir. Runspace'de calisir, UI bloklamaz.
# Sonuc: $global:UpdateAvailable doldurulur (yeni surum varsa) veya $null (guncel/erisilemiyor).
# UI thread'i status bar'i guncellemek icin DispatcherTimer ile beklenmelidir.
function Test-AppUpdate {
    if (-not $global:AppRepo -or $global:AppRepo -match "KULLANICI_ADIN|KULLANICI/REPO") {
        return  # Repo placeholder ise check yapma (kullanici kendi repo'sunu yazmamis)
    }

    # Atlanan surumler dosyasini oku — kullanici "Bu surumu atla" demisse listede vardir
    $skipped = @()
    if (Test-Path $global:UpdateSkippedFile) {
        try { $skipped = Get-Content $global:UpdateSkippedFile -ErrorAction SilentlyContinue } catch {}
    }

    $script:UpdRunspace = [powershell]::Create()
    $script:UpdRunspace.AddScript({
        param($repo)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        try {
            $headers = @{ "User-Agent" = "GeminiCare-App" }
            $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
            $res = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 5 -ErrorAction Stop
            return ($res | ConvertTo-Json -Depth 10 -Compress)
        } catch { return $null }
    }).AddArgument($global:AppRepo) | Out-Null

    $script:UpdAsync = $script:UpdRunspace.BeginInvoke()

    $script:UpdTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:UpdTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:UpdTimer.Add_Tick({
        if (-not $script:UpdAsync.IsCompleted) { return }
        $script:UpdTimer.Stop()

        try {
            $rawJson = $script:UpdRunspace.EndInvoke($script:UpdAsync) -join ""
            if (-not $rawJson) {
                # Erisim yok — sessizce gec, kullaniciyi rahatsiz etme
                return
            }
            $release = $rawJson | ConvertFrom-Json
            $remoteTag = $release.tag_name
            if (-not $remoteTag) { return }

            # SemVer karsilastirma
            $cmp = Compare-Version -Lhs $remoteTag -Rhs $global:AppVersion
            if ($cmp -le 0) {
                # Guncel ya da daha eski (development build) — bildirim gosterme
                return
            }

            # Atlanmis surum mu?
            $cleanTag = ($remoteTag -replace "^v","").Trim()
            if ($skipped -contains $cleanTag) {
                return  # Kullanici bu surumu atlamis
            }

            # Asset'leri ayikla
            $exeAsset  = $release.assets | Where-Object { $_.name -match "\.exe$" }       | Select-Object -First 1
            $ps1Asset  = $release.assets | Where-Object { $_.name -match "\.ps1$" }       | Select-Object -First 1
            $hashAsset = $release.assets | Where-Object { $_.name -match "SHA256.*\.txt$" } | Select-Object -First 1

            if (-not $exeAsset -and -not $ps1Asset) {
                return  # Hicbir kullanilabilir asset yok
            }

            $global:UpdateAvailable = @{
                Tag        = $remoteTag
                CleanTag   = $cleanTag
                Notes      = $release.body
                ReleaseUrl = $release.html_url
                ExeUrl     = if ($exeAsset)  { $exeAsset.browser_download_url }  else { $null }
                Ps1Url     = if ($ps1Asset)  { $ps1Asset.browser_download_url }  else { $null }
                HashUrl    = if ($hashAsset) { $hashAsset.browser_download_url } else { $null }
                ExeSize    = if ($exeAsset)  { $exeAsset.size }  else { 0 }
                Ps1Size    = if ($ps1Asset)  { $ps1Asset.size }  else { 0 }
            }

            # UI bildirim — status bar'i guncelle, Tools menu'sunde badge goster
            if ($lblStatus) {
                $lblStatus.Text = "🔔 Yeni sürüm: $remoteTag — Güncellemek için Tools menüsünden 'Programı Güncelle'"
            }
            WpfLog "🔔 Yeni sürüm bulundu: $remoteTag (mevcut: $global:AppVersion)"

        } catch {
            # JSON parse veya baska hata — sessizce gec
        } finally {
            if ($script:UpdRunspace) {
                $script:UpdRunspace.Dispose()
                $script:UpdRunspace = $null
            }
        }
    })
    $script:UpdTimer.Start()
}

# Updater PS1 template — AppData'ya yazilip Start-Process ile baslatilir.
# Parametreler: $TargetPid (ana program), $AppDir, $StagingDir, $LaunchExe (yeniden baslatilacak)
$global:UpdaterScriptTemplate = @'
# GeminiCare Auto-Updater Script (otomatik olusturuldu)
# Ana programi kapanmasini bekler, dosyalari swap eder, programi tekrar baslatir.
param(
    [Parameter(Mandatory=$true)][int]$TargetPid,
    [Parameter(Mandatory=$true)][string]$AppDir,
    [Parameter(Mandatory=$true)][string]$StagingDir,
    [string]$LaunchExe = ""
)

# 1. Ana programin kapanmasini bekle (max 30 sn)
try {
    $proc = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
    if ($proc) { $proc.WaitForExit(30000) | Out-Null }
} catch {}
Start-Sleep -Milliseconds 500

# 2. Staging'deki dosyalari ana klasore tasi (.old rename trick)
$staged = Get-ChildItem -Path $StagingDir -File -ErrorAction SilentlyContinue
foreach ($f in $staged) {
    $target = Join-Path $AppDir $f.Name
    try {
        # Eski dosyayi .old'a rename et (kullanimda olsa bile rename calisir Windows'ta)
        if (Test-Path $target) {
            Move-Item -Path $target -Destination "$target.old" -Force -ErrorAction Stop
        }
        # Yeniyi yerlestir
        Move-Item -Path $f.FullName -Destination $target -Force -ErrorAction Stop
    } catch {
        # Tek dosya bile basarisiz olursa abort, ama denemeye devam et
        Write-Host "[Updater] HATA: $($f.Name) tasinmadi: $($_.Exception.Message)"
    }
}

# 3. Staging klasorunu temizle
Remove-Item -Path $StagingDir -Recurse -Force -ErrorAction SilentlyContinue

# 4. Programi tekrar baslat
if ($LaunchExe -and (Test-Path $LaunchExe)) {
    Start-Process -FilePath $LaunchExe -ErrorAction SilentlyContinue
} else {
    # EXE yoksa Baslat.cmd'yi dene
    $cmd = Join-Path $AppDir "Baslat.cmd"
    if (Test-Path $cmd) {
        Start-Process -FilePath $cmd -ErrorAction SilentlyContinue
    }
}

# 5. Updater'in kendi dosyasini sil (Self-cleanup)
Start-Sleep -Milliseconds 500
try { Remove-Item -Path $PSCommandPath -Force -ErrorAction SilentlyContinue } catch {}
'@

# Indir + SHA256 dogrula + updater spawn et + ana programi kapat
# Caller (Show-AppUpdateWindow) bunu cagirinca tum download flow calisir.
# Hata durumunda $false doner, basari durumunda program zaten kapanir (return olmaz).
function Invoke-AppUpdate {
    param(
        [Parameter(Mandatory=$true)]$ProgressCallback  # ScriptBlock(percent, message)
    )

    if (-not $global:UpdateAvailable) { return $false }
    $upd = $global:UpdateAvailable

    # Staging klasorunu temizle ve yarat
    if (Test-Path $global:UpdateStagingDir) {
        Remove-Item $global:UpdateStagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $global:UpdateStagingDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    # 1. SHA256SUMS.txt indir (varsa)
    $hashMap = @{}
    if ($upd.HashUrl) {
        try {
            & $ProgressCallback 5 "SHA256 listesi indiriliyor..."
            $hashFile = Join-Path $global:UpdateStagingDir "SHA256SUMS.txt"
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "GeminiCare-App")
            $wc.DownloadFile($upd.HashUrl, $hashFile)
            # Format: "<hash>  <filename>" her satirda
            Get-Content $hashFile | ForEach-Object {
                if ($_ -match "^([0-9a-fA-F]{64})\s+(.+)$") {
                    $hashMap[$Matches[2].Trim()] = $Matches[1].ToUpper()
                }
            }
        } catch {
            & $ProgressCallback 5 "SHA256 listesi indirilemedi (devam ediliyor, hash dogrulamasi atlanacak)..."
        }
    }

    # 2. Asset'leri indir
    $downloads = @()
    if ($upd.ExeUrl) { $downloads += @{ Url = $upd.ExeUrl; Name = "TemizlikAsistani.exe"; Size = $upd.ExeSize } }
    if ($upd.Ps1Url) { $downloads += @{ Url = $upd.Ps1Url; Name = "TemizlikAsistani.ps1"; Size = $upd.Ps1Size } }

    $stepBase = 10
    $stepRange = 70
    $perFile = $stepRange / $downloads.Count

    foreach ($d in $downloads) {
        & $ProgressCallback $stepBase ("{0} indiriliyor..." -f $d.Name)
        $target = Join-Path $global:UpdateStagingDir $d.Name
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "GeminiCare-App")
            $wc.DownloadFile($d.Url, $target)

            # Boyut sanity check (en az 50 KB ve <100 MB)
            $actualSize = (Get-Item $target).Length
            if ($actualSize -lt 50KB -or $actualSize -gt 100MB) {
                throw "Dosya boyutu beklenmedik: $actualSize byte"
            }

            # SHA256 hash kontrolu (varsa)
            if ($hashMap.ContainsKey($d.Name)) {
                $expected = $hashMap[$d.Name]
                $actual = (Get-FileHash $target -Algorithm SHA256).Hash
                if ($actual -ne $expected) {
                    throw "SHA256 dogrulamasi BASARISIZ. Beklenen: $expected, gercek: $actual"
                }
                & $ProgressCallback ($stepBase + ($perFile / 2)) ("{0} hash dogrulandi" -f $d.Name)
            }

            Unblock-File -Path $target -ErrorAction SilentlyContinue
            $stepBase += $perFile
            & $ProgressCallback $stepBase ("{0} indirildi" -f $d.Name)
        } catch {
            & $ProgressCallback 100 ("HATA: {0} indirme/dogrulama basarisiz: {1}" -f $d.Name, $_.Exception.Message)
            return $false
        }
    }

    # 3. Updater PS1'i AppData'ya yaz
    & $ProgressCallback 85 "Updater script hazirlaniyor..."
    $updaterPath = "$AppDataPath\update_runner.ps1"
    Set-Content -Path $updaterPath -Value $global:UpdaterScriptTemplate -Encoding UTF8 -Force

    # 4. Mevcut process bilgilerini topla
    $myPid = $PID
    $appDir = Get-AppExeDirectory
    if (-not $appDir) {
        & $ProgressCallback 100 "HATA: Uygulama klasoru tespit edilemedi"
        return $false
    }

    # Yeniden baslatilacak EXE'yi bul (oncelik: TemizlikAsistani.exe)
    $launchExe = Join-Path $appDir "TemizlikAsistani.exe"
    if (-not (Test-Path $launchExe)) { $launchExe = "" }  # PS1 modunda EXE yok, Baslat.cmd'ye dusulur

    & $ProgressCallback 95 "Updater spawn ediliyor..."

    # 5. Updater'i Start-Process ile baslat (yeni bir powershell proceesi olarak)
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", "`"$updaterPath`"",
        "-TargetPid", $myPid,
        "-AppDir", "`"$appDir`"",
        "-StagingDir", "`"$global:UpdateStagingDir`"",
        "-LaunchExe", "`"$launchExe`""
    ) -ErrorAction SilentlyContinue

    & $ProgressCallback 100 "Hazir. Program birazdan kapanip yeniden baslayacak..."
    Start-Sleep -Seconds 1

    return $true
}

# Atla edilen surumu kayit dosyasina ekle (kullanici "Bu surumu atla" derse)
function Add-SkippedVersion {
    param([string]$VersionTag)
    $clean = ($VersionTag -replace "^v","").Trim()
    try {
        $existing = @()
        if (Test-Path $global:UpdateSkippedFile) {
            $existing = Get-Content $global:UpdateSkippedFile -ErrorAction SilentlyContinue
        }
        if ($existing -notcontains $clean) {
            Add-Content -Path $global:UpdateSkippedFile -Value $clean -Encoding UTF8
        }
    } catch {}
}

# =========================================================
# SHELL REFRESH HELPER'LARI (RestartExplorer Soft/Hard icin)
# =========================================================
# Soft refresh: Explorer'i kapatmadan, acik pencereleri "refresh" et.
# HideFileExt, Hidden gibi gorunum tweak'leri icin ideal — pencere kaybolmaz.
function Invoke-ShellSoftRefresh {
    try {
        # SHCNE_ASSOCCHANGED = 0x08000000 — tum acik Explorer pencereleri yenilenir
        [NativeMethods]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
        # WM_SETTINGCHANGE broadcast — uygulamalara "ayar degisti" sinyali
        $null = [NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 2, 1000, [ref][UIntPtr]::Zero)
        WpfLog "[SHELL] Acik Explorer pencereleri yenilendi (soft refresh)."
    } catch {
        WpfLog "[UYARI] Soft refresh hatasi: $($_.Exception.Message)"
    }
}

# Hard restart: Explorer'i kill et ve /factory mode ile yeniden baslat.
# /factory,{75dff2b7-...} — Microsoft'un internal "shell instance" mode'u:
# shell process'ini baslatir AMA gorunur Explorer penceresi acmaz.
# Klasik Sag Tik Menu, Gorsel Efektler gibi shell'in tam reload'u gereken tweak'ler icin.
function Invoke-ExplorerHardRestart {
    try {
        WpfLog "[SHELL] Explorer yeniden baslatiliyor..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Stop-Process -Name sihost   -Force -ErrorAction SilentlyContinue

        # Windows shell, explorer.exe kill edildiginde GENELDE otomatik restart eder
        Start-Sleep -Seconds 2

        $autoRestarted = [bool](Get-Process explorer -ErrorAction SilentlyContinue)
        if ($autoRestarted) {
            WpfLog "[SHELL] Windows otomatik restart yapti."
        } else {
            # Auto-restart olmadi — manuel baslat
            try {
                Start-Process -FilePath "explorer.exe" -ArgumentList "/factory,{75dff2b7-6936-4c06-a8bb-676a7b00b24b} -Embedding" -ErrorAction Stop
                Start-Sleep -Milliseconds 1500
                if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
                    Start-Process -FilePath "explorer.exe" -ErrorAction SilentlyContinue
                }
            } catch {
                Start-Process -FilePath "explorer.exe" -ErrorAction SilentlyContinue
            }
        }

        # KRITIK: Windows restart sonrasi bazen "previous folders" mantigi ile
        # bos Explorer pencereleri acar. Bunlari Shell.Application COM ile kapatalim.
        # Taskbar/Desktop bu collection'da DEGIL, sadece klasor pencereleri kapanir.
        Start-Sleep -Milliseconds 1500  # Pencereler acilmasi icin biraz bekle
        try {
            $shell = New-Object -ComObject Shell.Application
            $windows = @($shell.Windows())
            $closed = 0
            foreach ($w in $windows) {
                try { $w.Quit(); $closed++ } catch {}
            }
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
            if ($closed -gt 0) { WpfLog "[SHELL] $closed adet otomatik acilan pencere kapatildi." }
        } catch {
            WpfLog "[UYARI] Otomatik pencere kapatma: $($_.Exception.Message)"
        }

        WpfLog "[SHELL] Explorer yeniden baslatildi."
    } catch {
        WpfLog "[HATA] Explorer hard restart: $($_.Exception.Message)"
    }
}

# =========================================================
# SISTEM GERI YUKLEME NOKTASI
# - Mode: $global:RestorePointMode ("Ask" | "Auto" | "Never")
# - VSS servis kontrolu, 24 saat throttle
# - Async olustur + modal "lutfen bekleyin" penceresi (UI donmaz)
# - Donus degeri: $true = islem devam etsin, $false = iptal
# =========================================================

# VSS (Volume Shadow Copy) servisi calisiyor mu?
function Test-VssServiceRunning {
    try {
        $svc = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
        if (-not $svc) { return $false }
        # Servis otomatik baslatiliyor olabilir (Manual/Automatic), Stop degilse OK
        return ($svc.Status -eq "Running" -or $svc.StartType -ne "Disabled")
    } catch { return $false }
}

# Son restore point tarihini donduren yardimci (null dondurebilir)
function Get-LastRestorePointDate {
    try {
        $lastPoint = Get-ComputerRestorePoint -ErrorAction SilentlyContinue |
                     Sort-Object SequenceNumber -Descending | Select-Object -First 1
        if (-not $lastPoint) { return $null }
        $lastDate = $lastPoint.CreationTime
        if ($lastDate -is [string]) {
            try { $lastDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastDate) }
            catch { return $null }
        }
        return $lastDate
    } catch { return $null }
}

# Ana fonksiyon: mode + throttle + sor + async olustur
function Create-Restore-Point {
    param(
        [string]$Description,
        [switch]$ForceManual  # Ayarlar panelinden "Simdi Manuel Olustur" icin mod kontrolunu atla
    )

    # 1. VSS servis kontrolu
    if (-not (Test-VssServiceRunning)) {
        WpfLog "[UYARI] VSS (Volume Shadow Copy) servisi kapali. Geri yukleme noktasi olusturulamaz."
        WpfLog "         Cozum: Ayarlar > Sistem Geri Yukleme > Windows Paneli'ni acarak servis ve korumayi etkinlestirin."
        return $true  # Islem engellenmesin, kullanici bilinclendi
    }

    # 2. Mode kontrolu (ForceManual ise atla)
    $mode = if ($global:RestorePointMode) { $global:RestorePointMode } else { "Ask" }
    if (-not $ForceManual -and $mode -eq "Never") {
        WpfLog "[AYAR] Kullanici tercihi: Geri yukleme noktasi olusturulmayacak."
        return $true  # Islem devam etsin
    }

    # 3. 24 saat throttle (ForceManual ise atla)
    if (-not $ForceManual) {
        $lastDate = Get-LastRestorePointDate
        if ($lastDate) {
            $diff = (Get-Date) - $lastDate
            if ($diff.TotalMinutes -lt 1440) {
                $hrs = [Math]::Round($diff.TotalHours, 1)
                WpfLog "[BILGI] Son $hrs saat once zaten geri yukleme noktasi olusturulmus, yenisi olusturulmuyor."
                return $true
            }
        }
    }

    # 4. Ask modu: kullaniciya sor
    if (-not $ForceManual -and $mode -eq "Ask") {
        $msg = "Guvenlik icin bir Sistem Geri Yukleme Noktasi olusturulsun mu?`n`n" +
               "Islem: $Description`n" +
               "Sure: ~20-40 saniye (arayuz donmayacak)`n`n" +
               "Tavsiye: EVET secin — degisiklik yanlis giderse sistemi geri alabilirsiniz.`n" +
               "Bu tercihi: Ayarlar > Sistem Geri Yukleme bolumunden degistirebilirsiniz."

        $res = [System.Windows.MessageBox]::Show($msg, "Geri Yukleme Noktasi",
            [System.Windows.MessageBoxButton]::YesNoCancel,
            [System.Windows.MessageBoxImage]::Question)

        if ($res -eq 'Cancel') {
            WpfLog "[IPTAL] Islem kullanici tarafindan iptal edildi."
            return $false
        }
        if ($res -eq 'No') {
            WpfLog "[ATLA] Kullanici geri yukleme noktasi olusturmadan devam etmeyi sectI."
            return $true
        }
        # Yes: olusturmaya devam
    }

    # 5. Async olustur + modal "lutfen bekleyin" penceresi
    return (Invoke-RestorePointAsync -Description $Description)
}

# Runspace'te Checkpoint-Computer cagirir, modal bir pencere gosterir.
# Donus: $true = devam, $false = hata durumunda bile isleme devam edelim
function Invoke-RestorePointAsync {
    param([string]$Description)

    # Bekleme penceresi XAML (kucuk, merkezde, kapatilmaz)
    $xamlRP = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Geri Yukleme Noktasi' Height='180' Width='460'
        Background='#181818' WindowStartupLocation='CenterOwner'
        WindowStyle='ToolWindow' ResizeMode='NoResize' ShowInTaskbar='False'>
    <Grid Margin='20'>
        <StackPanel VerticalAlignment='Center'>
            <TextBlock Text='🔒 Sistem Geri Yukleme Noktasi Olusturuluyor'
                       Foreground='#4CC2FF' FontSize='14' FontWeight='Bold'
                       HorizontalAlignment='Center'/>
            <TextBlock x:Name='txtRPStatus' Text='Windows VSS servisinden cevap bekleniyor...'
                       Foreground='#AAA' FontSize='11' Margin='0,10,0,10'
                       HorizontalAlignment='Center' TextAlignment='Center' TextWrapping='Wrap'/>
            <ProgressBar x:Name='pbRP' IsIndeterminate='True' Height='6'
                         Background='#333' Foreground='#4CC2FF' BorderThickness='0'/>
            <TextBlock Text='Bu islem genelde 20-40 saniye surer. Lutfen bekleyin.'
                       Foreground='#555' FontSize='10' Margin='0,10,0,0'
                       HorizontalAlignment='Center'/>
        </StackPanel>
    </Grid>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlRP)
    $winRP = [Windows.Markup.XamlReader]::Load($reader)
    if (-not $winRP) {
        WpfLog "[HATA] Restore point penceresi yuklenemedi (XAML parse)."
        return $true  # Devam edilsin
    }
    $winRP.Owner = $Win
    $txtRPStatus = $winRP.FindName('txtRPStatus')

    # NOT: Closing handler EKLEMIYORUZ — PowerShell delegate binding'i
    # bazen Closing event'inde NullReference fırlatip Close()'u sabote ediyor.
    # Kullanici X tuslarsa pencere kapanir; runspace arka planda kendiliğinden tamamlanir.

    # Runspace olustur ve baslat
    $ps = [powershell]::Create()
    $ps.RunspacePool = $global:GeminiPool
    $ps.AddScript({
        param($desc)
        try {
            Checkpoint-Computer -Description $desc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            return @{ Success = $true; Error = $null }
        } catch {
            return @{ Success = $false; Error = $_.Exception.Message }
        }
    }).AddArgument($Description) | Out-Null

    $asyncResult = $ps.BeginInvoke()
    if ($null -ne $global:ActiveRunspaces) { [void]$global:ActiveRunspaces.Add($ps) }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Timer: runspace bitisini takip et (closure ile $winRP/$ps/$asyncResult/$txtRPStatus capture)
    $rpTimer = New-Object System.Windows.Threading.DispatcherTimer
    $rpTimer.Interval = [TimeSpan]::FromMilliseconds(250)

    $rpTimer.Add_Tick({
        # Status metnini akici tut
        if ($txtRPStatus) {
            try {
                $secs = [Math]::Floor($stopwatch.Elapsed.TotalSeconds)
                $txtRPStatus.Text = "Windows VSS servisinden cevap bekleniyor... ($secs sn)"
            } catch {}
        }

        if (-not $asyncResult.IsCompleted) { return }
        $rpTimer.Stop()

        try {
            $ret = $ps.EndInvoke($asyncResult)
            $result = if ($ret -and $ret.Count -gt 0) { $ret[0] } else { $null }

            if ($result -and $result.Success) {
                WpfLog "[SISTEM] Geri Yukleme Noktasi basariyla olusturuldu."
            } else {
                $err = if ($result) { $result.Error } else { "Bilinmeyen hata" }
                if ($err -match "frequency") {
                    WpfLog "[BILGI] Windows'un kendi 24 saat kotasi nedeniyle atlandi."
                } else {
                    WpfLog "[UYARI] Geri Yukleme Noktasi olusturulamadi: $err"
                    WpfLog "         Islem yine de devam edecek."
                }
            }
        } catch {
            WpfLog "[HATA] Restore point sonuc okuma: $($_.Exception.Message)"
        } finally {
            try {
                if ($null -ne $global:ActiveRunspaces) { [void]$global:ActiveRunspaces.Remove($ps) }
                $ps.Dispose()
            } catch {}
        }

        # Pencereyi kapat: DialogResult tercih (modal'i dogru sekilde kapatir).
        # User X ile zaten kapatmissa $winRP.IsLoaded false olur, sessizce gec.
        try {
            if ($winRP -and $winRP.IsLoaded) { $winRP.DialogResult = $true }
        } catch {
            try { if ($winRP) { $winRP.Close() } } catch {}
        }
    }.GetNewClosure())
    $rpTimer.Start()

    WpfLog "[SISTEM] Geri Yukleme Noktasi olusturma baslatildi (arka planda)..."
    [void]$winRP.ShowDialog()

    return $true
}

# --- TWEAK MANTIK ---
# powercfg sonucunu cache'le (her Check-Tweak-Status / Apply-System-Tweaks öncesi yenilenir)
$script:PowerCfgActiveScheme = $null
function Refresh-PowerCfg-Cache {
    try { $script:PowerCfgActiveScheme = powercfg /getactivescheme 2>$null } catch { $script:PowerCfgActiveScheme = "" }
}

function Get-Tweak-IsActive($tweak) {
    # Debug Açık mı?
    $isDebug = $chkDebug.IsChecked

    # Yardımcı Log Fonksiyonu
    $log = { param($m) if ($isDebug) { WpfLog "[DEBUG-TWEAK] $($tweak.Name): $m" } }

    try {
        # --- 0. ÖZEL DETECT SCRIPT (genel-amaclı detection)
        # Tweak'e DetectScript field'i tanimliysa onu calistirip bool donusu kullaniriz.
        # Registry/Service/Command pattern'ina uymayan tweak'ler icin (orn. Disable-MMAgent).
        if ($tweak.DetectScript) {
            try {
                $sb = [ScriptBlock]::Create("$($tweak.DetectScript)")
                $r = & $sb
                return [bool]$r
            } catch {
                & $log "DetectScript hatasi: $($_.Exception.Message)"
                return $false
            }
        }

       # --- ÖZEL GRUP: AĞ PROFİLİ KONTROLÜ ---
        if ($tweak.Group -eq "NetProfile") {
            $pathTCP = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            $pathMM  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            
            $minRto   = (Get-ItemProperty -Path $pathTCP -Name "MinRto"                  -ErrorAction SilentlyContinue).MinRto
            $tcpWin   = (Get-ItemProperty -Path $pathTCP -Name "TcpWindowSize"            -ErrorAction SilentlyContinue).TcpWindowSize
            $throttle = (Get-ItemProperty -Path $pathMM  -Name "NetworkThrottlingIndex"   -ErrorAction SilentlyContinue).NetworkThrottlingIndex

            # autotuninglevel değerini netsh'ten oku
            $autoTuneLine = netsh int tcp show global | Select-String "Auto-Tuning"
            $autoTuneVal  = if ($autoTuneLine) { $autoTuneLine.ToString().Split(":")[-1].Trim().ToLower() } else { "" }

            # [PROFİL] Düşük Gecikme + Tam Hız (Üniversal):
            # autotune=normal, throttle=0xFFFFFFFF, MinRto=300, TcpWindowSize SİLİNMİŞ (autotune halleder)
            if ($tweak.Name -match "Üniversal" -or $tweak.Name -match "Universal") {
                if (("$throttle" -eq "4294967295" -or "$throttle" -eq "-1") -and
                    $autoTuneVal -eq "normal" -and
                    "$minRto" -eq "300" -and
                    $null -eq $tcpWin) { return $true }
            }
            # [SIFIRLA] Windows Varsayılanları: autotune=normal, throttle=10, TcpWindowSize yok, MinRto yok
            elseif ($tweak.Name -match "Varsayılan") {
                if ("$throttle" -eq "10" -and
                    $autoTuneVal -eq "normal" -and
                    $null -eq $tcpWin -and
                    $null -eq $minRto) { return $true }
            }
            return $false
        }

        # --- 1. STANDART REGISTRY KONTROLÜ ---
        if ($tweak.Key) {
            $current = Get-ItemProperty -Path $tweak.Key -Name $tweak.ValueName -ErrorAction SilentlyContinue
            if ($current) {
                $val = if ([string]::IsNullOrEmpty($tweak.ValueName)) { $current."(default)" } else { $current.($tweak.ValueName) }
                
                # Network Throttling Fix
                if ($tweak.ValueName -eq "NetworkThrottlingIndex") {
                    if ("$val" -eq "4294967295" -or "$val" -eq "-1") { return $true }
                }

                $dataStr = "$($tweak.Data)"
                $valStr = "$val"
                
                if ($valStr -eq $dataStr) { return $true }
            }
        }
        
        # --- 2. KOMUT ve BATCH ÖZEL KONTROLLERİ ---
        elseif ($tweak.Command -or $tweak.Batch) { 
            
            # A) BCDEDIT KONTROLLERİ
            if ($tweak.Command -match "bcdedit") {
                $bcdOut = cmd /c bcdedit /enum 2>&1 | Out-String
                if ($tweak.Name -match "Dynamic Tick") {
                    if ($bcdOut -match "(?im)disabledynamictick\s+Yes") { return $true }
                }
                elseif ($tweak.Name -match "HPET") {
                    if ($bcdOut -notmatch "(?im)useplatformclock\s+Yes") { return $true }
                }
                elseif ($tweak.Name -match "Platform Tick") {
                    if ($bcdOut -match "(?im)useplatformtick\s+Yes") { return $true }
                }
            }

            # B) TCP/NETWORK KONTROLLERİ (NoDelay)
            elseif ($tweak.Name -match "TCP NoDelay") {
                $nics = Get-NetAdapter | Where-Object {
                    $_.Status -eq "Up" -and
                    $_.InterfaceType -in @(6, 71) -and
                    $_.InterfaceDescription -notmatch "(?i)VPN|Virtual|Tunnel|Loopback|TAP|WAN Miniport|Hyper-V|Bluetooth"
                }
                $successCount = 0
                foreach ($nic in $nics) {
                    $guid = $nic.InterfaceGuid
                    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                    $v1 = (Get-ItemProperty -Path $path -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency
                    $v2 = (Get-ItemProperty -Path $path -Name "TCPNoDelay" -ErrorAction SilentlyContinue).TCPNoDelay
                    if ("$v1" -eq "1" -and "$v2" -eq "1") { $successCount++ }
                }
                if ($successCount -gt 0) { return $true }
            }

            # C) MSI MODE (GPU) — tum Display class GPU'larin Interrupt yolundaki MSISupported degerini kontrol et.
            #    En az BIR GPU'da MSISupported=1 ise tweak aktif sayilir.
            elseif ($tweak.Name -match "MSI Mode") {
                $any = $false
                try {
                    Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | ForEach-Object {
                        $instId = $_.InstanceId
                        if (-not $instId) { return }
                        $key = "HKLM:\SYSTEM\ControlSet001\Enum\$instId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                        $v = (Get-ItemProperty -Path $key -Name "MSISupported" -ErrorAction SilentlyContinue).MSISupported
                        if ("$v" -eq "1") { $any = $true }
                    }
                } catch {}
                if ($any) { return $true }
            }

            # --- DİĞER KONTROLLER ---
            $privacyKeys = @("LetAppsAccessCamera", "LetAppsAccessMicrophone", "LetAppsAccessNotifications", "LetAppsAccessAccountInfo", "LetAppsAccessContacts", "LetAppsAccessCalendar", "LetAppsAccessPhone", "LetAppsAccessCallHistory", "LetAppsAccessEmail", "LetAppsAccessTasks", "LetAppsAccessMessaging", "LetAppsAccessRadios", "LetAppsGetDiagnosticInfo")
            foreach ($k in $privacyKeys) {
                if ($tweak.Name -match $k -or $tweak.Batch -match $k) {
                    $polVal = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name $k -ErrorAction SilentlyContinue).$k
                    if ("$polVal" -eq "2") { return $true }
                }
            }

            if ($tweak.Name -match "Konum Hizmetlerini") {
                $polVal = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -ErrorAction SilentlyContinue).DisableLocation
                if ("$polVal" -eq "1") { return $true }
            }
            
            if ($tweak.Name -match "Karanlık Modu Aç") {
                $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                $sys = (Get-ItemProperty -Path $path -Name "SystemUsesLightTheme" -ErrorAction SilentlyContinue).SystemUsesLightTheme
                $app = (Get-ItemProperty -Path $path -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue).AppsUseLightTheme
                if ("$sys" -eq "0" -and "$app" -eq "0") { return $true }
            }
			
            if ($tweak.Name -match "Widget") {
                $pol = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue).AllowNewsAndInterests
                if ("$pol" -eq "0") { return $true }
                $val = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ErrorAction SilentlyContinue).TaskbarDa
                if ("$val" -eq "0") { return $true }
            }
			
            if ($tweak.Name -match "Spotlight") {
                $bgType = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -ErrorAction SilentlyContinue).BackgroundType
                if ($bgType -ne 3 -and $bgType -ne $null) { return $true }
            }

            if ($tweak.Command -match "Set-DnsClientServerAddress") {
                $activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
                $currentDNS = $activeAdapters | Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 } | Select-Object -ExpandProperty ServerAddresses
                if ($tweak.Command -match "'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'") {
                    $targetIP = $Matches[1]
                    if ($currentDNS -contains $targetIP) { return $true }
                }
                elseif ($tweak.Command -match "-ResetServerAddresses") {
                    $knownManuals = @("8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1")
                    $isManualFound = $false
                    foreach ($ip in $currentDNS) { if ($knownManuals -contains $ip) { $isManualFound = $true } }
                    if (-not $isManualFound) { return $true }
                }
            }
			elseif ($tweak.Name -match "Tanılama") {
				$val = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
				if ("$val" -eq "0") { return $true }
			}
			elseif ($tweak.Name -match "OneDrive") {
				$odExe    = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
				$odSysWow = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
				$odRunning = Get-Process "OneDrive" -ErrorAction SilentlyContinue
				if (-not $odRunning -and -not (Test-Path $odExe) -and -not (Test-Path $odSysWow)) {
					return $true
				}
				return $false
			}
            elseif ($tweak.Command -match "powercfg -h off") {
                if (-not (Test-Path "$env:SystemDrive\hiberfil.sys")) { return $true }
            }
            elseif ($tweak.Name -match "Nihai" -or $tweak.Name -match "Ultimate") {
                if ($script:PowerCfgActiveScheme -match "Nihai" -or $script:PowerCfgActiveScheme -match "Ultimate") { return $true }
            }
            elseif ($tweak.Command -match "powercfg") {
                if ($tweak.Command -match "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})") {
                    $guid = $Matches[1]
                    if ($script:PowerCfgActiveScheme -match $guid) { return $true }
                }
            }
        }
    } catch {
        & $log "HATA: $($_.Exception.Message)"
    }
    
    return $false
}

# --- TWEAK AĞACINI YÜKLE (GÜNCELLENDİ: Object/Hashtable Uyumu) ---
function Load-Tweak-Tree {
    # BeginInit: WPF layout hesaplamalarını toplu yapar, her ekleme sonrası render yapmaz → daha hızlı
    $tvTweaks.BeginInit()
    $tvTweaks.Items.Clear()
    
    try {
        foreach ($catName in $global:TweakList.Keys) {
            $catItem = New-Object System.Windows.Controls.TreeViewItem
            $catItem.Header = $catName
            $catItem.Foreground = [System.Windows.Media.Brushes]::Cyan
            $catItem.FontWeight = "Bold"
            $catItem.IsExpanded = $true
            $catItem.Tag = "ROOT" 

            $tweaksInCat = $global:TweakList[$catName]
            
            $groupedTweaks = $tweaksInCat | Group-Object { 
                if ($_ -is [System.Collections.IDictionary]) { $_["SubCategory"] }
                else { $_.SubCategory }
            }
            
            foreach ($group in $groupedTweaks) {
                if (-not [string]::IsNullOrWhiteSpace($group.Name)) {
                    
                    $subCatItem = New-Object System.Windows.Controls.TreeViewItem
                    $subCatHeader = New-Object System.Windows.Controls.CheckBox
                    $subCatHeader.Content = $group.Name
                    $subCatHeader.Foreground = [System.Windows.Media.Brushes]::Yellow
                    $subCatHeader.FontWeight = "SemiBold"
                    
                    $subCatHeader.Add_Click({ 
                        $isChecked = $this.IsChecked
                        $parentItem = $this.Parent
                        if ($parentItem -is [System.Windows.Controls.TreeViewItem]) {
                            foreach ($child in $parentItem.Items) {
                                $chk = Get-CheckFromItem $child
                                $chk.IsChecked = $isChecked
                                $chk.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.CheckBox]::ClickEvent)))
                            }
                        }
                    })

                    $subCatItem.Header = $subCatHeader
                    $subCatItem.IsExpanded = $true
                    $subCatItem.Tag = "SUBCAT"

                    foreach ($tweak in $group.Group) {
                        try {
                            $tweakItem = Create-Tweak-Item $tweak
                            $subCatItem.Items.Add($tweakItem) | Out-Null
                        } catch { WpfLog "[UYARI] Tweak yüklenemedi: $($tweak.Name) — $($_.Exception.Message)" }
                    }
                    $catItem.Items.Add($subCatItem) | Out-Null
                } 
                else {
                    foreach ($tweak in $group.Group) {
                        try {
                            $tweakItem = Create-Tweak-Item $tweak
                            $catItem.Items.Add($tweakItem) | Out-Null
                        } catch { WpfLog "[UYARI] Tweak yüklenemedi: $($tweak.Name) — $($_.Exception.Message)" }
                    }
                }
            }
            $tvTweaks.Items.Add($catItem) | Out-Null
        }
    } catch {
        WpfLog "[HATA] Tweak ağacı yüklenirken sorun oluştu: $($_.Exception.Message)"
    } finally {
        $tvTweaks.EndInit()
    }
}

# --- İPUCU (TOOLTIP) GÖRSEL TASARIM MOTORU ---
function Attach-ToolTip($uiElement, [string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { 
        $uiElement.ToolTip = $null 
        return 
    }
    $tt = New-Object System.Windows.Controls.ToolTip
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $text
    $tb.TextWrapping = "Wrap"
    $tb.MaxWidth = 350
    $tb.FontSize = 13
    $tt.Content = $tb
    $tt.Background = "#1E1E1E"
    $tt.Foreground = "#4CC2FF" # Açık Mavi Şık Metin
    $tt.BorderBrush = "#3E3E42"
    $tt.BorderThickness = New-Object System.Windows.Thickness(1)
    $tt.Placement =[System.Windows.Controls.Primitives.PlacementMode]::Right
    
    # Hafif Gölge Efekti (Premium Görünüm)
    $drop = New-Object System.Windows.Media.Effects.DropShadowEffect
    $drop.BlurRadius = 10
    $drop.ShadowDepth = 2
    $drop.Opacity = 0.5
    $tt.Effect = $drop

    $uiElement.ToolTip = $tt
}

function Sync-Children($parentItem, $isChecked) { foreach ($item in $parentItem.Items) { $chk = Get-CheckFromItem $item; $chk.IsChecked = $isChecked; if ($item.Items.Count -gt 0) { Sync-Children $item $isChecked } } }

function New-TreeItem([string]$header, [string]$tag,[bool]$isCustom = $false) {
    $item = New-Object System.Windows.Controls.TreeViewItem; $stack = New-Object System.Windows.Controls.StackPanel; $stack.Orientation = 'Horizontal'
    $chk = New-Object System.Windows.Controls.CheckBox; $chk.Margin = '0,0,8,0'; $chk.Tag = $tag; $chk.Content = $header; $chk.Foreground = [System.Windows.Media.Brushes]::White; $chk.FontSize = 13
    $chk.Add_Click({ $thisChk = $this; $thisItem = $thisChk.Parent.Parent; if ($thisItem -is [System.Windows.Controls.TreeViewItem]) { Sync-Children $thisItem $thisChk.IsChecked } })
    $stack.Children.Add($chk) | Out-Null
    if ($isCustom) { $item.ContextMenu = $Win.Resources["CustomItemMenu"] } elseif ($tag -match '^WINAPP2:') { $item.ContextMenu = $Win.Resources["ItemMenu"] }
    $item.Header = $stack; $item.Tag = $tag; $item.Padding = "0,2"
    
    # --- TOOLTIP KONTROLÜ (GÜNCELLENDİ) ---
    $cleanName = $header -replace " \(Aktif\)$", "" -replace " \(Yüklü\)$", ""
    $finalDesc = ""
    # 1. Önce JSON'da manuel eklenmiş açıklama var mı bak
    if ($global:ItemDescriptions.ContainsKey($cleanName)) { $finalDesc = $global:ItemDescriptions[$cleanName] }
    
    if ($finalDesc) { Attach-ToolTip $chk $finalDesc }
    
    return $item
}

function Get-CheckFromItem($item) {
    if ($item.Header -is[System.Windows.Controls.CheckBox]) { return $item.Header }
    elseif ($item.Header -is[System.Windows.Controls.Panel]) { return $item.Header.Children[0] }
    return $null
}

# Tweak/app item'inin gercek goruntulenen ad'ini doner.
# Content StackPanel ise icindeki TextBlock.Text'i, string ise direkt content'i alir.
# (Risk dot Ellipse'lerini ve "(Aktif)" suffix'ini olduğu gibi birakir — caller temizlemeli)
function Get-TweakDisplayName($item) {
    $chk = Get-CheckFromItem $item
    if (-not $chk) {
        try { return $item.Header.ToString() } catch { return "" }
    }
    if ($chk.Content -is [System.Windows.Controls.Panel]) {
        foreach ($child in $chk.Content.Children) {
            if ($child -is [System.Windows.Controls.TextBlock]) { return $child.Text }
        }
        return ""
    }
    return "$($chk.Content)"
}

function Create-Tweak-Item($tweak) {
    $item = New-Object System.Windows.Controls.TreeViewItem
    $stack = New-Object System.Windows.Controls.StackPanel; $stack.Orientation = 'Horizontal'
    
    $chk = New-Object System.Windows.Controls.CheckBox
    $chk.Margin = '0,0,8,0'

    # Content = StackPanel { [Ellipse risk dot] + TextBlock(name) }
    # Ellipse foreground'tan bagimsiz, kendi Fill rengini korur (LimeGreen sorunu yok).
    $contentPanel = New-Object System.Windows.Controls.StackPanel
    $contentPanel.Orientation = 'Horizontal'

    $rsVal = "$($tweak.Risk)"
    if ($rsVal -eq "High" -or $rsVal -eq "Medium") {
        $dot = New-Object System.Windows.Shapes.Ellipse
        $dot.Width = 9
        $dot.Height = 9
        $dot.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
        $dot.VerticalAlignment = 'Center'
        $dot.Fill = if ($rsVal -eq "High") {
            [System.Windows.Media.Brushes]::Red
        } else {
            [System.Windows.Media.Brushes]::Gold
        }
        $dot.ToolTip = if ($rsVal -eq "High") { "Yüksek risk — sistemi ciddi etkiler" } else { "Orta risk" }
        [void]$contentPanel.Children.Add($dot)
    }

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $tweak.Name
    $lbl.VerticalAlignment = 'Center'
    [void]$contentPanel.Children.Add($lbl)

    $chk.Content = $contentPanel
    $chk.Foreground = [System.Windows.Media.Brushes]::White
    $chk.Style = $Win.Resources["ToggleSwitch"]

    $chk.Add_Click({
        $me = $this; $treeItem = $me.Parent.Parent; $tweakObj = $treeItem.Tag
        if ($me.IsChecked -and $tweakObj.Group) {
            $parentFolder = $treeItem.Parent 
            foreach ($sibling in $parentFolder.Items) {
                if ($sibling -ne $treeItem -and $sibling.Tag.Group -eq $tweakObj.Group) { (Get-CheckFromItem $sibling).IsChecked = $false }
            }
        }
        $currentParent = $treeItem.Parent
        while ($currentParent -is[System.Windows.Controls.TreeViewItem]) {
            $allChildrenChecked = $true
            foreach ($child in $currentParent.Items) {
                if (-not (Get-CheckFromItem $child).IsChecked) { $allChildrenChecked = $false; break }
            }
            $parentChk = Get-CheckFromItem $currentParent
            if ($parentChk) { $parentChk.IsChecked = $allChildrenChecked }
            $currentParent = $currentParent.Parent
        }
    })

    $stack.Children.Add($chk) | Out-Null
    $item.Header = $stack
    $item.Tag = $tweak 
    $item.ContextMenu = $Win.Resources["TweakItemMenu"]
    
    # --- TOOLTIP KONTROLÜ (GÜNCELLENDİ) ---
    $finalDesc = ""
    # 1. Eğer kod içinde (hardcoded) Description tanımlıysa onu al
    if ($tweak.Description) { $finalDesc = $tweak.Description }
    # 2. Eğer sağ tıkla sonradan eklenmiş bir açıklama varsa (JSON), onu tercih et (Override)
    if ($global:ItemDescriptions.ContainsKey($tweak.Name)) { $finalDesc = $global:ItemDescriptions[$tweak.Name] }
    
    if ($finalDesc) { Attach-ToolTip $chk $finalDesc }
    
    return $item
}

function Show-Privacy-Warning {
    # Eğer kullanıcı "Gösterme" dediyse direk çık
    if (-not $global:ShowPrivacyWarning) { return }

    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlPrivacyWarn)
        $winWarn = [Windows.Markup.XamlReader]::Load($reader)
        
        $chk = $winWarn.FindName('chkDontShowAgain')
        $btn = $winWarn.FindName('btnOk')
        
        $btn.Add_Click({
            if ($chk.IsChecked) {
                $global:ShowPrivacyWarning = $false
                Mark-ConfigDirty # Tercihi kaydet
            }
            $winWarn.Close()
        })
        
        $winWarn.ShowDialog() | Out-Null
    } catch { WpfLog "❌ [HATA] Gizlilik uyarısı: $($_.Exception.Message)" }
}

function Apply-System-Tweaks {
    Refresh-PowerCfg-Cache
    $toEnable = New-Object System.Collections.ArrayList
    $toDisable = New-Object System.Collections.ArrayList
    
    $script:latencyChanged = $false

    function Scan-Nodes($nodes) {
        foreach ($node in $nodes) {
            if ($node.Tag -is[System.Collections.IDictionary] -or $node.Tag -is [System.Management.Automation.PSCustomObject]) {
                $tweak = $node.Tag
                if ($tweak.Name) {
                    $chk = Get-CheckFromItem $node
                    $isCurrentlyApplied = $false
                    try {
                        if (Get-Tweak-IsActive $tweak) { $isCurrentlyApplied = $true }
                        elseif ($tweak.Batch) {
                            $batchResult = $true
                            foreach ($sub in $tweak.Batch) { if (-not (Get-Tweak-IsActive $sub)) { $batchResult = $false; break } }
                            $isCurrentlyApplied = $batchResult
                        }
                    } catch { $isCurrentlyApplied = $false }

                    if ($chk.IsChecked -and -not $isCurrentlyApplied) { $toEnable.Add($tweak) | Out-Null }
                    elseif (-not $chk.IsChecked -and $isCurrentlyApplied) { $toDisable.Add($tweak) | Out-Null }
                }
            }
            if ($node.Items.Count -gt 0) { Scan-Nodes $node.Items }
        }
    }
    
    Scan-Nodes $tvTweaks.Items
    
    $totalOps = $toEnable.Count + $toDisable.Count
    if ($totalOps -eq 0) {[System.Windows.MessageBox]::Show("Herhangi bir değişiklik yapılmadı. Sistem zaten seçimlerinizle aynı durumda.", "Bilgi") | Out-Null; return }
    
    # --- MESAJ GÜNCELLEMESİ (Daha Anlaşılır) ---
    $msg = "Seçimleriniz (Açık/Kapalı durumları) sisteminizle eşitlenecek.`n`n"
    if ($toEnable.Count -gt 0) { $msg += "✅ $($toEnable.Count) ayar UYGULANACAK (Açılacak).`n" }
    if ($toDisable.Count -gt 0) { $msg += "❌ $($toDisable.Count) ayar GERİ ALINACAK (Varsayılana dönecek).`n" }
    $msg += "`nDevam edilsin mi?"
    
    if ([System.Windows.MessageBox]::Show($msg, "Tweak Eşitleme Onayı", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question) -ne 'Yes') { return }

    # --- YÜKSEK RİSK UYARISI (Sprint 4.4) ---
    # Risk="High" olan tweak'ler icin ek onay (sadece Apply icin, Undo'da risk yok)
    $highRiskApply = @($toEnable | Where-Object { "$($_.Risk)" -eq "High" })
    if ($highRiskApply.Count -gt 0) {
        $names = ($highRiskApply | ForEach-Object { "  • $($_.Name)" }) -join "`n"
        $hrMsg = "DİKKAT — Yüksek riskli ayar(lar) uygulanacak:`n`n$names`n`n" +
                 "Bu ayarlar sistem davranışını ciddi şekilde değiştirebilir veya geri alma gerektirebilir.`n`n" +
                 "Devam etmek istiyor musunuz?"
        if ([System.Windows.MessageBox]::Show($hrMsg, "Yüksek Risk Onayı", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -ne 'Yes') {
            WpfLog "[İPTAL] Yüksek riskli ayar onayı reddedildi."
            return
        }
    }

    # --- VENDOR UYUMSUZLUK UYARISI ---
    # Vendor="NVIDIA"|"AMD" tagli tweak'lerin sistemdeki GPU ile uyumlu olup olmadigini kontrol eder.
    # Sadece Apply icin (Undo'da dokunmuyoruz, halihazirda yazilmis registry'leri silmek genelde guvenli).
    $vendorMismatch = @($toEnable | Where-Object {
        $_.Vendor -and ((Get-System-Gpu-Vendors) -notcontains $_.Vendor)
    })
    if ($vendorMismatch.Count -gt 0) {
        $sysVendors = Get-System-Gpu-Vendors
        $sysList = if ($sysVendors.Count -gt 0) { $sysVendors -join ", " } else { "Algılanmadı" }
        $vmList  = ($vendorMismatch | ForEach-Object { "  • $($_.Name) (gerekli: $($_.Vendor))" }) -join "`n"
        $vmMsg   = "DİKKAT — GPU uyumsuzluğu tespit edildi:`n`n$vmList`n`n" +
                   "Sisteminizde algılanan GPU(lar): $sysList`n`n" +
                   "Bu ayar(lar) farklı bir GPU üreticisi için tasarlanmış. Yine de uygulansın mı?`n" +
                   "(Hibrit sistemler için — örn. dizüstü Intel+NVIDIA — devam edebilirsiniz.)"
        if ([System.Windows.MessageBox]::Show($vmMsg, "GPU Uyumsuzluk Uyarısı", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -ne 'Yes') {
            WpfLog "[İPTAL] GPU uyumsuzluk uyarisi reddedildi."
            return
        }
    }

    # Sistem Geri Yukleme: mode gore sor/olustur/atla. Cancel ise tweak islemi durur.
    $rpOK = Create-Restore-Point "Tweak Islemleri"
    if (-not $rpOK) {
        WpfLog "--- TWEAK ISLEMI IPTAL EDILDI ---"
        return
    }

    WpfLog "--- TWEAK İŞLEMİ BAŞLATILIYOR ---"
    # Restart Explorer mantigi 3 seviyeli:
    #   $false / null  → hicbir sey yapma
    #   "Soft" / $true → SHChangeNotify + WM_SETTINGCHANGE broadcast (acik pencereler refresh)
    #   "Hard"         → explorer.exe'yi kill et + /factory ile yeniden baslat (taskbar/desktop yenilenir)
    # Geriye uyumluluk: $true → Hard kabul edilir (mevcut config'lerde kalmis olabilir)
    $script:needsRestart    = $false  # Hard restart bayragi
    $script:needsSoftRefresh = $false # Soft refresh bayragi

    function Process-TweakItem($tweakItem, $isUndo) {
        $actionName = if ($isUndo) { "Geri Alınıyor" } else { "Uygulanıyor" }
        WpfLog "$actionName : $($tweakItem.Name)"
        Do-Events

        # RestartExplorer field'ini parse et — "Hard" / $true → hard, "Soft" → soft
        $rpAction = $null
        if ($tweakItem.RestartExplorer) {
            $val = "$($tweakItem.RestartExplorer)"
            if ($val -eq "Hard" -or $val -eq "True") { $rpAction = "Hard" }
            elseif ($val -eq "Soft") { $rpAction = "Soft" }
        }
        if     ($rpAction -eq "Hard") { $script:needsRestart    = $true }
        elseif ($rpAction -eq "Soft") { $script:needsSoftRefresh = $true }
        
        if ($tweakItem.Group -eq "NetProfile" -or 
            $tweakItem.SubCategory -match "Giriş ve İşlemci" -or 
            $tweakItem.SubCategory -match "Ağ ve Ping" -or 
            $tweakItem.SubCategory -match "Zamanlayıcı" -or
            $tweakItem.Name -match "TCP" -or 
            $tweakItem.Name -match "Win32" -or
            $tweakItem.Name -match "HPET") {
            
            $script:latencyChanged = $true
        }
        
        $batchList = if ($tweakItem.Batch) { $tweakItem.Batch } else { @($tweakItem) }
        
        foreach ($sub in $batchList) {
            try {
                if ($isUndo -and $sub.UndoCommand) {
                    # NetProfile komutları UI thread'ini bloklayabilir — önce UI'ı flush et
                    if ($sub.Group -eq "NetProfile") { Do-Events; Start-Sleep -Milliseconds 50; Do-Events }
                    # GÜVENLİ ÇALIŞTIRMA: Invoke-Expression yerine ScriptBlock kullan
                    $sb = [ScriptBlock]::Create($sub.UndoCommand)
                    & $sb
                }
                elseif (-not $isUndo -and $sub.Command) {
                    if ($sub.Group -eq "NetProfile") { Do-Events; Start-Sleep -Milliseconds 50; Do-Events }
                    # GÜVENLİ ÇALIŞTIRMA: Invoke-Expression yerine ScriptBlock kullan
                    $sb = [ScriptBlock]::Create($sub.Command)
                    & $sb
                }
                elseif ($sub.Key) {
                    $targetValue = if ($isUndo) { $sub.Undo } else { $sub.Data }
                    if ($targetValue -eq "DELETE_KEY") { 
                        if ($sub.ValueName) { if (Test-Path $sub.Key) { Remove-ItemProperty -Path $sub.Key -Name $sub.ValueName -ErrorAction SilentlyContinue } } 
                        else { if (Test-Path $sub.Key) { Remove-Item -Path $sub.Key -Force -Recurse -ErrorAction Stop } }
                    } 
                    elseif ($targetValue -eq "DELETE_VALUE") { if (Test-Path $sub.Key) { Remove-ItemProperty -Path $sub.Key -Name $sub.ValueName -ErrorAction SilentlyContinue } }
                    else {
                        if (-not (Test-Path $sub.Key)) { try { New-Item -Path $sub.Key -Force -ErrorAction Stop | Out-Null } catch { continue } }
                        if ([string]::IsNullOrEmpty($sub.ValueName)) { Set-Item -Path $sub.Key -Value $targetValue -Force -ErrorAction Stop } 
                        else { Set-ItemProperty -Path $sub.Key -Name $sub.ValueName -Value $targetValue -Type $sub.Type -Force -ErrorAction Stop }
                    }
                }
            } catch { 
                $errTitle = if ($isUndo) { "Geri Alma" } else { "Uygulama" }
                $errMsg = $_.Exception.Message
                
                # Sadece kritik hataları göster
                if ($errMsg -match "Access is denied" -or $errMsg -match "Erişim engellendi") {
                    WpfLog "🛡️ [YETKİ HATASI] $actionName ($($tweakItem.Name)): Registry erişimi engellendi."
                } else {
                    WpfLog "❌ [HATA] $actionName ($($tweakItem.Name)): $errMsg"
                }
            }
        }
    }

    foreach ($t in $toDisable) { Process-TweakItem $t $true }
    foreach ($t in $toEnable) { Process-TweakItem $t $false }

    # --- QUICK UNDO için snapshot (Sprint 4.3) ---
    $global:LastTweakOperation = [ordered]@{
        Applied = @($toEnable)
        Undone  = @($toDisable)
        Time    = (Get-Date).ToString("o")
    }
    if ($btnQuickUndo) { $btnQuickUndo.IsEnabled = ($toEnable.Count + $toDisable.Count -gt 0) }

    # --- AUDIT LOG (Bonus E1) ---
    Write-TweakAuditLog -Operation "Apply" -Applied $toEnable -Undone $toDisable

    WpfLog "--- İŞLEM TAMAMLANDI ---"
    
    # --- ÖNCE / SONRA KARŞILAŞTIRMA RAPORU ---
    $appliedCount  = ($toEnable  | Where-Object { $_ }).Count
    $revertedCount = ($toDisable | Where-Object { $_ }).Count
    
    if ($appliedCount -gt 0 -or $revertedCount -gt 0) {
        WpfLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        WpfLog "📊 UYGULAMA ÖZETİ"
        WpfLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if ($appliedCount -gt 0) {
            WpfLog "✅ UYGULANAN ($appliedCount adet):"
            foreach ($t in $toEnable) {
                WpfLog "   + $($t.Name)"
            }
        }
        if ($revertedCount -gt 0) {
            WpfLog "↩️  GERİ ALINAN ($revertedCount adet):"
            foreach ($t in $toDisable) {
                WpfLog "   - $($t.Name)"
            }
        }
        WpfLog "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    }
    
    # Cache'i invalidate et — sistem durumu degisti, eski cache stale
    $global:TweakStatusCache = @{}
    try {
        $cachePath = Get-TweakStatusCachePath
        if ($cachePath -and (Test-Path $cachePath)) { Remove-Item $cachePath -Force -ErrorAction SilentlyContinue }
    } catch {}

    $btnCheckTweaks.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))

    # 1) ONCE Soft refresh — sessizce, kullaniciya sormadan yapilir (gorunum tweak'leri)
    if ($script:needsSoftRefresh) {
        Invoke-ShellSoftRefresh
    }

    # 2) Restart dialog — latencyChanged en agir, sonra hard restart, sonra hicbir sey
    if ($script:latencyChanged) {
        Show-RestartDialog
    }
    elseif ($script:needsRestart) {
        $msg = "Bu degisiklikler icin Windows Gezgini'nin yeniden baslatilmasi gerekiyor.`n`n" +
               "Acik Explorer pencereleri kapatilacak (taskbar/desktop yenilenecek).`n`n" +
               "Simdi yapilsin mi?"
        if ([System.Windows.MessageBox]::Show($msg, "Explorer Yeniden Baslat", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question) -eq 'Yes') {
            Invoke-ExplorerHardRestart
        } else {
            WpfLog "[BILGI] Kullanici yeniden baslatmayi erteledi. Bazi degisiklikler bir sonraki oturum acmada uygulanacak."
        }
    }
}

function Show-TweakManager {
    param($TargetTweak = $null)
    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlTweakMgr)
        $winTM = [Windows.Markup.XamlReader]::Load($reader)
        
        # Kontroller
        $lst = $winTM.FindName('lstTweaks')
        $txtName = $winTM.FindName('txtName')
        $cbCategory = $winTM.FindName('cbCategory')
        $txtSubCat = $winTM.FindName('txtSubCat')
        $txtGroup = $winTM.FindName('txtGroup')
        $txtTweakDesc = $winTM.FindName('txtTweakDesc') # YENİ AÇIKLAMA KUTUSU
        
        $rbReg = $winTM.FindName('rbReg')
        $rbCmd = $winTM.FindName('rbCmd')
        $rbBatch = $winTM.FindName('rbBatch')
        $rbDns = $winTM.FindName('rbDns')
        
        $pnlReg = $winTM.FindName('pnlRegistry')
        $pnlCmd = $winTM.FindName('pnlCommand')
        $pnlBatch = $winTM.FindName('pnlBatch')
        $pnlDns = $winTM.FindName('pnlDns')
        
        $txtKey = $winTM.FindName('txtKey')
        $txtValueName = $winTM.FindName('txtValueName')
        $cbType = $winTM.FindName('cbType')
        $txtData = $winTM.FindName('txtData')
        $txtUndo = $winTM.FindName('txtUndo')
        
        $txtCommand = $winTM.FindName('txtCommand')
        $txtUndoCommand = $winTM.FindName('txtUndoCommand')
        
        $txtBatchInput = $winTM.FindName('txtBatchInput')
        $txtRawInput = $winTM.FindName('txtRawInput')
        $btnConvert = $winTM.FindName('btnConvert')
        $btnValidate = $winTM.FindName('btnValidate')
        
        $txtDns1 = $winTM.FindName('txtDns1')
        $txtDns2 = $winTM.FindName('txtDns2')
        $chkDnsIPv6 = $winTM.FindName('chkDnsIPv6')
        $grdIPv6 = $winTM.FindName('grdIPv6')
        $txtDns6_1 = $winTM.FindName('txtDns6_1')
        $txtDns6_2 = $winTM.FindName('txtDns6_2')
        
        $btnSave = $winTM.FindName('btnSaveTweak')
        $btnNew = $winTM.FindName('btnNewTweak')
        $btnDel = $winTM.FindName('btnDelTweak')

        # YENİ KONTROLLER (Sprint 3)
        $btnClone        = $winTM.FindName('btnCloneTweak')
        $cbRestartMode   = $winTM.FindName('cbRestartMode')
        $cbRiskLevel     = $winTM.FindName('cbRiskLevel')
        $txtPreview      = $winTM.FindName('txtPreview')
        $btnPreviewRfsh  = $winTM.FindName('btnPreviewRefresh')

        # Placeholder Mantığı
        $placeholderText = "Örnek Girişler:`n1. Yöntem:`nreg add `"HKEY_CURRENT_USER\Software\Test`" /v Ornek /t REG_DWORD /d 0 /f`n`n2. Yöntem (.reg dosyası içeriği):`n[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OneDrive]`n`"DisableFileSyncNGSC`"=dword:00000001"
        $txtRawInput.Text = $placeholderText
        $txtRawInput.Foreground =[System.Windows.Media.Brushes]::Gray
        
        $txtRawInput.Add_GotFocus({ if ($this.Text -eq $placeholderText) { $this.Text = ""; $this.Foreground = [System.Windows.Media.Brushes]::White } })
        $txtRawInput.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = $placeholderText; $this.Foreground =[System.Windows.Media.Brushes]::Gray } })

        $btnConvert.Add_Click({
            $rawText = $txtRawInput.Text
            if ([string]::IsNullOrWhiteSpace($rawText) -or $rawText -eq $placeholderText) { return }
            
            $convertedList = @()
            $currentRegKey = ""
            $lines = $rawText -split "`n"
            
            foreach ($line in $lines) {
                $l = $line.Trim()
                if ([string]::IsNullOrWhiteSpace($l) -or $l.StartsWith(";")) { continue }

                if ($l -match "^\[(.*)\]$") { 
                    $currentRegKey = $Matches[1] -replace "HKEY_LOCAL_MACHINE", "HKLM:" -replace "HKEY_CURRENT_USER", "HKCU:"
                    continue 
                }

                if ($currentRegKey -ne "" -and $l -match '^"([^"]+)"=(.*)$') {
                     $vName = $Matches[1]; $vDataRaw = $Matches[2].Trim()
                     $vType = "String"; $vData = $vDataRaw -replace '"', ''
                     if ($vDataRaw -match "dword:([0-9a-fA-F]+)") { $vType = "DWord"; $vData = [Convert]::ToInt32($Matches[1], 16) }
                     $undoVal = if ($vData -eq 0) { 1 } else { 0 }
                     $convertedList += [ordered]@{ ValueName = $vName; Undo = $undoVal; Key = $currentRegKey; Data = $vData; Type = $vType }
                }

                if ($l -match 'reg add\s+"?([^"]+)"?\s+/v\s+"?([^"]+)"?\s+/t\s+(\w+)\s+/d\s+"?([^"/]+)"?') {
                    $rKey = $Matches[1] -replace "HKEY_LOCAL_MACHINE", "HKLM:" -replace "HKEY_CURRENT_USER", "HKCU:"
                    $rValName = $Matches[2]; $rTypeRaw = $Matches[3]; $rDataRaw = $Matches[4].Trim() -replace '"', ''
                    $rType = "String"; $rData = $rDataRaw
                    if ($rTypeRaw -eq "REG_DWORD") { $rType = "DWord"; $rData = [int]$rDataRaw }
                    $rUndo = if ($rData -eq 0) { 1 } else { 0 }
                    $convertedList += [ordered]@{ ValueName = $rValName; Undo = $rUndo; Key = $rKey; Data = $rData; Type = $rType }
                }
            }
            if ($convertedList.Count -gt 0) { $txtBatchInput.Text = $convertedList | ConvertTo-Json -Depth 5 } 
            else { [System.Windows.MessageBox]::Show("Geçerli format bulunamadı.", "Hata") | Out-Null }
        })

        $btnValidate.Add_Click({
            try {
                if ([string]::IsNullOrWhiteSpace($txtBatchInput.Text)) { throw "Kutu boş." }
                $testObj = $txtBatchInput.Text | ConvertFrom-Json
                $count = if ($testObj -is [Array]) { $testObj.Count } else { 1 }[System.Windows.MessageBox]::Show("✔ JSON Yapısı Geçerli!`nToplam İşlem Sayısı: $count", "Onaylandı") | Out-Null
            } catch { [System.Windows.MessageBox]::Show("❌ JSON Formatı HATALI!`n$($_.Exception.Message)", "Hata", [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null }
        })

        $global:TweakList.Keys | ForEach-Object { $cbCategory.Items.Add($_) | Out-Null }
        
        function Refresh-List { 
            $lst.Items.Clear()
            foreach ($cat in $global:TweakList.Keys) { 
                foreach ($t in $global:TweakList[$cat]) { 
                    $lItem = New-Object System.Windows.Controls.ListBoxItem
                    $lItem.Content = "$cat - $($t.Name)"
                    $lItem.Tag = $t
                    $lst.Items.Add($lItem) | Out-Null 
                } 
            } 
        }
        Refresh-List
        
        $rbReg.Add_Checked({ $pnlReg.Visibility='Visible'; $pnlCmd.Visibility='Collapsed'; $pnlBatch.Visibility='Collapsed'; $pnlDns.Visibility='Collapsed' })
        $rbCmd.Add_Checked({ $pnlReg.Visibility='Collapsed'; $pnlCmd.Visibility='Visible'; $pnlBatch.Visibility='Collapsed'; $pnlDns.Visibility='Collapsed' })
        $rbBatch.Add_Checked({ $pnlReg.Visibility='Collapsed'; $pnlCmd.Visibility='Collapsed'; $pnlBatch.Visibility='Visible'; $pnlDns.Visibility='Collapsed' })
        $rbDns.Add_Checked({ $pnlReg.Visibility='Collapsed'; $pnlCmd.Visibility='Collapsed'; $pnlBatch.Visibility='Collapsed'; $pnlDns.Visibility='Visible' })
        $chkDnsIPv6.Add_Click({ if ($chkDnsIPv6.IsChecked) { $grdIPv6.IsEnabled=$true; $grdIPv6.Opacity=1 } else { $grdIPv6.IsEnabled=$false; $grdIPv6.Opacity=0.5 } })

        # Liste Seçimi (Yükleme)
        $lst.Add_SelectionChanged({
            if ($lst.SelectedIndex -ne -1) {
                $selTweak = $lst.SelectedItem.Tag
                $txtName.Text = $selTweak.Name
                $cbCategory.Text = $global:TweakList.Keys | Where-Object { $global:TweakList[$_] -contains $selTweak }
                
                $txtSubCat.Text = if ($selTweak.SubCategory) { $selTweak.SubCategory } else { "" }
                $txtGroup.Text = if ($selTweak.Group) { $selTweak.Group } else { "" }
                
                # --- YENİ EKLENEN: AÇIKLAMAYI (TOOLTIP) GETİR (DÜZELTİLDİ) ---
                if ($global:ItemDescriptions.ContainsKey($selTweak.Name)) {
                    # 1. Öncelik: Kullanıcının sonradan düzenleyip kaydettiği açıklama
                    $txtTweakDesc.Text = $global:ItemDescriptions[$selTweak.Name]
                } elseif ($selTweak.Description) {
                    # 2. Öncelik: Kodun içine gömülü orijinal (fabrika çıkışı) açıklama
                    $txtTweakDesc.Text = $selTweak.Description
                } else {
                    # Hiçbiri yoksa boş bırak
                    $txtTweakDesc.Text = ""
                }

                # RestartExplorer: 3 değerli mapping
                $rpVal = "$($selTweak.RestartExplorer)"
                if     ($rpVal -eq "Hard" -or $rpVal -eq "True") { $cbRestartMode.SelectedIndex = 2 }
                elseif ($rpVal -eq "Soft")                       { $cbRestartMode.SelectedIndex = 1 }
                else                                             { $cbRestartMode.SelectedIndex = 0 }

                # Risk seviyesi: Low/Medium/High → 0/1/2
                $rsVal = "$($selTweak.Risk)"
                if     ($rsVal -eq "High")   { $cbRiskLevel.SelectedIndex = 2 }
                elseif ($rsVal -eq "Medium") { $cbRiskLevel.SelectedIndex = 1 }
                else                         { $cbRiskLevel.SelectedIndex = 0 }

                if ($selTweak.Command -match "Set-DnsClientServerAddress" -and -not $selTweak.Batch) {
                    $rbDns.IsChecked = $true
                    if ($selTweak.Command -match "-ServerAddresses \((.*?)\)") {
                        $ips = $Matches[1] -split "," | ForEach-Object { $_.Trim().Trim("'").Trim('"') }
                        $txtDns1.Text = $ips[0]; $txtDns2.Text = $ips[1]
                        if ($ips.Count -gt 2) { 
                            $chkDnsIPv6.IsChecked = $true; $grdIPv6.IsEnabled = $true; $grdIPv6.Opacity = 1
                            $txtDns6_1.Text = $ips[2]; $txtDns6_2.Text = $ips[3] 
                        } else {
                            $chkDnsIPv6.IsChecked = $false; $grdIPv6.IsEnabled = $false; $grdIPv6.Opacity = 0.5
                            $txtDns6_1.Text = ""; $txtDns6_2.Text = ""
                        }
                    }
                } elseif ($selTweak.Batch) { 
                    $rbBatch.IsChecked = $true; $txtBatchInput.Text = $selTweak.Batch | ConvertTo-Json -Depth 5 
                } elseif ($selTweak.Key) { 
                    $rbReg.IsChecked = $true
                    $txtKey.Text = $selTweak.Key; $txtValueName.Text = $selTweak.ValueName
                    $cbType.Text = $selTweak.Type; $txtData.Text = $selTweak.Data; $txtUndo.Text = $selTweak.Undo
                } else {
                    $rbCmd.IsChecked = $true
                    $txtCommand.Text = $selTweak.Command; $txtUndoCommand.Text = $selTweak.UndoCommand
                }

                # Selection değişimi sonrası önizlemeyi güncelle
                Update-TweakPreview
            }
        })

        # ÖNİZLEME üreten yardımcı (form alanlarından okur)
        # Tek registry value icin "su an sistemde ne var?" oku
        function Get-CurrentRegistryValue($key, $valueName) {
            if ([string]::IsNullOrWhiteSpace($key)) { return @{ Status="EMPTY"; Value=$null } }
            if (-not (Test-Path $key)) { return @{ Status="NOKEY"; Value=$null } }
            try {
                if ([string]::IsNullOrEmpty($valueName)) {
                    $prop = Get-ItemProperty -Path $key -ErrorAction Stop
                    $val = $prop.'(default)'
                } else {
                    $prop = Get-ItemProperty -Path $key -Name $valueName -ErrorAction Stop
                    $val = $prop.$valueName
                }
                if ($null -eq $val) { return @{ Status="NOVALUE"; Value=$null } }
                # Binary array ise hex string'e cevir (ilk 16 byte)
                if ($val -is [byte[]]) {
                    $hex = ($val | Select-Object -First 16 | ForEach-Object { "{0:X2}" -f $_ }) -join " "
                    if ($val.Length -gt 16) { $hex += " ..." }
                    return @{ Status="OK"; Value=$hex }
                }
                return @{ Status="OK"; Value=$val }
            } catch {
                return @{ Status="NOVALUE"; Value=$null }
            }
        }

        # "su an" / "apply" / "undo" durumunu yorumla → Aktif / Pasif / Farkli
        function Get-RegistryDiffStatus($current, $applyVal, $undoVal) {
            if ($null -eq $current) { return "⚪ UYGULANMAMIS (deger yok)" }
            $curStr = "$current"
            if ($curStr -eq "$applyVal") { return "✅ AKTIF (Apply degeriyle uyusuyor)" }
            if ($curStr -eq "$undoVal")  { return "⚪ UYGULANMAMIS (Undo degeriyle uyusuyor)" }
            return "❓ FARKLI ($curStr — Apply'a da Undo'ya da uymuyor)"
        }

        function Update-TweakPreview {
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.AppendLine("Ad: $($txtName.Text)")
            $rpIdx = $cbRestartMode.SelectedIndex
            $rpStr = @("Yok","Soft (refresh)","Hard (restart)")[$rpIdx]
            $rsIdx = $cbRiskLevel.SelectedIndex
            $rsStr = @("Düşük","Orta","Yüksek")[$rsIdx]
            [void]$sb.AppendLine("Restart: $rpStr  •  Risk: $rsStr")
            [void]$sb.AppendLine("─────────────────────────")

            if ($rbReg.IsChecked) {
                [void]$sb.AppendLine("[Registry]")
                [void]$sb.AppendLine("Key:   $($txtKey.Text)")
                [void]$sb.AppendLine("Value: $($txtValueName.Text)  ($($cbType.Text))")
                [void]$sb.AppendLine("")

                $cur = Get-CurrentRegistryValue $txtKey.Text $txtValueName.Text
                switch ($cur.Status) {
                    "EMPTY"   { [void]$sb.AppendLine("📌 SU AN sistemde: (Key alani bos)") }
                    "NOKEY"   { [void]$sb.AppendLine("📌 SU AN sistemde: KEY YOK (yeni olusturulacak)") }
                    "NOVALUE" { [void]$sb.AppendLine("📌 SU AN sistemde: VALUE YOK (yeni olusturulacak)") }
                    "OK"      { [void]$sb.AppendLine("📌 SU AN sistemde: $($cur.Value)") }
                }
                [void]$sb.AppendLine("✅ Apply edilirse: $($txtData.Text)")
                [void]$sb.AppendLine("↶  Undo edilirse:  $($txtUndo.Text)")

                if ($cur.Status -eq "OK") {
                    [void]$sb.AppendLine("")
                    [void]$sb.AppendLine("DURUM: $(Get-RegistryDiffStatus $cur.Value $txtData.Text $txtUndo.Text)")
                }
            } elseif ($rbCmd.IsChecked) {
                [void]$sb.AppendLine("[Komut]")
                [void]$sb.AppendLine("Apply  → $($txtCommand.Text)")
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine("Undo   → $($txtUndoCommand.Text)")
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine("(Komut tipi tweak'lerde mevcut sistem degeri otomatik tespit edilemez)")
            } elseif ($rbBatch.IsChecked) {
                [void]$sb.AppendLine("[Batch] (toplu islem)")
                try {
                    $batch = $txtBatchInput.Text | ConvertFrom-Json -ErrorAction Stop
                    $arr = @($batch)
                    [void]$sb.AppendLine("Toplam alt-islem: $($arr.Count)")
                    [void]$sb.AppendLine("")
                    $idx = 0
                    foreach ($b in $arr | Select-Object -First 5) {
                        $idx++
                        if ($b.Key) {
                            $cur = Get-CurrentRegistryValue $b.Key $b.ValueName
                            $curTxt = switch ($cur.Status) {
                                "NOKEY"   { "(key yok)" }
                                "NOVALUE" { "(value yok)" }
                                "OK"      { "$($cur.Value)" }
                                default   { "?" }
                            }
                            [void]$sb.AppendLine("  $idx) $($b.ValueName)")
                            [void]$sb.AppendLine("     SU AN: $curTxt   →   APPLY: $($b.Data)   |   UNDO: $($b.Undo)")
                        } elseif ($b.Command) {
                            $cmdShort = if ($b.Command.Length -gt 80) { $b.Command.Substring(0,80) + "..." } else { $b.Command }
                            [void]$sb.AppendLine("  $idx) CMD: $cmdShort")
                        }
                    }
                    if ($arr.Count -gt 5) { [void]$sb.AppendLine("  (+ $($arr.Count - 5) tane daha — Batch JSON'da hepsi var)") }
                } catch {
                    [void]$sb.AppendLine("⚠ Gecersiz JSON: $($_.Exception.Message)")
                }
            } elseif ($rbDns.IsChecked) {
                [void]$sb.AppendLine("[DNS]")
                [void]$sb.AppendLine("Hedef IPv4: $($txtDns1.Text), $($txtDns2.Text)")
                if ($chkDnsIPv6.IsChecked) {
                    [void]$sb.AppendLine("Hedef IPv6: $($txtDns6_1.Text), $($txtDns6_2.Text)")
                }
                [void]$sb.AppendLine("")
                # Mevcut sistem DNS'ini oku
                try {
                    $curList = Get-DnsClientServerAddress -ErrorAction SilentlyContinue |
                        Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses.Count -gt 0 -and $_.InterfaceAlias -notmatch "Loopback|VPN|Virtual|Tunnel" } |
                        Select-Object -First 3
                    if ($curList) {
                        [void]$sb.AppendLine("📌 SU AN aktif DNS sunuculari:")
                        foreach ($d in $curList) {
                            [void]$sb.AppendLine("   • $($d.InterfaceAlias): $($d.ServerAddresses -join ', ')")
                        }
                    } else {
                        [void]$sb.AppendLine("📌 SU AN: DNS bilgisi alinamadi (DHCP olabilir)")
                    }
                } catch {
                    [void]$sb.AppendLine("📌 SU AN: DNS sorgu hatasi")
                }
            }
            $txtPreview.Text = $sb.ToString()
        }

        $btnPreviewRfsh.Add_Click({ Update-TweakPreview })

        # Klonla butonu — seçili tweak'i kopyala, "(Kopya)" ekiyle yeni isim
        $btnClone.Add_Click({
            if ($lst.SelectedIndex -lt 0) {
                [System.Windows.MessageBox]::Show("Önce bir ayar seçin.", "Klonla") | Out-Null
                return
            }
            # Mevcut formu olduğu gibi bırak, sadece adı değiştir ve yeni kayıt yapılacak gibi seçimi sıfırla
            $txtName.Text = "$($txtName.Text) (Kopya)"
            $lst.SelectedIndex = -1
            Update-TweakPreview
        })

        $btnNew.Add_Click({
            $lst.SelectedIndex = -1; $txtName.Text = ""; $txtKey.Text=""; $txtData.Text=""; $txtCommand.Text=""; $txtBatchInput.Text=""
            $txtSubCat.Text=""; $txtGroup.Text=""; $txtTweakDesc.Text="" # Açıklamayı da temizle
            $cbRestartMode.SelectedIndex = 0; $cbRiskLevel.SelectedIndex = 0
            $txtRawInput.Text = $placeholderText; $txtRawInput.Foreground = [System.Windows.Media.Brushes]::Gray
            Update-TweakPreview
        })
        
        # KAYDET BUTONU (Sprint 3.2 + 3.4: schema validate + conflict check)
        $btnSave.Add_Click({
            $catName = $cbCategory.Text
            # --- TEMEL VALIDATION ---
            if ([string]::IsNullOrWhiteSpace($txtName.Text)) {
                [System.Windows.MessageBox]::Show("'Ad' alanı zorunludur.", "Eksik Bilgi", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            if ([string]::IsNullOrWhiteSpace($catName)) {
                [System.Windows.MessageBox]::Show("'Kategori' alanı zorunludur.", "Eksik Bilgi", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            if (-not $cbCategory.Items.Contains($catName)) { $cbCategory.Items.Add($catName) | Out-Null }

            # RestartExplorer mapping (cbRestartMode.SelectedIndex → string)
            $rpStrMap = @($false, "Soft", "Hard")
            $rpVal = $rpStrMap[$cbRestartMode.SelectedIndex]

            # Risk mapping
            $rsStrMap = @("Low", "Medium", "High")
            $rsVal = $rsStrMap[$cbRiskLevel.SelectedIndex]

            $newObj = [ordered]@{ Name = $txtName.Text; RestartExplorer = $rpVal; Risk = $rsVal }
            if ($txtSubCat.Text) { $newObj["SubCategory"] = $txtSubCat.Text }
            if ($txtGroup.Text)  { $newObj["Group"] = $txtGroup.Text }

            # --- TÜR-BAZLI ALANLAR ---
            if ($rbDns.IsChecked) {
                $ipList = @(); if ($txtDns1.Text) { $ipList += "'$($txtDns1.Text)'" }; if ($txtDns2.Text) { $ipList += "'$($txtDns2.Text)'" }
                if ($chkDnsIPv6.IsChecked) { if ($txtDns6_1.Text) { $ipList += "'$($txtDns6_1.Text)'" }; if ($txtDns6_2.Text) { $ipList += "'$($txtDns6_2.Text)'" } }
                if ($ipList.Count -lt 2) {
                    [System.Windows.MessageBox]::Show("DNS için en az 2 sunucu adresi gerekir.", "DNS", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    return
                }
                $ipString = $ipList -join ", "
                $newObj["Command"]     = "Get-NetAdapter | Where Status -eq Up | Set-DnsClientServerAddress -ServerAddresses ($ipString) -ErrorAction SilentlyContinue; ipconfig /flushdns > `$null"
                $newObj["UndoCommand"] = "Get-NetAdapter | Where Status -eq Up | Set-DnsClientServerAddress -ResetServerAddresses -ErrorAction SilentlyContinue; ipconfig /flushdns > `$null"
                $newObj["RestartExplorer"] = $false
            } elseif ($rbReg.IsChecked) {
                # Registry validation
                if ([string]::IsNullOrWhiteSpace($txtKey.Text)) {
                    [System.Windows.MessageBox]::Show("Registry için 'Key' alanı zorunludur.", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    return
                }
                if ($txtKey.Text -notmatch '^(HKCU|HKLM|HKCR|HKU|HKCC):\\') {
                    [System.Windows.MessageBox]::Show("Registry Key 'HKCU:\\...', 'HKLM:\\...' formatında olmalı.", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    return
                }
                if ([string]::IsNullOrWhiteSpace($cbType.Text)) {
                    [System.Windows.MessageBox]::Show("Registry için 'Tip' alanı zorunludur (DWord, String, Binary vb.).", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    return
                }
                $newObj["Key"] = $txtKey.Text; $newObj["ValueName"] = $txtValueName.Text; $newObj["Type"] = $cbType.Text; $newObj["Data"] = $txtData.Text; $newObj["Undo"] = $txtUndo.Text

                # --- CONFLICT DETECTION (Sprint 3.4) ---
                # Aynı Key+ValueName'i farklı bir tweak değiştiriyorsa uyar
                $conflicts = @()
                foreach ($cat in $global:TweakList.Keys) {
                    foreach ($t in $global:TweakList[$cat]) {
                        # Şu anki düzenlenen tweak'i atla
                        if ($lst.SelectedIndex -ge 0 -and $lst.SelectedItem.Tag -eq $t) { continue }
                        if ($t.Name -eq $txtName.Text) { continue }
                        if ($t.Key -eq $txtKey.Text -and "$($t.ValueName)" -eq "$($txtValueName.Text)") {
                            $conflicts += "$cat → $($t.Name) (Data=$($t.Data))"
                        }
                        # Batch içindeki sub-tweak'leri de kontrol et
                        if ($t.Batch) {
                            foreach ($sub in $t.Batch) {
                                if ($sub.Key -eq $txtKey.Text -and "$($sub.ValueName)" -eq "$($txtValueName.Text)") {
                                    $conflicts += "$cat → $($t.Name) [Batch] (Data=$($sub.Data))"
                                }
                            }
                        }
                    }
                }
                if ($conflicts.Count -gt 0) {
                    $msg = "Bu Key+ValueName başka ayar(lar)la çakışıyor:`n`n" + ($conflicts -join "`n") + "`n`nYine de kaydedilsin mi?"
                    if ([System.Windows.MessageBox]::Show($msg, "Çakışma Algılandı", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -ne 'Yes') {
                        return
                    }
                }
            } elseif ($rbCmd.IsChecked) {
                if ([string]::IsNullOrWhiteSpace($txtCommand.Text)) {
                    [System.Windows.MessageBox]::Show("Komut tipinde 'Command' alanı zorunludur.", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    return
                }
                $newObj["Command"] = $txtCommand.Text; $newObj["UndoCommand"] = $txtUndoCommand.Text
            } elseif ($rbBatch.IsChecked) {
                try {
                    if ([string]::IsNullOrWhiteSpace($txtBatchInput.Text)) { throw "Batch JSON kutusu boş." }
                    $rawJson = $txtBatchInput.Text | ConvertFrom-Json -ErrorAction Stop
                    $newObj["Batch"] = if ($rawJson.value) { $rawJson.value } else { @($rawJson) }
                } catch {
                    [System.Windows.MessageBox]::Show("Batch JSON geçersiz: $($_.Exception.Message)", "Validation", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                    return
                }
            }

            if (-not $global:TweakList.Contains($catName)) { $global:TweakList[$catName] = @() }
            
            # --- YENİ EKLENEN: AÇIKLAMAYI (TOOLTIP) KAYDET ---
            $newDesc = $txtTweakDesc.Text.Trim()
            if ($lst.SelectedIndex -ne -1) {
                $oldTweak = $lst.SelectedItem.Tag
                
                # Eğer isim değiştirildiyse, eski açıklamayı sil
                if ($oldTweak.Name -ne $txtName.Text) {
                    $global:ItemDescriptions.Remove($oldTweak.Name)
                }

                $oldCat = $global:TweakList.Keys | Where-Object { $global:TweakList[$_] -contains $oldTweak }
                $arr = [System.Collections.ArrayList]$global:TweakList[$oldCat]
                $arr.Remove($oldTweak)
                $global:TweakList[$oldCat] = $arr.ToArray()
            }

            # Açıklama boş değilse ekle, boşsa sil
            if ([string]::IsNullOrWhiteSpace($newDesc)) { $global:ItemDescriptions.Remove($txtName.Text) } 
            else { $global:ItemDescriptions[$txtName.Text] = $newDesc }

            $global:TweakList[$catName] += $newObj
            Mark-ConfigDirty; Refresh-List; Load-Tweak-Tree
            [System.Windows.MessageBox]::Show("Kaydedildi.") | Out-Null
        })
        
        # SİL BUTONU
        $btnDel.Add_Click({ 
            if ($lst.SelectedIndex -ne -1) { 
                $selTweak = $lst.SelectedItem.Tag
                $cat = $global:TweakList.Keys | Where-Object { $global:TweakList[$_] -contains $selTweak }
                $arr = [System.Collections.ArrayList]$global:TweakList[$cat]
                $arr.Remove($selTweak)
                $global:TweakList[$cat] = $arr.ToArray()
                
                # Silerken açıklamayı da JSON'dan temizle
                $global:ItemDescriptions.Remove($selTweak.Name)

                Mark-ConfigDirty; Refresh-List; Load-Tweak-Tree 
            } 
        })
        
        if ($TargetTweak) { foreach ($item in $lst.Items) { if ($item.Tag.Name -eq $TargetTweak.Name) { $lst.SelectedItem = $item; $lst.ScrollIntoView($item); break } } }
        $winTM.ShowDialog() | Out-Null
    } catch { WpfLog "TweakMgr Hata: $_" }
}

# =========================================================
# TWEAK AUDIT LOG (Bonus E1)
# Her Apply / Undo islemini timestamp + tweak listesiyle dosyaya yazar.
# Dosya: %APPDATA%\GeminiCare\tweak_history.log
# =========================================================
function Write-TweakAuditLog {
    param(
        [string]$Operation,  # "Apply", "QuickUndo", vb.
        $Applied = @(),
        $Undone  = @()
    )
    if (-not $AppDataPath) { return }
    $logPath = Join-Path $AppDataPath "tweak_history.log"
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("=== [$ts] $Operation ===")
        if ($Applied.Count -gt 0) {
            [void]$sb.AppendLine("UYGULANAN ($($Applied.Count) adet):")
            foreach ($t in $Applied) { [void]$sb.AppendLine("  + $($t.Name)") }
        }
        if ($Undone.Count -gt 0) {
            [void]$sb.AppendLine("GERI ALINAN ($($Undone.Count) adet):")
            foreach ($t in $Undone) { [void]$sb.AppendLine("  - $($t.Name)") }
        }
        [void]$sb.AppendLine("")
        Add-Content -Path $logPath -Value $sb.ToString() -Encoding UTF8 -ErrorAction SilentlyContinue

        # Dosya 5 MB'dan buyukse ilk yarisini kes
        if ((Test-Path $logPath) -and (Get-Item $logPath).Length -gt 5MB) {
            $lines = Get-Content $logPath
            $half = [int]($lines.Count / 2)
            Set-Content $logPath -Value ($lines | Select-Object -Skip $half) -Encoding UTF8
        }
    } catch {}
}

# =========================================================
# QUICK UNDO (Sprint 4.3)
# Son apply'i tersine cevirir: $global:LastTweakOperation kullanilir.
# Apply edilenlerin Undo'sunu, Undo edilenlerin Apply'ini calistirir.
# =========================================================
function Invoke-QuickUndo {
    if (-not $global:LastTweakOperation) {
        [System.Windows.MessageBox]::Show("Geri alinacak son islem yok.", "Bilgi") | Out-Null
        return
    }
    $op = $global:LastTweakOperation
    $applied = @($op.Applied)
    $undone  = @($op.Undone)
    $total = $applied.Count + $undone.Count
    if ($total -eq 0) { return }

    $msg = "Son tweak islemi tersine cevrilecek:`n`n" +
           "  • $($applied.Count) ayar GERI ALINACAK (Apply edilen → Undo)`n" +
           "  • $($undone.Count) ayar TEKRAR UYGULANACAK (Undo edilen → Apply)`n`n" +
           "Devam edilsin mi?"
    if ([System.Windows.MessageBox]::Show($msg, "Geri Al Onayi", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question) -ne 'Yes') {
        return
    }

    Refresh-PowerCfg-Cache
    WpfLog "--- QUICK UNDO BASLADI ---"

    # Process-TweakItem inline kopyasi (Apply-System-Tweaks icindeki nested fonksiyona disardan erisemiyoruz)
    function Invoke-TweakAction($tweakItem, [bool]$isUndo) {
        $actionName = if ($isUndo) { "Geri Aliniyor" } else { "Yeniden Uygulaniyor" }
        WpfLog "$actionName : $($tweakItem.Name)"
        Do-Events
        $batchList = if ($tweakItem.Batch) { $tweakItem.Batch } else { @($tweakItem) }
        foreach ($sub in $batchList) {
            try {
                if ($isUndo -and $sub.UndoCommand) {
                    & ([ScriptBlock]::Create($sub.UndoCommand))
                } elseif (-not $isUndo -and $sub.Command) {
                    & ([ScriptBlock]::Create($sub.Command))
                } elseif ($sub.Key) {
                    $targetValue = if ($isUndo) { $sub.Undo } else { $sub.Data }
                    if ($targetValue -eq "DELETE_KEY") {
                        if ($sub.ValueName) {
                            if (Test-Path $sub.Key) { Remove-ItemProperty -Path $sub.Key -Name $sub.ValueName -ErrorAction SilentlyContinue }
                        } else {
                            if (Test-Path $sub.Key) { Remove-Item -Path $sub.Key -Force -Recurse -ErrorAction Stop }
                        }
                    } elseif ($targetValue -eq "DELETE_VALUE") {
                        if (Test-Path $sub.Key) { Remove-ItemProperty -Path $sub.Key -Name $sub.ValueName -ErrorAction SilentlyContinue }
                    } else {
                        if (-not (Test-Path $sub.Key)) {
                            try { New-Item -Path $sub.Key -Force -ErrorAction Stop | Out-Null } catch { continue }
                        }
                        if ([string]::IsNullOrEmpty($sub.ValueName)) {
                            Set-Item -Path $sub.Key -Value $targetValue -Force -ErrorAction Stop
                        } else {
                            Set-ItemProperty -Path $sub.Key -Name $sub.ValueName -Value $targetValue -Type $sub.Type -Force -ErrorAction Stop
                        }
                    }
                }
            } catch {
                WpfLog "❌ [HATA] $actionName ($($tweakItem.Name)): $($_.Exception.Message)"
            }
        }
    }

    # Apply edilenler → Undo, Undone → Apply (TERSINE)
    foreach ($t in $applied) { Invoke-TweakAction $t $true  }
    foreach ($t in $undone)  { Invoke-TweakAction $t $false }

    WpfLog "--- QUICK UNDO TAMAMLANDI ---"
    Write-TweakAuditLog -Operation "QuickUndo" -Applied $undone -Undone $applied

    # Geri alindi → tek seferlik kullanilir, simdi temizle
    $global:LastTweakOperation = $null
    if ($btnQuickUndo) { $btnQuickUndo.IsEnabled = $false }

    # Cache'i invalidate et + UI'yi yenile
    $global:TweakStatusCache = @{}
    try {
        $cachePath = Get-TweakStatusCachePath
        if ($cachePath -and (Test-Path $cachePath)) { Remove-Item $cachePath -Force -ErrorAction SilentlyContinue }
    } catch {}
    Check-Tweak-Status -ForceRefresh
}

# =========================================================
# TWEAK STATUS CACHE — ASYNC CHUNKED SCAN
# - Cache dosyasi: %APPDATA%\GeminiCare\tweak_status_cache.json
# - TTL: 30 dakika
# - Anahtar formati: tweak.Name (cogu unique)
# - Chunked scan: her DispatcherTimer tick'inde 10 tweak isle, UI nefes alsin
# =========================================================
$global:TweakStatusCachePath = $null  # Load-All-Settings'ten sonra set edilir
$global:TweakStatusCacheTTL  = [TimeSpan]::FromMinutes(30)
$global:TweakStatusCache     = @{}
$script:TweakScanTimer       = $null

function Get-TweakStatusCachePath {
    if ($global:TweakStatusCachePath) { return $global:TweakStatusCachePath }
    if ($AppDataPath) { return (Join-Path $AppDataPath "tweak_status_cache.json") }
    return $null
}

function Load-TweakStatusCache {
    # Donus: hashtable (string→bool) veya $null (yok/expired/bozuk)
    $path = Get-TweakStatusCachePath
    if (-not $path -or -not (Test-Path $path)) { return $null }
    try {
        $raw = Get-Content $path -Raw -ErrorAction Stop | ConvertFrom-Json
        if (-not $raw -or -not $raw._timestamp) { return $null }
        $ts = [datetime]$raw._timestamp
        if ((Get-Date) - $ts -gt $global:TweakStatusCacheTTL) { return $null }
        $result = @{}
        if ($raw.results) {
            foreach ($prop in $raw.results.PSObject.Properties) {
                $result[$prop.Name] = [bool]$prop.Value
            }
        }
        return $result
    } catch { return $null }
}

function Save-TweakStatusCache($cacheMap) {
    $path = Get-TweakStatusCachePath
    if (-not $path) { return }
    try {
        $data = [ordered]@{
            _timestamp = (Get-Date).ToString("o")
            results    = $cacheMap
        }
        $data | ConvertTo-Json -Depth 4 | Set-Content $path -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

# Tweak agacindaki tum item'lari (sadece tweak olanlari) duz listeye topla
function Get-AllTweakItems {
    $list = New-Object System.Collections.ArrayList
    function Collect($nodes) {
        foreach ($item in $nodes) {
            if (($item.Tag -is [System.Collections.IDictionary] -or
                 $item.Tag -is [System.Management.Automation.PSCustomObject]) -and
                $item.Tag.Name) {
                [void]$list.Add($item)
            }
            if ($item.Items.Count -gt 0) { Collect $item.Items }
        }
    }
    Collect $tvTweaks.Items
    return $list
}

# Tek tweak icin "uygulanmis mi" hesapla (batch kontrolu dahil)
function Test-TweakApplied($tweak) {
    try {
        if (Get-Tweak-IsActive $tweak) { return $true }
        if ($tweak.Batch) {
            foreach ($sub in $tweak.Batch) {
                if (-not (Get-Tweak-IsActive $sub)) { return $false }
            }
            return $true
        }
    } catch {}
    return $false
}

# UI uzerinde tek tweak'i isaretle/temizle
function Set-TweakItemUI($item, $isApplied, [bool]$fromCache = $false) {
    $chk = Get-CheckFromItem $item
    if (-not $chk) { return }

    # Content StackPanel mi (yeni Risk dot pattern) yoksa string mi (eski/diger)
    $isPanel = $chk.Content -is [System.Windows.Controls.Panel]
    $lblTb   = $null
    if ($isPanel) {
        foreach ($child in $chk.Content.Children) {
            if ($child -is [System.Windows.Controls.TextBlock]) { $lblTb = $child; break }
        }
    }

    if ($isApplied) {
        $chk.IsChecked = $true
        $newColor = if ($fromCache) {
            [System.Windows.Media.Brushes]::ForestGreen
        } else {
            [System.Windows.Media.Brushes]::LimeGreen
        }
        $chk.Foreground = $newColor
        # "(Aktif)" suffix'i — ya TextBlock.Text'e ya da string content'e ekle
        if ($isPanel -and $lblTb) {
            if ($lblTb.Text -notmatch "\(Aktif\)") { $lblTb.Text = "$($lblTb.Text) (Aktif)" }
        } else {
            if ($chk.Content -notmatch "\(Aktif\)") { $chk.Content = "$($chk.Content) (Aktif)" }
        }
    } else {
        $chk.IsChecked = $false
        $chk.Foreground = [System.Windows.Media.Brushes]::White
        if ($isPanel -and $lblTb) {
            $lblTb.Text = $lblTb.Text -replace " \(Aktif\)", ""
        } else {
            $chk.Content = $chk.Content -replace " \(Aktif\)", ""
        }
    }
}

# Parent SUBCAT header'lari guncelle (tum cocuklar checked ise parent da)
function Update-Parent-Headers-Recursive($nodes) {
    foreach ($item in $nodes) {
        if ($item.Items.Count -gt 0) {
            Update-Parent-Headers-Recursive $item.Items
            if ($item.Tag -eq "SUBCAT") {
                $allChildrenChecked = $true; $hasChildren = $false
                foreach ($child in $item.Items) {
                    $hasChildren = $true
                    $childChk = Get-CheckFromItem $child
                    if (-not $childChk.IsChecked) { $allChildrenChecked = $false; break }
                }
                if ($hasChildren) {
                    $headerChk = Get-CheckFromItem $item
                    if ($headerChk) { $headerChk.IsChecked = $allChildrenChecked }
                }
            }
        }
    }
}

function Check-Tweak-Status {
    param([switch]$ForceRefresh)  # Cache'i yoksay, sifirdan tara

    # Onceki tarama varsa iptal et
    if ($script:TweakScanTimer -and $script:TweakScanTimer.IsEnabled) {
        $script:TweakScanTimer.Stop()
    }

    Refresh-PowerCfg-Cache

    if ($btnCheckTweaks) {
        $btnCheckTweaks.Content = "Denetleniyor..."
        $btnCheckTweaks.IsEnabled = $false
    }

    # 1) Tum tweak item'larini topla
    $allItems = Get-AllTweakItems
    $totalCount = $allItems.Count
    if ($totalCount -eq 0) {
        if ($btnCheckTweaks) { $btnCheckTweaks.Content = "♻ Denetle"; $btnCheckTweaks.IsEnabled = $true }
        return
    }

    # 2) Cache'ten ANINDA on-yukleme yap (UI'da hemen gozukur, donmaz)
    if (-not $ForceRefresh) {
        $cache = Load-TweakStatusCache
        if ($cache) {
            foreach ($item in $allItems) {
                $key = $item.Tag.Name
                if ($cache.ContainsKey($key)) {
                    Set-TweakItemUI -item $item -isApplied $cache[$key] -fromCache $true
                }
            }
            Update-Parent-Headers-Recursive $tvTweaks.Items
        }
    }

    # 3) Background scan'i baslat (chunked DispatcherTimer)
    $script:TweakScanIdx       = 0
    $script:TweakScanChunk     = 10
    $script:TweakScanItems     = $allItems
    $script:TweakScanResultMap = @{}

    $script:TweakScanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:TweakScanTimer.Interval = [TimeSpan]::FromMilliseconds(20)
    $script:TweakScanTimer.Add_Tick({
        $end = [Math]::Min($script:TweakScanIdx + $script:TweakScanChunk, $script:TweakScanItems.Count)
        for ($i = $script:TweakScanIdx; $i -lt $end; $i++) {
            $item  = $script:TweakScanItems[$i]
            $tweak = $item.Tag
            try {
                $isApplied = Test-TweakApplied $tweak
                Set-TweakItemUI -item $item -isApplied $isApplied -fromCache $false
                $script:TweakScanResultMap[$tweak.Name] = $isApplied
            } catch {}
        }
        $script:TweakScanIdx = $end

        if ($btnCheckTweaks) {
            $pct = [int](($script:TweakScanIdx / $script:TweakScanItems.Count) * 100)
            $btnCheckTweaks.Content = "Denetleniyor... %$pct"
        }

        if ($script:TweakScanIdx -ge $script:TweakScanItems.Count) {
            $script:TweakScanTimer.Stop()
            Update-Parent-Headers-Recursive $tvTweaks.Items
            Save-TweakStatusCache $script:TweakScanResultMap
            $global:TweakStatusCache = $script:TweakScanResultMap
            if ($btnCheckTweaks) {
                $btnCheckTweaks.Content = "♻ Denetle"
                $btnCheckTweaks.IsEnabled = $true
            }
        }
    })
    $script:TweakScanTimer.Start()
}

# --- TARAYICI & SİSTEM FONKSİYONLARI ---

# #endregion 9 -- TWEAK SISTEMI (IsActive, Apply, Check, Manager)


# =========================================================================
# #region 10 -- TEMIZLIK MOTORU (Winapp2, Resolve-ComplexPath, Process-Tree)
# =========================================================================

function Check-And-Close-Browsers {
    WpfLog "[SİSTEM] Tarayıcı işlemleri kontrol ediliyor..."
    $script:targets = @(); function Find-Selected-Browsers($items) { foreach ($item in $items) { $chk = Get-CheckFromItem $item; if ($chk.IsChecked) { $name = $chk.Content.ToString(); if ($name -match 'Chrome') { $script:targets += "chrome" } if ($name -match 'Edge') { $script:targets += "msedge" } if ($name -match 'Firefox') { $script:targets += "firefox" } if ($name -match 'Brave') { $script:targets += "brave" } if ($name -match 'Opera') { $script:targets += "opera" } if ($name -match 'Yandex') { $script:targets += "browser" } } if ($item.Items.Count -gt 0) { Find-Selected-Browsers $item.Items } } }
    Find-Selected-Browsers $tvBrowser.Items; $uniqueTargets = $script:targets | Select-Object -Unique
    if ($uniqueTargets) {
        $running = Get-Process -Name $uniqueTargets -ErrorAction SilentlyContinue
        if ($running) {
            if ([System.Windows.MessageBox]::Show("Açık tarayıcılar var. Temizlik için kapatılsın mı?", "Uyarı", [System.Windows.MessageBoxButton]::YesNo) -eq 'Yes') { $running | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
        }
    }
}

function Check-Browser-Safety {
    $riskyItems = New-Object System.Collections.ArrayList; $keywords = @("Password", "Parola", "Şifre", "Login Data", "Auth", "Bookmark", "Yer İmleri", "Favicon", "Extension", "Cüzdan", "Form", "Autofill", "Sync", "Oturum", "User Data", "Profile")
    function Scan-Risky($items) { foreach ($item in $items) { $chk = Get-CheckFromItem $item; if ($chk.IsChecked) { $name = $chk.Content.ToString(); $isRisky = $false; foreach ($kw in $keywords) { if ($name -match $kw) { $isRisky = $true; break } } if ($name -match "Search Engine") { $isRisky = $false } if ($isRisky) { $riskyItems.Add($item) | Out-Null } } if ($item.Items.Count -gt 0) { Scan-Risky $item.Items } } }
    Scan-Risky $tvBrowser.Items
    if ($riskyItems.Count -gt 0) {
        $res = [System.Windows.MessageBox]::Show("DİKKAT! Şifreler veya Yer İmleri gibi kritik veriler seçildi. Devam edilsin mi?", "Uyarı", [System.Windows.MessageBoxButton]::YesNoCancel, [System.Windows.MessageBoxImage]::Warning)
        if ($res -eq 'Cancel') { return "STOP" }
        if ($res -eq 'No') { foreach ($i in $riskyItems) { (Get-CheckFromItem $i).IsChecked = $false }; WpfLog "[GÜVENLİK] Kritik öğelerin seçimi kaldırıldı."; return "GO" }
    }
    return "GO"
}



function Update-Cache {
    param([string]$Type, [object]$Data)
    
    # --- CACHE KONTROLÜ (EKLENDİ) ---
    if ($global:IsCacheDisabled) { return }

    $currentCache = @{ Winapp2 = @(); Winget = @() }
    if (Test-Path $CachePath) { try { $raw = Get-Content $CachePath -Raw | ConvertFrom-Json; if ($raw.Winapp2) { $currentCache.Winapp2 = $raw.Winapp2 }; if ($raw.Winget) { $currentCache.Winget = $raw.Winget } } catch {} }
    if ($Type -eq 'Winapp2') { $currentCache.Winapp2 = $Data }
    if ($Type -eq 'Winget')  { $currentCache.Winget  = $Data }
    $currentCache | ConvertTo-Json -Depth 4 | Set-Content $CachePath -Encoding UTF8
}

$global:AppsBuffer = @{}; $global:BrowserBuffer = @{}
function Flush-Buffers-To-Tree {
    $tvApps.BeginInit(); $tvBrowser.BeginInit()
    $tvApps.Items.Clear(); $tvBrowser.Items.Clear(); $global:AppCounter = 0
    try {
        foreach ($vendor in ($global:AppsBuffer.Keys | Sort-Object)) { $apps = $global:AppsBuffer[$vendor]; $global:AppCounter++; if ($apps.Count -eq 1) { $tvApps.Items.Add((New-TreeItem $apps[0].Name $apps[0].Tag)) | Out-Null } else { $group = New-TreeItem $vendor "ROOT"; foreach ($app in $apps) { $group.Items.Add((New-TreeItem $app.Name $app.Tag)) | Out-Null }; $tvApps.Items.Add($group) | Out-Null } }
        foreach ($vendor in ($global:BrowserBuffer.Keys | Sort-Object)) { $apps = $global:BrowserBuffer[$vendor]; $global:AppCounter++; if ($apps.Count -eq 1) { $tvBrowser.Items.Add((New-TreeItem $apps[0].Name $apps[0].Tag)) | Out-Null } else { $group = New-TreeItem $vendor "ROOT"; foreach ($app in $apps) { $group.Items.Add((New-TreeItem $app.Name $app.Tag)) | Out-Null }; $tvBrowser.Items.Add($group) | Out-Null } }
    } finally {
        $tvApps.EndInit(); $tvBrowser.EndInit()
    }
    $txtWinappStatus.Text = "Tespit Edilen: $global:AppCounter Uygulama"; Load-System-Tree; Restore-Checkboxes
}

function Add-To-Buffer($appName, $tag, $isBrowser) {
    if ($isBrowser -and $appName -match '^Microsoft') { $appName = $appName -replace '^Microsoft', 'Microsoft Edge' }
    $splitName = $appName -split ' '; $vendor = $splitName[0]; if ($vendor.Length -lt 2) { $vendor = $appName }; if ($vendor -eq "Microsoft" -and $isBrowser) { $vendor = "Microsoft Edge" }
    $obj = @{ Name = $appName; Tag = $tag }
    if ($isBrowser) { if (-not $global:BrowserBuffer.ContainsKey($vendor)) { $global:BrowserBuffer[$vendor] = @() }; $global:BrowserBuffer[$vendor] += $obj } else { if (-not $global:AppsBuffer.ContainsKey($vendor)) { $global:AppsBuffer[$vendor] = @() }; $global:AppsBuffer[$vendor] += $obj }
}

function Load-System-Tree {
    $tvSystem.Items.Clear()
    try {
        $nodeSys = New-TreeItem 'Windows Sistemi' '' ; $tvSystem.Items.Add($nodeSys) | Out-Null
        $nodeSys.Items.Add((New-TreeItem 'Temp (Kullanıcı)' '$env:TEMP|*')) | Out-Null
        $nodeSys.Items.Add((New-TreeItem 'Windows Temp' 'C:\\Windows\\Temp|*')) | Out-Null
        $nodeSys.Items.Add((New-TreeItem 'Prefetch' 'C:\\Windows\\Prefetch|*')) | Out-Null
        $nodeSys.IsExpanded = $true
        if ($global:CustomRules) {
            $nodeCustom = New-TreeItem 'Kullanıcı Tanımlı (Özel)' 'ROOT'
            foreach ($rule in $global:CustomRules) {
                try {
                    $item = New-TreeItem $rule.Name $rule.Rule $true
                    if ($rule.IsChecked -eq $true -or "$($rule.IsChecked)" -eq "True") { (Get-CheckFromItem $item).IsChecked = $true }
                    $nodeCustom.Items.Add($item) | Out-Null
                } catch { WpfLog "[UYARI] Özel kural yüklenemedi: $($rule.Name)" }
            }
            $nodeCustom.IsExpanded = $true; $tvSystem.Items.Add($nodeCustom) | Out-Null
        }
    } catch {
        WpfLog "[HATA] Sistem ağacı yüklenirken sorun: $($_.Exception.Message)"
    }
}
$nodeSB = New-TreeItem 'Klasör Görünüm Geçmişi (ShellBags)' ''
$nodeSB.Items.Add((New-TreeItem 'Modern Klasör Ayarları (Win10/11 - MRU)' 'REGISTRY:HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU')) | Out-Null
$nodeSB.Items.Add((New-TreeItem 'Modern Klasör Ayarları (Win10/11 - Bags)' 'REGISTRY:HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags')) | Out-Null
$nodeSB.Items.Add((New-TreeItem 'Klasik Geçmiş (Desktop/Legacy - MRU)' 'REGISTRY:HKCU\Software\Microsoft\Windows\Shell\BagMRU')) | Out-Null
$nodeSB.Items.Add((New-TreeItem 'Masaüstü Simge Düzeni (Desktop Layout & Bags)' 'REGISTRY:HKCU\Software\Microsoft\Windows\Shell\Bags')) | Out-Null
$nodeSB.Items.Add((New-TreeItem 'ShellNoRoam (Eski Sistem Artıkları)' 'REGISTRY:HKCU\Software\Microsoft\Windows\ShellNoRoam')) | Out-Null
$nodeSB.IsExpanded = $true; $tvShellBags.Items.Add($nodeSB) | Out-Null

function Start-Winapp2-Process {
    $btnRefreshApp.IsEnabled = $false; $global:AppsBuffer = @{}; $global:BrowserBuffer = @{}
    
    # Ayarları Yükle
    Load-All-Settings
    
    # --- GÜNCELLEME KONTROL BLOĞU (ORTAK) ---
    # Bu blok hem Cache'den hem Diskten yükleme sonrası çalışacak
    $CheckUpdateBlock = {
        # Ağ kontrolü UI thread'ini bloklamaz — arka planda çalıştır
        $winapp2Src = $Winapp2Sources[0]
        $winapp2Path = $Winapp2Path
        $uiCtrl = $txtWinappStatus

        $script:UpdateRS = [powershell]::Create()
        $script:UpdateRS.AddScript({
            param($src, $localPath)
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            try {
                # Yerel sürüm
                $rdr = New-Object System.IO.StreamReader($localPath)
                $local = $rdr.ReadLine(); $rdr.Close()
                
                # Online sürüm (sadece ilk satırı indir - bant genişliği tasarrufu)
                $req = [System.Net.WebRequest]::Create($src)
                $req.Timeout = 5000
                $req.Headers.Add("User-Agent", "Mozilla/5.0")
                $resp = $req.GetResponse()
                $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $online = $sr.ReadLine(); $sr.Close(); $resp.Close()
                
                return @{ Success=$true; Local=$local; Online=$online; Error="" }
            } catch {
                return @{ Success=$false; Local=""; Online=""; Error=$_.Exception.Message }
            }
        }) | Out-Null
        $script:UpdateRS.AddArgument($winapp2Src) | Out-Null
        $script:UpdateRS.AddArgument($winapp2Path) | Out-Null
        $script:UpdateAsync = $script:UpdateRS.BeginInvoke()

        $script:UpdateTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:UpdateTimer.Interval = [TimeSpan]::FromMilliseconds(300)
        $script:UpdateTimer.Add_Tick({
            if ($script:UpdateAsync.IsCompleted) {
                $script:UpdateTimer.Stop()
                try {
                    $r = $script:UpdateRS.EndInvoke($script:UpdateAsync)
                    $script:UpdateRS.Dispose()
                    if ($r.Success) {
                        if ($r.Local -ne $r.Online) {
                            WpfLog "---------------------------------------------------"
                            WpfLog "[BİLGİ] 📢 Yeni Winapp2 güncellemesi bulundu!"
                            WpfLog "[BİLGİ] İndirmek için Güncelle butonuna basın!"
                            WpfLog "---------------------------------------------------"
                            $uiCtrl.Text = "Yeni Sürüm Mevcut!"
                        } else {
                            WpfLog "[SİSTEM] Veritabanı güncel."
                            $uiCtrl.Text = "Sürüm Güncel."
                        }
                    }
                    # Hata durumunda sessiz kal — kullanıcıyı rahatsız etme
                } catch {}
            }
        }.GetNewClosure())
        $script:UpdateTimer.Start()
    }

    # SENARYO 1: CACHE DOSYASINDAN OKU
    if (-not $global:IsCacheDisabled -and (Test-Path $CachePath)) {
        try {
            WpfLog "[SİSTEM] Önbellek yükleniyor..."
            $json = Get-Content $CachePath -Raw | ConvertFrom-Json
            if ($json.Winapp2) {
                foreach ($item in $json.Winapp2) {
                    $global:Winapp2Rules[$item.Name] = $item.Rules
                    if ($global:Blacklist -notcontains $item.Name) { Add-To-Buffer $item.Name $item.Tag $item.IsBrowser }
                }
                Flush-Buffers-To-Tree; $btnRefreshApp.IsEnabled = $true
                WpfLog "[SİSTEM] Önbellek yüklendi."
                
                # Kontrolü Çalıştır
                & $CheckUpdateBlock
                return
            }
        } catch { WpfLog "[UYARI] Önbellek okunamadı, yeniden oluşturulacak." }
    }
    
    # SENARYO 2: INI DOSYASINDAN OKU (DİSKTE VARSA)
    if (Test-Path $Winapp2Path) {
        WpfLog "[BİLGİ] Winapp2.ini diskte mevcut, işleniyor..."
        Parse-Winapp2
        $btnRefreshApp.IsEnabled = $true
        
        # DÜZELTME: Kontrolü burada da çalıştır (Eskiden yoktu)
        & $CheckUpdateBlock
        return
    }
    
    # SENARYO 3: İNDİR VE OKU (DOSYA YOKSA)
    $txtWinappStatus.Text = "İndiriliyor..."
    WpfLog "[BİLGİ] Winapp2.ini indiriliyor..."
    Do-Events
    
    $downloadSuccess = $false; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    foreach ($url in $Winapp2Sources) { 
        try { 
            (New-Object System.Net.WebClient).DownloadFile($url, $Winapp2Path)
            $downloadSuccess = $true; WpfLog "[BAŞARILI] Winapp2.ini indirildi."
            break 
        } catch {} 
    }
    
    if ($downloadSuccess) { 
        Parse-Winapp2 
        $txtWinappStatus.Text = "Sürüm Güncel." # Yeni indiği için günceldir
    } else { 
        $txtWinappStatus.Text = "Hata."
        WpfLog "[HATA] Winapp2.ini indirilemedi!" 
    }
    $btnRefreshApp.IsEnabled = $true
}

function Parse-Winapp2 {
    if (-not (Test-Path $Winapp2Path)) { return }
    $txtWinappStatus.Text = "Winapp2: Ayıklanıyor (Turbo)..."; Do-Events
    
    $localAppsBuffer = @{}; $localBrowserBuffer = @{}; $cacheList = @()
    $osVer = [System.Environment]::OSVersion.Version

    # --- YARDIMCI FONKSİYON: Orijinal Mantık Birebir Korundu ---
    function Process-AppBlock {
        param($appName, $lines)
        $isDetected = $false; $isExcluded = $false; $appFiles = @()
        if ($global:PathOverrides.ContainsKey($appName)) { $isDetected = $true }
        
        foreach ($line in $lines) {
            $l = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($l) -or $l.StartsWith(';')) { continue }

            # 0. DetectOS Kontrolü
            if ($l -match '^DetectOS\s*=\s*(.*)') {
                $parts = $Matches[1].Split('|'); $minStr = $parts[0].Trim()
                $maxStr = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "" }
                try {
                    if ($minStr -ne "" -and [version]$osVer -lt [version]$minStr) { $isExcluded = $true }
                    if ($maxStr -ne "" -and [version]$osVer -gt [version]$maxStr) { $isExcluded = $true }
                } catch {}
                continue
            }
            if ($l -match '^Warning\s*=') { continue }

            # 1. Dosya Tespiti
            if ($l -match '^DetectFile\d*\s*=\s*(.*)') { 
                $rawP = $Matches[1].Trim(); $path = [Environment]::ExpandEnvironmentVariables($rawP)
                if (-not (Test-Path $path -EA SilentlyContinue) -and $rawP -match "%ProgramFiles%") {
                    $path64 = $rawP -replace "%ProgramFiles%", $env:ProgramW6432
                    if (Test-Path $path64 -EA SilentlyContinue) { $path = $path64 }
                }
                if (Test-Path $path -EA SilentlyContinue) { $isDetected = $true } 
            }
            # 2. Kayıt Defteri Tespiti
            elseif ($l -match '^(Detect|DetectReg)\d*\s*=\s*(.*)') { 
                $reg = "Registry::" + $Matches[2].Trim().Replace("HKLM","HKEY_LOCAL_MACHINE").Replace("HKCU","HKEY_CURRENT_USER")
                if (Test-Path $reg -EA SilentlyContinue) { $isDetected = $true } 
            }
            # 3. Kural Toplama
            elseif ($l -match '^ExcludeKey\d*\s*=\s*(.*)') { $appFiles += "EXCLUDE:" + $Matches[1].Trim() }
            elseif ($l -match '^(FileKey\d*|RegKey\d*)\s*=\s*(.*)') { $appFiles += $Matches[2].Trim() }
        }

        if ($isExcluded) { return $null }
        if ($isDetected -and $appFiles.Count -gt 0) {
            $effectiveRules = $appFiles | Where-Object { -not $_.StartsWith("EXCLUDE:") }
            $global:Winapp2Rules[$appName] = $effectiveRules
            $tag = "WINAPP2:" + $appName
            $isBrowser = ($appName -match '(?i)Chrome|Firefox|Edge|Brave|Opera|Vivaldi|Browser|Yandex|Thorium' -and $appName -notmatch '(?i)DB Browser|Browser Agent')
            return @{ Name=$appName; Tag=$tag; Rules=$effectiveRules; IsBrowser=$isBrowser }
        }
        return $null
    }

    try {
        # --- P3 ÇÖZÜMÜ: StreamReader ile Dosyayı RAM'i Şişirmeden Oku ---
        $reader = New-Object System.IO.StreamReader($Winapp2Path)
        $currentApp = ""
        $currentLines = New-Object System.Collections.Generic.List[string]

        while (($line = $reader.ReadLine()) -ne $null) {
            $l = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($l) -or $l.StartsWith(";")) { continue }

            if ($l.StartsWith("[") -and $l.EndsWith("]")) {
                # Bir önceki bloğu işle
                if ($currentApp -ne "" -and -not $global:PathOverrides.ContainsKey($currentApp)) {
                    $res = Process-AppBlock -appName $currentApp -lines $currentLines.ToArray()
                    if ($res) { $cacheList += $res }
                }
                $currentApp = $l.Trim("[]")
                $currentLines.Clear()
            } else {
                $currentLines.Add($line)
            }
        }
        # Dosya bittiğinde son bloğu da işle
        if ($currentApp -ne "" -and -not $global:PathOverrides.ContainsKey($currentApp)) {
            $res = Process-AppBlock -appName $currentApp -lines $currentLines.ToArray()
            if ($res) { $cacheList += $res }
        }
        $reader.Close(); $reader.Dispose()

        # --- AŞAMA 2: OVERRIDE (Özel Ayarlar) ---
        foreach ($appName in $global:PathOverrides.Keys) {
            $res = Process-AppBlock -appName $appName -lines $global:PathOverrides[$appName]
            if ($res) { $cacheList += $res }
        }

        # --- AŞAMA 3: TAMPONLARI DOLDUR (Orijinal Mantık) ---
        foreach ($item in $cacheList) {
            if ($global:Blacklist -notcontains $item.Name) {
                $vendor = ($item.Name -split ' ')[0]
                if ($vendor.Length -lt 2) { $vendor = $item.Name }
                if ($vendor -match "(?i)Microsoft" -and $item.IsBrowser) { $vendor = "Microsoft Edge" }
                
                if ($item.IsBrowser) { 
                    if (-not $localBrowserBuffer.ContainsKey($vendor)) { $localBrowserBuffer[$vendor] = @() }
                    $localBrowserBuffer[$vendor] += $item 
                } else { 
                    if (-not $localAppsBuffer.ContainsKey($vendor)) { $localAppsBuffer[$vendor] = @() }
                    $localAppsBuffer[$vendor] += $item 
                }
            }
        }
        
        $global:AppsBuffer = $localAppsBuffer
        $global:BrowserBuffer = $localBrowserBuffer
        Update-Cache -Type "Winapp2" -Data $cacheList
        Flush-Buffers-To-Tree
        
    } catch {
        WpfLog "[HATA] Winapp2 ayrıştırılırken hata: $($_.Exception.Message)"
    }
}

function Load-Winget-Tree {
    param([array]$MemoryList = $null)
    
    $tvWinget.BeginInit()
    $tvWinget.Items.Clear()
    
    try {
        # 1. Yüklü Listesini Belirle
        $installedList = @()
        if ($MemoryList) {
            $installedList = $MemoryList
        }
        elseif (Test-Path $CachePath) { 
            try { 
                $json = Get-Content $CachePath -Raw | ConvertFrom-Json
                if ($json.Winget) { $installedList = $json.Winget } 
            } catch { } 
        }
        
        # 2. WINGET KÖKÜ
        $rootWinget = New-TreeItem "Winget Uygulamaları" "ROOT"
        $sortedWingetApps = $global:WingetApps.Keys | Sort-Object

        foreach ($appName in $sortedWingetApps) {
            try {
                $wingetID = $global:WingetApps[$appName]
                $item = New-TreeItem $appName "WINGET_INSTALL:$wingetID"
                
                if ($installedList -contains $wingetID) { 
                    $chk = Get-CheckFromItem $item
                    if ($chk.Content -notmatch "\(Yüklü\)") { $chk.Content = "$($chk.Content) (Yüklü)" }
                    $chk.Foreground = [System.Windows.Media.Brushes]::LimeGreen
                    $chk.IsChecked = $false
                }
                
                $rootWinget.Items.Add($item) | Out-Null
            } catch { WpfLog "[UYARI] Winget öğesi yüklenemedi: $appName" }
        }
        $rootWinget.IsExpanded = $true
        $tvWinget.Items.Add($rootWinget) | Out-Null

        # 3. WINDOWS APPX KÖKÜ
        $rootAppx = New-TreeItem "Windows Uygulamaları (Gömülü)" "ROOT"
        $rootAppx.Foreground = [System.Windows.Media.Brushes]::Orange
        
        try {
            $sysPackages = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { 
                $_.IsFramework -eq $false -and 
                $_.NonRemovable -eq $false -and 
                $_.SignatureKind -eq "Store" -and 
                $_.Name -notmatch "Microsoft.Windows.Search" -and 
                $_.Name -notmatch "ExperienceHost" -and
                $_.Name -notmatch "Cortana"
            } | Sort-Object Name
            
            foreach ($pkg in $sysPackages) {
                $simpleName = $pkg.Name -replace "Microsoft\.", "" -replace "Windows\.", ""
                $tagID = $pkg.PackageFullName 
                $item = New-TreeItem "$simpleName" "APPX:$tagID"
                $rootAppx.Items.Add($item) | Out-Null
            }
        } catch { WpfLog "[UYARI] AppxPackage listesi alınamadı: $($_.Exception.Message)" }
        
        # Manuel Eklenen Appx'ler
        if ($global:CustomAppx) {
            $sortedAppxApps = $global:CustomAppx.Keys | Sort-Object
            foreach ($name in $sortedAppxApps) {
                try {
                    $pkgPattern = $global:CustomAppx[$name]
                    $item = New-TreeItem "$name (Manuel)" "APPX:$pkgPattern"
                    $item.Foreground = [System.Windows.Media.Brushes]::Yellow
                    $rootAppx.Items.Add($item) | Out-Null
                } catch {}
            }
        }
        
        $rootAppx.IsExpanded = $false 
        $tvWinget.Items.Add($rootAppx) | Out-Null

    } catch {
        WpfLog "[HATA] Winget ağacı yüklenirken sorun: $($_.Exception.Message)"
    } finally {
        $tvWinget.EndInit()
    }
}

function Remove-Empty-Folders-Recursive([string]$path) {
    if (-not [System.IO.Directory]::Exists($path)) { return }
    try { [System.IO.Directory]::GetDirectories($path) | ForEach-Object { Remove-Empty-Folders-Recursive $_ }; if (([System.IO.Directory]::GetFiles($path).Length -eq 0) -and ([System.IO.Directory]::GetDirectories($path).Length -eq 0)) { [System.IO.Directory]::Delete($path) } } catch {}
}

function Secure-Remove-Item([string]$path, [string]$mode) {
    try {
        if ([System.IO.Directory]::Exists($path)) {[System.IO.Directory]::Delete($path, $true)
            return $true
        }
        if (-not[System.IO.File]::Exists($path)) { return $true }

        if ($mode -match "Güvenli" -or $cbSecureDelete.SelectedIndex -gt 0) {
            # Hızlı (1 tur) veya Paronayak (3 tur) silme
            $passes = if ($mode -match "Random" -or $cbSecureDelete.SelectedIndex -eq 2) { 3 } else { 1 }
            return [SecureWiper]::WipeFile($path, $passes)
        } else {[System.IO.File]::Delete($path)
            return $true
        }
    } catch {
        return $false 
    }
}

# --- DÜZELTİLEN ANALİZ FONKSİYONU ---
function Resolve-ComplexPath {
    param([string]$ruleString, [bool]$CalculateSizeOnly = $false)
    
    $parts = $ruleString -split '\|'
    $rawPathPattern = [Environment]::ExpandEnvironmentVariables($parts[0])
    
    if ([string]::IsNullOrWhiteSpace($rawPathPattern)) { return 0 }

    # =========================================================
    # GÜVENLİK KALKANI: KORUNAN SİSTEM KLASÖRÜ KONTROLÜ
    # =========================================================
    $protectedRoots = @(
        "$env:SystemRoot",                          # C:\Windows
        "$env:SystemRoot\System32",                 # C:\Windows\System32
        "$env:SystemRoot\SysWOW64",                 # C:\Windows\SysWOW64
        "$env:SystemRoot\system",                   # C:\Windows\system
        "$env:ProgramFiles",                        # C:\Program Files
        [Environment]::GetFolderPath('ProgramFiles'), 
        [Environment]::GetFolderPath('Windows')
    )
    
    $expandedCheck = $rawPathPattern -replace '\*.*$', ''
    $expandedCheck = $expandedCheck.TrimEnd('\', '/')
    
    foreach ($protected in $protectedRoots) {
        if ($protected -and $expandedCheck.ToLower() -eq $protected.ToLower()) {
            if ($chkDebug.IsChecked) { WpfLog "[GÜVENLİK] Korunan klasör atlandı: $rawPathPattern" }
            if ($CalculateSizeOnly) { return [PSCustomObject]@{ SizeBytes = 0; FileCount = 0 } }
            return 0
        }
    }
    # =========================================================

    $filterStr = "*"
    if ($parts.Count -gt 1) { $filterStr = $parts[1] }
    $filters = $filterStr -split ';'
    
    $flags = ""
    if ($parts.Count -gt 2) { $flags = $parts[2] }
    $isRecurse = $flags -match 'RECURSE'
    $isRemoveSelf = $flags -match 'REMOVESELF'

    $totalSize = 0; $totalCount = 0; $deletedCount = 0
    
    # Silme Modunu Belirle (Normal, Zeroes, Random)
    $sModeIndex = 0
    if (-not $CalculateSizeOnly) { 
        $Win.Dispatcher.Invoke([action]{ $sModeIndex = $cbSecureDelete.SelectedIndex }) 
    }
    
    $modeStr = "Normal"
    if ($sModeIndex -eq 1) { $modeStr = "Zeroes" }
    if ($sModeIndex -eq 2) { $modeStr = "Random" }
    
    $targetFolders = @()
    if ($rawPathPattern -match '\*|\?') { 
        try { Get-Item -Path $rawPathPattern -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | ForEach-Object { $targetFolders += $_.FullName } } catch {} 
    } elseif (Test-Path $rawPathPattern -PathType Container) { 
        $targetFolders += $rawPathPattern 
    }

    $loopCount = 0
    
    # --- KRİTİK ÇÖZÜM: UI FRENLEYİCİ (THROTTLE) ---
    # Zamanlayıcı başlatıyoruz, böylece ekranı saniyede binlerce kez değil, kontrollü güncelleyeceğiz
    $uiThrottle = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($folderPath in $targetFolders) {
        $searchOpt = [System.IO.SearchOption]::TopDirectoryOnly
        if ($isRecurse) { $searchOpt = [System.IO.SearchOption]::AllDirectories }
        
        foreach ($f in $filters) {
            try {
                $filesEnum = [System.IO.Directory]::EnumerateFiles($folderPath, $f.Trim(), $searchOpt)
                foreach ($filePath in $filesEnum) {
                    $loopCount++
                    
                    if ($global:StopOperation) { return 0 }
                    
                    if ($CalculateSizeOnly) { 
                        try { $totalSize += (New-Object System.IO.FileInfo($filePath)).Length; $totalCount++ } catch {} 
                        # Analiz sırasında da UI nefes alsın
                        if ($uiThrottle.ElapsedMilliseconds -gt 50) { Do-Events; $uiThrottle.Restart() }
                    } else { 
                        # --- EKRANIN DONMASINI ENGELLEYEN SİHİR ---
                        # Sadece 50 milisaniye (0.05 sn) geçtiyse ekranı güncelle.
                        if ($uiThrottle.ElapsedMilliseconds -gt 50) {
                            $lblDetail.Text = "Siliniyor: $([System.IO.Path]::GetFileName($filePath))"
                            Do-Events
                            $uiThrottle.Restart()
                        }
                        
                        if (Secure-Remove-Item $filePath $modeStr) { $deletedCount++ }
                    }
                }
            } catch {}
        }
        
        if (-not $CalculateSizeOnly) { 
            if ($isRecurse -or $isRemoveSelf) { Remove-Empty-Folders-Recursive $folderPath }
            if ($isRemoveSelf) { 
                try { 
                    if (Test-Path $folderPath -PathType Container) {
                        if ((Get-ChildItem $folderPath -Force -ErrorAction SilentlyContinue).Count -eq 0) { 
                            [System.IO.Directory]::Delete($folderPath) 
                        }
                    }
                } catch {} 
            } 
        }
    }
    
    if ($CalculateSizeOnly) { return [PSCustomObject]@{ SizeBytes =[double]$totalSize; FileCount = [int]$totalCount } }
    return $deletedCount
}

function Run-CMD-Realtime {
    param([string]$cmd)

    WpfLog "[BAŞLATILDI] İşlem Yürütülüyor..."
    # DISM komutlari icin: % parse aktif, ilk yuzde gelene kadar indeterminate (animasyon)
    # Ilk % yakalandiginda determinate moda gecilir, butonda %X gosterilir
    $isDism = $cmd -match "(?i)\bdism\b"
    if ($isDism) {
        $Win.Dispatcher.Invoke([action]{
            $pbMain.IsIndeterminate = $true
            $btnRun.Content = "⏳ DISM..."
            $lblStatus.Text = "DISM: imaj taraması başladı..."
        })
    } else {
        $Win.Dispatcher.Invoke([action]{ $pbMain.IsIndeterminate = $true; $btnRun.Content = "İŞLENİYOR..." })
    }

    $outputBuilder = New-Object System.Text.StringBuilder
    $script:cmdRtStartTime = Get-Date
    $script:cmdRtLastPct = -1

    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "cmd.exe"
        # Winget barlarını kapatmak için parametre
        if ($cmd -match "winget") { $cmd += " --disable-interactivity" }

        $pinfo.Arguments = "/c chcp 65001 >nul & $cmd 2>&1"
        $pinfo.WindowStyle = 'Hidden'
        $pinfo.CreateNoWindow = $true
        $pinfo.UseShellExecute = $false
        $pinfo.RedirectStandardOutput = $true
        $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $pinfo
        $proc.Start() | Out-Null

        while (-not $proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line) {
                $outputBuilder.AppendLine($line) | Out-Null
                $clean = $line.Trim()

                # --- DISM PROGRESS PARSE ---
                # DISM ciktisi: "[==========     ] 45.0%" veya "45.0% complete"
                # Sadece DISM komutu icin parse — winget gibi komutlarda yanlis pozitif olmasin
                if ($isDism) {
                    $pctMatch = [regex]::Match($clean, '(\d{1,3}(?:\.\d+)?)\s*%')
                    if ($pctMatch.Success) {
                        $rawPct = [double]$pctMatch.Groups[1].Value
                        $pct = [int][Math]::Floor($rawPct)
                        if ($pct -ge 0 -and $pct -le 100 -and $pct -ne $script:cmdRtLastPct) {
                            $script:cmdRtLastPct = $pct
                            $elapsed = [int]((Get-Date) - $script:cmdRtStartTime).TotalSeconds
                            $mm = [int]([Math]::Floor($elapsed / 60))
                            $ss = [int]($elapsed % 60)
                            $statusMsg = ("DISM: %{0} (geçen: {1:D2}:{2:D2})" -f $pct, $mm, $ss)
                            $btnContent = "⏳ %$pct"
                            $Win.Dispatcher.Invoke([action]{
                                # Ilk % yakalandiginda animasyondan determinate'a gec
                                if ($pbMain.IsIndeterminate) { $pbMain.IsIndeterminate = $false }
                                $pbMain.Value = $pct
                                $btnRun.Content = $btnContent
                                $lblStatus.Text = $statusMsg
                            })
                        }
                    }
                }

                # --- FİLTRELEME ---
                if (-not [string]::IsNullOrWhiteSpace($clean)) {
                    if ($clean -match "Active code page" -or $clean -match "Copyright" -or $clean -match "Writing to log") { continue }
                    if ($clean -match "^[█▒\|\/\\\-\s\d\.]+(KB|MB|%)*") { continue }

                    # Ekrana Yaz (Hata ise Kırmızı ikonlu, değilse normal)
                    if ($clean -match "fail" -or $clean -match "error" -or $clean -match "0x[0-9A-Fa-f]+" -or $clean -match "başarısız") {
                        WpfLog "❌ $clean"
                    } else {
                        WpfLog ">> $clean"
                    }
                }
            }
            Do-Events
        }
        $proc.WaitForExit()
        
        # --- AKILLI SONUÇ ANALİZİ ---
        WpfLog "----------------------------------------"
        
        $fullOutput = $outputBuilder.ToString()
        $lines = $fullOutput -split "`r`n"
        
        $failedApps = @()
        $currentAppName = "Bilinmeyen Uygulama"
        $successCount = 0

        foreach ($l in $lines) {
            # 1. Uygulama İsmini Yakala (Örn: "Found Notepad++ [Notepad++.Notepad++]")
            if ($l -match "Found\s+(.+?)\s+\[") {
                $currentAppName = $Matches[1].Trim()
            }
            
            # 2. Başarıyı Say
            if ($l -match "Successfully installed" -or $l -match "Successfully verified") {
                $successCount++
            }

            # 3. Hataları Yakala ve Sebebini Belirle
            if ($l -match "Application is currently running" -or $l -match "exit code: 5") {
                $failedApps += "$currentAppName (UYARI: Uygulama şu an çalışıyor, kapatıp deneyin)"
            }
            elseif ($l -match "Hash validation failed") {
                $failedApps += "$currentAppName (HATA: Dosya doğrulama hatası)"
            }
            elseif ($l -match "0x8A150014" -or $l -match "-1978335212") { # GPU-Z gibi portable sorunu
                $failedApps += "$currentAppName (UYARI: Kaldırma desteklenmiyor/Portable)"
            }
            elseif ($l -match "Installer failed with exit code") {
                # Eğer daha spesifik bir sebep eklenmediyse bunu ekle
                if ($failedApps -notcontains "$currentAppName (UYARI: Uygulama şu an çalışıyor, kapatıp deneyin)") {
                     $failedApps += "$currentAppName (HATA: Yükleyici hatası)"
                }
            }
        }
        
        # SONUÇ RAPORU
        if ($failedApps.Count -gt 0) {
            WpfLog "⚠️ BAZI İŞLEMLER TAMAMLANAMADI:"
            foreach ($err in $failedApps) {
                WpfLog "   • $err"
            }
            if ($successCount -gt 0) {
                WpfLog "   ℹ️ Diğer işlemler başarıyla tamamlandı."
            }
        }
        elseif ($fullOutput -match "did not find any integrity violations") { 
            WpfLog "✅ SONUÇ: Sistem Temiz (Bütünlük ihlali yok)." 
        } 
        elseif ($successCount -gt 0) { 
            WpfLog "✅ SONUÇ: Tüm işlemler başarıyla tamamlandı." 
        }
        else {
            WpfLog "ℹ️ İşlem tamamlandı."
        }
        
        WpfLog "----------------------------------------"

    } catch {
        WpfLog "[HATA] Sistem hatası: $($_.Exception.Message)"
    } finally {
        $Win.Dispatcher.Invoke([action]{ $pbMain.IsIndeterminate = $false; $pbMain.Value = 100; $lblStatus.Text = "Bitti."; $btnRun.Content = "BAŞLAT" })
    }
}

function Process-Tree {
    param($items, $mode)
    if ($global:ShellBagsTargets -eq $null) { $global:ShellBagsTargets = @() }
    if ($global:IsDesktopResetSelected -eq $null) { $global:IsDesktopResetSelected = $false }
    foreach ($it in $items) {
        # UI'yi nefes aldır ve STOP butonu click'ine şans ver
        Do-Events
        if ($global:StopOperation) { break }
        $chk = Get-CheckFromItem $it
        if ($chk -and $chk.IsChecked -eq $true -and $chk.Tag -ne "ROOT") {
            $tag = $chk.Tag.ToString(); $name = $chk.Content.ToString()
            try {
                if ($mode -eq 'Analyze') {
                    if ($tag -match '^CMD' -or $tag -match '^WINGET') { continue }
                    $result = $null
                    if ($tag -match '^REGISTRY:(.*)') {
                        $regPath = "Registry::" + $Matches[1]
                        if (Test-Path $regPath) { try { $count = (Get-ChildItem $regPath -Recurse -ErrorAction SilentlyContinue).Count + (Get-Item $regPath).Property.Count; if ($count -gt 0) { $result = [PSCustomObject]@{ SizeBytes = 0; FileCount = $count; IsReg = $true } } } catch {} }
                    } elseif ($tag -match '^WINAPP2:(.*)') {
                        $appName = $Matches[1]; 
                        $rules = $global:Winapp2Rules[$appName] 
                        if ($rules) { $totalSize = 0; $totalCount = 0; foreach ($rule in $rules) { $res = Resolve-ComplexPath $rule -CalculateSizeOnly $true; $totalSize += $res.SizeBytes; $totalCount += $res.FileCount }; if ($totalCount -gt 0) { $result = [PSCustomObject]@{ SizeBytes = $totalSize; FileCount = $totalCount; IsReg = $false } } }
                    } else { $result = Resolve-ComplexPath $tag -CalculateSizeOnly $true }
                    if ($result -and $result.FileCount -gt 0) { $script:TotalBytes += $result.SizeBytes; $script:TotalFiles += $result.FileCount; WpfLog ("{0,-45} {1,12} {2,15}" -f $name, (Format-Size $result.SizeBytes), $result.FileCount) }
                } elseif ($mode -eq 'Run') {
                    if ($tag -match 'Shell\\Bags' -or $tag -match 'Shell\\BagMRU' -or $tag -match 'ShellNoRoam') {
                        $regPath = $tag -replace '^REGISTRY:', ''; $psPath = $regPath -replace '^HKCU', 'Registry::HKEY_CURRENT_USER'
                        if (Test-Path $psPath) { if (((Get-ChildItem $psPath -Recurse -ErrorAction SilentlyContinue).Count + (Get-Item $psPath -ErrorAction SilentlyContinue).Property.Count) -gt 0) { $global:ShellBagsTargets += @{ Name=$name; Path=$regPath; PsPath=$psPath }; if ($name -match "Masaüstü") { $global:IsDesktopResetSelected = $true } } }
                        continue 
                    }
                    $Win.Dispatcher.Invoke([action]{ $lblStatus.Text = "Temizleniyor: $name" }); $itemsDeleted = 0
                    if ($tag -match '^REGISTRY:(.*)') {
                        $regPath = "Registry::" + $Matches[1]; if (Test-Path $regPath) { try { Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue; WpfLog "[TEMİZLENDİ] $name" } catch { WpfLog "❌ [HATA] $name (registry): $($_.Exception.Message)" } }
                    } elseif ($tag -match '^CMD') { if ($tag -match '^CMD:') { $sb = [ScriptBlock]::Create($tag.Substring(4)); & $sb | Out-Null } elseif ($tag -match '^CMD_REALTIME:') { Run-CMD-Realtime $tag.Substring(13) }
                    } elseif ($tag -match '^WINAPP2:(.*)') {
                        $appName = $Matches[1]; 
                        $rules = $global:Winapp2Rules[$appName] 
                        if ($rules) { foreach ($rule in $rules) { $itemsDeleted += Resolve-ComplexPath $rule -CalculateSizeOnly $false }; if ($itemsDeleted -gt 0) { WpfLog "[TEMİZLENDİ] $appName ($itemsDeleted dosya)" } }
                    } else { $itemsDeleted = Resolve-ComplexPath $tag -CalculateSizeOnly $false; if ($itemsDeleted -gt 0) { WpfLog "[TEMİZLENDİ] $name ($itemsDeleted dosya)" } }
                }
            } catch {
                WpfLog "❌ [HATA] '$name' işlenirken sorun: $($_.Exception.Message)"
            }
        }
        if ($it.Items.Count -gt 0) { Process-Tree $it.Items $mode }
    }
}

# =========================================================
# YENİ NESİL WORKER MOTORU (PAYLAŞIMLI BELLEK KANALI - V3 FİNAL)
# =========================================================

# #endregion 10 -- TEMIZLIK MOTORU (Winapp2, Resolve-ComplexPath, Process-Tree)


# =========================================================================
# #region 11 -- WORKER & KOMUT CALISTIRMA (Start-Worker-Process)
# =========================================================================

function Start-Worker-Process($ScriptContent, $activeBtn, $type, $TimeoutSeconds = 1800) {
    # Buton ve UI Hazırlığı
    $originalContent = ""
    if ($activeBtn) {
        $originalContent = $activeBtn.Content
        $activeBtn.IsEnabled = $false
        $activeBtn.Content = "⏳ İŞLENİYOR..."
    }

    $pbMain.IsIndeterminate = $true
    $lblStatus.Text = "İşlem havuzuna gönderildi..."

    # 1. PowerShell'in bozuk iletişim kanallarını ÇÖPE ATIP kendi Bellek Kuyruğumuzu (Queue) oluşturuyoruz!
    $msgQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[string]

    $ps = [powershell]::Create()
    $ps.RunspacePool = $global:GeminiPool

    # 2. İÇ YARDIMCI SCRİPT
    # `$Q` parametresi ile bellek kuyruğumuzu arka plan odacığına gizlice sokuyoruz.
    $wrapper = @"
    param(`$Q)
    `$ErrorActionPreference = 'Continue'
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Tüm Log ve Status mesajlarını doğrudan RAM'deki bu ortak kuyruğa fırlatıyoruz!
    function WS(`$msg) { `$Q.Enqueue(`"[[STATUS]]:`$msg`") }
    function Log(`$msg) { `$Q.Enqueue(`"[[LOG]]:`$msg`") }

    try {
        $ScriptContent
    } catch {
        Log "❌ KRİTİK HATA: `$($_.Exception.Message)"
    }
"@

    # Kuyruğu içeri enjekte edip başlat
    $ps.AddScript($wrapper).AddArgument($msgQueue) | Out-Null
    $asyncResult = $ps.BeginInvoke()

    # ActiveRunspaces listesine ekle (kapanışta temizlensin)
    if ($null -ne $global:ActiveRunspaces) { [void]$global:ActiveRunspaces.Add($ps) }

    # İşlem süresini takip et (timeout için)
    $workerStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Tek seferlik bitiş bayrağı (race önleme)
    $finishedRef = [ref]$false

    # 3. CANLI TAKİP ZAMANLAYICISI (Arayüz Thread'i)
    $workerTimer = New-Object System.Windows.Threading.DispatcherTimer
    $workerTimer.Interval = [TimeSpan]::FromMilliseconds(100)

    $finishAction = {
        param($reason)
        if ($finishedRef.Value) { return }
        $finishedRef.Value = $true
        $workerTimer.Stop()

        try { if (-not $asyncResult.IsCompleted) { $ps.Stop() } } catch {}
        try { if ($asyncResult.IsCompleted) { $null = $ps.EndInvoke($asyncResult) } } catch {}

        # Kuyrukta kalan son mesajları da boşalt
        $line = ""
        while ($msgQueue.TryDequeue([ref]$line)) {
            if ($line -match "^\[\[STATUS\]\]:(.*)") { $lblStatus.Text = $Matches[1] }
            elseif ($line -match "^\[\[LOG\]\]:(.*)") { WpfLog $Matches[1] }
        }

        # UI Reset
        $pbMain.IsIndeterminate = $false
        $pbMain.Value = 100
        $lblStatus.Text = $reason
        if ($activeBtn) {
            $activeBtn.IsEnabled = $true
            $activeBtn.Content = $originalContent
        }

        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
            WpfLog "[SİSTEM] Explorer yeniden başlatılıyor..."
            Start-Process explorer.exe
        }

        if ($type -match "WINGET|KURULUM|KALDIRMA") {
            try { Refresh-Winget-Status -Silent $true } catch { WpfLog "[HATA] Winget durumu: $($_.Exception.Message)" }
        }

        try {
            if ($null -ne $global:ActiveRunspaces) { [void]$global:ActiveRunspaces.Remove($ps) }
            if ($ps) { $ps.Dispose() }
        } catch {}
    }.GetNewClosure()

    $workerTimer.Add_Tick({
        try {
            # --- RAM KUYRUĞUNDAN MESAJLARI ÇEK ---
            $line = ""
            while ($msgQueue.TryDequeue([ref]$line)) {
                if ($line -match "^\[\[STATUS\]\]:(.*)") {
                    $lblStatus.Text = $Matches[1]
                }
                elseif ($line -match "^\[\[LOG\]\]:(.*)") {
                    WpfLog $Matches[1]
                }
            }

            # --- SİSTEM HATALARINI OKU ---
            if ($ps.Streams.Error.Count -gt 0) {
                $errors = $ps.Streams.Error.ReadAll()
                foreach ($err in $errors) { WpfLog "⚠️ SİSTEM: $err" }
            }

            # --- KULLANICI DURDURMA İSTEĞİ ---
            if ($global:StopOperation -and -not $finishedRef.Value) {
                WpfLog "🛑 İşlem kullanıcı tarafından durduruldu."
                & $finishAction "Durduruldu."
                return
            }

            # --- TIMEOUT KONTROLÜ ---
            if (-not $finishedRef.Value -and $workerStopwatch.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
                WpfLog "⏱️ İşlem zaman aşımına uğradı (${TimeoutSeconds}s). Zorla sonlandırılıyor."
                & $finishAction "Zaman Aşımı."
                return
            }

            # --- İŞLEM BİTTİ Mİ? ---
            if ($asyncResult.IsCompleted -and -not $finishedRef.Value) {
                & $finishAction "Tamamlandı."
            }
        }
        catch {
            WpfLog "❌ Motor Hatası: $($_.Exception.Message)"
            if (-not $finishedRef.Value) { & $finishAction "Motor Hatası." }
        }
    }.GetNewClosure())

    $workerTimer.Start()
}

function Refresh-Winget-Status {
    param([bool]$Silent = $false)
    
    # Global değişken zaten mevcut, tekrar FindName gerekmez
    if ($btnRefreshWinget) { $btnRefreshWinget.IsEnabled = $false; $btnRefreshWinget.Content = "Taranıyor..." }
    Do-Events
    
    try {
        $installedOutput = & winget list --disable-interactivity 2>&1 | Out-String
        $detectedIDs = @()
        
        foreach ($appName in $global:WingetApps.Keys) {
            $wingetID = $global:WingetApps[$appName]
            
            # DÜZELTME: Hem Winget ID'sini hem de Uygulama Adını güvenli formata çevir
            $safeID = [regex]::Escape($wingetID)
            $safeName = [regex]::Escape($appName)
            
            # 1. Tam Winget ID'si eşleşiyor mu? (Örn: Discord.Discord)
            # 2. VEYA Uygulama listesinde Adı direkt geçiyor mu? (Örn: Discord)
            if ($installedOutput -match "(?i)$safeID" -or $installedOutput -match "(?im)^$safeName\s+") {
                $detectedIDs += $wingetID
            }
        }
        
        Update-Cache -Type "Winget" -Data $detectedIDs
        Load-Winget-Tree -MemoryList $detectedIDs
        
        if (-not $Silent) { [System.Windows.MessageBox]::Show("Tarama tamamlandı.", "Bilgi") | Out-Null }
        
    } catch { WpfLog "Hata: $_" }
    
    if ($btnRefreshWinget) { $btnRefreshWinget.Content = "♻ Denetle"; $btnRefreshWinget.IsEnabled = $true }
}

# =========================================================
# BAŞLANGIÇ YÖNETİCİSİ MOTURU (%100 TASK MANAGER SENKRONİZASYONU VE UWP DESTEĞİ)
# =========================================================

# #endregion 11 -- WORKER & KOMUT CALISTIRMA (Start-Worker-Process)



# =========================================================================
# #region 12 -- BASLANGIC YONETICISI (Refresh-StartupView)
# =========================================================================

function Refresh-StartupView {
    $tempList = New-Object System.Collections.ArrayList

    if ($rbStartupWin.IsChecked) {
        
        # --- 1. KAYIT DEFTERİ ---
        $regPaths = @(
            @{ Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; ApprPath="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; Type="Registry (Kullanıcı)" },
            @{ Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ApprPath="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"; Type="Registry (Sistem)" },
            @{ Path="HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; ApprPath="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"; Type="Registry (Sistem 32)" }
        )

        foreach ($reg in $regPaths) {
            if (Test-Path $reg.Path) {
                $props = Get-ItemProperty -Path $reg.Path -ErrorAction SilentlyContinue
                $apprProps = $null
                if (Test-Path $reg.ApprPath) { $apprProps = Get-ItemProperty -Path $reg.ApprPath -ErrorAction SilentlyContinue }

                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -match "^PS" -or $p.Name -eq "System") { continue }
                    
                    $cleanName = $p.Name
                    $realPath = $p.Value

                    if ($p.Name -match "^GeminiDisabled_(.*)") {
                        $cleanName = $Matches[1]
                        Rename-ItemProperty -Path $reg.Path -Name $p.Name -NewName $cleanName -Force -ErrorAction SilentlyContinue
                    }

                    $isEnabled = $true
                    if ($apprProps -and $null -ne $apprProps.$cleanName) {
                        $byteVal = $apprProps.$cleanName[0]
                        if ($byteVal -eq 0x03 -or $byteVal -eq 0x01 -or ($byteVal % 2 -ne 0)) { $isEnabled = $false }
                    }

                    $tempList.Add([PSCustomObject]@{
                        RawName = $cleanName; Name = $cleanName; Path = $realPath
                        Type = $reg.Type; RegPath = $reg.Path; ApprPath = $reg.ApprPath
                        IsEnabled = $isEnabled
                        StatusColor = if($isEnabled){"#00CC00"}else{"#FF3333"}
                        StatusText = if($isEnabled){"Açık"}else{"Kapalı"}
                        DelayStr  = "Normal"
                        DelayColor = "#888888"
                        Source = "Registry"
                    }) | Out-Null
                }
            }
        }

        # --- 2. KLASÖR BAŞLANGICI ---
        $folderPaths = @(
            @{ Path="$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"; ApprPath="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"; Type="Klasör (Kullanıcı)" },
            @{ Path="$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\StartUp"; ApprPath="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"; Type="Klasör (Sistem)" }
        )

        foreach ($fol in $folderPaths) {
            if (Test-Path $fol.Path) {
                $apprProps = $null
                if (Test-Path $fol.ApprPath) { $apprProps = Get-ItemProperty -Path $fol.ApprPath -ErrorAction SilentlyContinue }

                Get-ChildItem -Path $fol.Path -File -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.Name -eq "desktop.ini") { return }
                    
                    $cleanName = $_.Name
                    if ($_.Extension -eq ".disabled") {
                        $cleanName = $_.Name -replace "\.disabled$", ""
                        Rename-Item -Path $_.FullName -NewName $cleanName -Force -ErrorAction SilentlyContinue
                    }

                    $isEnabled = $true
                    if ($apprProps -and $null -ne $apprProps.$cleanName) {
                        $byteVal = $apprProps.$cleanName[0]
                        if ($byteVal -eq 0x03 -or $byteVal -eq 0x01 -or ($byteVal % 2 -ne 0)) { $isEnabled = $false }
                    }

                    $tempList.Add([PSCustomObject]@{
                        RawName = $cleanName; Name = $cleanName; Path = $_.FullName
                        Type = $fol.Type; RegPath = $fol.Path; ApprPath = $fol.ApprPath
                        IsEnabled = $isEnabled
                        StatusColor = if($isEnabled){"#00CC00"}else{"#FF3333"}
                        StatusText = if($isEnabled){"Açık"}else{"Kapalı"}
                        DelayStr  = "Normal"
                        DelayColor = "#888888"
                        Source = "Folder"
                    }) | Out-Null
                }
            }
        }

        # --- 3. UWP (MICROSOFT STORE) UYGULAMALARI ---
        $uwpBase = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData"
        if (Test-Path $uwpBase) {
            $uwpPackages = Get-ChildItem -Path $uwpBase -ErrorAction SilentlyContinue
            foreach ($pkg in $uwpPackages) {
                Get-ChildItem -Path $pkg.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $taskKey = $_.PSPath
                    $stateProp = Get-ItemProperty -Path $taskKey -Name "State" -ErrorAction SilentlyContinue
                    
                    if ($null -ne $stateProp -and $null -ne $stateProp.State) {
                        $isEnabled = ($stateProp.State -eq 2)
                        
                        # --- HATA DÜZELTİLDİ ---
                        # Name yerine PSChildName kullanıyoruz ki "HKEY..." yazmasın, gerçek ismi alsın.
                        $appName = $pkg.PSChildName -replace "_.*", ""
                        
                        # Başındaki gereksiz "Microsoft." veya "Windows." yazılarını temizle (daha şık görünsün)
                        $appName = $appName -replace "(?i)^Microsoft\.", "" -replace "(?i)^Windows\.", ""
                        
                        $taskName = $_.PSChildName

                        $tempList.Add([PSCustomObject]@{
                            RawName = $taskName; Name = $appName
                            Path = "Mağaza Görevi (UWP): $taskName" 
                            Type = "UWP (Modern)"; RegPath = $taskKey; ApprPath = $taskKey
                            IsEnabled = $isEnabled
                            StatusColor = if($isEnabled){"#00CC00"}else{"#FF3333"}
                            StatusText = if($isEnabled){"Açık"}else{"Kapalı"}
                            DelayStr   = "Mağaza Uyg."
                            DelayColor = "#888888"
                            Source = "UWP"
                        }) | Out-Null
                    }
                }
            }
        }

    } else {
        # --- 4. GÖREV ZAMANLAYICI (ULTIMATE KALKAN EKLENDİ) ---
        try {
            $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
            foreach ($t in $tasks) {
                $isTarget = $false
                $isWinCore = ($t.TaskPath -match "^\\Microsoft\\Windows\\")

                # KURAL 1: SADECE WINDOWS TELEMETRİ VE CASUSLUK GÖREVLERİ (Çekirdek klasörde olsalar bile affetme)
                if ($isWinCore) {
                    if ($t.TaskPath -match "Customer Experience" -or $t.TaskPath -match "Application Experience" -or $t.TaskName -match "CEIP" -or $t.TaskName -match "BthSQM") {
                        $isTarget = $true
                    }
                }
                # KURAL 2: 3. PARTİ UYGULAMALAR (Windows çekirdek klasörü DIŞINDA kalan her şeyi tara)
                else {
                    # Kelime tuzakları (EA, Asus vb.) kaldırıldı. Daha net ve spesifik filtreler eklendi.
                    $badTasks = @("Google", "Edge", "Mozilla", "Adobe", "OneDrive", "Dropbox", "Brave", "Opera", "CCleaner", "Discord", "Steam", "Epic", "EA Desktop", "EALauncher", "NVIDIA", "AMD", "Logitech", "Razer", "AnyDesk", "TeamViewer", "Intel", "AsusUpdate", "Gigabyte", "HP", "Dell", "Lenovo", "Avast", "McAfee")
                    foreach ($b in $badTasks) { 
                        if ($t.TaskName -match "(?i)$b" -or $t.TaskPath -match "(?i)$b") { 
                            $isTarget = $true; break 
                        } 
                    }
                }

                if ($isTarget) {
                    $isEnabled = if ($t.State -eq "Ready" -or $t.State -eq "Running") { $true } else { $false }
                    $actionPath = "Görev Zamanlayıcı"
                    if ($t.Actions -and $t.Actions.Count -gt 0) { $actionPath = $t.Actions[0].Execute }

                    # Gecikme süresi: tetikleyicideki Delay değerini oku (ISO 8601 süre formatı)
                    $delayStr = "—"
                    $delayColor = "#555555"
                    try {
                        if ($t.Triggers -and $t.Triggers.Count -gt 0) {
                            $trig = $t.Triggers[0]
                            if ($trig.Delay -and $trig.Delay -ne "PT0S" -and $trig.Delay -ne "") {
                                # ISO 8601: PT30S=30sn, PT5M=5dk, PT1H=1sa
                                $raw = $trig.Delay
                                if ($raw -match "PT(\d+)H(\d+)M(\d+)S") {
                                    $delayStr  = "$($Matches[1])sa $($Matches[2])dk"
                                } elseif ($raw -match "PT(\d+)M(\d+)S") {
                                    $delayStr  = "$($Matches[1])dk $($Matches[2])sn"
                                } elseif ($raw -match "PT(\d+)M") {
                                    $delayStr  = "$($Matches[1]) dakika"
                                } elseif ($raw -match "PT(\d+)S") {
                                    $sec = [int]$Matches[1]
                                    $delayStr = if ($sec -ge 60) { "$([int]($sec/60)) dk" } else { "$sec sn" }
                                } elseif ($raw -match "PT(\d+)H") {
                                    $delayStr  = "$($Matches[1]) saat"
                                } else {
                                    $delayStr = $raw
                                }
                                $delayColor = "#E68A00"
                            } else {
                                $delayStr  = "Anında"
                                $delayColor = "#888888"
                            }
                        }
                    } catch {}

                    $tempList.Add([PSCustomObject]@{
                        RawName = $t.TaskName; Name = $t.TaskName; Path = $actionPath
                        Type = "Görev (Task)"; RegPath = $t.TaskPath; ApprPath = ""
                        IsEnabled = $isEnabled
                        StatusColor = if($isEnabled){"#00CC00"}else{"#FF3333"}
                        StatusText = if($isEnabled){"Açık"}else{"Kapalı"}
                        DelayStr   = $delayStr
                        DelayColor = $delayColor
                        Source = "Task"
                        TaskObj = $t
                    }) | Out-Null
                }
            }
        } catch {}
    }

    $Win.Dispatcher.Invoke([action]{
        $lvStartup.Items.Clear()
        foreach ($item in $tempList | Sort-Object Name) { $lvStartup.Items.Add($item) | Out-Null }
    })
}

# =============================================================

# #endregion 12 -- BASLANGIC YONETICISI (Refresh-StartupView)

# #region 13 -- UI / MODAL FONKSIYONLARI
# Tools, Profiller, Dashboard, Donanim, Dialog pencereleri,
# Bloatware yoneticisi, Buyuk dosya tarayici vb.
# =============================================================

# ---- Fill-WatcherComboBox ----
function Fill-WatcherComboBox($cb, $otherCb) {
    $current = if ($cb.SelectedItem) { $cb.SelectedItem.Tag } else { $null }
    $cb.Items.Clear()

    $excluded = @('svchost','csrss','smss','wininit','winlogon','lsass','services',
                  'System','Idle','Registry','MemCompression','fontdrvhost','dwm',
                  'conhost','RuntimeBroker','SearchHost','StartMenuExperienceHost',
                  'ShellExperienceHost','sihost','taskhostw','ctfmon','spoolsv',
                  'WmiPrvSE','dllhost','msdtc','VBCSCompiler')

    # "Yok / Seçme" seçeneği
    $noneItem = New-Object System.Windows.Controls.ComboBoxItem
    $noneItem.Content = "— Seçme —"
    $noneItem.Tag = "none"
    $cb.Items.Add($noneItem) | Out-Null

    Get-Process | Where-Object {
        $_.MainWindowHandle -ne 0 -or $_.Name -match 'EA|steam|battle|uplay|epic|riot|game|bf|cod|apex|valve|origin|link2'
    } | Where-Object { $_.Name -notin $excluded } |
    Sort-Object Name | Select-Object -Unique Name | ForEach-Object {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = "$($_.Name).exe"
        $item.Tag = $_.Name
        $cb.Items.Add($item) | Out-Null
    }

    $customItem = New-Object System.Windows.Controls.ComboBoxItem
    $customItem.Content = "✏️ Manuel Gir"
    $customItem.Tag = "custom"
    $cb.Items.Add($customItem) | Out-Null

    # Önceki seçimi koru
    $restored = $false
    if ($current) {
        foreach ($item in $cb.Items) {
            if ($item.Tag -eq $current) { $cb.SelectedItem = $item; $restored = $true; break }
        }
    }
    if (-not $restored) { $cb.SelectedIndex = 0 }
}

# ---- Get-WebLink + Refresh-Tools-Menu ----
function Get-WebLink {
    param($Url, $RegexPattern, $Keyword)
    try {
        # Güvenlik Protokolleri
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        
        # --- HEADER AYARLARI ---
        # HATA DÜZELTİLDİ: "Connection" satırı silindi.
        $headers = @{
            "User-Agent"      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            "Accept"          = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
            "Accept-Language" = "en-US,en;q=0.9,tr;q=0.8"
            "Referer"         = $Url 
        }

        # İsteği Gönder
        $response = Invoke-WebRequest -Uri $Url -Headers $headers -UseBasicParsing -ErrorAction Stop
        $html = $response.Content
        
        # 1. YÖNTEM: Özel Regex
        if (-not [string]::IsNullOrWhiteSpace($RegexPattern)) {
            if ($html -match $RegexPattern) { return $Matches[1] }
        }

        # 2. YÖNTEM: Akıllı Anahtar Kelime Taraması
        if (-not [string]::IsNullOrWhiteSpace($Keyword)) {
            $linkMatches = [regex]::Matches($html, "<a\s+(.*?)href\s*=\s*[""']([^""']+\.(?:exe|msi|zip|7z|rar))[""'](.*?)>", "IgnoreCase")
            
            foreach ($match in $linkMatches) {
                $wholeTag = $match.Value       
                $linkUrl  = $match.Groups[2].Value 
                
                if ($wholeTag -match [regex]::Escape($Keyword)) {
                    # Link tamamlama
                    if ($linkUrl -match "^/") { 
                        $uri = New-Object System.Uri($Url)
                        return "https://" + $uri.Host + $linkUrl
                    }
                    if ($linkUrl -notmatch "^http") { return $Url.TrimEnd('/') + '/' + $linkUrl }
                    
                    return $linkUrl
                }
            }
        }
        
        return $null
    } catch { return "ERROR: $($_.Exception.Message)" }
}

# --- DİNAMİK MENÜYÜ YÜKLE ---
function Refresh-Tools-Menu {
    $ctxToolsMenu.Items.Clear()
    
    # 1. BÖLÜM: HAZIR SİSTEM ARAÇLARI (GÖMÜLÜ GITHUB)
    if ($global:EmbeddedTools.Count -gt 0) {
        $header1 = New-Object System.Windows.Controls.MenuItem
        $header1.Header = "🌟 HAZIR ARAÇLAR (PORTABLE)"
        $header1.IsEnabled = $false
        $header1.Foreground = [System.Windows.Media.Brushes]::Yellow
        $ctxToolsMenu.Items.Add($header1) | Out-Null

        foreach ($toolName in $global:EmbeddedTools.Keys) {
            $item = New-Object System.Windows.Controls.MenuItem
            $item.Header = "  $toolName"
            $item.Tag = $global:EmbeddedTools[$toolName] # Repo yolu saklanır
            $item.Add_Click($script:RunEmbeddedToolBlock.GetNewClosure())
            $ctxToolsMenu.Items.Add($item) | Out-Null
        }
        $ctxToolsMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
    }
	
	# 1.5 BÖLÜM: ÖZEL SİSTEM ARAÇLARI (İLK KULLANIMDA GITHUB'DAN İNDİRİLİR, SONRA CACHE)
    $headerBase64 = New-Object System.Windows.Controls.MenuItem
    $headerBase64.Header = "⚡ ÖZEL SİSTEM ARAÇLARI"
    $headerBase64.IsEnabled = $false
    $headerBase64.Foreground = [System.Windows.Media.Brushes]::Orange
    $ctxToolsMenu.Items.Add($headerBase64) | Out-Null

    $itemMsi = New-Object System.Windows.Controls.MenuItem
    $itemMsi.Header = "  MSI Utility V3"
    $itemMsi.Add_Click($script:RunMsiUtilityBlock.GetNewClosure())
    $ctxToolsMenu.Items.Add($itemMsi) | Out-Null

    $ctxToolsMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

    # 2. BÖLÜM: KULLANICI WEB ARAÇLARI (SCRAPER)
    if ($global:CustomTools.Count -gt 0) {
        $header2 = New-Object System.Windows.Controls.MenuItem
        $header2.Header = "🌐 BENİM ARAÇLARIM"
        $header2.IsEnabled = $false
        $header2.Foreground = [System.Windows.Media.Brushes]::Cyan
        $ctxToolsMenu.Items.Add($header2) | Out-Null

        foreach ($tool in $global:CustomTools) {
            $item = New-Object System.Windows.Controls.MenuItem
            $item.Header = "  $($tool.Name)"
            $item.Tag = $tool
            $item.Add_Click($script:RunToolBlock.GetNewClosure())
            $ctxToolsMenu.Items.Add($item) | Out-Null
        }
        $ctxToolsMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
    }
	# 2.5 BÖLÜM: SİSTEM ARAÇLARI
    $itemDrv = New-Object System.Windows.Controls.MenuItem
    $itemDrv.Header = "📦 Sürücüleri Yedekle (Export)"
    $itemDrv.Add_Click($script:ExportDriversBlock.GetNewClosure())
    $ctxToolsMenu.Items.Add($itemDrv) | Out-Null
    
    $ctxToolsMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
    
    # 3. BÖLÜM: YÖNET BUTONU
    $itmManage = New-Object System.Windows.Controls.MenuItem
    $itmManage.Header = "⚙ Araçları Yönet..."
    $itmManage.FontWeight = "Bold"
    $itmManage.Add_Click({ Show-ToolManager })
    $ctxToolsMenu.Items.Add($itmManage) | Out-Null

    # 4. BÖLÜM: PROGRAM GÜNCELLEMESI
    $ctxToolsMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
    $itmAppUpdate = New-Object System.Windows.Controls.MenuItem
    if ($global:UpdateAvailable) {
        $itmAppUpdate.Header = "🔔 Programı Güncelle ($($global:UpdateAvailable.Tag) hazır)"
        $itmAppUpdate.Foreground = [System.Windows.Media.Brushes]::LimeGreen
        $itmAppUpdate.FontWeight = "Bold"
    } else {
        $itmAppUpdate.Header = "🔄 Programı Güncelle (kontrol et)"
        # Cyan tonu — tema ile uyumlu, MenuItem koyu arka planda net okunur
        $itmAppUpdate.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#4CC2FF"))
    }
    $itmAppUpdate.Add_Click({
        if ($global:UpdateAvailable) {
            Show-AppUpdateWindow
        } else {
            # Manuel kontrol — Test-AppUpdate'i tekrar cagir, biraz bekle, sonra Show-AppUpdateWindow
            WpfLog "[Update] Manuel kontrol: GitHub Releases sorgulaniyor..."
            Test-AppUpdate
            # 6 sn icinde sonuc gelmezse "yok" mesaji
            $script:UpdManualTimer = New-Object System.Windows.Threading.DispatcherTimer
            $script:UpdManualTimer.Interval = [TimeSpan]::FromSeconds(6)
            $script:UpdManualTimer.Add_Tick({
                $script:UpdManualTimer.Stop()
                if ($global:UpdateAvailable) {
                    Show-AppUpdateWindow
                } else {
                    [System.Windows.MessageBox]::Show("Su an icin yeni bir surum yok. Mevcut: v$($global:AppVersion)", "Guncel", "OK", "Information") | Out-Null
                }
            })
            $script:UpdManualTimer.Start()
        }
    })
    $ctxToolsMenu.Items.Add($itmAppUpdate) | Out-Null
}

# ---- Tool script blocks ----
$script:RunEmbeddedToolBlock = {
    $repo = $this.Tag
    $toolName = $this.Header.Trim()
    $btnTools.IsEnabled = $false
    
    WpfLog "--- GITHUB ARACI: $toolName ---"
    WpfLog "[API] GitHub üzerinden sürümler kontrol ediliyor..."
    Do-Events

    $apiUrl = "https://api.github.com/repos/$repo/releases"
    
    # API Sorgusunu Arka Planda Yap (JSON'a Çevirerek Güvenli Aktarım Sağlıyoruz)
    $script:GhRunspace = [powershell]::Create()
    $script:GhRunspace.AddScript({
        param($u)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        try {
            $headers = @{"User-Agent" = "GeminiCare-App"}
            $res = Invoke-RestMethod -Uri $u -Headers $headers -Method Get -TimeoutSec 10 -ErrorAction Stop
            # Array bozulmasını önlemek için sonucu JSON'a sıkıştırıp metin olarak yolluyoruz
            return ($res | ConvertTo-Json -Depth 10 -Compress)
        } catch { return $null }
    }).AddArgument($apiUrl) | Out-Null

    $script:GhAsync = $script:GhRunspace.BeginInvoke()

    $script:GhTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:GhTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    
    $script:GhTimer.Add_Tick({
        if (-not $script:GhAsync.IsCompleted) { return }
        $script:GhTimer.Stop()

        try {
            $rawJson = $script:GhRunspace.EndInvoke($script:GhAsync) -join ""
            
            if (-not $rawJson -or $rawJson -eq "") {
                WpfLog "❌ [HATA] Sürüm bilgisi alınamadı. (İnternet veya API sınırı)"
                $btnTools.IsEnabled = $true
                return
            }

            # JSON metnini güvenli bir şekilde tekrar listeye çeviriyoruz
            $releases = $rawJson | ConvertFrom-Json

            # --- SÜRÜM KARAR MEKANİZMASI ---
            $targetRelease = $null
            # Artık $releases[0] kesinlikle SADECE İLK SÜRÜMÜ verir!
            $latest = $releases[0]
            
            if ($latest.prerelease -eq $true) {
                $stable = $releases | Where-Object { $_.prerelease -eq $false } | Select-Object -First 1
                
                # --- SENİN TASARIMIN: ÖZEL WPF PENCERESİ (XAML) ---
                $xamlVersionSelect = @"
                <Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
                        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
                        Title='Sürüm Seçimi' Height='280' Width='520' 
                        Background='#181818' WindowStartupLocation='CenterOwner' WindowStyle='ToolWindow' ResizeMode='NoResize'>
                    <Window.Resources>
                        <Style TargetType='Button'>
                            <Setter Property='Foreground' Value='White'/>
                            <Setter Property='Cursor' Value='Hand'/>
                            <Setter Property='Template'>
                                <Setter.Value>
                                    <ControlTemplate TargetType='Button'>
                                        <Border x:Name='border' CornerRadius='8' Background='{TemplateBinding Background}' BorderThickness='0'>
                                            <ContentPresenter HorizontalAlignment='Center' VerticalAlignment='Center' Margin='{TemplateBinding Padding}'/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property='IsMouseOver' Value='True'> <Setter TargetName='border' Property='Opacity' Value='0.8'/> </Trigger>
                                            <Trigger Property='IsPressed' Value='True'> <Setter TargetName='border' Property='Opacity' Value='0.6'/> </Trigger>
                                            <Trigger Property='IsEnabled' Value='False'> <Setter TargetName='border' Property='Opacity' Value='0.2'/> </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </Style>
                    </Window.Resources>
                    <Grid Margin='20'>
                        <Grid.RowDefinitions>
                            <RowDefinition Height='Auto'/>
                            <RowDefinition Height='Auto'/>
                            <RowDefinition Height='*'/>
                            <RowDefinition Height='Auto'/>
                        </Grid.RowDefinitions>
                        
                        <TextBlock x:Name='txtTitle' Text='Yeni Sürüm Tespit Edildi' Foreground='#4CC2FF' FontSize='18' FontWeight='Bold' HorizontalAlignment='Center'/>
                        <TextBlock Grid.Row='1' Text='Bu araç için yeni bir test (Beta) sürümü mevcut. Lütfen indirmek istediğiniz versiyonu seçin:' Foreground='#AAA' TextWrapping='Wrap' Margin='0,10,0,20' TextAlignment='Center'/>
                        
                        <UniformGrid Grid.Row='2' Columns='2'>
                            <!-- STABİL BUTONU -->
                            <Button x:Name='btnStable' Background='#006600' Margin='0,0,5,0'>
                                <StackPanel Margin='10'>
                                    <TextBlock Text='🌟 STABİL SÜRÜM' Foreground='White' FontSize='15' FontWeight='Bold' HorizontalAlignment='Center'/>
                                    <TextBlock x:Name='txtStableVer' Text='v...' Foreground='#DDD' FontSize='12' HorizontalAlignment='Center' Margin='0,5,0,0'/>
                                </StackPanel>
                            </Button>
                            
                            <!-- BETA BUTONU -->
                            <Button x:Name='btnBeta' Background='#E68A00' Margin='5,0,0,0'>
                                <StackPanel Margin='10'>
                                    <TextBlock Text='🧪 BETA SÜRÜM' Foreground='White' FontSize='15' FontWeight='Bold' HorizontalAlignment='Center'/>
                                    <TextBlock x:Name='txtBetaVer' Text='v...' Foreground='#DDD' FontSize='12' HorizontalAlignment='Center' Margin='0,5,0,0'/>
                                </StackPanel>
                            </Button>
                        </UniformGrid>
                        
                        <Button x:Name='btnCancel' Grid.Row='3' Content='İptal Et' Background='#333' Foreground='White' Width='100' Height='30' Margin='0,15,0,0' HorizontalAlignment='Right'/>
                    </Grid>
                </Window>
"@
                $readerVer = New-Object System.Xml.XmlNodeReader ([xml]$xamlVersionSelect)
                $winVer = [Windows.Markup.XamlReader]::Load($readerVer)
                $winVer.Owner = $Win

                $winVer.FindName('txtTitle').Text = "$toolName - Sürüm Seçimi"
                $winVer.FindName('txtBetaVer').Text = "$($latest.tag_name) (Deneysel)"
                
                $btnStable = $winVer.FindName('btnStable')
                if ($stable) {
                    $winVer.FindName('txtStableVer').Text = "$($stable.tag_name) (Önerilen)"
                } else {
                    $winVer.FindName('txtStableVer').Text = "Bulunamadı"
                    $btnStable.IsEnabled = $false
                }

                $btnBeta = $winVer.FindName('btnBeta')
                $btnCancel = $winVer.FindName('btnCancel')

                $script:SelectedRelease = $null

                $btnStable.Add_Click({ $script:SelectedRelease = $stable; $winVer.Close() })
                $btnBeta.Add_Click({ $script:SelectedRelease = $latest; $winVer.Close() })
                $btnCancel.Add_Click({ $winVer.Close() })

                # Sızıntı Koruması (Belleği Temizle)
                $winVer.Add_Closed({
                    $btnStable = $null; $btnBeta = $null; $btnCancel = $null
                })

                $winVer.ShowDialog() | Out-Null

                # Karar kontrolü
                if ($null -eq $script:SelectedRelease) {
                    WpfLog "⚠️[İPTAL] İşlem kullanıcı tarafından iptal edildi."
                    $btnTools.IsEnabled = $true
                    return
                }
                
                $targetRelease = $script:SelectedRelease
            } else {
                $targetRelease = $latest
                WpfLog "[BİLGİ] En güncel stabil sürüm otomatik seçildi."
            }

            WpfLog "[SÜRÜM] İndirilecek: $($targetRelease.tag_name)"

            # --- ZIP DOSYASINI BUL ---
            $asset = $targetRelease.assets | Where-Object { $_.name -match '\.zip$' } | Select-Object -First 1
            if (-not $asset) {
                WpfLog "❌ [HATA] Bu sürüm için .zip dosyası bulunamadı."
                $btnTools.IsEnabled = $true
                return
            }

            $downloadUrl = $asset.browser_download_url
            $fileName = $asset.name

            # İndirme klasörünü ayarla
            $targetDir = if ($global:ToolDownloadPath) { $global:ToolDownloadPath } else { "$env:USERPROFILE\Downloads" }
            if (-not (Test-Path $targetDir)) { try { New-Item -Path $targetDir -ItemType Directory -Force | Out-Null } catch { $targetDir = "$env:TEMP" } }
            
            $instPath = Join-Path $targetDir $fileName

            # --- YENİ V3 WORKER SCRIPT (HIZLI RAM KUYRUĞU İLE) ---
            $innerScript = @"
                WS 'İndiriliyor...'
                Log 'İNDİRİLİYOR: $fileName'
                
                try {
                    if (Test-Path '$instPath') { Remove-Item '$instPath' -Force -ErrorAction SilentlyContinue }

                    `$wc = New-Object System.Net.WebClient
                    `$wc.Headers.Add("User-Agent", "GeminiCare-App")
                    `$wc.DownloadFile('$downloadUrl', '$instPath')
                    
                    if (Test-Path '$instPath') {
                        `$size = (Get-Item '$instPath').Length
                        if (`$size -gt 0) {
                            # MoTW (İnternet Damgası) Temizliği
                            Unblock-File '$instPath' -ErrorAction SilentlyContinue
                            
                            Log '✅ BAŞARILI: İndirme tamamlandı.'
                            WS 'Açılıyor...'
                            
                            # Zip dosyasını MAVİ RENKLE SEÇİLİ olarak Windows Gezgini'nde aç
                            Start-Process explorer.exe -ArgumentList '/select,`"$instPath`"'
                            
                        } else { throw "İndirilen dosya boş." }
                    } else { throw "Dosya indirilemedi." }
                } catch { 
                    Log "❌ HATA: `$($_.Exception.Message)" 
                }
                WS 'Bitti'
"@

            # İşçi Havuzuna Gönder (Start-Worker-Process)
            Start-Worker-Process $innerScript $btnTools "ARAÇ İNDİRME"

        } catch {
            WpfLog "❌ HATA: $($_.Exception.Message)"
            $btnTools.IsEnabled = $true
        } finally {
            if ($script:GhRunspace) { 
                $script:GhRunspace.Dispose()
                $script:GhRunspace = $null 
            }
        }
    })
    $script:GhTimer.Start()
}

# --- SÜRÜCÜ YEDEKLEME (DRIVER EXPORT) MANTIĞI ---
$script:ExportDriversBlock = {
    # 1. Klasör Seçme Diyaloğu (UI Thread)
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "Sürücülerin yedekleneceği klasörü seçin:"
    
    if ($fbd.ShowDialog() -eq 'OK') {
        $targetDir = $fbd.SelectedPath
        
        # Klasör dolu mu kontrolü
        if ((Get-ChildItem $targetDir -ErrorAction SilentlyContinue).Count -gt 0) {
            $msg = "Seçilen klasör boş değil. Mevcut dosyaların üzerine yazılabilir veya karmaşa oluşabilir.`n`nYine de devam edilsin mi?"
            if ([System.Windows.MessageBox]::Show($msg, "Uyarı", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -eq 'No') { return }
        }

        # UI Hazırlığı
        $txtLog.Text = ""
        WpfLog "--- SÜRÜCÜ YEDEKLEME BAŞLATILDI (RAM MODU) ---"
        WpfLog "Hedef: $targetDir"
        $pbMain.IsIndeterminate = $true

        # 2. Arka Planda Çalışacak Script Bloğu (Boşluk Hatası Giderildi!)
        $innerScript = @"
            WS 'Hazırlanıyor...'
            Log 'İŞLEM BAŞLATILDI: DISM Driver Export'
            Log 'Lütfen bekleyin, sürücü sayısına göre 1-5 dakika sürebilir...'
            
            WS 'Sürücüler taranıyor...'
            
            # DISM komutunu çalıştır ve çıktısını yakala
            & dism /online /export-driver /destination:`"$targetDir`" 2>&1 | ForEach-Object {
                `$line = `$_.ToString().Trim()
                if (-not [string]::IsNullOrWhiteSpace(`$line)) {
                    Log ">> `$line"
                }
            }
            
            if (Test-Path `"$targetDir`") {
                Log '----------------------------------------'
                Log '✅ İŞLEM BAŞARIYLA TAMAMLANDI.'
                WS 'Bitti'
                
                # Klasörü kullanıcı için otomatik aç
                explorer.exe `"$targetDir`"
            }
"@

        Start-Worker-Process $innerScript $btnTools "SÜRÜCÜ YEDEKLEME"
    }
}
# --- ARAÇ ÇALIŞTIRMA MANTIĞI (V2 - GÜVENLİ VE DİSKSİZ) ---
$script:RunToolBlock = {
    $tool = $this.Tag
    $btnTools.IsEnabled = $false
    
    # UI Temizliği
    $txtLog.Text = ""
    WpfLog "--- ARAÇ BAŞLATILDI: $($tool.Name) ---"
    WpfLog "[WEB] Güncel sürüm taranıyor: $($tool.Url)"
    Do-Events
    
    # 1. Linki bul (UI thread'de hızlıca regex/keyword taraması yapar)
    $foundLink = Get-WebLink -Url $tool.Url -RegexPattern $tool.Regex -Keyword $tool.Keyword
    
    if (-not $foundLink -or $foundLink -match "^ERROR") {
        WpfLog "❌ [HATA] İndirme linki bulunamadı: $foundLink"
        $btnTools.IsEnabled = $true
        return
    }
    
    $fileName = [System.IO.Path]::GetFileName($foundLink.Split('?')[0])
    $targetDir = if ($global:ToolDownloadPath) { $global:ToolDownloadPath } else { "$env:USERPROFILE\Downloads" }
    $instPath = Join-Path $targetDir $fileName
    
    WpfLog "[BULUNDU] Dosya: $fileName"
    WpfLog "[HEDEF] $targetDir"
    $pbMain.IsIndeterminate = $true

    # 2. ARKA PLAN İŞÇİ SCRİPTİ (Start-Worker-Process için)
    # Not: $instPath ve $foundLink gibi dış değişkenleri string içine gömdük.
    $innerScript = @"
        WS 'Hazırlanıyor...'
        Log 'BAŞLATILIYOR: $fileName'
        
        try {
            if (Test-Path '$instPath') { Remove-Item '$instPath' -Force -ErrorAction SilentlyContinue }

            WS 'İndiriliyor...'
            `$wc = New-Object System.Net.WebClient
            # Anti-403 Koruması (Chrome Taklidi)
            `$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
            `$wc.Headers.Add("Referer", "$($tool.Url)")
            
            `$wc.DownloadFile('$foundLink', '$instPath')
            
            if (Test-Path '$instPath') {
                `$size = (Get-Item '$instPath').Length
                if (`$size -gt 0) {
                    Unblock-File '$instPath'
                    Log '✅ İndirme tamamlandı.'
                    
                    # --- G1 GÜVENLİK KONTROLÜ ---
                    Log 'GÜVENLİK: Dijital imza doğrulanıyor...'
                    `$sig = Get-AuthenticodeSignature -FilePath '$instPath'
                    
                    if (`$sig.Status -eq 'HashMismatch') {
                        Log "❌ KRİTİK HATA: Dosya bütünlüğü bozuk! (HashMismatch)"
                        throw "Güvenlik İhlali: Dosya değiştirilmiş olabilir."
                    }
                    elseif (`$sig.Status -eq 'NotSigned') {
                        Log "⚠️ UYARI: Dosya imzasız (Açık Kaynak/Portable). Devam ediliyor..."
                    }
                    else {
                        Log "✅ İMZA DOĞRULANDI: `$(`$sig.Status)"
                    }

                    # --- ÇALIŞTIRMA ---
                    Log 'ÇALIŞTIRILIYOR: Kurulum başlatılıyor...'
                    WS 'Kuruluyor...'
                    `$p = Start-Process -FilePath '$instPath' -PassThru
                    
                    if (`$p) {
                        Log "🚀 TAMAMLANDI: Uygulama başlatıldı (PID: `$(`$p.Id))"
                    }
                } else { throw "İndirilen dosya 0 KB!" }
            }
        } catch {
            Log "❌ HATA: `$($_.Exception.Message)"
        }
        WS 'Bitti'
"@

    # 3. Havuza Gönder
    Start-Worker-Process $innerScript $btnTools "ARAÇ KURULUMU"
}

# --- MSI UTILITY V3: GITHUB'DAN İNDİR + CACHE ---
# İlk kullanımda GitHub raw'dan indirir, sonraki kullanımlarda cache'den çalıştırır.
# Base64 gömme yerine bu yaklaşım: antivirüs dostu + dosya boyutu küçük.
$script:RunMsiUtilityBlock = {
    $btnTools.IsEnabled = $false
    $targetPath  = "$AppDataPath\MSI_Utility_V3.exe"
    $downloadUrl = "https://raw.githubusercontent.com/zeugmass/MSI_Utility_v3/main/MSI_util_v3.exe"

    # --- CACHE HIT: daha önce indirildiyse direkt çalıştır ---
    if (Test-Path $targetPath) {
        try {
            WpfLog "--- MSI Utility V3 (önbellekten) ---"
            Start-Process -FilePath $targetPath -Verb RunAs
            WpfLog "🚀 Başlatıldı."
        } catch {
            WpfLog "❌ [HATA] Çalıştırma: $($_.Exception.Message)"
            WpfLog "   Cache bozulmuş olabilir. Dosyayı silip tekrar deneyin: $targetPath"
        }
        $btnTools.IsEnabled = $true
        return
    }

    # --- İLK KULLANIM: GitHub'dan indir (async, UI donmaz) ---
    WpfLog "--- MSI UTILITY V3 (ilk kullanım) ---"
    WpfLog "[GITHUB] Kaynak: $downloadUrl"
    $pbMain.IsIndeterminate = $true

    $innerScript = @"
        WS 'İndiriliyor...'
        Log 'İNDİRİLİYOR: MSI_util_v3.exe'
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            `$wc = New-Object System.Net.WebClient
            `$wc.Headers.Add("User-Agent", "GeminiCare-App")
            `$wc.DownloadFile('$downloadUrl', '$targetPath')

            if ((Test-Path '$targetPath') -and (Get-Item '$targetPath').Length -gt 0) {
                `$size = [Math]::Round((Get-Item '$targetPath').Length / 1KB, 1)
                Unblock-File -Path '$targetPath' -ErrorAction SilentlyContinue
                Log ("✅ İndirildi: " + `$size + " KB")

                WS 'Başlatılıyor...'
                Start-Process -FilePath '$targetPath' -Verb RunAs
                Log '🚀 MSI Utility V3 çalıştırıldı.'
            } else {
                throw "İndirilen dosya boş veya kaydedilemedi."
            }
        } catch {
            Log "❌ HATA: `$(`$_.Exception.Message)"
            Log "   Not: Antivirüs dosyayı engelliyor olabilir."
            Log "   Çözüm: GeminiCare klasörünü istisnaya ekleyin: $AppDataPath"
        }
        WS 'Bitti'
"@

    Start-Worker-Process $innerScript $btnTools "MSI UTILITY"
}

# ---- Show-ToolManager ----
function Show-ToolManager {
    try {
        # DÜZELTME: Doğrudan temiz XAML'ı yüklüyoruz, -replace yok.
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlToolMgr)
        $winTM = [Windows.Markup.XamlReader]::Load($reader)
        
        # Kontroller
        $lst = $winTM.FindName('lstTools'); $tN = $winTM.FindName('txtName'); $tU = $winTM.FindName('txtUrl'); 
        $tK = $winTM.FindName('txtKeyword'); $tR = $winTM.FindName('txtRegex'); $tRes = $winTM.FindName('txtResult')
        $bN = $winTM.FindName('btnNew'); $bD = $winTM.FindName('btnDel'); $bS = $winTM.FindName('btnSaveAll'); $bT = $winTM.FindName('btnTest')
        $tDP = $winTM.FindName('txtDownPath'); $bPP = $winTM.FindName('btnPickPath')

        # İndirme Yolu Yükle
        if ($global:ToolDownloadPath) { $tDP.Text = $global:ToolDownloadPath } 
        else { $tDP.Text = "$env:USERPROFILE\Downloads" }

        # Listeyi Doldur
        if ($global:CustomTools) { foreach ($t in $global:CustomTools) { $lst.Items.Add($t.Name)|Out-Null } }
        
        # Seçim Olayı
        $lst.Add_SelectionChanged({
            if ($lst.SelectedIndex -ne -1) {
                $sel = $global:CustomTools | Where {$_.Name -eq $lst.SelectedItem}
                if($sel){ $tN.Text=$sel.Name; $tU.Text=$sel.Url; $tK.Text=$sel.Keyword; $tR.Text=$sel.Regex }
            }
        })
        
        $bN.Add_Click({ $lst.SelectedIndex=-1; $tN.Text=""; $tU.Text=""; $tK.Text=""; $tR.Text=""; $tRes.Text="" })
        
        # Klasör Seçimi
        $bPP.Add_Click({
            $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($fbd.ShowDialog() -eq 'OK') { $tDP.Text = $fbd.SelectedPath }
        })

        $bT.Add_Click({
            if (-not $tU.Text) { $tRes.Text = "Lütfen URL girin."; return }
            $tRes.Text = "Taranıyor..."; $tRes.Foreground = [System.Windows.Media.Brushes]::Yellow; Do-Events
            $link = Get-WebLink -Url $tU.Text -RegexPattern $tR.Text -Keyword $tK.Text
            if ($link -match "^ERROR") { $tRes.Text = $link; $tRes.Foreground = [System.Windows.Media.Brushes]::Red } 
            elseif ($link) { $tRes.Text = "✔ BULUNDU!`n$link"; $tRes.Foreground = [System.Windows.Media.Brushes]::LimeGreen } 
            else { $tRes.Text = "❌ BULUNAMADI."; $tRes.Foreground = [System.Windows.Media.Brushes]::Orange }
        })
        
        $bS.Add_Click({
            if (-not $tN.Text) { return }
            $newTool = @{ Name=$tN.Text; Url=$tU.Text; Keyword=$tK.Text; Regex=$tR.Text }
            $exists = $false
            for($i=0; $i -lt $global:CustomTools.Count; $i++) {
                if ($global:CustomTools[$i].Name -eq $tN.Text) { $global:CustomTools[$i] = $newTool; $exists=$true; break }
            }
            if (-not $exists) { $global:CustomTools += $newTool; $lst.Items.Add($tN.Text)|Out-Null }
            
            # Yolu Kaydet
            $global:ToolDownloadPath = $tDP.Text
            
            Mark-ConfigDirty; Refresh-Tools-Menu
            [System.Windows.MessageBox]::Show("Kaydedildi.")|Out-Null
        })
        
        $bD.Add_Click({
            if ($lst.SelectedIndex -ne -1) {
                $name = $lst.SelectedItem; $global:CustomTools = $global:CustomTools | Where {$_.Name -ne $name}
                $lst.Items.Remove($name); Mark-ConfigDirty; Refresh-Tools-Menu
            }
        })
		
        
        $winTM.Add_Closed({
        # 1. Pencere içindeki tüm UI referanslarını null yaparak bağı kopar
        $lst = $null; $tN = $null; $tU = $null; $tK = $null; $tR = $null
        $tRes = $null; $bN = $null; $bD = $null; $bS = $null; $bT = $null
        $tDP = $null; $bPP = $null
        
        # 2. Bellek Temizleyiciyi Çağır (Noktalı virgül eklendi, artık hata vermez)
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        # Opsiyonel: Log ekleyerek temizliği teyit et (Debug modu için)
        if ($chkDebug.IsChecked) { WpfLog "[DEBUG] Araç Yöneticisi belleği tahliye edildi." }
    })
		$winTM.ShowDialog() | Out-Null
    } catch { WpfLog "Yönetici hatası: $_" }
}

# ---- RecommendedProfiles + Show-RecommendedProfiles ----
$script:RecommendedProfiles = @{

    "Oyun" = @{
        Icon        = "🎮"
        Title       = "Oyun / Düşük Gecikme"
        Description = "Input lag azaltma, CPU/ağ optimizasyonu"
        Color       = "#1A472A"
        AccentColor = "#4CAF50"
        Tweaks      = @(
            "Nihai Performans Güç Planını Aktif Et",
            "Win32 Öncelik Ayırma (CPU Oyuna Odaklanır)",
            "Fare İvmesini (Acceleration) Tamamen Kapat",
            "Mouse Sürücü Önceliği (Thread Priority: High)",
            "Mouse Data Queue Size (Tamponu Artır)",
            "Keyboard Sürücü Önceliği (Thread Priority: High)",
            "Keyboard Data Queue Size (Tamponu Artır)",
            "MSI Mode (GPU Interrupt) Aç",
            "Network Throttling Kapat (Ağ Kısıtlamasını Kaldır)",
            "TCP NoDelay ve AckFrequency (Nagle Algoritmasını Kapat)",
            "Dinamik Tık (Dynamic Tick) Kapat",
            "HPET (Platform Clock) Kapat",
            "Platform Tick Zorla (Stabilite)",
            "Görsel Efektler: Özel (Yazı Tipi + Küçük Resimler Açık)",
            "Xbox Game DVR Kapat"
        )
    }

    "Gizlilik" = @{
        Icon        = "🔒"
        Title       = "Gizlilik Odaklı"
        Description = "Telemetri, izinler ve Microsoft takibini kapatır"
        Color       = "#1A1A4A"
        AccentColor = "#4A90D9"
        Tweaks      = @(
            "Reklam Kimliğini Kapat",
            "Konum Hizmetlerini Tamamen Kapat",
            "Kamera (Webcam) Erişimini Tamamen Kapat",
            "Bildirim Erişimi Kapat",
            "Kişilere (Contacts) Erişimi Kapat",
            "Takvim Erişimi Kapat",
            "Telefon Araması Erişimi Kapat",
            "Arama Geçmişi Erişimi Kapat",
            "E-posta Erişimi Kapat",
            "Görevler (Tasks) Erişimi Kapat",
            "Mesajlaşma (Chat) Erişimi Kapat",
            "Radyo (Bluetooth vb.) Erişimi Kapat",
            "Uygulama Tanılama (Diagnostics) Erişimi Kapat",
            "Arka Plan Uygulamalarını Kapat (Sistem Politikası)",
            "Cortana ve Cloud Aramayı Tamamen Kapat",
            "Yerel olarak uygun içerik Kapat"
        )
    }

    "Hiz" = @{
        Icon        = "⚡"
        Title       = "Maksimum Hız"
        Description = "Gereksiz servisleri ve görsel efektleri kapatır"
        Color       = "#4A2800"
        AccentColor = "#E68A00"
        Tweaks      = @(
            "Görsel Efektler: Özel (Yazı Tipi + Küçük Resimler Açık)",
            "Hazırda Bekletmeyi Kapat (Hibernate)",
            "Nihai Performans Güç Planını Aktif Et",
            "Cortana ve Cloud Aramayı Tamamen Kapat",
            "Windows Update'i Kısıtla (Otomatik Yüklemeyi Kapat)",
            "Xbox Game DVR Kapat",
            "Pencere Öğelerini (Widget) Kapat",
            "Başlat Önerilenler Bölümünü Kapat",
            "OneDrive'ı Sistemden Tamamen Kaldır"
        )
    }
}

function Show-RecommendedProfiles {
    # Secili profil setini tut
    $script:SelProfiles = @{}   # "Oyun"=$true vb.

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Önerilen Profil Seç" Height="560" Width="820"
        Background="#181818" WindowStartupLocation="CenterOwner"
        WindowStyle="ToolWindow" ResizeMode="NoResize">
    <Window.Resources>
        <Style TargetType="Button" x:Key="CardBtn">
            <Setter Property="Background"   Value="#007ACC"/>
            <Setter Property="Foreground"   Value="White"/>
            <Setter Property="Height"       Value="30"/>
            <Setter Property="FontWeight"   Value="SemiBold"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
        <Style TargetType="Button" x:Key="ActionBtn">
            <Setter Property="Foreground"   Value="White"/>
            <Setter Property="Height"       Value="36"/>
            <Setter Property="FontWeight"   Value="Bold"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
        <Style TargetType="CheckBox" x:Key="ProfileCheck">
            <Setter Property="Foreground"   Value="#CCCCCC"/>
            <Setter Property="FontSize"     Value="13"/>
            <Setter Property="Cursor"       Value="Hand"/>
            <Setter Property="Margin"       Value="0,0,0,4"/>
        </Style>
    </Window.Resources>
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- BASLIK -->
        <StackPanel Grid.Row="0" Margin="0,0,0,14">
            <TextBlock Text="Önerilen Profil Seç" Foreground="#FFFFFF"
                       FontSize="18" FontWeight="Bold"/>
            <TextBlock Text="Bir veya birden fazla profil seçip uygulayabilirsiniz. Profil içeriğini görmek için oka tıklayın."
                       Foreground="#666" FontSize="11" Margin="0,4,0,0" TextWrapping="Wrap"/>
        </StackPanel>

        <!-- 3 KART -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- OYUN KARTI -->
            <Border Grid.Column="0" Background="#1A2A1A" CornerRadius="8"
                    BorderBrush="#2E5E2E" BorderThickness="1" Padding="14,12">
                <StackPanel>
                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox x:Name="chkOyun" Grid.Column="0" Style="{StaticResource ProfileCheck}"
                                  VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Margin="8,0,0,0">
                            <TextBlock Text="🎮 Oyun / Düşük Gecikme" Foreground="#4CAF50"
                                       FontSize="14" FontWeight="Bold"/>
                            <TextBlock Text="Input lag azaltma, CPU/ağ optimizasyonu"
                                       Foreground="#888" FontSize="11" TextWrapping="Wrap"/>
                        </StackPanel>
                        <Button x:Name="btnOyunExpand" Grid.Column="2" Content="▼"
                                Background="Transparent" Foreground="#888"
                                BorderThickness="0" Width="24" Height="24"
                                VerticalAlignment="Top"/>
                    </Grid>
                    <Border Background="#222" CornerRadius="4" Padding="10,8"
                            Margin="0,0,0,4">
                        <TextBlock Foreground="#AAA" FontSize="11">
                            <Run Text="15 tweak" FontWeight="Bold" Foreground="#4CAF50"/>
                            <Run Text=" · Güç planı, fare/klavye önceliği, MSI Mode, ağ optimizasyonu, timer"/>
                        </TextBlock>
                    </Border>
                    <ScrollViewer x:Name="svOyun" MaxHeight="160"
                                  Visibility="Collapsed"
                                  VerticalScrollBarVisibility="Auto">
                        <ItemsControl x:Name="icOyun" Margin="0,4,0,0"/>
                    </ScrollViewer>
                </StackPanel>
            </Border>

            <!-- GİZLİLİK KARTI -->
            <Border Grid.Column="2" Background="#1A1A2A" CornerRadius="8"
                    BorderBrush="#2E2E6E" BorderThickness="1" Padding="14,12">
                <StackPanel>
                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox x:Name="chkGizlilik" Grid.Column="0" Style="{StaticResource ProfileCheck}"
                                  VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Margin="8,0,0,0">
                            <TextBlock Text="🔒 Gizlilik Odaklı" Foreground="#4A90D9"
                                       FontSize="14" FontWeight="Bold"/>
                            <TextBlock Text="Telemetri, izinler ve Microsoft takibini kapatır"
                                       Foreground="#888" FontSize="11" TextWrapping="Wrap"/>
                        </StackPanel>
                        <Button x:Name="btnGizlilikExpand" Grid.Column="2" Content="▼"
                                Background="Transparent" Foreground="#888"
                                BorderThickness="0" Width="24" Height="24"
                                VerticalAlignment="Top"/>
                    </Grid>
                    <Border Background="#222" CornerRadius="4" Padding="10,8"
                            Margin="0,0,0,4">
                        <TextBlock Foreground="#AAA" FontSize="11">
                            <Run Text="16 tweak" FontWeight="Bold" Foreground="#4A90D9"/>
                            <Run Text=" · Konum, kamera, telemetri, Cortana, arka plan uygulamaları, izinler"/>
                        </TextBlock>
                    </Border>
                    <ScrollViewer x:Name="svGizlilik" MaxHeight="160"
                                  Visibility="Collapsed"
                                  VerticalScrollBarVisibility="Auto">
                        <ItemsControl x:Name="icGizlilik" Margin="0,4,0,0"/>
                    </ScrollViewer>
                </StackPanel>
            </Border>

            <!-- HIZ KARTI -->
            <Border Grid.Column="4" Background="#2A1A00" CornerRadius="8"
                    BorderBrush="#6E4A00" BorderThickness="1" Padding="14,12">
                <StackPanel>
                    <Grid Margin="0,0,0,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox x:Name="chkHiz" Grid.Column="0" Style="{StaticResource ProfileCheck}"
                                  VerticalAlignment="Center"/>
                        <StackPanel Grid.Column="1" Margin="8,0,0,0">
                            <TextBlock Text="⚡ Maksimum Hız" Foreground="#E68A00"
                                       FontSize="14" FontWeight="Bold"/>
                            <TextBlock Text="Gereksiz servisler ve görsel efektleri kapatır"
                                       Foreground="#888" FontSize="11" TextWrapping="Wrap"/>
                        </StackPanel>
                        <Button x:Name="btnHizExpand" Grid.Column="2" Content="▼"
                                Background="Transparent" Foreground="#888"
                                BorderThickness="0" Width="24" Height="24"
                                VerticalAlignment="Top"/>
                    </Grid>
                    <Border Background="#222" CornerRadius="4" Padding="10,8"
                            Margin="0,0,0,4">
                        <TextBlock Foreground="#AAA" FontSize="11">
                            <Run Text="9 tweak" FontWeight="Bold" Foreground="#E68A00"/>
                            <Run Text=" · Görsel efektler, hibernate, gereksiz servisler"/>
                        </TextBlock>
                    </Border>
                    <ScrollViewer x:Name="svHiz" MaxHeight="160"
                                  Visibility="Collapsed"
                                  VerticalScrollBarVisibility="Auto">
                        <ItemsControl x:Name="icHiz" Margin="0,4,0,0"/>
                    </ScrollViewer>
                </StackPanel>
            </Border>
        </Grid>

        <!-- BİLGİ SATIRI -->
        <TextBlock x:Name="txtProfileInfo" Grid.Row="2"
                   Text="En az bir profil seçin."
                   Foreground="#666" FontSize="11"
                   Margin="0,10,0,6" HorizontalAlignment="Center"/>

        <!-- BUTONLAR -->
        <Grid Grid.Row="3">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" x:Name="txtTweakCount"
                       Text="" Foreground="#888" FontSize="11"
                       VerticalAlignment="Center"/>
            <Button x:Name="btnProfileCancel" Grid.Column="2"
                    Content="İptal" Style="{StaticResource ActionBtn}"
                    Width="90" Background="#2E2E2E"/>
            <Button x:Name="btnProfileApply" Grid.Column="4"
                    Content="✔ Seçip Uygula" Style="{StaticResource ActionBtn}"
                    Width="150" Background="#E68A00" IsEnabled="False"/>
        </Grid>
    </Grid>
</Window>
"@

    try {
        $reader  = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
        $winP    = [Windows.Markup.XamlReader]::Load($reader)
        $winP.Owner = $Win

        $chkOyun    = $winP.FindName('chkOyun')
        $chkGizlilik= $winP.FindName('chkGizlilik')
        $chkHiz     = $winP.FindName('chkHiz')

        $svOyun     = $winP.FindName('svOyun')
        $svGizlilik = $winP.FindName('svGizlilik')
        $svHiz      = $winP.FindName('svHiz')

        $icOyun     = $winP.FindName('icOyun')
        $icGizlilik = $winP.FindName('icGizlilik')
        $icHiz      = $winP.FindName('icHiz')

        $txtInfo    = $winP.FindName('txtProfileInfo')
        $txtCount   = $winP.FindName('txtTweakCount')
        $btnApply   = $winP.FindName('btnProfileApply')
        $btnCancel  = $winP.FindName('btnProfileCancel')

        $btnOyunExpand     = $winP.FindName('btnOyunExpand')
        $btnGizlilikExpand = $winP.FindName('btnGizlilikExpand')
        $btnHizExpand      = $winP.FindName('btnHizExpand')

        # Tweak listelerini doldur
        function Fill-TweakList($ic, $profileKey) {
            $ic.Items.Clear()
            foreach ($tweak in $script:RecommendedProfiles[$profileKey].Tweaks) {
                $tb = New-Object System.Windows.Controls.TextBlock
                $tb.Text       = "• $tweak"
                $tb.Foreground = [System.Windows.Media.Brushes]::Gray
                $tb.FontSize   = 11
                $tb.Margin     = [System.Windows.Thickness]::new(0,1,0,1)
                $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap
                $ic.Items.Add($tb) | Out-Null
            }
        }
        Fill-TweakList $icOyun     "Oyun"
        Fill-TweakList $icGizlilik "Gizlilik"
        Fill-TweakList $icHiz      "Hiz"

        # Expand toggle
        function Toggle-Expand($sv, $btn) {
            if ($sv.Visibility -eq [System.Windows.Visibility]::Collapsed) {
                $sv.Visibility = [System.Windows.Visibility]::Visible
                $btn.Content = "▲"
            } else {
                $sv.Visibility = [System.Windows.Visibility]::Collapsed
                $btn.Content = "▼"
            }
        }
        $btnOyunExpand.Add_Click({     Toggle-Expand $svOyun     $btnOyunExpand     })
        $btnGizlilikExpand.Add_Click({ Toggle-Expand $svGizlilik $btnGizlilikExpand })
        $btnHizExpand.Add_Click({      Toggle-Expand $svHiz      $btnHizExpand      })

        # Checkbox değişince tweak sayısını güncelle
        function Update-Selection {
            $allTweaks = @()
            if ($chkOyun.IsChecked)     { $allTweaks += $script:RecommendedProfiles["Oyun"].Tweaks }
            if ($chkGizlilik.IsChecked) { $allTweaks += $script:RecommendedProfiles["Gizlilik"].Tweaks }
            if ($chkHiz.IsChecked)      { $allTweaks += $script:RecommendedProfiles["Hiz"].Tweaks }

            # Tekrarları kaldır
            $unique = $allTweaks | Select-Object -Unique
            $count  = $unique.Count

            if ($count -gt 0) {
                $btnApply.IsEnabled = $true
                $parts = @()
                if ($chkOyun.IsChecked)     { $parts += "Oyun" }
                if ($chkGizlilik.IsChecked) { $parts += "Gizlilik" }
                if ($chkHiz.IsChecked)      { $parts += "Hız" }
                $txtInfo.Text  = "$($parts -join ' + ') profili seçili"
                $txtCount.Text = "$count tweak uygulanacak (tekrarlar birleştirildi)"
            } else {
                $btnApply.IsEnabled = $false
                $txtInfo.Text  = "En az bir profil seçin."
                $txtCount.Text = ""
            }
        }

        $chkOyun.Add_Checked({     Update-Selection })
        $chkOyun.Add_Unchecked({   Update-Selection })
        $chkGizlilik.Add_Checked({ Update-Selection })
        $chkGizlilik.Add_Unchecked({ Update-Selection })
        $chkHiz.Add_Checked({      Update-Selection })
        $chkHiz.Add_Unchecked({    Update-Selection })

        $btnCancel.Add_Click({ $winP.Close() })

        # Uygula
        $btnApply.Add_Click({
            $allTweaks = @()
            if ($chkOyun.IsChecked)     { $allTweaks += $script:RecommendedProfiles["Oyun"].Tweaks }
            if ($chkGizlilik.IsChecked) { $allTweaks += $script:RecommendedProfiles["Gizlilik"].Tweaks }
            if ($chkHiz.IsChecked)      { $allTweaks += $script:RecommendedProfiles["Hiz"].Tweaks }
            $unique = $allTweaks | Select-Object -Unique

            $parts = @()
            if ($chkOyun.IsChecked)     { $parts += "🎮 Oyun" }
            if ($chkGizlilik.IsChecked) { $parts += "🔒 Gizlilik" }
            if ($chkHiz.IsChecked)      { $parts += "⚡ Hız" }

            # SNAPSHOT: Profildeki tweaklerin SADECE suan false olanlari kaydet
            # (true olanlar zaten aktif, onlara dokunmuyoruz)
            # Performans: tum agaci degil sadece $unique listesini hedef aliyoruz
            $snapshot = @{}  # TweakName -> onceki IsChecked degeri
            function Take-Snapshot($nodes) {
                foreach ($node in $nodes) {
                    if ($node.Tag -is [System.Collections.IDictionary] -or
                        $node.Tag -is [System.Management.Automation.PSCustomObject]) {
                        $name = $node.Tag.Name
                        if ($unique -contains $name) {
                            $snapshot[$name] = (Get-CheckFromItem $node).IsChecked
                        }
                    }
                    if ($node.Items.Count -gt 0) { Take-Snapshot $node.Items }
                }
            }
            foreach ($cat in $tvTweaks.Items) { Take-Snapshot $cat.Items }

            # Checkbox'lari isaretleme fonksiyonu
            function Set-Checks($nodes) {
                foreach ($node in $nodes) {
                    if ($node.Tag -is [System.Collections.IDictionary] -or
                        $node.Tag -is [System.Management.Automation.PSCustomObject]) {
                        if ($unique -contains $node.Tag.Name) {
                            (Get-CheckFromItem $node).IsChecked = $true
                        }
                    }
                    if ($node.Items.Count -gt 0) { Set-Checks $node.Items }
                }
            }

            # Snapshot'tan geri yükleme — sadece degistirdigimiz tweak'leri hedef alir
            function Restore-Snapshot($nodes) {
                foreach ($node in $nodes) {
                    if ($node.Tag -is [System.Collections.IDictionary] -or
                        $node.Tag -is [System.Management.Automation.PSCustomObject]) {
                        $name = $node.Tag.Name
                        if ($snapshot.ContainsKey($name)) {
                            (Get-CheckFromItem $node).IsChecked = $snapshot[$name]
                        }
                    }
                    if ($node.Items.Count -gt 0) { Restore-Snapshot $node.Items }
                }
            }

            # Checkbox'lari isaretliyoruz
            foreach ($cat in $tvTweaks.Items) { Set-Checks $cat.Items }

            $winP.Close()

            # Apply-System-Tweaks cagir — ici zaten kendi onayini sorar
            # Kullanici Hayir derse Apply hicbir sey yapmaz VE biz snapshot'tan geri aliyoruz
            $Win.Dispatcher.Invoke([action]{
                # Apply'in kendi onay penceresini yakala:
                # Apply-System-Tweaks icerisinde MessageBox.Show YesNo var
                # Biz Apply'i cagirmadan once bir wrapper yazamayiz dogrudan,
                # bu yuzden Apply'dan once onay biz sorar, Apply'in onayini atlatmayiz —
                # bunun yerine Apply'i cagirip sonucunu kontrol etmek mumkun degil (void).
                # Cozum: Apply cagrilmadan ONCE biz onayi sorup,
                # Hayir ise snapshot restore edip duruyoruz.
                # DIFF analizi (Bonus E2): zaten aktif olanlar vs yeni uygulanacaklar
                $alreadyOn  = 0
                $willChange = 0
                foreach ($snapVal in $snapshot.Values) {
                    if ($snapVal) { $alreadyOn++ } else { $willChange++ }
                }
                $confirmMsg = "$($parts -join ' + ') profili:`n`n" +
                              "  ✅ $alreadyOn tweak zaten aktif (degismeyecek)`n" +
                              "  🆕 $willChange tweak yeni uygulanacak`n`n" +
                              "Toplam $($unique.Count) tweak.`n`n" +
                              "Devam edilsin mi?"
                $confirmRes = [System.Windows.MessageBox]::Show(
                    $confirmMsg, "Profil Uygula",
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question)

                if ($confirmRes -ne 'Yes') {
                    # Kullanici Hayir dedi — snapshot'tan geri al
                    foreach ($cat in $tvTweaks.Items) { Restore-Snapshot $cat.Items }
                    return
                }

                # Evet — Apply'in kendi onay penceresini atlamak icin
                # Apply-System-Tweaks'in Scan-Nodes mantigi sadece
                # "isaretli ama aktif degil" veya "aktif ama isaretsiz" olanlari isler.
                # Snapshot'ta false olan tweakler Set-Checks ile true yapildi,
                # bunlar "isaretli ama aktif degil" kategorisine giriyor = uygulanacak.
                # Apply'in kendi onay mesaji bu durumu dogru gosterir.
                Apply-System-Tweaks
            }, [System.Windows.Threading.DispatcherPriority]::Background)
        })

        $winP.ShowDialog() | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Pencere açılamadı: $($_.Exception.Message)", "Hata") | Out-Null
    }
}

# ---- Show-ProfileManager ----
function Show-ProfileManager {
    $profileDir = Join-Path $env:APPDATA "GeminiCare\Profiles"
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    function Load-ProfileFiles {
        $profiles = @()
        Get-ChildItem $profileDir -Filter "*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 3 |
        ForEach-Object {
            try {
                $data = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $profiles += [PSCustomObject]@{
                    Name     = $data.Name
                    Date     = $_.LastWriteTime.ToString("dd.MM.yyyy HH:mm")
                    Count    = $data.Tweaks.Count
                    Tweaks   = $data.Tweaks
                    FilePath = $_.FullName
                }
            } catch {}
        }
        return $profiles
    }

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Profil Yöneticisi" Height="460" Width="560"
        Background="#181818" WindowStartupLocation="CenterOwner"
        WindowStyle="ToolWindow" ResizeMode="NoResize">
    <Window.Resources>
        <!-- Custom Button Style: disabled state okunaklı kalır -->
        <Style x:Key="PMButton" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="4"
                                Background="{TemplateBinding Background}"
                                BorderThickness="0">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.85"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.65"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <!-- Disabled: arka plani daha koyu, foreground gri ama hala okunabilir -->
                                <Setter TargetName="border" Property="Background" Value="#2A4A60"/>
                                <Setter Property="Foreground" Value="#B0B0B0"/>
                                <Setter Property="Cursor" Value="Arrow"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Profil Yöneticisi" Foreground="#FFFFFF"
                   FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
        <TextBlock Grid.Row="1" Text="Son 3 profil listelenir. Profiller AppData\GeminiCare\Profiles klasörüne kaydedilir."
                   Foreground="#555" FontSize="11" Margin="0,0,0,12" TextWrapping="Wrap"/>

        <!-- PROFİL LİSTESİ -->
        <Border Grid.Row="2" Background="#202020" CornerRadius="6"
                BorderBrush="#2E2E2E" BorderThickness="1">
            <ListBox x:Name="lstProfiles" Background="Transparent" BorderThickness="0"
                     Foreground="White">
                <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                        <Setter Property="Padding" Value="12,8"/>
                        <Setter Property="Background" Value="Transparent"/>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="{Binding Name}" Foreground="#E8E8E8"
                                           FontWeight="SemiBold" FontSize="13"/>
                                <TextBlock Foreground="#888" FontSize="11">
                                    <Run Text="{Binding Date}"/>
                                    <Run Text="  ·  "/>
                                    <Run Text="{Binding Count}"/>
                                    <Run Text=" tweak"/>
                                </TextBlock>
                            </StackPanel>
                        </Grid>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>
        </Border>

        <!-- KAYDET BÖLÜMÜ -->
        <Border Grid.Row="3" Background="#202020" CornerRadius="6"
                BorderBrush="#2E2E2E" BorderThickness="1"
                Padding="12,10" Margin="0,8,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="8"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="txtProfileName" Grid.Column="0"
                         Background="#282828" Foreground="#E8E8E8"
                         BorderBrush="#3E3E3E" BorderThickness="1"
                         Padding="8,6" Height="32"
                         Text="Profilim"/>
                <Button x:Name="btnSave" Grid.Column="2"
                        Style="{StaticResource PMButton}"
                        Content="💾 Kaydet" Height="32" Width="100"
                        Background="#2E5E2E"/>
            </Grid>
        </Border>

        <!-- ALT BUTONLAR -->
        <Grid Grid.Row="4" Margin="0,8,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="txtPMStatus" Grid.Column="0"
                       Text="" Foreground="#888" FontSize="11"
                       VerticalAlignment="Center"/>
            <Button x:Name="btnLoad" Grid.Column="2"
                    Style="{StaticResource PMButton}"
                    Content="📂 Yükle" Height="34" Width="100"
                    Background="#007ACC" IsEnabled="False"/>
            <Button x:Name="btnPMClose" Grid.Column="4"
                    Style="{StaticResource PMButton}"
                    Content="Kapat" Height="34" Width="80"
                    Background="#3A3A3A"/>
        </Grid>
    </Grid>
</Window>
"@

    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
        $winPM  = [Windows.Markup.XamlReader]::Load($reader)
        $winPM.Owner = $Win

        $lstP    = $winPM.FindName('lstProfiles')
        $txtName = $winPM.FindName('txtProfileName')
        $btnSv   = $winPM.FindName('btnSave')
        $btnLd   = $winPM.FindName('btnLoad')
        $btnCl   = $winPM.FindName('btnPMClose')
        $txtStat = $winPM.FindName('txtPMStatus')

        function Refresh-List {
            $lstP.Items.Clear()
            $profiles = Load-ProfileFiles
            if ($profiles.Count -eq 0) {
                $txtStat.Text = "Henüz kayıtlı profil yok."
            } else {
                foreach ($p in $profiles) { $lstP.Items.Add($p) | Out-Null }
                $txtStat.Text = "$($profiles.Count) profil"
            }
        }
        Refresh-List

        $lstP.Add_SelectionChanged({
            $btnLd.IsEnabled = ($null -ne $lstP.SelectedItem)
        })

        # Kaydet
        $btnSv.Add_Click({
            $name = $txtName.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($name)) {
                $txtStat.Text = "Profil adı boş olamaz."
                return
            }

            # Şu an işaretli tweak isimlerini topla
            $tweakNames = @()
            foreach ($cat in $tvTweaks.Items) {
                function ScanSave($nodes) {
                    foreach ($node in $nodes) {
                        if ($node.Tag -is [System.Collections.IDictionary] -or
                            $node.Tag -is [System.Management.Automation.PSCustomObject]) {
                            if ((Get-CheckFromItem $node).IsChecked) {
                                $script:_savedTweaks += $node.Tag.Name
                            }
                        }
                        if ($node.Items.Count -gt 0) { ScanSave $node.Items }
                    }
                }
                $script:_savedTweaks = @()
                ScanSave $cat.Items
                $tweakNames += $script:_savedTweaks
            }

            $safeFileName = ($name -replace '[\\/:*?"<>|]', '_') + "_$(Get-Date -Format 'yyyyMMdd_HHmm').json"
            $filePath = Join-Path $profileDir $safeFileName
            $data = @{ Name=$name; Date=(Get-Date -Format "yyyy-MM-dd HH:mm"); Tweaks=$tweakNames }
            $data | ConvertTo-Json -Depth 3 | Set-Content $filePath -Encoding UTF8

            $txtStat.Text = "✅ '$name' kaydedildi ($($tweakNames.Count) tweak)."
            Refresh-List
        })

        # Yükle (sadece checkbox işaretle, uygulamaz)
        $btnLd.Add_Click({
            $sel = $lstP.SelectedItem
            if (-not $sel) { return }

            $loaded = 0
            foreach ($cat in $tvTweaks.Items) {
                function ScanLoad($nodes) {
                    foreach ($node in $nodes) {
                        if ($node.Tag -is [System.Collections.IDictionary] -or
                            $node.Tag -is [System.Management.Automation.PSCustomObject]) {
                            $chk = Get-CheckFromItem $node
                            if ($sel.Tweaks -contains $node.Tag.Name) {
                                $chk.IsChecked = $true
                                $script:_loadCount++
                            } else {
                                $chk.IsChecked = $false
                            }
                        }
                        if ($node.Items.Count -gt 0) { ScanLoad $node.Items }
                    }
                }
                $script:_loadCount = 0
                ScanLoad $cat.Items
                $loaded += $script:_loadCount
            }

            $winPM.Close()
            [System.Windows.MessageBox]::Show(
                "'$($sel.Name)' profili yüklendi.`n$loaded tweak işaretlendi.`n`nUYGULA butonuna basarak sisteme uygulayabilirsiniz.",
                "Profil Yüklendi",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
        })

        $btnCl.Add_Click({ $winPM.Close() })
        $winPM.ShowDialog() | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Pencere açılamadı: $($_.Exception.Message)", "Hata") | Out-Null
    }
}

# ---- Check-BlackBoxStatus ----
function Check-BlackBoxStatus {
    $isEnabled = $true
    $reasons = @()

    # 1. WER Servisi
    $werSvc = Get-Service -Name "WerSvc" -ErrorAction SilentlyContinue
    if ($werSvc -and $werSvc.StartType -eq 'Disabled') {
        $isEnabled = $false
        $reasons += "WER Servisi Devre Dışı"
    }

    # 2. Kernel Crash Dump (Türünü esnek kontrol et!)
    $crashReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "CrashDumpEnabled" -ErrorAction SilentlyContinue
    # CrashDumpEnabled: 0=Kapalı, 1=Tam, 2=Çekirdek, 3=Minidump (yetersiz), 7=Otomatik (W11 varsayılanı, geçerli)
    # Geçerli değerler: 1, 2 veya 7. Sadece 0 ve 3 yetersizdir.
    if ($null -eq $crashReg -or $crashReg.CrashDumpEnabled -eq 0 -or $crashReg.CrashDumpEnabled -eq 3) {
        $isEnabled = $false
        $reasons += "Mavi Ekran (BSOD) Kaydı kapalı veya yetersiz (Minidump/Kapalı)"
    }

    # 3. Local Dumps (Oyun Çökmeleri)
    $dumpReg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" -Name "DumpType" -ErrorAction SilentlyContinue
    if ($null -eq $dumpReg -or $dumpReg.DumpType -ne 2) {
        $isEnabled = $false
        $reasons += "Oyun/Uygulama Çökme Kaydı (.dmp) Kapalı"
    }

    # Arayüzü Güncelle
    if ($isEnabled) {
        $shpBlackBoxStatus.Fill = [System.Windows.Media.Brushes]::LimeGreen
        $txtBlackBoxStatus.Text = "Aktif. Tüm çökmeler (Oyun/BSOD) detaylı olarak kaydediliyor."
        $txtBlackBoxStatus.Foreground =[System.Windows.Media.Brushes]::White
        $btnFixBlackBox.Content = "🔴 Devre Dışı Bırak"
        $btnFixBlackBox.Background = [System.Windows.Media.Brushes]::DimGray
        $btnFixBlackBox.Tag = "on"
        $btnFixBlackBox.Visibility = "Visible"
    } else {
        $shpBlackBoxStatus.Fill = [System.Windows.Media.Brushes]::Red
        $errText = $reasons -join ", "
        $txtBlackBoxStatus.Text = "Kayıt Kapalı/Yetersiz! Sebep: $errText"
        $txtBlackBoxStatus.Foreground =[System.Windows.Media.Brushes]::Salmon
        $btnFixBlackBox.Content = "🔧 Kara Kutuyu Aç"
        $btnFixBlackBox.Background = [System.Windows.Media.Brushes]::Firebrick
        $btnFixBlackBox.Tag = "off"
        $btnFixBlackBox.Visibility = "Visible"
    }
}

# ---- Start-ShutdownCountdown ----
function Start-ShutdownCountdown {
    $global:NightModeActive = $false
    if ($global:NightModeTimer) { $global:NightModeTimer.Stop() }
    
    $Win.Dispatcher.Invoke([action]{
        $btnNightMode.Content = "🌙 Shutdown"
        $btnNightMode.Foreground = [System.Windows.Media.Brushes]::Cyan
        
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlCountdown)
        $winCount = [Windows.Markup.XamlReader]::Load($reader)
        
        $txtSec = $winCount.FindName('txtSeconds')
        $btnAbort = $winCount.FindName('btnAbort')
        
        $script:timeLeft = 60
        $cdTimer = New-Object System.Windows.Threading.DispatcherTimer
        $cdTimer.Interval =[TimeSpan]::FromSeconds(1)
        
        $cdTimer.Add_Tick({
            $script:timeLeft--
            $txtSec.Text = $script:timeLeft.ToString()
            if ($script:timeLeft -le 0) {
                $cdTimer.Stop()
                $winCount.Close()
                # ZORLA KAPATMA KOMUTU
                Start-Process shutdown.exe -ArgumentList "/s /f /t 0" -WindowStyle Hidden
            }
        })
        
        $btnAbort.Add_Click({
            $cdTimer.Stop()
            $winCount.Close()
            WpfLog "🌙 [GECE MODU] Geri sayım kullanıcı tarafından İPTAL EDİLDİ."
        })
        
        $cdTimer.Start()
        $winCount.ShowDialog() | Out-Null
    })
}

# ---- Show-Winapp2Editor ----
function Show-Winapp2Editor {
    $xamlEdit = @"
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Title="Winapp2 Editörü (Override)" Height="600" Width="700" 
            Background="#181818" WindowStartupLocation="CenterScreen" WindowStyle="ToolWindow">
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="5"/>
                <RowDefinition Height="200"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- ARAMA -->
            <StackPanel Grid.Row="0">
                <TextBlock Text="Uygulama Ara (Winapp2.ini):" Foreground="#4CC2FF" FontWeight="Bold" Margin="0,0,0,5"/>
                <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="80"/></Grid.ColumnDefinitions>
                    <TextBox x:Name="txtSearch" Padding="5" Background="#222" Foreground="White" Text=""/>
                    <Button x:Name="btnSearch" Grid.Column="1" Content="BUL" Background="#007ACC" Foreground="White" Margin="5,0,0,0"/>
                </Grid>
                <TextBlock Text="Sonuçlar:" Foreground="#AAA" Margin="0,10,0,5"/>
            </StackPanel>

            <!-- SONUÇ LİSTESİ -->
            <ListBox x:Name="lstResults" Grid.Row="1" Background="#1E1E1E" Foreground="White" BorderBrush="#444"/>

            <GridSplitter Grid.Row="2" HorizontalAlignment="Stretch" Background="#444"/>

            <!-- EDİTÖR -->
            <Grid Grid.Row="3">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <TextBlock Text="Düzenle (Kendi kurallarınızı yazın):" Foreground="#E68A00" FontWeight="Bold" Margin="0,5,0,5"/>
                <TextBox x:Name="txtContent" Grid.Row="1" AcceptsReturn="True" Background="#252526" Foreground="#0F0" FontFamily="Consolas" Padding="5" VerticalScrollBarVisibility="Auto"/>
            </Grid>

            <!-- BUTONLAR -->
            <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
                <Button x:Name="btnDeleteOverride" Content="Özel Ayarı Sil (Sıfırla)" Background="#A00" Foreground="White" Width="150" Margin="0,0,10,0" Visibility="Collapsed"/>
                <Button x:Name="btnSave" Content="KAYDET ve ÇIK" Background="#006600" Foreground="White" FontWeight="Bold" Width="120" Height="30"/>
            </StackPanel>
        </Grid>
    </Window>
"@
    
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlEdit)
    $winEd = [Windows.Markup.XamlReader]::Load($reader)
    
    $txtS = $winEd.FindName('txtSearch'); $btnS = $winEd.FindName('btnSearch')
    $lst = $winEd.FindName('lstResults'); $txtC = $winEd.FindName('txtContent')
    $btnSave = $winEd.FindName('btnSave'); $btnDel = $winEd.FindName('btnDeleteOverride')

    $btnS.Add_Click({
        $k = $txtS.Text; if (-not $k -or -not (Test-Path $global:Winapp2Path)) { return }
        $lst.Items.Clear()
        $content = [System.IO.File]::ReadAllText($global:Winapp2Path)
        $matches = [regex]::Matches($content, "\[.*?$k.*?\]", "IgnoreCase")
        foreach ($m in $matches) { $lst.Items.Add($m.Value) | Out-Null }
    })

    $lst.Add_SelectionChanged({
        if ($lst.SelectedItem) {
            $appName = $lst.SelectedItem.ToString().Trim('[]')
            
            if ($global:PathOverrides.ContainsKey($appName)) {
                $rawLines = $global:PathOverrides[$appName]
                if ($rawLines -is [string]) { $txtC.Text = $rawLines }
                elseif ($rawLines -is [Array]) { $txtC.Text = $rawLines -join "`r`n" }
                
                $btnDel.Visibility = "Visible"
                $btnSave.Content = "GÜNCELLE"
            } 
            else {
                $lines = [System.IO.File]::ReadAllLines($global:Winapp2Path)
                $block = @()
                $capture = $false
                foreach ($line in $lines) {
                    if ($line.Trim() -eq "[$appName]") { $capture = $true; continue }
                    if ($capture) {
                        if ($line.StartsWith("[")) { break }
                        if ($line.Trim() -ne "") { $block += $line }
                    }
                }
                $txtC.Text = $block -join "`r`n"
                $btnDel.Visibility = "Collapsed"
                $btnSave.Content = "KAYDET"
            }
        }
    })

    $btnSave.Add_Click({
        if ($lst.SelectedItem) {
            $appName = $lst.SelectedItem.ToString().Trim('[]')
            
            # DÜZELTME: Satırları bölerken daha esnek bir ayırıcı kullanıldı
            $newRules = $txtC.Text -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            
            $global:PathOverrides[$appName] = $newRules
            Mark-ConfigDirty
            [System.Windows.MessageBox]::Show("'$appName' için özel ayarlar kaydedildi.`nAna menüdeki Güncelle -> Listeyi Yenile butonuna basarak görebilirsiniz.", "Başarılı") | Out-Null
            $winEd.Close()
        }
    })

    $btnDel.Add_Click({
        if ($lst.SelectedItem) {
            $appName = $lst.SelectedItem.ToString().Trim('[]')
            if ($global:PathOverrides.ContainsKey($appName)) {
                $global:PathOverrides.Remove($appName)
                Mark-ConfigDirty
                [System.Windows.MessageBox]::Show("Özel ayar silindi. Orijinal Winapp2 ayarlarına dönüldü.", "Bilgi") | Out-Null
                $winEd.Close()
            }
        }
    })

    $winEd.ShowDialog() | Out-Null
}

# ---- Show-AppUpdateWindow (Otomatik program guncellemesi, Show-UpdateWindow Winapp2 icin) ----
function Show-AppUpdateWindow {
    if (-not $global:UpdateAvailable) {
        [System.Windows.MessageBox]::Show("Su an icin yeni bir surum yok veya kontrol henuz tamamlanmadi.", "Guncelleme Yok", "OK", "Information") | Out-Null
        return
    }
    $upd = $global:UpdateAvailable

    $xamlAU = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Program Guncellemesi" Height="520" Width="600"
        Background="#181818" WindowStartupLocation="CenterOwner"
        WindowStyle="ToolWindow" ResizeMode="NoResize">
    <Window.Resources>
        <Style x:Key="AUButton" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="4" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.85"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.65"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#2A4A60"/>
                                <Setter Property="Foreground" Value="#B0B0B0"/>
                                <Setter Property="Cursor" Value="Arrow"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- BASLIK -->
        <StackPanel Grid.Row="0">
            <TextBlock Text="🚀 Yeni Surum Mevcut" Foreground="#4CC2FF" FontSize="20" FontWeight="Bold"/>
            <TextBlock x:Name="txtAUSubtitle" Text="" Foreground="#888" FontSize="12" Margin="0,4,0,16"/>
        </StackPanel>

        <!-- VERSION GRID -->
        <Grid Grid.Row="1" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="#202020" CornerRadius="6" BorderBrush="#2E2E2E" BorderThickness="1" Padding="12,10">
                <StackPanel>
                    <TextBlock Text="Mevcut Surum" Foreground="#888" FontSize="11" HorizontalAlignment="Center"/>
                    <TextBlock x:Name="txtAUCurrent" Text="" Foreground="White" FontWeight="Bold" FontSize="16" HorizontalAlignment="Center" Margin="0,4,0,0"/>
                </StackPanel>
            </Border>
            <TextBlock Grid.Column="1" Text="➔" Foreground="#4CC2FF" FontSize="22" VerticalAlignment="Center" Margin="12,0"/>
            <Border Grid.Column="2" Background="#1A2A1A" CornerRadius="6" BorderBrush="#2E5E2E" BorderThickness="1" Padding="12,10">
                <StackPanel>
                    <TextBlock Text="Yeni Surum" Foreground="#888" FontSize="11" HorizontalAlignment="Center"/>
                    <TextBlock x:Name="txtAUNew" Text="" Foreground="#4CAF50" FontWeight="Bold" FontSize="16" HorizontalAlignment="Center" Margin="0,4,0,0"/>
                </StackPanel>
            </Border>
        </Grid>

        <!-- RELEASE NOTES -->
        <Border Grid.Row="2" Background="#1A1A1A" CornerRadius="6" BorderBrush="#2E2E2E" BorderThickness="1" Padding="12,10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="✨ Degisiklikler" Foreground="#E68A00" FontWeight="Bold" FontSize="12" Margin="0,0,0,6"/>
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                    <TextBlock x:Name="txtAUNotes" Foreground="#CCC" FontSize="12" TextWrapping="Wrap" FontFamily="Consolas"/>
                </ScrollViewer>
            </Grid>
        </Border>

        <!-- PROGRESS -->
        <Grid Grid.Row="3" Margin="0,12,0,0">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" x:Name="txtAUProgress" Text="" Foreground="#AAA" FontSize="11" Margin="0,0,0,4"/>
            <ProgressBar Grid.Row="1" x:Name="pbAU" Height="6" Background="#2A2A2A" Foreground="#4CC2FF" BorderThickness="0" Value="0"/>
        </Grid>

        <!-- BUTONLAR -->
        <Grid Grid.Row="4" Margin="0,16,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" x:Name="btnAUSkip" Style="{StaticResource AUButton}" Content="🔇  Bu sürümü atla" Background="#3A2A2A" Height="36" Width="180" HorizontalAlignment="Left"/>
            <Button Grid.Column="2" x:Name="btnAULater" Style="{StaticResource AUButton}" Content="💤  Daha sonra" Background="#3A3A3A" Height="36" Width="140"/>
            <Button Grid.Column="4" x:Name="btnAUUpdate" Style="{StaticResource AUButton}" Content="📦  Güncelle" Background="#2E5E2E" Height="36" Width="170"/>
            <Button Grid.Column="6" x:Name="btnAURelease" Style="{StaticResource AUButton}" Content="🌐" Background="#3A3A3A" Height="36" Width="44" ToolTip="Release sayfasını tarayıcıda aç"/>
        </Grid>
    </Grid>
</Window>
"@

    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlAU)
        $winAU  = [Windows.Markup.XamlReader]::Load($reader)
        $winAU.Owner = $Win

        $txtSub      = $winAU.FindName('txtAUSubtitle')
        $txtCurrent  = $winAU.FindName('txtAUCurrent')
        $txtNew      = $winAU.FindName('txtAUNew')
        $txtNotes    = $winAU.FindName('txtAUNotes')
        $txtProgress = $winAU.FindName('txtAUProgress')
        $pbAU        = $winAU.FindName('pbAU')
        $btnSkip     = $winAU.FindName('btnAUSkip')
        $btnLater    = $winAU.FindName('btnAULater')
        $btnUpdate   = $winAU.FindName('btnAUUpdate')
        $btnRelease  = $winAU.FindName('btnAURelease')

        # Verileri doldur
        $txtSub.Text     = "GitHub Releases'tan otomatik kontrol — $($global:AppRepo)"
        $txtCurrent.Text = "v$($global:AppVersion)"
        $txtNew.Text     = $upd.Tag
        $txtNotes.Text   = if ($upd.Notes) { $upd.Notes } else { "(Release notlari yok)" }

        # 4 buton handler

        $btnSkip.Add_Click({
            Add-SkippedVersion -VersionTag $upd.Tag
            WpfLog "[Update] $($upd.Tag) atlandi — bu surum icin tekrar uyari gosterilmeyecek."
            $global:UpdateAvailable = $null
            if ($lblStatus) { $lblStatus.Text = "Sistem Hazır" }
            $winAU.Close()
        })

        $btnLater.Add_Click({ $winAU.Close() })

        $btnRelease.Add_Click({
            try { Start-Process $upd.ReleaseUrl } catch {}
        })

        $btnUpdate.Add_Click({
            # UI'i progress moda al
            $btnUpdate.IsEnabled = $false
            $btnSkip.IsEnabled = $false
            $btnLater.IsEnabled = $false

            # Progress callback — her step'te UI'a yansitir
            $progressCb = {
                param($pct, $msg)
                $winAU.Dispatcher.Invoke([action]{
                    $pbAU.Value = $pct
                    $txtProgress.Text = "[$pct%] $msg"
                }) | Out-Null
            }

            # Async olarak download flow'u baslat
            $dispatcher = $winAU.Dispatcher
            $dispatcher.Invoke([action]{
                $ok = Invoke-AppUpdate -ProgressCallback $progressCb
                if ($ok) {
                    $txtProgress.Text = "✓ Hazir. Program yeniden baslatiliyor..."
                    Start-Sleep -Milliseconds 800
                    # Ana programi kapat — updater script otomatik tetiklenecek
                    $winAU.Close()
                    if ($Win) { $Win.Close() }
                    [Environment]::Exit(0)
                } else {
                    [System.Windows.MessageBox]::Show("Guncelleme basarisiz oldu. Log'u kontrol edin.", "Hata", "OK", "Error") | Out-Null
                    $btnUpdate.IsEnabled = $true
                    $btnSkip.IsEnabled = $true
                    $btnLater.IsEnabled = $true
                }
            }) | Out-Null
        })

        # Bellek sizinti koruma
        $winAU.Add_Closed({
            $txtSub = $null; $txtCurrent = $null; $txtNew = $null; $txtNotes = $null
            $txtProgress = $null; $pbAU = $null
            $btnSkip = $null; $btnLater = $null; $btnUpdate = $null; $btnRelease = $null
        })

        $winAU.ShowDialog() | Out-Null

    } catch {
        WpfLog "❌ Show-AppUpdateWindow hatasi: $($_.Exception.Message)"
    }
}

# ---- Show-UpdateWindow (Winapp2.ini icin — eski isim, korunmasi gereken Winapp2 update mantigi) ----
function Show-UpdateWindow {
    # --- XAML ARAYÜZÜ ---
    $xamlUpdate = @"
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Title="Veritabanı Güncelleme" Height="250" Width="500" 
            Background="#181818" WindowStartupLocation="CenterScreen" WindowStyle="ToolWindow" ResizeMode="NoResize">
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <TextBlock Text="Winapp2.ini Veritabanı ve Liste" Foreground="#4CC2FF" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>

            <!-- SÜRÜM BİLGİLERİ -->
            <Grid Grid.Row="1" VerticalAlignment="Center">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <StackPanel Grid.Column="0" HorizontalAlignment="Center">
                    <TextBlock Text="Mevcut Sürüm" Foreground="#888" FontSize="11" HorizontalAlignment="Center"/>
                    <TextBlock x:Name="txtLocalVer" Text="..." Foreground="White" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" Margin="0,5,0,0"/>
                </StackPanel>

                <TextBlock Grid.Column="1" Text="➔" Foreground="#555" FontSize="20" VerticalAlignment="Center" Margin="10,0"/>

                <StackPanel Grid.Column="2" HorizontalAlignment="Center">
                    <TextBlock Text="Sunucu Sürümü" Foreground="#888" FontSize="11" HorizontalAlignment="Center"/>
                    <TextBlock x:Name="txtOnlineVer" Text="Kontrol Ediliyor..." Foreground="#E68A00" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" Margin="0,5,0,0"/>
                </StackPanel>
            </Grid>

            <!-- DURUM VE BUTONLAR -->
            <StackPanel Grid.Row="2">
                <TextBlock x:Name="txtStatus" Text="Lütfen bekleyin..." Foreground="#AAA" HorizontalAlignment="Center" Margin="0,0,0,15"/>
                
                <!-- 3 SÜTUNLU BUTON YAPISI -->
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="5"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="5"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    
                    <Button x:Name="btnOpenFolder" Grid.Column="0" Content="📂 Klasörü Aç" Height="35" Background="#333" Foreground="White" ToolTip="Dosya konumunu açar."/>
                    <Button x:Name="btnRescan" Grid.Column="2" Content="♻ Listeyi Yenile" Height="35" Background="#E68A00" Foreground="White" FontWeight="SemiBold" ToolTip="Önbelleği siler ve yüklü uygulamaları tekrar tarar."/>
                    <Button x:Name="btnDoUpdate" Grid.Column="4" Content="GÜNCELLE" Height="35" Background="#006600" Foreground="White" FontWeight="Bold" IsEnabled="False" ToolTip="İnternetten yeni sürümü indirir."/>
                </Grid>
            </StackPanel>
        </Grid>
    </Window>
"@

    # --- PENCEREYİ YÜKLE ---
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlUpdate)
    $winUpd = [Windows.Markup.XamlReader]::Load($reader)

    # Kontroller
    $txtLocal = $winUpd.FindName('txtLocalVer')
    $txtOnline = $winUpd.FindName('txtOnlineVer')
    $txtStat = $winUpd.FindName('txtStatus')
    $btnUpd = $winUpd.FindName('btnDoUpdate')
    $btnFol = $winUpd.FindName('btnOpenFolder')
    $btnRescan = $winUpd.FindName('btnRescan')

    # Yollar
    $localFile = $global:Winapp2Path 
    $url = $global:Winapp2Sources[0]

    # --- 1. MEVCUT SÜRÜMÜ OKU (TEMİZLİK EKLENDİ) ---
    $localVer = "Yok"
    if (Test-Path $localFile) {
        try {
            $reader = New-Object System.IO.StreamReader($localFile)
            $line = $reader.ReadLine()
            $reader.Close()
            if ($line -match "Version") { 
                # DÜZELTME: Noktalı virgülü sil ve boşlukları temizle
                $localVer = $line.Replace(";", "").Trim() 
            } else { 
                $localVer = "Bilinmiyor" 
            }
        } catch { $localVer = "Okunamadı" }
    }
    $txtLocal.Text = $localVer

    $script:UpdTimer = $null
    $script:CloseTimer = $null

    # --- 2. ONLINE KONTROL (ARKA PLAN + TEMİZLİK) ---
    $winUpd.Add_Loaded({
        $script:UpdRunspace = [powershell]::Create()
        $script:UpdRunspace.AddScript({
            param($u)
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $wc = New-Object System.Net.WebClient
			$wc.Headers.Add("User-Agent", "Mozilla/5.0")
			try {
				$stream = $wc.OpenRead($u)
				$r = New-Object System.IO.StreamReader($stream)
				$ver = $r.ReadLine()
				$r.Close(); $stream.Close()
				if ($ver) { return $ver.Replace(";", "").Trim() }
				return "HATA"
			} catch { return "HATA" } finally { $wc.Dispose() }
        })
        $script:UpdRunspace.AddArgument($url)
        $script:UpdAsync = $script:UpdRunspace.BeginInvoke()

        $script:UpdTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:UpdTimer.Interval = [TimeSpan]::FromMilliseconds(200)
        
        $script:UpdTimer.Add_Tick({
            if (-not $winUpd.IsLoaded) { 
                $script:UpdTimer.Stop()
                return 
            }

            if ($script:UpdAsync.IsCompleted) {
			# 1. Döngüyü hemen durdur
			$script:UpdTimer.Stop()

			try {
				# 2. Sonucu al
				$onlineVer = $script:UpdRunspace.EndInvoke($script:UpdAsync)
				$txtOnline.Text = $onlineVer
				
				# 3. Sonuca göre arayüzü güncelle
				if ($onlineVer -eq "HATA" -or [string]::IsNullOrWhiteSpace($onlineVer)) {
					$txtStat.Text = "Sunucuya bağlanılamadı veya yanıt boş."
					$txtOnline.Foreground = [System.Windows.Media.Brushes]::Red
					$txtOnline.Text = "Hata"
				}
				elseif ($onlineVer -ne $txtLocal.Text) {
					$txtStat.Text = "✨ Yeni sürüm mevcut!"
					$txtStat.Foreground = [System.Windows.Media.Brushes]::LimeGreen
					$btnUpd.IsEnabled = $true
					$btnUpd.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#007ACC")
				} 
				else {
					$txtStat.Text = "✅ Veritabanı güncel."
					$btnUpd.Content = "Yine de İndir"
					$btnUpd.IsEnabled = $true
					$btnUpd.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#333")
				}
			} 
			catch {
				# 4. Hata olursa kullanıcıya bilgi ver
				$txtStat.Text = "Sürüm kontrolü sırasında bir hata oluştu."
				$txtOnline.Text = "Hata"
				$txtOnline.Foreground = [System.Windows.Media.Brushes]::Red
				WpfLog "Update Check Hatası: $($_.Exception.Message)"
			} 
			finally {
				# 5. KRİTİK: Hata olsa da olmasa da Runspace'i RAM'den temizle
				if ($script:UpdRunspace) {
					$script:UpdRunspace.Dispose()
					$script:UpdRunspace = $null
				}
			}
		}
        })
        $script:UpdTimer.Start()
    })

    # --- PENCERE KAPANINCA TEMİZLİK ---
    $winUpd.Add_Closed({
        if ($script:UpdTimer) { $script:UpdTimer.Stop() }
        if ($script:CloseTimer) { $script:CloseTimer.Stop() }
        if ($script:UpdRunspace) { $script:UpdRunspace.Dispose() }
    })

    # --- 3. BUTON OLAYLARI ---
    
    # KLASÖRÜ AÇ
    $btnFol.Add_Click({
        Invoke-Item (Split-Path $localFile)
    })

    # LİSTEYİ YENİLE
    $btnRescan.Add_Click({
        if (Test-Path $global:CachePath) { Remove-Item $global:CachePath -Force }
        Start-Winapp2-Process 
        $winUpd.Close()
    })

    # GÜNCELLEME İŞLEMİ
    $btnUpd.Add_Click({
        $btnUpd.IsEnabled = $false
        $btnUpd.Content = "İndiriliyor..."
        $txtStat.Text = "Dosya indiriliyor, lütfen bekleyin..."
        Do-Events

        try {
            $backupFile = "$localFile.old"
            
            if (Test-Path $localFile) {
                if (Test-Path $backupFile) { Remove-Item $backupFile -Force }
                Move-Item $localFile $backupFile -Force
            }

            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $wc = New-Object System.Net.WebClient
			try { $wc.DownloadFile($url, $localFile) } finally { $wc.Dispose() }

            if ((Test-Path $localFile) -and (Get-Item $localFile).Length -gt 1024) {
                $txtStat.Text = "✔ Başarıyla güncellendi!"
                $txtStat.Foreground = [System.Windows.Media.Brushes]::LimeGreen
                $btnUpd.Content = "TAMAMLANDI"
                
				if (Test-Path $backupFile) { Remove-Item $backupFile -Force -ErrorAction SilentlyContinue }
				
                if (Test-Path $global:CachePath) { Remove-Item $global:CachePath -Force }
                Start-Winapp2-Process 
                
                $script:CloseTimer = New-Object System.Windows.Threading.DispatcherTimer
                $script:CloseTimer.Interval = [TimeSpan]::FromSeconds(2)
                $script:CloseTimer.Add_Tick({ 
                    $script:CloseTimer.Stop()
                    if ($winUpd.IsLoaded) { $winUpd.Close() }
                })
                $script:CloseTimer.Start()

            } else {
                throw "İndirilen dosya bozuk veya çok küçük."
            }

        } catch {
            $txtStat.Text = "❌ HATA: Eski sürüme dönülüyor..."
            $txtStat.Foreground = [System.Windows.Media.Brushes]::Red
            WpfLog "[HATA] Güncelleme başarısız: $($_.Exception.Message)"
            
            if (Test-Path $localFile) { Remove-Item $localFile -Force }
            if (Test-Path $backupFile) { Move-Item $backupFile $localFile -Force }
            
            $btnUpd.Content = "HATA"
            $btnUpd.Background = "#A00"
            $btnUpd.IsEnabled = $true
        }
    })

    $winUpd.ShowDialog() | Out-Null
}

# ---- Show-RestartDialog ----
function Show-RestartDialog {
    $xamlRestart = @"
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Title="Sistem Yeniden Başlatma" Height="220" Width="480" 
            Background="#181818" WindowStartupLocation="CenterScreen" WindowStyle="ToolWindow" ResizeMode="NoResize">
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- BAŞLIK VE İKON -->
            <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,15">
                <TextBlock Text="⚠️" FontSize="20" Margin="0,0,10,0"/>
                <TextBlock Text="Yeniden Başlatma Gerekiyor" Foreground="#FF5555" FontSize="18" FontWeight="Bold" VerticalAlignment="Center"/>
            </StackPanel>

            <!-- AÇIKLAMA -->
            <TextBlock Grid.Row="1" Text="Low Latency (Espor), Ping ve İşlemci ayarlarının Windows çekirdeğinde (Kernel) devreye girebilmesi için bilgisayarın yeniden başlatılması şarttır." 
                       Foreground="#DDD" TextWrapping="Wrap" TextAlignment="Center" FontSize="13"/>

            <!-- BUTONLAR -->
            <Grid Grid.Row="2" Margin="0,15,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="10"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <Button x:Name="btnLater" Grid.Column="0" Content="Daha Sonra" Height="40" Background="#333" Foreground="White"/>
                
                <Button x:Name="btnRestartNow" Grid.Column="2" Height="40" Background="#A00" Foreground="White" FontWeight="Bold">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="🔥 ŞİMDİ YENİDEN BAŞLAT" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </Grid>
        </Grid>
    </Window>
"@
    
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlRestart)
    $winRes = [Windows.Markup.XamlReader]::Load($reader)
    
    $btnLater = $winRes.FindName('btnLater')
    $btnNow = $winRes.FindName('btnRestartNow')
    
    $btnLater.Add_Click({ $winRes.Close() })
    
    $btnNow.Add_Click({
        $winRes.Close()
        # ZORLA YENİDEN BAŞLATMA KOMUTU (/f = Force, /r = Restart, /t 0 = Hemen)
        Start-Process shutdown.exe -ArgumentList "/r /f /t 0" -WindowStyle Hidden
    })
    
    $winRes.ShowDialog() | Out-Null
}

# ---- Show-HardwareDetail ----
function Show-HardwareDetail {
    $d = $global:DashResult
    if (-not $d) { return }

    $xamlHW = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Detayli Donanim Bilgisi" Height="640" Width="700"
        Background="#181818" WindowStartupLocation="CenterOwner"
        WindowStyle="ToolWindow" ResizeMode="CanResize">
    <Window.Resources>
        <Style x:Key="LblStyle" TargetType="TextBlock">
            <Setter Property="Foreground"        Value="#888888"/>
            <Setter Property="FontSize"          Value="12"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Margin"            Value="0,3,12,3"/>
        </Style>
        <Style x:Key="ValStyle" TargetType="TextBox">
            <Setter Property="Foreground"        Value="#E8E8E8"/>
            <Setter Property="Background"        Value="Transparent"/>
            <Setter Property="BorderThickness"   Value="0"/>
            <Setter Property="IsReadOnly"        Value="True"/>
            <Setter Property="FontSize"          Value="12"/>
            <Setter Property="Padding"           Value="0"/>
            <Setter Property="Margin"            Value="0,3,0,3"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="TextWrapping"      Value="Wrap"/>
            <Setter Property="Cursor"            Value="IBeam"/>
        </Style>
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background"      Value="#202020"/>
            <Setter Property="CornerRadius"    Value="6"/>
            <Setter Property="Padding"         Value="16,12"/>
            <Setter Property="Margin"          Value="0,0,0,8"/>
            <Setter Property="BorderBrush"     Value="#2E2E2E"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style x:Key="SectionTitle" TargetType="TextBlock">
            <Setter Property="Foreground"  Value="#CCCCCC"/>
            <Setter Property="FontSize"    Value="13"/>
            <Setter Property="FontWeight"  Value="SemiBold"/>
            <Setter Property="Margin"      Value="0,0,0,10"/>
        </Style>
        <Style x:Key="SubCard" TargetType="Border">
            <Setter Property="Background"      Value="#282828"/>
            <Setter Property="CornerRadius"    Value="4"/>
            <Setter Property="Padding"         Value="12,8"/>
            <Setter Property="Margin"          Value="0,0,0,5"/>
            <Setter Property="BorderBrush"     Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
    </Window.Resources>
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Margin="0,0,0,14">
            <TextBlock Text="Detayli Donanim Bilgisi" Foreground="#FFFFFF" FontSize="18" FontWeight="Bold"/>
            <TextBlock Text="Tum degerler secilip kopyalanabilir (Ctrl+C)" Foreground="#555555" FontSize="11" Margin="0,3,0,0"/>
        </StackPanel>
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <!-- ANAKART ve BIOS -->
                <Border Style="{StaticResource Card}">
                    <StackPanel>
                        <TextBlock Style="{StaticResource SectionTitle}" Text="Anakart ve BIOS"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="120"/><ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Anakart"/>
                            <TextBox   Grid.Row="0" Grid.Column="1" Style="{StaticResource ValStyle}" x:Name="txtMB"/>
                            <TextBlock Grid.Row="1" Grid.Column="0" Style="{StaticResource LblStyle}" Text="BIOS Surumu"/>
                            <TextBox   Grid.Row="1" Grid.Column="1" Style="{StaticResource ValStyle}" x:Name="txtBIOS"/>
                        </Grid>
                    </StackPanel>
                </Border>
                <!-- RAM -->
                <Border Style="{StaticResource Card}">
                    <StackPanel>
                        <TextBlock Style="{StaticResource SectionTitle}" Text="RAM Modulleri"/>
                        <ItemsControl x:Name="icRAM">
                            <ItemsControl.ItemTemplate>
                                <DataTemplate>
                                    <Border Style="{StaticResource SubCard}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="120"/><ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <Grid.RowDefinitions>
                                                <RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Slot"/>
                                            <TextBox   Grid.Row="0" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding Slot}"/>
                                            <TextBlock Grid.Row="1" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Marka / Model"/>
                                            <TextBox   Grid.Row="1" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding MfrPart}"/>
                                            <TextBlock Grid.Row="2" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Kapasite"/>
                                            <TextBox   Grid.Row="2" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding CapStr}"/>
                                            <TextBlock Grid.Row="3" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Hiz"/>
                                            <TextBox   Grid.Row="3" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding SpeedStr}"/>
                                        </Grid>
                                    </Border>
                                </DataTemplate>
                            </ItemsControl.ItemTemplate>
                        </ItemsControl>
                    </StackPanel>
                </Border>
                <!-- GPU -->
                <Border Style="{StaticResource Card}">
                    <StackPanel>
                        <TextBlock Style="{StaticResource SectionTitle}" Text="Grafik Karti (GPU)"/>
                        <ItemsControl x:Name="icGPU">
                            <ItemsControl.ItemTemplate>
                                <DataTemplate>
                                    <Border Style="{StaticResource SubCard}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="120"/><ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <Grid.RowDefinitions>
                                                <RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Uretici (AIB)"/>
                                            <TextBox   Grid.Row="0" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding Vendor}"/>
                                            <TextBlock Grid.Row="1" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Model"/>
                                            <TextBox   Grid.Row="1" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding Name}"/>
                                            <TextBlock Grid.Row="2" Grid.Column="0" Style="{StaticResource LblStyle}" Text="VRAM"/>
                                            <TextBox   Grid.Row="2" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding VramStr}"/>
                                            <TextBlock Grid.Row="3" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Surucu"/>
                                            <TextBox   Grid.Row="3" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding Driver}"/>
                                        </Grid>
                                    </Border>
                                </DataTemplate>
                            </ItemsControl.ItemTemplate>
                        </ItemsControl>
                    </StackPanel>
                </Border>
                <!-- DISK -->
                <Border Style="{StaticResource Card}">
                    <StackPanel>
                        <TextBlock Style="{StaticResource SectionTitle}" Text="Fiziksel Diskler"/>
                        <ItemsControl x:Name="icDisk">
                            <ItemsControl.ItemTemplate>
                                <DataTemplate>
                                    <Border Style="{StaticResource SubCard}">
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="120"/><ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            <Grid.RowDefinitions>
                                                <RowDefinition/><RowDefinition/><RowDefinition/>
                                            </Grid.RowDefinitions>
                                            <TextBlock Grid.Row="0" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Model"/>
                                            <TextBox   Grid.Row="0" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding Model}"/>
                                            <TextBlock Grid.Row="1" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Kapasite"/>
                                            <TextBox   Grid.Row="1" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding SizeStr}"/>
                                            <TextBlock Grid.Row="2" Grid.Column="0" Style="{StaticResource LblStyle}" Text="Seri No"/>
                                            <TextBox   Grid.Row="2" Grid.Column="1" Style="{StaticResource ValStyle}" Text="{Binding Serial}"/>
                                        </Grid>
                                    </Border>
                                </DataTemplate>
                            </ItemsControl.ItemTemplate>
                        </ItemsControl>
                    </StackPanel>
                </Border>
            </StackPanel>
        </ScrollViewer>
        <Button x:Name="btnCloseHW" Grid.Row="2" Content="Kapat" Height="34" Width="100"
                HorizontalAlignment="Right" Margin="0,10,0,0"
                Background="#2E2E2E" Foreground="#CCCCCC"/>
    </Grid>
</Window>
"@

    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlHW)
        $winHW  = [Windows.Markup.XamlReader]::Load($reader)
        $winHW.Owner = $Win

        $txtMB   = $winHW.FindName('txtMB')
        $txtBIOS = $winHW.FindName('txtBIOS')
        $icRAM   = $winHW.FindName('icRAM')
        $icGPU   = $winHW.FindName('icGPU')
        $icDisk  = $winHW.FindName('icDisk')
        $btnCl   = $winHW.FindName('btnCloseHW')

        # ── ANAKART & BIOS ─────────────────────────────────────
        $txtMB.Text   = if ($d.MbInfo)   { $d.MbInfo }   else { "Alinamadi" }
        $txtBIOS.Text = if ($d.BiosInfo) { $d.BiosInfo } else { "Alinamadi" }

        # ── RAM ────────────────────────────────────────────────
        $brandTable = @{
            "F4-"  = "G.Skill";  "F5-"  = "G.Skill";  "FA-"  = "G.Skill"
            "CMK"  = "Corsair";  "CMW"  = "Corsair";  "CMH"  = "Corsair"
            "CMP"  = "Corsair";  "CMT"  = "Corsair";  "CML"  = "Corsair"
            "KF4"  = "Kingston (Fury)"; "KF5"  = "Kingston (Fury)"
            "KVR"  = "Kingston"; "HX"   = "Kingston (HyperX)"
            "CT"   = "Crucial";  "BL"   = "Crucial (Ballistix)"
            "M378" = "Samsung";  "M471" = "Samsung";  "M425" = "Samsung"
            "M324" = "Samsung";  "M4R"  = "Samsung"
            "HMA"  = "SK Hynix"; "HMT"  = "SK Hynix"; "HMCG" = "SK Hynix"; "HMAA" = "SK Hynix"
            "MTC"  = "Micron"
            "TF4"  = "TeamGroup"; "TF5" = "TeamGroup"; "TLZGD" = "TeamGroup"
            "AX4"  = "ADATA (XPG)"; "AX5" = "ADATA (XPG)"; "AD4U" = "ADATA"; "AD5U" = "ADATA"
            "PVS"  = "Patriot";  "PX4"  = "Patriot";  "PX5"  = "Patriot"
            "RG"   = "Thermaltake (TOUGHRAM)"
            "KD4"  = "Klevv";    "KD5"  = "Klevv"
            "LD4"  = "Lexar";    "LD5"  = "Lexar"
        }

        function Resolve-RamBrand([string]$pn) {
            if ([string]::IsNullOrWhiteSpace($pn)) { return $null }
            $pn = $pn.Trim()
            foreach ($len in 5,4,3,2) {
                if ($pn.Length -ge $len) {
                    $pfx = $pn.Substring(0,$len)
                    if ($brandTable.ContainsKey($pfx)) { return $brandTable[$pfx] }
                }
            }
            return $null
        }

        function Resolve-DdrType([int]$t) {
            switch ($t) {
                19 { return "DDR2"    }
                24 { return "DDR3"    }
                26 { return "DDR4"    }
                27 { return "LPDDR4"  }
                28 { return "LPDDR4X" }
                29 { return "DDR5"    }
                34 { return "DDR5"    }
                35 { return "LPDDR5"  }
                default { return $null }
            }
        }

        $ramItems = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        foreach ($mod in $d.RamModules) {
            $brand   = Resolve-RamBrand $mod.Part
            $ddrType = Resolve-DdrType ([int]$mod.MemType)

            # "G.Skill  -  F5-6000J3038F16G  (DDR5)"
            $mfrPart = if ($brand) { "$brand  -  $($mod.Part)" } else { "$($mod.Part)" }
            if ($ddrType) { $mfrPart += "  ($ddrType)" }

            # Hiz: ConfiguredClockSpeed = BIOS aktif hiz (XMP/EXPO dahil)
            # Speed (Win32_PhysicalMemory.Speed) = SPD max profili
            # Ikisi esitse XMP/EXPO tam calisuyor demektir.
            # Cfg < Spd   = XMP/EXPO etkin degil (JEDEC ile calisuyor)
            $cfg = [int]$mod.CfgMHz
            $spd = [int]$mod.SpeedMHz
            $speedStr = "$cfg MHz"
            if ($spd -gt 0 -and $spd -ne $cfg) {
                if ($cfg -lt $spd) {
                    $speedStr = "$cfg MHz  (XMP/EXPO etkin degil  -  Kit hizi: $spd MHz)"
                } else {
                    $speedStr = "$cfg MHz  (Kit SPD max: $spd MHz)"
                }
            }

            $ramItems.Add([PSCustomObject]@{
                Slot    = $mod.Slot
                MfrPart = $mfrPart
                CapStr  = "$($mod.Capacity) GB"
                SpeedStr = $speedStr
            }) | Out-Null
        }
        $icRAM.ItemsSource = $ramItems

        # ── GPU ────────────────────────────────────────────────
        # PCI SubSystem Vendor ID tablosu -> AIB kart uretici
        # SUBSYS_SSSSSVVVV formatinda:
        #   SSSS = SubSystem Device ID (kart modeli, ornegin 89D7)
        #   VVVV = SubSystem Vendor ID  (AIB uretici, ornegin 1043 = ASUS)
        # Senin RTX 5080: SUBSYS_89D71043 -> SubVendor=1043 -> ASUS
        $aibTable = @{
            "1043" = "ASUS"
            "1462" = "MSI"
            "1458" = "Gigabyte"
            "3842" = "EVGA"
            "174B" = "Sapphire"
            "1DA2" = "Sapphire"
            "148C" = "PowerColor"
            "1682" = "XFX"
            "19DA" = "Zotac"
            "196E" = "Palit / Gainward"
            "1B4C" = "Inno3D / Galax"
            "1849" = "ASRock"
            "7377" = "Colorful"
            "1ACC" = "Manli"
        }

        function Get-GpuAibMap {
            # PnPClass = "Display" olan tum cihazlari tara.
            # HardwareID listesindeki ilk SUBSYS degerinin son 4 hanesini SubVendor olarak al.
            # { "NVIDIA GeForce RTX 5080" -> "ASUS" } seklinde map dondurur.
            $map = @{}
            try {
                $displays = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
                            Where-Object { $_.PNPClass -eq "Display" }
                foreach ($dev in $displays) {
                    if (-not $dev.HardwareID -or -not $dev.Name) { continue }
                    foreach ($hwId in $dev.HardwareID) {
                        # Ornek: PCI\VEN_10DE&DEV_2C02&SUBSYS_89D71043&REV_A1
                        if ($hwId -match "SUBSYS_([0-9A-Fa-f]{4})([0-9A-Fa-f]{4})") {
                            $subVendorId = $Matches[2].ToUpper()   # son 4 hane = AIB
                            if ($aibTable.ContainsKey($subVendorId)) {
                                $map[$dev.Name] = $aibTable[$subVendorId]
                            }
                            break  # bu cihaz icin ilk SUBSYS yeterli
                        }
                    }
                }
            } catch {}
            return $map
        }

        function Get-GpuVramMap {
            $map = @{}
            $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
            try {
                Get-ChildItem $regKey -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -match '^\d{4}$' } |
                ForEach-Object {
                    $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    $desc  = $props.DriverDesc
                    if (-not $desc) { return }
                    $qw = $props."HardwareInformation.qwMemorySize"
                    if (-not $qw) { $qw = $props."HardwareInformation.MemorySize" }
                    if ($qw) { $map[$desc] = [Math]::Round([long]$qw / 1GB, 1) }
                }
            } catch {}
            return $map
        }

        $aibMap  = Get-GpuAibMap
        $vramMap = Get-GpuVramMap
        $gpuItems = New-Object System.Collections.ObjectModel.ObservableCollection[Object]

        foreach ($g in $d.GpuDetail) {
            # AIB eslestirmesi — once birebir isim eslesimi, sonra partial
            $vendor = $null
            foreach ($pnpName in $aibMap.Keys) {
                if ($pnpName -eq $g.Name -or
                    $pnpName.ToLower().Contains($g.Name.ToLower()) -or
                    $g.Name.ToLower().Contains($pnpName.ToLower())) {
                    $vendor = $aibMap[$pnpName]; break
                }
            }
            # Partial match fallback (GPU adi parcalara bolunup aranir)
            if (-not $vendor) {
                foreach ($part in ($g.Name -split '\s+' | Where-Object { $_.Length -gt 4 })) {
                    foreach ($pnpName in $aibMap.Keys) {
                        if ($pnpName.ToLower().Contains($part.ToLower())) {
                            $vendor = $aibMap[$pnpName]; break
                        }
                    }
                    if ($vendor) { break }
                }
            }
            # Son fallback: chip uretici
            if (-not $vendor) {
                if     ($g.Name -match "NVIDIA|GeForce|RTX|GTX|Quadro") { $vendor = "NVIDIA" }
                elseif ($g.Name -match "Radeon|RX |AMD")                 { $vendor = "AMD"    }
                elseif ($g.Name -match "Intel|Arc|Iris|UHD")             { $vendor = "Intel"  }
                else                                                      { $vendor = "Bilinmiyor" }
            }

            # VRAM: registry QWORD, fallback WMI degerine don
            $vramGB = $null
            foreach ($rk in $vramMap.Keys) {
                if ($rk -eq $g.Name -or
                    $rk.ToLower().Contains($g.Name.ToLower()) -or
                    $g.Name.ToLower().Contains($rk.ToLower())) {
                    $vramGB = $vramMap[$rk]; break
                }
            }
            $vramStr = if ($vramGB) { "$vramGB GB" } else { "$($g.VRAM) GB" }

            # Surucu versiyonu: NVIDIA Windows suru numarasini oyun suru numarasina cevir
            $drv = $g.Driver
            if ($g.Name -match "NVIDIA|GeForce|RTX|GTX" -and $drv) {
                $digits = $drv -replace "\D",""
                if ($digits.Length -ge 5) {
                    $drv = $digits.Substring($digits.Length - 5).Insert(3,".")
                }
            }

            $gpuItems.Add([PSCustomObject]@{
                Vendor  = $vendor
                Name    = $g.Name
                VramStr = $vramStr
                Driver  = $drv
            }) | Out-Null
        }
        $icGPU.ItemsSource = $gpuItems

        # ── DISK ───────────────────────────────────────────────
        $diskItems = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        foreach ($dk in $d.DiskDetail) {
            $diskItems.Add([PSCustomObject]@{
                Model   = $dk.Model
                SizeStr = "$($dk.SizeGB) GB"
                Serial  = if ($dk.Serial -and $dk.Serial.Trim()) { $dk.Serial.Trim() } else { "-" }
            }) | Out-Null
        }
        $icDisk.ItemsSource = $diskItems

        $btnCl.Add_Click({ $winHW.Close() })
        $winHW.ShowDialog() | Out-Null

    } catch {
        [System.Windows.MessageBox]::Show("Pencere acilamadi: $($_.Exception.Message)", "Hata") | Out-Null
    }
}

# ---- Load-DashboardData ----
function Load-DashboardData {
    # =========================================================
    # 5 DAKİKA CACHE — Her yenileme WMI sorgularını tekrar çalıştırmaz.
    # Bu sayede sekme değişimlerinde UI donması yaşanmaz.
    # =========================================================
    if ($global:DashCache -and $global:DashCacheTime -and 
        ((Get-Date) - $global:DashCacheTime).TotalMinutes -lt 5) {
        
        $cached = $global:DashCache
        $global:DashResult = $cached
        
        # UI'ı cache'den doldur
        $txtDashOS.Text   = $cached.OS
        $txtDashCPU.Text  = $cached.CPU
        $txtDashGPU.Text  = $cached.GPU
		$txtDashDNS.Text  = $cached.DNS
        $txtDashRAM.Text  = $cached.RAM_Text
        $pbDashRAM.Value  = $cached.RAM_Val
        if ($cached.RAM_Val -gt 85) { $pbDashRAM.Foreground = [System.Windows.Media.Brushes]::Red }
        $txtDashDisk.Text = $cached.Disk_Text
        $pbDashDisk.Value = $cached.Disk_Val
        if ($cached.Disk_Val -gt 90 -or $cached.Smart -match "Kritik") { 
            $pbDashDisk.Foreground = [System.Windows.Media.Brushes]::Red 
        }
        $txtDashSubHeader.Text = "✅ Önbellekten yüklendi. (Son tarama: $($global:DashCacheTime.ToString('HH:mm:ss')))"
        if ($btnHardwareDetail) { $btnHardwareDetail.IsEnabled = $true }
        return
    }

    # 1. Arka Plan Motorunu Başlat
    $script:DashRunspace = [powershell]::Create()
    
    $script:DashRunspace.AddScript({
        $ErrorActionPreference = "SilentlyContinue"
        
        # --- CimSession: Tek bağlantıyla tüm WMI sorguları (her Get-CimInstance ayrı bağlantı açar) ---
        $cim = New-CimSession -ErrorAction SilentlyContinue
        
        # --- 1. İŞLETİM SİSTEMİ ---
        $os = Get-CimInstance Win32_OperatingSystem -CimSession $cim
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $displayVersion = (Get-ItemProperty -Path $regPath -Name "DisplayVersion" -ErrorAction SilentlyContinue).DisplayVersion
        if (-not $displayVersion) { $displayVersion = (Get-ItemProperty -Path $regPath -Name "ReleaseId" -ErrorAction SilentlyContinue).ReleaseId }
        $osName = "$($os.Caption) ($displayVersion)"
        
        # --- 2. CPU ---
        $cpu = Get-CimInstance Win32_Processor -CimSession $cim | Select-Object -First 1
        $cpuName = $cpu.Name

        # --- 3. GPU (SÜRÜCÜ PARSE EDİCİ EKLENDİ) ---
        $gpus = Get-CimInstance Win32_VideoController -CimSession $cim
        $gpuList = @()
        
        if ($gpus) {
            foreach ($g in $gpus) {
                $gName = $g.Name
                $drvRaw = $g.DriverVersion
                $drvFinal = ""

                # NVIDIA Sürücü Numarası Çevirici (Örn: 32.0.15.5186 -> 551.86)
                if ($gName -match "NVIDIA" -and $drvRaw) {
                    $digits = $drvRaw -replace "\D", "" 
                    if ($digits.Length -ge 5) {
                        $last5 = $digits.Substring($digits.Length - 5)
                        $drvFinal = $last5.Insert(3, ".")
                    } else {
                        $drvFinal = $drvRaw
                    }
                } 
                elseif ($drvRaw) {
                    $drvFinal = $drvRaw
                }

                if ($drvFinal) {
                    $gpuList += "$gName `n(Sürüm: $drvFinal)"
                } else {
                    $gpuList += "$gName"
                }
            }
            $gpuName = $gpuList -join "`n`n"
        } else {
            $gpuName = "Standart Grafik Kartı"
        }

        # --- 4. RAM ---
        $totalRamBytes = $os.TotalVisibleMemorySize * 1KB
        $freeRamBytes  = $os.FreePhysicalMemory * 1KB
        $usedRamBytes  = $totalRamBytes - $freeRamBytes
        
        $totalRamGB = [Math]::Round($totalRamBytes / 1GB, 1)
        $usedRamGB  = [Math]::Round($usedRamBytes / 1GB, 1)
        $ramPercent = [Math]::Round(($usedRamBytes / $totalRamBytes) * 100)
        
        # --- 5. DISK ---
        $disk = Get-CimInstance Win32_LogicalDisk -CimSession $cim -Filter "DeviceID='C:'" | Select-Object -First 1
        $diskSizeGB = [Math]::Round($disk.Size / 1GB, 1)
        $diskFreeGB = [Math]::Round($disk.FreeSpace / 1GB, 1)
        $diskUsedGB = $diskSizeGB - $diskFreeGB
        $diskPercent = [Math]::Round(($diskUsedGB / $diskSizeGB) * 100)
        
        # --- 6. S.M.A.R.T. ---
        $smartStatus = "Sağlıklı ✅"
        try {
            $smart = Get-CimInstance -CimSession $cim -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue
            if ($smart -and $smart.PredictFailure) { $smartStatus = "Kritik (Arıza Riski!) ⚠️" }
        } catch {}

        # --- 7. RAM DETAY (Marka, Model, MHz, DDR Tipi) ---
        $ramModules = @()
        try {
            $physRam = Get-CimInstance Win32_PhysicalMemory -CimSession $cim -ErrorAction SilentlyContinue
            foreach ($mod in $physRam) {
                $mfr    = if ($mod.Manufacturer -and $mod.Manufacturer.Trim() -notmatch "^\s*$|Unknown|Not Specified") { $mod.Manufacturer.Trim() } else { "" }
                $part   = if ($mod.PartNumber   -and $mod.PartNumber.Trim()   -ne "") { $mod.PartNumber.Trim() }   else { "?" }
                $cap    = [Math]::Round($mod.Capacity / 1GB)
                $spd    = $mod.Speed
                $cfgSpd = $mod.ConfiguredClockSpeed
                $slot   = $mod.DeviceLocator
                $memType = [int]$mod.SMBIOSMemoryType

                $ramModules += [PSCustomObject]@{
                    Slot    = $slot
                    Capacity = $cap
                    Mfr     = $mfr
                    Part    = $part
                    SpeedMHz = $spd
                    CfgMHz  = $cfgSpd
                    MemType = $memType
                }
            }
        } catch {}

        # --- 8. BIOS ---
        $biosInfo = ""
        try {
            $bios = Get-CimInstance Win32_BIOS -CimSession $cim -ErrorAction SilentlyContinue
            $biosVer  = $bios.SMBIOSBIOSVersion
            $biosDate = if ($bios.ReleaseDate) { ([DateTime]$bios.ReleaseDate).ToString("yyyy-MM-dd") } else { "?" }
            $biosInfo = "$biosVer  ($biosDate)"
        } catch {}

        # --- 9. ANAKART ---
        $mbInfo = ""
        try {
            $mb = Get-CimInstance Win32_BaseBoard -CimSession $cim -ErrorAction SilentlyContinue
            $mbInfo = "$($mb.Manufacturer) $($mb.Product)"
        } catch {}

        # --- 10. GPU DETAY (VRAM) ---
        $gpuDetail = @()
        try {
            foreach ($g in $gpus) {
                $vramGB = if ($g.AdapterRAM -gt 0) { [Math]::Round($g.AdapterRAM / 1GB, 1) } else { "?" }
                $gpuDetail += [PSCustomObject]@{
                    Name   = $g.Name
                    VRAM   = $vramGB
                    Driver = $g.DriverVersion
                }
            }
        } catch {}

        # --- 11. DİSK DETAY (Fiziksel Diskler) ---
        $diskDetail = @()
        try {
            foreach ($d in (Get-CimInstance Win32_DiskDrive -CimSession $cim -ErrorAction SilentlyContinue)) {
                $sizeGB = [Math]::Round($d.Size / 1GB, 0)
                $diskDetail += [PSCustomObject]@{
                    Model  = $d.Model
                    SizeGB = $sizeGB
                    Serial = $d.SerialNumber
                }
            }
        } catch {}
		# --- 12. AKTİF DNS (Modem veya Windows) ---
        $activeDns = "Bilinmiyor"
        try {
            $netConfigs = Get-CimInstance Win32_NetworkAdapterConfiguration -CimSession $cim -Filter "IPEnabled = True" -ErrorAction SilentlyContinue
            $dnsList = @()
            foreach ($net in $netConfigs) {
                if ($net.DNSServerSearchOrder) { $dnsList += $net.DNSServerSearchOrder }
            }
            if ($dnsList.Count -gt 0) { $activeDns = ($dnsList | Select-Object -Unique) -join ", " }
        } catch {}

        # CimSession'ı kapat
        if ($cim) { Remove-CimSession $cim -ErrorAction SilentlyContinue }

        # CimSession'ı kapat
        if ($cim) { Remove-CimSession $cim -ErrorAction SilentlyContinue }

        # Sonuç Paketi
        return @{
            OS = $osName
            CPU = $cpuName
            GPU = $gpuName
			DNS = $activeDns
            
            RAM_Text = "Kullanılan: $usedRamGB GB / $totalRamGB GB"
            RAM_Val  = $ramPercent
            
            Disk_Text = "Dolu: $diskUsedGB GB / $diskSizeGB GB`nSağlık: $smartStatus"
            Disk_Val  = $diskPercent
            
            Smart      = $smartStatus
            RamModules = $ramModules
            BiosInfo   = $biosInfo
            MbInfo     = $mbInfo
            GpuDetail  = $gpuDetail
            DiskDetail = $diskDetail
        }
    })

    $script:DashAsync = $script:DashRunspace.BeginInvoke()
    
	# 2. Zamanlayıcı (DASHBOARD SONUÇLANDIRICI)
	$script:DashTimer = New-Object System.Windows.Threading.DispatcherTimer
	$script:DashTimer.Interval = [TimeSpan]::FromMilliseconds(500)

	$script:DashTimer.Add_Tick({
		# Eğer async handle null ise veya işlem bitmemişse hiç girme
		if ($null -eq $script:DashAsync -or -not $script:DashAsync.IsCompleted) { return }

		# 1. Hemen durdur (Birden fazla tetiklenmeyi ve çakışmayı önle)
		$script:DashTimer.Stop()
		
		$result = $null
		try {
			# 2. Arka plan verisini al
			$rawResult = $script:DashRunspace.EndInvoke($script:DashAsync)
			
			# PowerShell asenkron sonuçları bazen koleksiyon içinde döndürür, tekil nesneye indirge
			if ($rawResult -is [System.Collections.IEnumerable]) { 
				$result = $rawResult | Select-Object -First 1 
			} else { 
				$result = $rawResult 
			}
			
			if ($null -ne $result) {
				# 3. Cache Güncelleme (Atomik İşlem)
				$global:DashResult = $result
				$global:DashCache  = $result
				$global:DashCacheTime = Get-Date

				# --- 4. ARAYÜZ GÜNCELLEME (Hata Toleranslı) ---
				$txtDashOS.Text   = [string]$result.OS
				$txtDashCPU.Text  = [string]$result.CPU
				$txtDashGPU.Text  = [string]$result.GPU
				$txtDashDNS.Text  = [string]$result.DNS
				
				# RAM Kontrolü
				$txtDashRAM.Text = [string]$result.RAM_Text
				$pbDashRAM.Value = [double]$result.RAM_Val
				$pbDashRAM.Foreground = if ($result.RAM_Val -gt 85) { [System.Windows.Media.Brushes]::Red } else { [System.Windows.Media.Brushes]::LimeGreen }
				
				# Disk Kontrolü
				$txtDashDisk.Text = [string]$result.Disk_Text
				$pbDashDisk.Value = [double]$result.Disk_Val
				
				# Kritik Durum Renklendirmesi (P7 iyileştirmesi)
				if ($result.Disk_Val -gt 90 -or $result.Smart -match "Kritik") { 
					$pbDashDisk.Foreground = [System.Windows.Media.Brushes]::Red 
				} else {
					$pbDashDisk.Foreground = [System.Windows.Media.Brushes]::MediumPurple # Disk için görsel ayrım
				}
				
				$txtDashSubHeader.Text = "✅ Sistem verileri başarıyla güncellendi."
				$txtDashSubHeader.Foreground = [System.Windows.Media.Brushes]::Gray
				
				# Buton Kilidini Aç
				if ($btnHardwareDetail) { $btnHardwareDetail.IsEnabled = $true }
			}
		} 
		catch {
			# 5. Hata Yönetimi
			$txtDashSubHeader.Text = "⚠️ Donanım verileri okunamadı!"
			$txtDashSubHeader.Foreground = [System.Windows.Media.Brushes]::Salmon
			WpfLog "Dashboard Hatası: $($_.Exception.Message)"
		} 
		finally {
			# 6. KRİTİK BELLEK TEMİZLİĞİ (B1 Çözümü)
			if ($script:DashRunspace) { 
				$script:DashRunspace.Dispose()
				$script:DashRunspace = $null 
			}
			# Nesne referanslarını tamamen kopar (Garbage Collector'a yardım et)
			$script:DashAsync = $null
			$result = $null
			$rawResult = $null
		}
	})

$script:DashTimer.Start()
}

# ---- Show-BloatwareManager ----
function Show-BloatwareManager {
    try {
        # 1. XAML Tanımı
        $xamlBloat = @"
        <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                Title="Akıllı Bloatware Yöneticisi" Height="600" Width="500" 
                Background="#181818" WindowStartupLocation="CenterScreen" WindowStyle="ToolWindow">
            <Grid Margin="15">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <StackPanel>
                    <TextBlock Text="Windows Uygulamaları Temizleyici" Foreground="#FF5555" FontSize="18" FontWeight="Bold"/>
                    <TextBlock Text="Kaldırmak istediğiniz uygulamaları seçin." Foreground="#AAA" FontSize="12" Margin="0,5,0,10"/>
                    <CheckBox x:Name="chkSelectAll" Content="Tümünü Seç / Kaldır" Foreground="White" Margin="0,0,0,10"/>
                </StackPanel>
                <TreeView x:Name="tvBloat" Grid.Row="1" Background="#222" BorderThickness="0" Padding="5"/>
                <Button x:Name="btnClean" Grid.Row="2" Content="SEÇİLENLERİ KALDIR" Background="#A00" Foreground="White" Height="40" Margin="0,15,0,0" FontWeight="Bold"/>
            </Grid>
        </Window>
"@
        # 2. Pencereyi ve Kontrolleri Yükle
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlBloat)
        $winBloat = [Windows.Markup.XamlReader]::Load($reader)
        
        $tvBloat = $winBloat.FindName('tvBloat')
        $btnClean = $winBloat.FindName('btnClean')
        $chkSelectAll = $winBloat.FindName('chkSelectAll')

        # 3. Listeyi Doldur (UWP Paketleri)
        $categories = [ordered]@{
            "📢 Sponsorlu / Gereksiz (Önerilen)" = @("Bing", "Weather", "News", "GetHelp", "GetStarted", "Solitaire", "OfficeHub", "OneNote", "Skype", "Maps", "Zune", "YourPhone", "People", "Feedback", "Cortana", "Clipchamp", "Family", "QuickAssist", "ToDo", "Spotify", "Netflix", "TikTok", "Instagram", "Facebook", "Twitter", "Disney", "CandyCrush")
            "🎮 Xbox ve Oyun" = @("Xbox")
            "🔧 Sistem Araçları (Dikkat)" = @("Calculator", "Photos", "Camera", "SoundRecorder", "Alarms", "StickyNotes", "Paint", "Terminal")
        }

        $allApps = Get-AppxPackage | Where-Object { $_.NonRemovable -eq $false -and $_.IsFramework -eq $false } | Sort-Object Name
        
        foreach ($catName in $categories.Keys) {
            $catItem = New-TreeItem $catName "ROOT"
            $catItem.Foreground = if ($catName -match "Sponsorlu") { [System.Windows.Media.Brushes]::LimeGreen } else { [System.Windows.Media.Brushes]::Yellow }
            $catItem.IsExpanded = $true
            
            $keywords = $categories[$catName]
            $foundInCat = 0

            foreach ($app in $allApps) {
                foreach ($kw in $keywords) {
                    if ($app.Name -match $kw) {
                        $item = New-TreeItem "$($app.Name) ($($app.Version))" $app.PackageFullName
                        if ($catName -match "Sponsorlu") { (Get-CheckFromItem $item).IsChecked = $true }
                        $catItem.Items.Add($item) | Out-Null
                        $foundInCat++
                        break
                    }
                }
            }
            if ($foundInCat -gt 0) { $tvBloat.Items.Add($catItem) | Out-Null }
        }

        # 4. "Tümünü Seç" Olayı
        $chkSelectAll.Add_Click({
            $state = $chkSelectAll.IsChecked
            foreach ($parent in $tvBloat.Items) {
                (Get-CheckFromItem $parent).IsChecked = $state
                Sync-Children $parent $state
            }
        })

        # 5. "Kaldır" Butonu Olayı (MODERN RAM MOTORU)
        $btnClean.Add_Click({
            $toRemove = @()
            foreach ($parent in $tvBloat.Items) {
                foreach ($child in $parent.Items) {
                    $chk = Get-CheckFromItem $child
                    if ($chk -and $chk.IsChecked) { $toRemove += $child.Tag }
                }
            }

            if ($toRemove.Count -eq 0) { return }

            if ([System.Windows.MessageBox]::Show("$($toRemove.Count) uygulama sistemden silinecek. Onaylıyor musunuz?", "Onay", [System.Windows.MessageBoxButton]::YesNo) -eq 'Yes') {
                $winBloat.Close()
                WpfLog "--- BLOATWARE TEMİZLİĞİ BAŞLIYOR ---"
                
                $listStr = ($toRemove | ForEach-Object { "'$_'" }) -join ","
                $innerScript = @"
                    WS 'Hazırlanıyor...'
                    `$apps = @($listStr)
                    foreach (`$app in `$apps) {
                        `$short = `$app.Split('_')[0]
                        WS "Siliniyor: `$short"
                        Log ">> HEDEF: `$app"
                        try {
                            Remove-AppxPackage -Package `$app -ErrorAction Stop
                            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq `$short | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                            Log "   ✅ BAŞARILI"
                        } catch { Log "   ❌ HATA: `$($_.Exception.Message)" }
                    }
                    WS 'Bitti'
"@
                Start-Worker-Process $innerScript $null "BLOATWARE TEMİZLİĞİ"
            }
        })

        # B5 Sızıntı Koruması
        $winBloat.Add_Closed({
            $tvBloat = $null; $btnClean = $null; $chkSelectAll = $null; $winBloat = $null
            [System.GC]::Collect()
        })

        $winBloat.ShowDialog() | Out-Null

    } catch {
        WpfLog "❌ Bloatware penceresi yüklenemedi: $($_.Exception.Message)"
    }
}

# ---- Start-LargeFileScan ----
function Start-LargeFileScan {
    # 1. HEDEF BELİRLEME
    $targetPath = ""
    $selIndex = $cbScanTarget.SelectedIndex
    
    if ($selIndex -eq 0) { $targetPath = $env:USERPROFILE } 
    elseif ($selIndex -eq 1) { $targetPath = "C:\" }       
    elseif ($selIndex -eq 2) {
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($fbd.ShowDialog() -eq 'OK') { $targetPath = $fbd.SelectedPath } else { return }
    }

    # 2. BOYUT BELİRLEME
    $minBytes = 104857600 # 100MB
    if ($cbMinSize.SelectedItem.Tag) { $minBytes = [int64]$cbMinSize.SelectedItem.Tag }

    # UI KİLİTLEME
    $lvLargeFiles.Items.Clear()
    $btnScanFiles.IsEnabled = $false
    $pbLargeScan.Visibility = "Visible"
    $txtLargeStatus.Text = "Taranıyor: $targetPath (Bekleyin...)"

    # 3. ARKA PLAN MOTORU
    $script:FileRunspace = [powershell]::Create()
    
    $script:FileRunspace.AddScript({
        param($startPath, $limitBytes)
        $ErrorActionPreference = "SilentlyContinue"
        
        # PERFORMANS 1: Hantal olan Array (+=) yerine, ışık hızında çalışan Generic List kullanıyoruz.
        $results = New-Object System.Collections.Generic.List[object]
        $totalFoundBytes = 0 
        
        $stack = New-Object System.Collections.Generic.Stack[string]
        $stack.Push($startPath)
        
        while ($stack.Count -gt 0) {
            $currentDir = $stack.Pop()
            try {
                $files = [System.IO.Directory]::GetFiles($currentDir)
                foreach ($f in $files) {
                    $info = New-Object System.IO.FileInfo($f)
                    if ($info.Length -ge $limitBytes) {
                        
                        $totalFoundBytes += $info.Length

                        $sizeDisplay = ""
                        if ($info.Length -ge 1GB) { $sizeDisplay = "{0:N2} GB" -f ($info.Length / 1GB) }
                        else { $sizeDisplay = "{0:N2} MB" -f ($info.Length / 1MB) }

                        # Elemanı listeye ekle
                        $results.Add(@{
                            Name = $info.Name
                            FullName = $info.FullName
                            SizeRaw = $info.Length 
                            SizeStr = $sizeDisplay 
                            Extension = $info.Extension
                            Folder = $info.DirectoryName
                            Date = $info.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                        })
                    }
                }
                
                $dirs = [System.IO.Directory]::GetDirectories($currentDir)
                foreach ($d in $dirs) { $stack.Push($d) }
            } catch { continue }
        }
        
        # PERFORMANS 2: "Sort-Object" tamamen kaldırıldı! Yük sadece UI'a (WPF'e) bırakıldı.
        return @{
            Files = $results
            TotalBytes = $totalFoundBytes
        }
    })
    
    $script:FileRunspace.AddArgument($targetPath)
    $script:FileRunspace.AddArgument($minBytes)
    $script:FileAsync = $script:FileRunspace.BeginInvoke()

    # 4. ZAMANLAYICI (DOSYA TARAMA SONUÇLANDIRICI)
	$script:FileTimer = New-Object System.Windows.Threading.DispatcherTimer
	$script:FileTimer.Interval = [TimeSpan]::FromMilliseconds(500)

	$script:FileTimer.Add_Tick({
		# Eğer işlem henüz bitmediyse çık
		if (-not $script:FileAsync.IsCompleted) { return }

		# 1. Hemen durdur (Birden fazla tetiklenmeyi önle)
		$script:FileTimer.Stop()
		
		try {
			# 2. Arka plan verisini al
			$package = $script:FileRunspace.EndInvoke($script:FileAsync)
			
			if ($package -and $package.Files -and $package.Files.Count -gt 0) {
				
				# --- PERFORMANS OPTİMİZASYONU ---
				# ListView'in her öğe eklendiğinde ekranı tazelemesini engelle
				$lvLargeFiles.BeginInit()
				$lvLargeFiles.Items.Clear() 

				$count = 0
				foreach ($d in $package.Files) {
					# Doğrudan ekle (Memory Leak yapmaması için nesne referanslarını temiz tut)
					$lvLargeFiles.Items.Add([PSCustomObject]@{
						Name      = $d.Name
						FullName  = $d.FullName
						SizeRaw   = $d.SizeRaw
						SizeStr   = $d.SizeStr
						Extension = $d.Extension
						Folder    = $d.Folder
						Date      = $d.Date
					}) | Out-Null
					$count++
				}

				# Sıralama kurallarını uygula
				$view = $lvLargeFiles.Items
				$view.SortDescriptions.Clear()
				$view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription "SizeRaw", "Descending"))
				
				# İşlemi bitir ve çizime izin ver
				$lvLargeFiles.EndInit()

				$totalStr = if ($package.TotalBytes -ge 1GB) { "{0:N2} GB" -f ($package.TotalBytes / 1GB) } else { "{0:N2} MB" -f ($package.TotalBytes / 1MB) }
				$txtLargeStatus.Text = "Tarama Tamamlandı. $count dosya bulundu. (Toplam: $totalStr)"

			} else {
				$txtLargeStatus.Text = "Kriterlere uygun dosya bulunamadı."
			}
		} 
		catch {
			# 3. Hata Yönetimi: Kullanıcıya görsel geri bildirim ver
			$txtLargeStatus.Text = "Tarama hatası oluştu!"
			$txtLargeStatus.Foreground = [System.Windows.Media.Brushes]::Red
			WpfLog "Büyük Dosya Tarama Hatası: $($_.Exception.Message)"
		} 
		finally {
			# 4. KRİTİK BELLEK TEMİZLİĞİ (Claude Geliştirmesi)
			if ($script:FileRunspace) { 
				$script:FileRunspace.Dispose()
				$script:FileRunspace = $null 
			}
			$script:FileAsync = $null  # Async tutamacı temizle
			$package = $null           # Büyük veri paketini bellekten düşür

			# 5. UI Reset
			$btnScanFiles.IsEnabled = $true
			$pbLargeScan.Visibility = [System.Windows.Visibility]::Collapsed
		}
	})

	$script:FileTimer.Start()
}

# #endregion 13 -- UI / MODAL FONKSIYONLARI


# --- BAŞLANGIÇ YÖNETİCİSİ OLAYLARI (EVENTS) ---


# =========================================================================
# #region 14 -- EVENT HANDLERS (Butonlar, Context Menus, Tab Selection)
# =========================================================================

$btnRefreshStartup.Add_Click({ Refresh-StartupView })
$rbStartupWin.Add_Checked({ if ($lvStartup) { Refresh-StartupView } })
$rbStartupTask.Add_Checked({ if ($lvStartup) { Refresh-StartupView } })

$global:StartupTabLoaded = $false

# Sağ Tık: AÇ / KAPAT (Toggle)
$ctxToggleStartup.Add_Click({
    if ($lvStartup.SelectedItem) {
        $item = $lvStartup.SelectedItem
        try {
            if ($item.Source -eq "Registry" -or $item.Source -eq "Folder") {
                if (-not (Test-Path $item.ApprPath)) { New-Item -Path $item.ApprPath -Force -ErrorAction SilentlyContinue | Out-Null }
                
                # Gizli Görev Yöneticisi ayarını değiştiriyoruz
                [byte[]]$newBinary = if ($item.IsEnabled) { 0x03,0,0,0,0,0,0,0,0,0,0,0 } else { 0x02,0,0,0,0,0,0,0,0,0,0,0 }
                Set-ItemProperty -Path $item.ApprPath -Name $item.RawName -Value $newBinary -Type Binary -Force -ErrorAction Stop
                
                # SİHİRLİ DOKUNUŞ: Görev yöneticisini uyandırmak için orijinal reg kaydını kendine tekrar kopyala (Dummy Write)
                if ($item.Source -eq "Registry") {
                    $currVal = (Get-ItemProperty -Path $item.RegPath -Name $item.RawName -ErrorAction SilentlyContinue).($item.RawName)
                    if ($null -ne $currVal) {
                        Set-ItemProperty -Path $item.RegPath -Name $item.RawName -Value $currVal -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            elseif ($item.Source -eq "UWP") {
                # UWP için: 2 = Etkin, 1 = Devre Dışı.
                $newState = if ($item.IsEnabled) { 1 } else { 2 }
                Set-ItemProperty -Path $item.RegPath -Name "State" -Value $newState -Type DWord -Force -ErrorAction Stop
                
                # --- SİHİRLİ DOKUNUŞ (CACHE BUSTER) ---
                # Windows 11 Görev Yöneticisi Kayıt Defterini anlık takip etmez, önbellekte tutar.
                # Kayıt defterinde suni (sahte) bir değişiklik yapıp silerek Windows'un önbelleğini
                # zorla yenilemesini (Invalidate) sağlıyoruz. Böylece anında senkronize oluyor.
                try {
                    Set-ItemProperty -Path $item.RegPath -Name "GeminiCacheBuster" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $item.RegPath -Name "GeminiCacheBuster" -Force -ErrorAction SilentlyContinue
                } catch {}
            }
            elseif ($item.Source -eq "Task") {
                if ($item.IsEnabled) { Disable-ScheduledTask -TaskName $item.Name -TaskPath $item.RegPath -ErrorAction Stop | Out-Null }
                else { Enable-ScheduledTask -TaskName $item.Name -TaskPath $item.RegPath -ErrorAction Stop | Out-Null }
            }
            
            # Tabloyu güncelle
            $item.IsEnabled = -not $item.IsEnabled
            $item.StatusColor = if ($item.IsEnabled) { "#00CC00" } else { "#FF3333" }
            $item.StatusText = if ($item.IsEnabled) { "Açık" } else { "Kapalı" }
            $lvStartup.Items.Refresh() 
            
            WpfLog "[BAŞLANGIÇ/GÖREV] Senkronize edildi: $($item.Name)"
        } catch { [System.Windows.MessageBox]::Show("Erişim reddedildi. Yönetici hakları gerekebilir.`nHata: $($_.Exception.Message)", "Hata") | Out-Null }
    }
})

# Sağ Tık: KALICI SİL
$ctxDeleteStartup.Add_Click({
    if ($lvStartup.SelectedItem) {
        $item = $lvStartup.SelectedItem
        if ([System.Windows.MessageBox]::Show("'$($item.Name)' KALICI OLARAK SİLİNECEK! Emin misiniz?", "Sil", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -eq 'Yes') {
            try {
                if ($item.Source -eq "Registry") { 
                    Remove-ItemProperty -Path $item.RegPath -Name $item.RawName -Force -ErrorAction SilentlyContinue 
                    Remove-ItemProperty -Path $item.ApprPath -Name $item.RawName -Force -ErrorAction SilentlyContinue 
                }
                elseif ($item.Source -eq "Folder") { 
                    Remove-Item -Path $item.Path -Force -ErrorAction SilentlyContinue 
                    Remove-ItemProperty -Path $item.ApprPath -Name $item.RawName -Force -ErrorAction SilentlyContinue 
                }
                elseif ($item.Source -eq "Task") { Unregister-ScheduledTask -TaskName $item.Name -TaskPath $item.RegPath -Confirm:$false -ErrorAction Stop }
                
                $lvStartup.Items.Remove($item) | Out-Null
                WpfLog "🗑️ [SİLİNDİ] $($item.Name)"
            } catch { [System.Windows.MessageBox]::Show("Silinemedi!", "Hata") | Out-Null }
        }
    }
})

# Sağ Tık: DOSYA KONUMUNU AÇ (API İLE KESİN SEÇİM)
$ctxOpenStartupLoc.Add_Click({
    if ($lvStartup.SelectedItem) {
        $path = $lvStartup.SelectedItem.Path
        $path = [Environment]::ExpandEnvironmentVariables($path)
        if ($path -match '^"([^"]+)"' -or $path -match '^([^\s]+\.exe)') { $path = $Matches[1] }
        
        if (Test-Path $path) { 
            [FileSelector]::Select($path)
        }
        else { 
            [System.Windows.MessageBox]::Show("Dosya bulunamadı: $path", "Hata") | Out-Null 
        }
    }
})

# Sağ Tık: DOSYA YOLUNU KOPYALA (YENİ)
$ctxCopyStartupPath.Add_Click({
    if ($lvStartup.SelectedItem) {
        $path = $lvStartup.SelectedItem.Path
        
        # Yolu temizle ve gerçek dosya yolunu al
        $path = [Environment]::ExpandEnvironmentVariables($path)
        if ($path -match '^"([^"]+)"' -or $path -match '^([^\s]+\.exe)') { $path = $Matches[1] }
        
        if ($path) {
            # Panoya kopyala
            [System.Windows.Clipboard]::SetText($path)
            WpfLog "📋 [KOPYALANDI] Dosya Yolu: $path"
        } else {
            [System.Windows.MessageBox]::Show("Kopyalanacak geçerli bir yol bulunamadı.", "Hata") | Out-Null
        }
    }
})

# Sağ Tık: REGISTRY'DE (VEYA GÖREV ZAMANLAYICIDA) AÇ
$ctxOpenStartupReg.Add_Click({
    $item = $lvStartup.SelectedItem
    if ($item) {
        if ($item.Source -eq "Registry" -or $item.Source -eq "UWP") {
            $key = $item.RegPath -replace "^.*::", ""
            $key = $key -replace "^HKCU:\\?", "HKEY_CURRENT_USER\" -replace "^HKLM:\\?", "HKEY_LOCAL_MACHINE\"
            $key = $key -replace "\\+", "\"
            $key = $key.TrimEnd('\')
            
            $regApplet = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit"
            $currentLast = (Get-ItemProperty -Path $regApplet -Name "LastKey" -ErrorAction SilentlyContinue).LastKey
            
            $rootName = "Bilgisayar" 
            if ($currentLast -and $currentLast -match "^([^\\]+)\\") {
                $rootName = $Matches[1] 
            }
            
            $fullKey = "$rootName\$key"
            
            try {
                Stop-Process -Name regedit -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 200
                
                Set-ItemProperty -Path $regApplet -Name "LastKey" -Value $fullKey -Type String -Force -ErrorAction Stop
                Start-Process regedit
            } catch {
                WpfLog "❌ HATA: Kayıt defteri konumu açılamadı. ($($_.Exception.Message))"
            }
        } 
        elseif ($item.Source -eq "Task") {
            Start-Process taskschd.msc
        } 
        else {
            [System.Windows.MessageBox]::Show("Bu öğe için özel bir pencere desteklenmiyor.", "Bilgi") | Out-Null 
        }
    }
})

# --- SAĞ TIK VE MENÜ OLAYLARI (GÜNCELLENDİ) ---
# Artık $Win.FindName(...) yerine doğrudan yukarıda tanımladığımız değişkenleri kullanıyoruz.

if ($ctxOpenLocation) {
    $ctxOpenLocation.Add_Click({
        $treeItem = $this.Parent.PlacementTarget
        if ($treeItem -and $treeItem.Tag -match '^WINAPP2:(.*)') {
            $appName = $Matches[1]
            $rules = if ($global:PathOverrides.ContainsKey($appName)) { $global:PathOverrides[$appName] } else { $global:Winapp2Rules[$appName] }
            
            if ($rules) { 
                foreach ($r in $rules) { 
                    # Karmaşık yol çözümleme
                    $raw = ($r -split '\|')[0]
                    $exp = [Environment]::ExpandEnvironmentVariables($raw)
                    
                    # Yıldız (*) varsa üst klasörü aç, yoksa direkt dosyayı/klasörü seç
                    if ($exp.Contains("*")) { 
                        $parentPath = $exp.Substring(0, $exp.IndexOf("*"))
                        if (Test-Path $parentPath) { Invoke-Item $parentPath }
                    } 
                    else {
                        if (Test-Path $exp) { 
                            [FileSelector]::Select($exp) 
                            break 
                        }
                    }
                } 
            }
        }
    })
}

if ($ctxEditTweak) {
    $ctxEditTweak.Add_Click({ Show-TweakManager -TargetTweak $this.Parent.PlacementTarget.Tag })
}

if ($ctxIgnoreApp) {
    $ctxIgnoreApp.Add_Click({
        $treeItem = $this.Parent.PlacementTarget
        if ($treeItem -and $treeItem.Tag -match '^WINAPP2:(.*)') {
            $global:Blacklist += $Matches[1]; Mark-ConfigDirty; $treeItem.Parent.Items.Remove($treeItem); WpfLog "[GİZLENDİ] $($Matches[1]) listeden gizlendi."
        }
    })
}

if ($ctxEditPaths) {
    $ctxEditPaths.Add_Click({
        $treeItem = $this.Parent.PlacementTarget
        if ($treeItem -and $treeItem.Tag -match '^WINAPP2:(.*)') {
            $appName = $Matches[1]
            try {
                $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlPathEdit); $winEdit = [Windows.Markup.XamlReader]::Load($reader)
                $txtRules = $winEdit.FindName('txtRules'); $lblApp = $winEdit.FindName('lblAppName'); $btnSave = $winEdit.FindName('btnSaveRules'); $btnReset = $winEdit.FindName('btnResetRules'); $btnClose = $winEdit.FindName('btnCloseEdit')
                $lblApp.Text = "Düzenleniyor: $appName"; $curr = @(); if ($global:PathOverrides.ContainsKey($appName)) { $curr = $global:PathOverrides[$appName] } elseif ($global:Winapp2Rules.ContainsKey($appName)) { $curr = $global:Winapp2Rules[$appName] }; $txtRules.Text = ($curr -join "`r`n")
                $btnSave.Add_Click({ $newRules = $txtRules.Text -split "`r`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }; $global:PathOverrides[$appName] = $newRules; Mark-ConfigDirty; WpfLog "[AYAR] $appName yolları güncellendi."; $winEdit.Close() })
                $btnReset.Add_Click({ if ($global:PathOverrides.ContainsKey($appName)) { $global:PathOverrides.Remove($appName); Mark-ConfigDirty }; $winEdit.Close() })
                $btnClose.Add_Click({ $winEdit.Close() }); $winEdit.ShowDialog() | Out-Null
            } catch {}
        }
    })
}

if ($ctxDeleteCustomRule) {
    $ctxDeleteCustomRule.Add_Click({
        $treeItem = $this.Parent.PlacementTarget
        if ($treeItem) {
            $name = (Get-CheckFromItem $treeItem).Content.ToString(); $global:CustomRules = $global:CustomRules | Where-Object { $_.Name -ne $name }; $treeItem.Parent.Items.Remove($treeItem); Mark-ConfigDirty; WpfLog "[SİLİNDİ] Özel kural: $name"
        }
    })
}

if ($ctxOpenReg) {
    $ctxOpenReg.Add_Click({
        $tweak = $this.Parent.PlacementTarget.Tag
        if ($tweak.Key) {
            $key = $tweak.Key -replace "^.*::", ""
            $key = $key -replace "^HKCU:\\?", "HKEY_CURRENT_USER\" -replace "^HKLM:\\?", "HKEY_LOCAL_MACHINE\"
            $key = $key -replace "\\+", "\"
            $key = $key.TrimEnd('\')
            
            $regApplet = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit"
            $currentLast = (Get-ItemProperty -Path $regApplet -Name "LastKey" -ErrorAction SilentlyContinue).LastKey
            
            $rootName = "Bilgisayar"
            if ($currentLast -and $currentLast -match "^([^\\]+)\\") {
                $rootName = $Matches[1]
            }
            
            $fullKey = "$rootName\$key"
            
            try {
                Stop-Process -Name regedit -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 200

                Set-ItemProperty -Path $regApplet -Name "LastKey" -Value $fullKey -Type String -Force -ErrorAction Stop
                Start-Process regedit
            } catch {
                WpfLog "❌ HATA: Kayıt defteri konumu açılamadı. ($($_.Exception.Message))"
            }
        } else {[System.Windows.MessageBox]::Show("Bu bir Registry ayarı değil.", "Bilgi") | Out-Null
        }
    })
}

if ($ctxDelTweak) {
    $ctxDelTweak.Add_Click({
        $tweak = $this.Parent.PlacementTarget.Tag
        if ([System.Windows.MessageBox]::Show("'$($tweak.Name)' silinsin mi?", "Sil", [System.Windows.MessageBoxButton]::YesNo) -eq 'Yes') {
            foreach ($cat in $global:TweakList.Keys) { if ($global:TweakList[$cat].Name -contains $tweak.Name) { $arr = [System.Collections.ArrayList]$global:TweakList[$cat]; $arr.Remove($tweak); $global:TweakList[$cat] = $arr.ToArray(); break } }
            Mark-ConfigDirty; Load-Tweak-Tree
        }
    })
}

if ($ctxForceClean) {
    $ctxForceClean.Add_Click({
        $treeItem = $this.Parent.PlacementTarget
        
        # Sadece Winapp2 öğelerinde çalışır
        if ($treeItem -and $treeItem.Tag -match '^WINAPP2:(.*)') {
            $appName = $Matches[1]
            
            $msg = "DİKKAT: '$appName' için tanımlı olan tüm veriler (Dosyalar, Klasörler, Kayıt Defteri girdileri) analiz edilmeden KALICI OLARAK silinecek.`n`nBu işlem, programı tamamen kaldırmaz ancak tüm ayarlarını ve kalıntılarını yok eder.`n`nEmin misiniz?"
            if ([System.Windows.MessageBox]::Show($msg, "Kritik Temizlik", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -eq 'Yes') {
                
                WpfLog "--- ZORLA TEMİZLİK: $appName ---"
                
                $rules = $global:Winapp2Rules[$appName] 
                
                if ($rules) {
                    $deletedCount = 0
                    $foldersToDelete = @()

                    # 1. STANDART DOSYA TEMİZLİĞİ
                    foreach ($rule in $rules) {
                        $deletedCount += Resolve-ComplexPath $rule -CalculateSizeOnly $false
                        
                        # --- 2. AGRESİF KLASÖR AVCISI (ANA KLASÖRÜ BULMA) ---
                        $rawPath = ($rule -split '\|')[0]
                        $expPath = [Environment]::ExpandEnvironmentVariables($rawPath)
                        
                        if ($expPath -match '\*|\?') {
                            $idx = $expPath.IndexOfAny(@('*', '?'))
                            $beforeWildcard = $expPath.Substring(0, $idx)
                            $expPath = Split-Path $beforeWildcard -Parent -ErrorAction SilentlyContinue
                        }

                        if (-not [string]::IsNullOrWhiteSpace($expPath) -and $expPath.Length -gt 5) {
                            $expPath = $expPath.TrimEnd('\')
                            
                            # GÜVENLİK KALKANI
                            $isSafeRoot = $false
                            $safeRoots = @(
                                [Environment]::GetFolderPath('ApplicationData'),
                                [Environment]::GetFolderPath('LocalApplicationData'),
                                [Environment]::GetFolderPath('ProgramFiles'),
                                [Environment]::GetFolderPath('ProgramFilesX86'),
                                [Environment]::GetFolderPath('Windows'),
                                [Environment]::GetFolderPath('System'),
                                [Environment]::ExpandEnvironmentVariables("%PUBLIC%"),
                                [Environment]::ExpandEnvironmentVariables("%USERPROFILE%"),
                                "C:", "C:\", "D:", "D:\"
                            )
                            
                            foreach ($root in $safeRoots) {
                                if ($expPath -eq $root) { $isSafeRoot = $true; break }
                            }
                            
                            if (-not $isSafeRoot) { $foldersToDelete += $expPath }
                        }
                    }

                    # --- 3. KLASÖRLERİ KÖKTEN SİL ---
                    $foldersToDelete = $foldersToDelete | Sort-Object Length | Select-Object -Unique
                    
                    foreach ($fol in $foldersToDelete) {
                        if (Test-Path $fol) {
                            try {
                                Remove-Item -Path $fol -Recurse -Force -ErrorAction SilentlyContinue
                                WpfLog "💥 [KÖKTEN SİLİNDİ] Ana Klasör: $fol"
                                $deletedCount++
                            } catch {}
                        }
                    }

                    WpfLog "✅ $appName kalıntıları tamamen yok edildi. ($deletedCount işlem)"
                    
                    # --- 4. ARAYÜZDEN ANINDA SİL (BUHARLAŞTIR) ---
                    $Win.Dispatcher.Invoke([action]{
                        $parent = $treeItem.Parent
                        if ($parent) {
                            # Seçili uygulamayı listeden sil
                            $parent.Items.Remove($treeItem) | Out-Null
                            
                            # Eğer ana grupta (Örn: "Microsoft" grubunda) başka uygulama kalmadıysa, klasör başlığını da sil!
                            if ($parent -is [System.Windows.Controls.TreeViewItem] -and $parent.Items.Count -eq 0) {
                                $grandParent = $parent.Parent
                                if ($grandParent) {
                                    $grandParent.Items.Remove($parent) | Out-Null
                                }
                            }
                        }
                    })

                    [System.Windows.MessageBox]::Show("$appName kalıntıları tamamen temizlendi ve listeden kaldırıldı.", "Bilgi") | Out-Null
                } else {
                    WpfLog "[HATA] Kural bulunamadı."
                }
            }
        }
    })
}

# =========================================================
# AÇIKLAMA / İPUCU (TOOLTIP) EDİTÖRÜ SİSTEMİ
# =========================================================
$script:EditDescriptionBlock = {
    $treeItem = $this.Parent.PlacementTarget
    if (-not $treeItem) { return }

    $chk = Get-CheckFromItem $treeItem
    if (-not $chk) { return }
    
    # StackPanel/string content uyumlu shim ile gercek goruntulenen ad'i al
    $itemName = Get-TweakDisplayName $treeItem
    if ([string]::IsNullOrEmpty($itemName)) { $itemName = "$($chk.Content)" }
    $cleanName = $itemName -replace " \(Aktif\)$", "" -replace " \(Yüklü\)$", ""

    $currentDesc = ""
    if ($global:ItemDescriptions.ContainsKey($cleanName)) { $currentDesc = $global:ItemDescriptions[$cleanName] }

    $xamlDesc = @"
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Title="Açıklama Düzenle" Height="250" Width="400" 
            Background="#181818" WindowStartupLocation="CenterScreen" WindowStyle="ToolWindow" ResizeMode="NoResize">
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Text="Seçilen: $cleanName" Foreground="#E68A00" FontWeight="Bold" Margin="0,0,0,10" TextTrimming="CharacterEllipsis"/>
            <TextBox x:Name="txtDesc" Grid.Row="1" Background="#222" Foreground="#4CC2FF" FontSize="13" TextWrapping="Wrap" AcceptsReturn="True" Padding="5" BorderBrush="#444"/>
            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                <Button x:Name="btnDelete" Content="Sil" Background="#A00" Foreground="White" Width="60" Height="30" Margin="0,0,10,0" ToolTip="Açıklamayı tamamen kaldırır."/>
                <Button x:Name="btnSave" Content="Kaydet" Background="#006600" Foreground="White" Width="80" Height="30"/>
            </StackPanel>
        </Grid>
    </Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlDesc)
    $winDesc = [Windows.Markup.XamlReader]::Load($reader)
    
    $txtD = $winDesc.FindName('txtDesc')
    $btnS = $winDesc.FindName('btnSave')
    $btnDel = $winDesc.FindName('btnDelete')
    
    $txtD.Text = $currentDesc

    $btnS.Add_Click({
        $newTxt = $txtD.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($newTxt)) {
            $global:ItemDescriptions.Remove($cleanName)
            Attach-ToolTip $chk "" 
        } else {
            $global:ItemDescriptions[$cleanName] = $newTxt
            Attach-ToolTip $chk $newTxt 
        }
        Mark-ConfigDirty
        $winDesc.Close()
    })
    
    $btnDel.Add_Click({
        $global:ItemDescriptions.Remove($cleanName)
        Attach-ToolTip $chk ""
        Mark-ConfigDirty
        $winDesc.Close()
    })

    $winDesc.ShowDialog() | Out-Null
}

$menuNames = @("TweakItemMenu", "ItemMenu", "CustomItemMenu")
foreach ($mName in $menuNames) {
    $menu = $Win.Resources[$mName]
    if ($menu) {
        $sep = New-Object System.Windows.Controls.Separator
        $menu.Items.Insert(0, $sep)
        
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = "📝 Açıklama / İpucu Düzenle"
        $mi.Foreground =[System.Windows.Media.Brushes]::Orange
        $mi.FontWeight = "Bold"
        $mi.Add_Click($script:EditDescriptionBlock.GetNewClosure())
        
        $menu.Items.Insert(0, $mi)
    }
}

# --- ARAMA KUTUSU ---
$txtSearch.Add_GotFocus({ if ($txtSearch.Text -eq "Uygulama Ara...") { $txtSearch.Text = ""; $txtSearch.Foreground = [System.Windows.Media.Brushes]::White } })
$txtSearch.Add_LostFocus({ if ($txtSearch.Text -eq "") { $txtSearch.Text = "Uygulama Ara..."; $txtSearch.Foreground = [System.Windows.Media.Brushes]::Gray } })
# --- GELİŞMİŞ ARAMA MOTORU (RECURSIVE) ---
# --- SEARCH DEBOUNCE TIMER (Sprint 4.1) ---
# Her tus basiminda taramak yerine 250ms bekleme — UI rahat
$script:SearchDebounceTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:SearchDebounceTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$script:SearchDebounceTimer.Add_Tick({
    $script:SearchDebounceTimer.Stop()
    $filter = $txtSearch.Text.Trim()

    # GENISLETILMIS arama: Header + Registry Key + Aciklama (ItemDescriptions)
    function Filter-Nodes($nodes, $text) {
        $nodeHasMatch = $false
        foreach ($item in $nodes) {
            # 1) Header (checkbox icerigi veya raw header)
            $headerText = Get-TweakDisplayName $item
            if ([string]::IsNullOrEmpty($headerText)) {
                $headerText = if (Get-CheckFromItem $item) { (Get-CheckFromItem $item).Content.ToString() } else { $item.Header.ToString() }
            }

            # 2) Tweak ise Key/ValueName/Group da ara
            $tweakBlob = ""
            if ($item.Tag -is [System.Collections.IDictionary] -or $item.Tag -is [System.Management.Automation.PSCustomObject]) {
                $t = $item.Tag
                if ($t.Name)        { $tweakBlob += " " + $t.Name }
                if ($t.Key)         { $tweakBlob += " " + $t.Key }
                if ($t.ValueName)   { $tweakBlob += " " + $t.ValueName }
                if ($t.Group)       { $tweakBlob += " " + $t.Group }
                if ($t.SubCategory) { $tweakBlob += " " + $t.SubCategory }
                if ($t.Description) { $tweakBlob += " " + $t.Description }
            }

            # 3) ItemDescriptions kullaniciya ozel aciklamalar (sadece suffix'leri temizle — Risk dot ayri Ellipse, text'te yok)
            $cleanName = $headerText -replace " \(Aktif\)$", "" -replace " \(Yüklü\)$", ""
            if ($global:ItemDescriptions.ContainsKey($cleanName)) {
                $tweakBlob += " " + $global:ItemDescriptions[$cleanName]
            }

            $allText = "$headerText $tweakBlob"
            try {
                $isDirectMatch = ($allText -match [regex]::Escape($text))
            } catch {
                $isDirectMatch = $allText.ToLower().Contains($text.ToLower())
            }

            $childMatch = $false
            if ($item.Items.Count -gt 0) { $childMatch = Filter-Nodes $item.Items $text }

            if ($isDirectMatch -or $childMatch) {
                $item.Visibility = 'Visible'
                if (-not [string]::IsNullOrWhiteSpace($text)) { $item.IsExpanded = $true }
                $nodeHasMatch = $true
            } else {
                $item.Visibility = 'Collapsed'
            }
        }
        return $nodeHasMatch
    }

    function Reset-Nodes($nodes) {
        foreach ($item in $nodes) {
            $item.Visibility = 'Visible'
            if ($item.Items.Count -gt 0) { Reset-Nodes $item.Items }
        }
    }

    $targets = @($tvBrowser, $tvApps, $tvTweaks, $tvSystem, $tvRepair, $tvShellBags, $tvWinget)
    if (-not [string]::IsNullOrWhiteSpace($filter) -and $filter -ne "Uygulama Ara...") {
        foreach ($tree in $targets) {
            if ($tree -and $tree.Items.Count -gt 0) { Filter-Nodes $tree.Items $filter | Out-Null }
        }
    } else {
        foreach ($tree in $targets) {
            if ($tree -and $tree.Items.Count -gt 0) { Reset-Nodes $tree.Items }
        }
    }
})

$txtSearch.Add_TextChanged({
    # Debounce: timer'i yeniden baslat — son tustan 250ms sonra tara
    $script:SearchDebounceTimer.Stop()
    $script:SearchDebounceTimer.Start()
})

# --- 5. OLAY BAĞLAYICILARI (EVENTS) ---
$btnBloatware.Add_Click({ Show-BloatwareManager })

# =========================================================
# PROCESS WATCHER — CANLI PROCESS İZLEYİCİ
# =========================================================

# ComboBox değişince "Diğer" seçilmişse manuel giriş kutusu göster
# Yardımcı: ComboBox'ı çalışan process'lerle doldur

$cbWatchProcess.Add_DropDownOpened({ Fill-WatcherComboBox $cbWatchProcess $cbWatchProcess2 })
$cbWatchProcess2.Add_DropDownOpened({ Fill-WatcherComboBox $cbWatchProcess2 $cbWatchProcess })

$cbWatchProcess2.Add_SelectionChanged({
    if ($cbWatchProcess2.SelectedItem -and $cbWatchProcess2.SelectedItem.Tag -eq "custom") {
        $txtWatchCustom.Visibility = "Visible"
    } else {
        $txtWatchCustom.Visibility = "Collapsed"
    }
})

# Tek process izleyen runspace scripti (her ikisi için ortak)
$watcherScript = {
    param($pname, $logFile)
    $ErrorActionPreference = 'SilentlyContinue'

    function WriteLog($m) {
        $line = "$(Get-Date -Format 'HH:mm:ss.fff')|$m"
        Add-Content $logFile $line -Encoding UTF8
    }

    $deadline = (Get-Date).AddMinutes(30)
    $proc = $null
    while ((Get-Date) -lt $deadline) {
        $proc = Get-Process -Name $pname -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc) { break }
        Start-Sleep -Milliseconds 400
    }

    if (-not $proc) { WriteLog "TIMEOUT"; return }

    WriteLog "STARTED|$($proc.Id)"
    try { $proc.WaitForExit() } catch {}

    $exitCode = $null
    try { $exitCode = $proc.ExitCode } catch {}
    $exitHex = if ($null -ne $exitCode) { "0x{0:X8}" -f [uint32]$exitCode } else { "?" }
    WriteLog "ENDED|$exitHex"

    $desc = switch ([uint32]$exitCode) {
        0          { "✅ Temiz kapanma (Exit 0) — menüden çıkış, sunucu kicki veya normal sonlanma." }
        1          { "⚠️ Genel hata (Exit 1) — detay kaydedilmedi." }
        0xC0000005 { "💥 ACCESS VIOLATION — geçersiz bellek erişimi. RAM veya bozuk oyun dosyası." }
        0xC0000094 { "💥 INTEGER DIVIDE BY ZERO." }
        0xC000013A { "ℹ️ Ctrl+C / Konsol kapatma sinyali." }
        0xC0000142 { "💥 DLL başlatılamadı — Visual C++ veya DirectX eksik/bozuk." }
        0xC06D007E { "💥 DLL bulunamadı." }
        0xE0434352 { "💥 .NET Runtime hatası." }
        0xDEAD0010 { "🛡️ EA Anti-Cheat tarafından sonlandırıldı (0xDEAD0010)." }
        0x40010004 { "🛡️ Anti-Cheat debugger tespiti (0x40010004)." }
        default    {
            if ($null -eq $exitCode) { "❓ Exit code alınamadı — TerminateProcess ile zorla kapatıldı." }
            else { "❓ Bilinmeyen exit code: $exitHex" }
        }
    }
    WriteLog "DESC|$desc"
}

$btnWatchStart.Add_Click({
    # Process isimlerini belirle
    $p1 = if ($cbWatchProcess.SelectedItem -and $cbWatchProcess.SelectedItem.Tag -notin @("none","custom")) { $cbWatchProcess.SelectedItem.Tag } else { $null }
    $p2 = if ($cbWatchProcess2.SelectedItem -and $cbWatchProcess2.SelectedItem.Tag -eq "custom") {
                $txtWatchCustom.Text.Trim() -replace '\.exe$',''
          } elseif ($cbWatchProcess2.SelectedItem -and $cbWatchProcess2.SelectedItem.Tag -notin @("none","custom")) {
                $cbWatchProcess2.SelectedItem.Tag
          } else { $null }

    if (-not $p1 -and -not $p2) {
        WpfLog "❌ En az bir process seçin."
        return
    }

    # Önceki watcher'ları temizle
    foreach ($t in @($script:WatcherTimer)) {
        if ($t -and $t.IsEnabled) { $t.Stop() }
    }
    foreach ($r in @($script:WatcherRunspace, $script:WatcherRunspace2)) {
        if ($r) { try { $r.Dispose() } catch {} }
    }

    $script:WatcherLog1 = "$env:TEMP\Gemini_W1.txt"
    $script:WatcherLog2 = "$env:TEMP\Gemini_W2.txt"
    Remove-Item $script:WatcherLog1,$script:WatcherLog2 -Force -ErrorAction SilentlyContinue

    $script:WP1 = $p1; $script:WP2 = $p2
    $script:WS1 = "waiting"; $script:WS2 = if ($p2) { "waiting" } else { "none" }
    $script:WEnd1 = $null; $script:WEnd2 = $null

    $btnWatchStart.IsEnabled = $false
    $btnWatchStop.IsEnabled = $true

    $pLabel = @(); if ($p1) { $pLabel += "$p1.exe" }; if ($p2) { $pLabel += "$p2.exe" }
    $txtWatchStatus.Text = "⏳ Bekleniyor: $($pLabel -join ' + ')"
    $txtWatchStatus.Foreground = [System.Windows.Media.Brushes]::Yellow
    WpfLog "🎯 Process İzleyici başlatıldı: $($pLabel -join ' + ')"

    # Runspace 1
    if ($p1) {
        $script:WatcherRunspace = [powershell]::Create()
        $script:WatcherRunspace.AddScript($watcherScript) | Out-Null
        $script:WatcherRunspace.AddArgument($p1) | Out-Null
        $script:WatcherRunspace.AddArgument($script:WatcherLog1) | Out-Null
        $script:WatcherAsync = $script:WatcherRunspace.BeginInvoke()
    }

    # Runspace 2
    if ($p2) {
        $script:WatcherRunspace2 = [powershell]::Create()
        $script:WatcherRunspace2.AddScript($watcherScript) | Out-Null
        $script:WatcherRunspace2.AddArgument($p2) | Out-Null
        $script:WatcherRunspace2.AddArgument($script:WatcherLog2) | Out-Null
        $script:WatcherAsync2 = $script:WatcherRunspace2.BeginInvoke()
    }

    # UI Timer
    $script:WatcherTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:WatcherTimer.Interval = [TimeSpan]::FromMilliseconds(400)
    $script:WatcherTimer.Add_Tick({

        # Log okuyucu yardımcı
        function Read-WLog($logFile) {
            if (Test-Path $logFile) { return Get-Content $logFile -ErrorAction SilentlyContinue }
            return @()
        }

        # Her iki process için durumu güncelle
        foreach ($idx in @(1,2)) {
            $pname  = if ($idx -eq 1) { $script:WP1 } else { $script:WP2 }
            $state  = if ($idx -eq 1) { $script:WS1 } else { $script:WS2 }
            $logF   = if ($idx -eq 1) { $script:WatcherLog1 } else { $script:WatcherLog2 }
            $async  = if ($idx -eq 1) { $script:WatcherAsync } else { $script:WatcherAsync2 }

            if ($state -eq "none" -or $state -eq "done") { continue }

            $lines = Read-WLog $logF
            foreach ($line in $lines) {
                if ($state -eq "waiting" -and $line -match '\|STARTED\|(\d+)') {
                    if ($idx -eq 1) { $script:WS1 = "running" } else { $script:WS2 = "running" }
                    WpfLog "🟢 [$pname] yakalandı (PID $($Matches[1]))"
                }
                if ($state -eq "running" -and $line -match '\|TIMEOUT') {
                    if ($idx -eq 1) { $script:WS1 = "done" } else { $script:WS2 = "done" }
                    WpfLog "⏰ [$pname] 30 dakikada başlamadı."
                }
            }

            # Bitti mi?
            if ($async -and $async.IsCompleted -and (if ($idx -eq 1) {$script:WS1} else {$script:WS2}) -eq "running") {
                if ($idx -eq 1) { $script:WS1 = "done"; $script:WEnd1 = Get-Date }
                else             { $script:WS2 = "done"; $script:WEnd2 = Get-Date }

                $allLines = Read-WLog $logF
                $exitHex = "?"; $desc = "Açıklama alınamadı."
                foreach ($l in $allLines) {
                    if ($l -match '\|ENDED\|(.+)') { $exitHex = $Matches[1] }
                    if ($l -match '\|DESC\|(.+)')  { $desc = $Matches[1] }
                }

                $color = if ($exitHex -eq "0x00000000") { "#00CC00" }
                         elseif ($desc -match "Anti-Cheat|DEAD|0xDEAD") { "#FF8C00" }
                         else { "#FF5555" }

                $uiObj = [PSCustomObject]@{
                    Time = (Get-Date).ToString("HH:mm:ss")
                    Category = "🎯 Process İzleyici"
                    Color = $color
                    FaultingModule = "$pname.exe ($exitHex)"
                    Description = $desc
                    RawMessage = ($allLines -join "`n")
                    DumpPath = ""
                }
                $lvCrashes.Items.Insert(0, $uiObj) | Out-Null
                WpfLog "🎯 [$pname] kapandı → $exitHex | $desc"
            }
        }

        # Her ikisi de bittiyse — hangisi önce kapandı?
        $both1 = $script:WS1 -in @("done","none")
        $both2 = $script:WS2 -in @("done","none")

        if ($both1 -and $both2) {
            $script:WatcherTimer.Stop()
            $btnWatchStart.IsEnabled = $true
            $btnWatchStop.IsEnabled = $false

            # Kapanma sırası analizi
            if ($script:WEnd1 -and $script:WEnd2) {
                $diff = [Math]::Round(($script:WEnd2 - $script:WEnd1).TotalMilliseconds)
                if ($diff -lt 0) {
                    $first = $script:WP2; $second = $script:WP1; $diffAbs = [Math]::Abs($diff)
                } else {
                    $first = $script:WP1; $second = $script:WP2; $diffAbs = $diff
                }

                $verdict = ""
                if ($diffAbs -lt 500) {
                    $verdict = "⚡ İkisi neredeyse aynı anda kapandı ($diffAbs ms fark) — dışarıdan bir şey (GPU driver, kernel) ikisini birden öldürdü olabilir."
                } elseif ($first -match 'AntiCheat|EAAnti|eac') {
                    $verdict = "🛡️ ÖNCE Anti-Cheat kapandı ($diffAbs ms önce) → Anti-Cheat oyunu sonlandırdı."
                } elseif ($second -match 'AntiCheat|EAAnti|eac') {
                    $verdict = "🎮 ÖNCE oyun kapandı ($diffAbs ms önce) → Oyun kendi çöktü, Anti-Cheat sonra temizlendi."
                } else {
                    $verdict = "🔍 $first önce kapandı ($diffAbs ms fark)."
                }

                $orderObj = [PSCustomObject]@{
                    Time = (Get-Date).ToString("HH:mm:ss")
                    Category = "⚖️ Kapanma Sırası"
                    Color = "#FFD700"
                    FaultingModule = "$first → $second"
                    Description = $verdict
                    RawMessage = $verdict
                    DumpPath = ""
                }
                $lvCrashes.Items.Insert(0, $orderObj) | Out-Null
                WpfLog "⚖️ $verdict"
            }

            $txtWatchStatus.Text = "✅ İzleme tamamlandı. Sonuçlar tabloya eklendi."
            $txtWatchStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
            try { if ($script:WatcherRunspace)  { $script:WatcherRunspace.Dispose()  } } catch {}
            try { if ($script:WatcherRunspace2) { $script:WatcherRunspace2.Dispose() } } catch {}
        } else {
            # Durum güncelle
            $parts = @()
            if ($script:WP1) { $parts += "$(if($script:WS1 -eq 'running'){'🟢'} elseif($script:WS1 -eq 'done'){'✅'} else {'⏳'}) $($script:WP1).exe" }
            if ($script:WP2) { $parts += "$(if($script:WS2 -eq 'running'){'🟢'} elseif($script:WS2 -eq 'done'){'✅'} else {'⏳'}) $($script:WP2).exe" }
            $txtWatchStatus.Text = $parts -join "   |   "
            $txtWatchStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
        }

    }.GetNewClosure())
    $script:WatcherTimer.Start()
})

$btnWatchStop.Add_Click({
    if ($script:WatcherTimer -and $script:WatcherTimer.IsEnabled) { $script:WatcherTimer.Stop() }
    foreach ($r in @($script:WatcherRunspace, $script:WatcherRunspace2)) {
        if ($r) { try { $r.Dispose() } catch {} }
    }
    $txtWatchStatus.Text = "İzleme durduruldu."
    $txtWatchStatus.Foreground = [System.Windows.Media.Brushes]::Gray
    $btnWatchStart.IsEnabled = $true
    $btnWatchStop.IsEnabled = $false
    WpfLog "⏹ Process İzleyici durduruldu."
})

# --- DEDEKTİF (ÇÖKME ANALİZİ) GOD TIER TARAMA MOTORU ---

$btnScanCrashes.Add_Click({
    $btnScanCrashes.IsEnabled = $false
    $btnScanCrashes.Content = "⏳ İNCELENİYOR..."
    $lvCrashes.Items.Clear()
    $pbMain.IsIndeterminate = $true
    WpfLog "--- ÇÖKME ANALİZİ BAŞLATILDI ---"

    $hours = 1
    if ($cbCrashTime.SelectedItem -and $cbCrashTime.SelectedItem.Tag) { $hours = [int]$cbCrashTime.SelectedItem.Tag }
    
    $dumpFolder = "$env:LOCALAPPDATA\CrashDumps"

    # 1. ARKA PLAN İŞÇİSİ
    $script:CrashRunspace = [powershell]::Create()
    $script:CrashRunspace.AddScript({
        param($h, $dumpDir)
        $ErrorActionPreference = 'SilentlyContinue'
        $results = @()
        $startTime = (Get-Date).AddHours(-$h)

        # --- PERFORMANS: TÜM DUMP DOSYALARINI SADECE 1 KERE OKU VE RAM'E AL ---
        $globalDumpCache = New-Object System.Collections.Generic.List[object]
        $searchDirs = @(
            $dumpDir,
            "$env:LOCALAPPDATA\CrashDumps",
            "$env:LOCALAPPDATA\Temp",
            "C:\Windows\Minidump",
            "$env:ProgramData\EA\Logs"
        )
        
        foreach ($dir in $searchDirs) {
            if (Test-Path $dir) {
                $dumps = Get-ChildItem -Path $dir -Filter "*.dmp" -File -ErrorAction SilentlyContinue
                if ($dumps) { $globalDumpCache.AddRange($dumps) }
            }
        }

        # --- YARDIMCI FONKSİYON: RAM'DEKİ LİSTEDEN EŞLEŞTİR (DİSKİ YORMAZ) ---
        function Get-DumpPath($appName, $crashTime) {
            if (-not $appName) { return "" }
            $baseName =[System.IO.Path]::GetFileNameWithoutExtension($appName)
            
            foreach ($d in $globalDumpCache) {
                if ($d.Name -match [regex]::Escape($baseName)) {
                    if ([Math]::Abs(($d.LastWriteTime - $crashTime).TotalMinutes) -le 10) {
                        return $d.FullName
                    }
                }
            }
            return ""
        }

        # --- A) UYGULAMA ÇÖKMELERİ VE DONMALARI (Event ID 1000 ve YENİ 1002) ---
        # (BU SATIRDAN İTİBAREN KODUNUZUN GERİ KALANI AYNI ŞEKİLDE DEVAM EDECEK...)

        # --- A) UYGULAMA ÇÖKMELERİ VE DONMALARI (Event ID 1000 ve YENİ 1002) ---
        $appEvents = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=@(1000, 1002); StartTime=$startTime}
        if ($appEvents) {
            foreach ($e in $appEvents) {
                $msg = $e.Message
                $app = "Bilinmiyor"; $mod = "Bilinmiyor"
                
                # 1000: Klasik Çökme
                if ($e.Id -eq 1000) {
                    if ($msg -match 'Hatalı uygulama adı:\s*([^,]+)') { $app = $Matches[1].Trim() }
                    elseif ($msg -match 'Faulting application name:\s*([^,]+)') { $app = $Matches[1].Trim() }
                    if ($msg -match 'Hatalı modül adı:\s*([^,]+)') { $mod = $Matches[1].Trim() }
                    elseif ($msg -match 'Faulting module name:\s*([^,]+)') { $mod = $Matches[1].Trim() }
                    
                    $cat = "🎮 Uygulama Çökmesi"
                    $color = "#FF5555"
                    
                    $desc = ""
                    if ($mod -match 'ntdll\.dll') { $desc = "Windows çekirdek hatası. Genellikle hatalı RAM frekansı (XMP/EXPO) veya bozuk sistem dosyası kaynaklıdır." }
                    elseif ($mod -match 'KERNELBASE\.dll' -or $mod -match 'kernel32\.dll') { $desc = "Uygulama geçersiz bir işlem yapmaya çalıştı. Sürücü uyuşmazlığı veya yetki sorunu olabilir." }
                    elseif ($mod -match 'd3d11\.dll' -or $mod -match 'dxgi\.dll' -or $mod -match 'd3d12') { $desc = "DirectX (Grafik) hatası. Ekran kartı sürücüsü veya oyunun grafik motoru çöktü." }
                    elseif ($mod -match 'ucrtbase\.dll' -or $mod -match 'VCRUNTIME') { $desc = "Visual C++ kütüphanesi hatası. Oyunun veya programın dosyaları eksik/bozuk olabilir." }
                    elseif ($app -eq $mod) { $desc = "Oyun/Program kendi iç hatasından dolayı çöktü. Dosya bütünlüğünü doğrulayın." }
                    else { $desc = "'$mod' modülü çökmeye sebep oldu. Bu modülün kime ait olduğunu Google'da aratarak suçluyu bulabilirsiniz." }
                    
                    $fullDesc = "Çöken: $app -> $desc"
                } 
                # 1002: Uygulama Donması (Hang)
                else {
                    if ($msg -match 'Program ([^\s]+) version') { $app = $Matches[1].Trim() }
                    elseif ($msg -match 'uygulaması ([^\s]+) sürüm') { $app = $Matches[1].Trim() }
                    
                    $cat = "⏳ Uygulama Donması"
                    $color = "#E68A00"
                    $mod = "Yanıt Vermiyor"
                    $fullDesc = "Donan: $app -> Uygulama Windows ile iletişimi kesti ve yanıt vermeyi durdurdu. Aşırı CPU/Disk kullanımı veya oyun içi bir bug (kilitlenme) sebebiyle oluşur."
                }

                $dmpPath = Get-DumpPath $app $e.TimeCreated
                if ($dmpPath) { $fullDesc += " 💾 [BELLEK DÖKÜMÜ BULUNDU]" }

                $results += @{
                    Time = $e.TimeCreated.ToString("HH:mm:ss")
                    Category = $cat
                    Color = $color
                    FaultingModule = $mod
                    Description = $fullDesc
                    RawMessage = $msg
                    DumpPath = $dmpPath
                    Ticks = $e.TimeCreated.Ticks
                }
            }
        }

        # --- B) GÜÇ VE SİSTEM ÇÖKMELERİ (41, Isınma: 86, 88, 89, 6008) ---
        $pwrEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Id=@(41, 86, 88, 89, 6008); StartTime=$startTime}
        if ($pwrEvents) {
            foreach ($e in $pwrEvents) {
                if ($e.Id -in @(86, 88, 89)) {
                    $cat = "🔥 Aşırı Isınma"; $col = "#FF0000"; $mod = "Termal Kapanma"
                    $desc = "SİSTEM KRİTİK SICAKLIĞA ULAŞTI! Donanımı korumak için bilgisayar zorla kapatıldı. İşlemci (CPU) veya Ekran Kartı (GPU) aşırı ısınmış durumda. Termal macun ve fanları acilen kontrol edin."
                } elseif ($e.Id -eq 6008) {
                    $cat = "⚡ Beklenmeyen Kapanma"; $col = "#E68A00"; $mod = "Güç Kesintisi"
                    $desc = "Sistem daha önce beklenmedik şekilde kapandı. Ani elektrik kesintisi veya kasadaki reset tuşuna basılmış olabilir."
                } else {
                    $cat = "⚡ Kernel-Power"; $col = "#E68A00"; $mod = "Sistem Çökmesi"
                    $desc = "Sistem düzgün kapatılmadan yeniden başlatıldı. PSU (Güç Kaynağı) yetersizliği, donanımsal kısa devre veya Mavi Ekran (BSOD) sebep olmuş olabilir."
                }
                $results += @{ Time = $e.TimeCreated.ToString("HH:mm:ss"); Category = $cat; Color = $col; FaultingModule = $mod; Description = $desc; RawMessage = $e.Message; DumpPath = ""; Ticks = $e.TimeCreated.Ticks }
            }
        }

        # --- C) EKRAN KARTI (GPU) ÇÖKMELERİ ---
        # FIX: 'Display' provider TDR olayları
        $gpuEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Display'; StartTime=$startTime} -ErrorAction SilentlyContinue
        if ($gpuEvents) {
            foreach ($e in $gpuEvents) {
                if ($e.Message -match 'yanıt vermeyi kesti' -or $e.Message -match 'stopped responding') {
                    $results += @{ Time = $e.TimeCreated.ToString("HH:mm:ss"); Category = "🖥️ Grafik Sürücüsü"; Color = "#4CC2FF"; FaultingModule = "GPU Sürücüsü (TDR)"; Description = "Ekran kartı sürücüsü yanıt vermeyi kesti ve sıfırlandı (TDR Hatası). Aşırı Overclock/Undervolt yapılmış olabilir veya grafik sürücüsü hatalı."; RawMessage = $e.Message; DumpPath = ""; Ticks = $e.TimeCreated.Ticks }
                }
            }
        }
        # FIX: GPU sürücüsü olaylarını ProviderName ile doğrudan filtrele (Where-Object yok = çok daha hızlı)
        foreach ($gpuProvider in @('nvlddmkm', 'amdkmdag', 'igfx', 'nvkflt')) {
            $gpuDrvEvents = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName=$gpuProvider; Level=@(1,2,3); StartTime=$startTime} -ErrorAction SilentlyContinue
            if ($gpuDrvEvents) {
                foreach ($e in $gpuDrvEvents) {
                    $results += @{ Time = $e.TimeCreated.ToString("HH:mm:ss"); Category = "🖥️ Ekran Kartı Sürücüsü"; Color = "#4CC2FF"; FaultingModule = $gpuProvider; Description = "GPU sürücüsünde kritik hata tespit edildi ($gpuProvider). VRAM dolmuş, overclock stabil olmayabilir veya sürücü bozuk olabilir."; RawMessage = $e.Message; DumpPath = ""; Ticks = $e.TimeCreated.Ticks }
                }
            }
        }

        # --- D) EA ANTİ-CHEAT / EA DESKTOP LOGLARI (BF6 İÇİN KRİTİK) ---
        # EA Anti-Cheat oyunu TerminateProcess() ile öldürürse WER tetiklenmez, Event Log'a bile düşmez!
        try {
            $eaLogPaths = @(
                "$env:ProgramData\EA\Logs",
                "$env:LOCALAPPDATA\Electronic Arts\EA Desktop\Logs"
            )
            foreach ($eaPath in $eaLogPaths) {
                if (Test-Path $eaPath) {
                    $eaLogs = Get-ChildItem -Path $eaPath -Filter "*.log" -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.LastWriteTime -ge $startTime } |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 5
                    foreach ($logFile in $eaLogs) {
                        $content = Get-Content $logFile.FullName -Tail 50 -ErrorAction SilentlyContinue
                        $errorLines = $content | Where-Object { $_ -match 'error|crash|terminate|killed|fatal|exception' }
                        if ($errorLines) {
                            $errSummary = ($errorLines | Select-Object -First 3) -join " | "
                            $results += @{
                                Time = $logFile.LastWriteTime.ToString("HH:mm:ss")
                                Category = "🛡️ EA Anti-Cheat/Desktop"
                                Color = "#FF8C00"
                                FaultingModule = $logFile.Name
                                Description = "EA bileşeni hata/sonlandırma logu: $errSummary — EA Anti-Cheat oyunu sessizce sonlandırıyor olabilir (WER tetiklenmiyor)."
                                RawMessage = $errSummary
                                DumpPath = ""
                                Ticks = $logFile.LastWriteTime.Ticks
                            }
                        }
                    }
                }
            }
        } catch {}

        # --- E) GİZLİ GÜVENİLİRLİK İZLEYİCİSİ (WMI RELIABILITY) ---
        try {
            $relRecords = Get-CimInstance Win32_ReliabilityRecords -ErrorAction SilentlyContinue | Where-Object { $_.TimeGenerated -ge $startTime }
            foreach ($r in $relRecords) {
                if ($r.EventType -eq 2 -or $r.EventType -eq 1) {
                    # FIX: Anti-duplikasyon — SourceName ile karşılaştır, Description ile değil
                    $isDup = $false
                    foreach ($res in $results) {
                        if ([Math]::Abs(($res.Ticks - $r.TimeGenerated.Ticks) / 10000000) -lt 5 -and $res.FaultingModule -match [regex]::Escape($r.SourceName)) { $isDup = $true; break }
                    }
                    if (-not $isDup) {
                        $results += @{
                            Time = $r.TimeGenerated.ToString("HH:mm:ss")
                            Category = "🕵️ Gizli Çökme (WMI)"
                            Color = "#A020F0"
                            FaultingModule = $r.SourceName
                            Description = "Windows Güvenilirlik İzleyicisi'nden yakalandı: $($r.Message)"
                            RawMessage = $r.Message
                            DumpPath = ""
                            Ticks = $r.TimeGenerated.Ticks
                        }
                    }
                }
            }
        } catch {}

        # Olayları Yeniden Eskiye (Zamana göre) sırala
        return $results | Sort-Object Ticks -Descending
    })
    
    $script:CrashRunspace.AddArgument($hours)
    $script:CrashRunspace.AddArgument($dumpFolder)
    $script:CrashAsync = $script:CrashRunspace.BeginInvoke()

    # 2. ZAMANLAYICI
    $script:CrashTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:CrashTimer.Interval =[TimeSpan]::FromMilliseconds(500)
    
    $script:CrashTimer.Add_Tick({
        if ($script:CrashAsync.IsCompleted) {
            $script:CrashTimer.Stop()
            try {
                $crashes = $script:CrashRunspace.EndInvoke($script:CrashAsync)
                
                if ($crashes -and $crashes.Count -gt 0) {
                    $count = 0
                    foreach ($c in $crashes) {
                        $uiObj = [PSCustomObject]@{
                            Time = $c.Time
                            Category = $c.Category
                            Color = $c.Color
                            FaultingModule = $c.FaultingModule
                            Description = $c.Description
                            RawMessage = $c.RawMessage
                            DumpPath = $c.DumpPath # Menü için gizli veri
                        }
                        $lvCrashes.Items.Add($uiObj) | Out-Null
                        $count++
                    }
                    WpfLog "✅ $count adet hata/çökme tespit edildi ve listelendi."
                } else {
                    WpfLog "ℹ️ Seçilen zaman aralığında hiçbir çökme veya kritik hata bulunamadı!"
                    $emptyObj =[PSCustomObject]@{ Time = "-"; Category = "✔️ Temiz"; Color = "#00CC00"; FaultingModule = "-"; Description = "Seçilen sürede hiçbir çökme günlüğü bulunamadı."; RawMessage = ""; DumpPath = "" }
                    $lvCrashes.Items.Add($emptyObj) | Out-Null
                }
            } catch {
				WpfLog "Hata: $_"
			} finally {
				# Hata çıksa da çıkmasa da Runspace RAM'den %100 silinir!
				if ($script:CrashRunspace) { 
					$script:CrashRunspace.Dispose()
					$script:CrashRunspace = $null 
				}
			}
            
            $btnScanCrashes.IsEnabled = $true
            $btnScanCrashes.Content = "🔍 NE OLDU BUL!"
            $pbMain.IsIndeterminate = $false
        }
    })
    $script:CrashTimer.Start()
})

# --- ÇÖKME TABLOSU SAĞ TIK OLAYLARI ---

$ctxCopyCrash.Add_Click({
    if ($lvCrashes.SelectedItem) {
        $msg = $lvCrashes.SelectedItem.RawMessage
        if ($msg) {
            [System.Windows.Clipboard]::SetText($msg)
            WpfLog "📋 Orijinal hata detayı panoya kopyalandı."
        }
    }
})

$ctxSearchCrash.Add_Click({
    if ($lvCrashes.SelectedItem) {
        $mod = $lvCrashes.SelectedItem.FaultingModule
        $cat = $lvCrashes.SelectedItem.Category
        
        # Eğer sistem çöktüyse farklı, oyun çöktüyse farklı kelime arat
        $query = ""
        if ($cat -match "Uygulama") {
            $query = "$mod application crash fix"
        } else {
            $query = "$mod windows 11 error fix"
        }
        
        $url = "https://www.google.com/search?q=$([uri]::EscapeDataString($query))"
        Start-Process $url
    }
})
$ctxOpenDump.Add_Click({
    if ($lvCrashes.SelectedItem) {
        $dPath = $lvCrashes.SelectedItem.DumpPath
        if ($dPath -and (Test-Path $dPath)) {
            # Yeni yazdığımız API ile mavi seçili halde klasörü açar
            [FileSelector]::Select($dPath)
            WpfLog "💾 Dump dosyası konumu açıldı. Bu dosyayı WinDbg ile analiz edebilirsiniz."
        } else {
            [System.Windows.MessageBox]::Show("Bu hata için kayıtlı bir Dump (.dmp) dosyası bulunamadı. Kara kutu ayarlarının aktif olduğundan emin olun.", "Bulunamadı",[System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }
    }
})

# --- ÇÖKME ANALİZİ (DEDEKTİF) OLAYLARI ---

$btnFixBlackBox.Add_Click({
    try {
        $btnFixBlackBox.IsEnabled = $false

        if ($btnFixBlackBox.Tag -eq "on") {
            # --- DEVRE DIŞI BIRAK ---
            WpfLog "--- KARA KUTU DEVRE DIŞI BIRAKILIYOR ---"

            $crashPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
            Set-ItemProperty -Path $crashPath -Name "CrashDumpEnabled" -Value 3 -Type DWord -Force
            Set-ItemProperty -Path $crashPath -Name "LogEvent" -Value 0 -Type DWord -Force
            WpfLog ">> BSOD kaydı Minidump (varsayılan) seviyesine indirildi."

            $werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps"
            if (Test-Path $werPath) { Remove-Item -Path $werPath -Recurse -Force -ErrorAction SilentlyContinue }
            WpfLog ">> Oyun/Uygulama çökme kaydı (.dmp) devre dışı bırakıldı."

            WpfLog "✅ Kara Kutu devre dışı bırakıldı."

        } else {
            # --- ETKİNLEŞTİR ---
            WpfLog "--- KARA KUTU AYARLARI ZORLANIYOR ---"

            Set-Service -Name "WerSvc" -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name "WerSvc" -ErrorAction SilentlyContinue
            WpfLog ">> Windows Hata Bildirimi (WER) servisi ayarlandı."

            $crashPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
            if (-not (Test-Path $crashPath)) { New-Item -Path $crashPath -Force | Out-Null }
            Set-ItemProperty -Path $crashPath -Name "CrashDumpEnabled" -Value 2 -Type DWord -Force
            Set-ItemProperty -Path $crashPath -Name "LogEvent" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $crashPath -Name "AutoReboot" -Value 0 -Type DWord -Force
            WpfLog ">> Mavi Ekran (BSOD) kaydı 'Çekirdek Bellek Dökümü' olarak ayarlandı."

            $werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps"
            if (-not (Test-Path $werPath)) { New-Item -Path $werPath -Force | Out-Null }
            Set-ItemProperty -Path $werPath -Name "DumpType" -Value 2 -Type DWord -Force
            Set-ItemProperty -Path $werPath -Name "DumpCount" -Value 10 -Type DWord -Force
            $dumpFolder = "$env:LOCALAPPDATA\CrashDumps"
            if (-not (Test-Path $dumpFolder)) { New-Item -Path $dumpFolder -ItemType Directory -Force | Out-Null }
            Set-ItemProperty -Path $werPath -Name "DumpFolder" -Value $dumpFolder -Type ExpandString -Force
            WpfLog ">> Oyun/Uygulama çökme kaydı (.dmp) özelliği ayarlandı."

            WpfLog "✅ Kara Kutu ayarları başarıyla uygulandı!"
        }

        Check-BlackBoxStatus
        $btnFixBlackBox.IsEnabled = $true

    } catch {
        WpfLog "❌ HATA: İşlem tamamlanamadı! $($_.Exception.Message)"
        $btnFixBlackBox.IsEnabled = $true
    }
})

# --- ONARIM SEKMESİ BUTONLARI ---

# --- ONARIM SEKMESİ BUTONLARI (ARKAPLAN İŞÇİSİ İLE) ---

$btnFixUpdate.Add_Click({
    $confirm = [System.Windows.MessageBox]::Show(
        "Windows Update onarımı başlatılacak. Bu işlem servisleri durdurup önbelleği temizleyecektir.`nDevam edilsin mi?", 
        "Onay", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($confirm -eq 'Yes') {
        # UI Hazırlığı
        $txtLog.Text = ""
        WpfLog "--- WINDOWS UPDATE ONARIMI BAŞLATILDI (RAM MODU) ---"
        
        # Çalıştırılacak Script Bloğu (String olarak gönderiyoruz)
        # Not: İçerideki WS ve Log fonksiyonları yeni motorumuz tarafından otomatik tanımlanır.
        $innerScript = @"
            WS 'Update onarılıyor...'
            Log 'Windows Update policy kayıtları sıfırlanıyor...'

            `$wuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            `$auKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            
            # Policy Temizliği
            if (Test-Path `$wuKey) {
                Remove-ItemProperty -Path `$wuKey -Name 'DisableOSUpgrade' -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path `$wuKey -Name 'SetDisableUXWUAccess' -ErrorAction SilentlyContinue
            }
            if (Test-Path `$auKey) {
                Remove-ItemProperty -Path `$auKey -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue
                Set-ItemProperty -Path `$auKey -Name 'AUOptions' -Value 4 -Type DWord -ErrorAction SilentlyContinue
            }

            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Name 'SearchOrderConfig' -Value 1 -Type DWord -ErrorAction SilentlyContinue

            # Servis Ayarları
            Log 'Servisler yapılandırılıyor...'
            Set-Service -Name 'wuauserv'     -StartupType Manual    -ErrorAction SilentlyContinue
            Set-Service -Name 'UsoSvc'       -StartupType Automatic -ErrorAction SilentlyContinue
            Set-Service -Name 'WaaSMedicSvc' -StartupType Manual    -ErrorAction SilentlyContinue

            Log 'Servisler durduruluyor...'
            `$services = @('wuauserv', 'cryptSvc', 'bits', 'msiserver')
            foreach (`$svc in `$services) {
                Log "Durduruluyor: `$svc"
                Stop-Service -Name `$svc -Force -ErrorAction SilentlyContinue
            }

            Log 'Önbellek (SoftwareDistribution) temizleniyor...'
            # Dosya isimlerine tarih ekleyerek çakışma ve kilitlenme riskini azaltıyoruz
            `$stamp = (Get-Date).Ticks
            if (Test-Path 'C:\Windows\SoftwareDistribution') {
                Rename-Item 'C:\Windows\SoftwareDistribution' "SoftwareDistribution.old.`$stamp" -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path 'C:\Windows\System32\catroot2') {
                Rename-Item 'C:\Windows\System32\catroot2' "Catroot2.old.`$stamp" -Force -ErrorAction SilentlyContinue
            }

            Log 'Servisler yeniden başlatılıyor...'
            foreach (`$svc in `$services) {
                Log "Başlatılıyor: `$svc"
                Start-Service -Name `$svc -ErrorAction SilentlyContinue
            }

            Log '----------------------------------------'
            Log '✅ İŞLEM TAMAMLANDI. Lütfen bilgisayarınızı yeniden başlatın.'
            WS 'Bitti'
"@

        # Yeni motoru çağır
        Start-Worker-Process $innerScript $btnFixUpdate "UPDATE ONARIM"
    }
})

$btnResetNet.Add_Click({
    if ([System.Windows.MessageBox]::Show("Tüm ağ ayarları (DNS, IP, WinSock) sıfırlanacak.`nBilgisayarı yeniden başlatmanız gerekecek.`nOnaylıyor musunuz?", "Ağ Sıfırlama", [System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning) -eq 'Yes') {
        
        $txtLog.Text = ""
        WpfLog "--- AĞ SIFIRLAMA (RAM) ---"
        
        $s = @'
        try {
            WS 'Ağ sıfırlanıyor...'
            
            Log '1/3: WinSock yapılandırması sıfırlanıyor...'
            # Çıktıyı gizliyoruz (> $null) çünkü arka planda başarıyla yapıyor.
            & netsh winsock reset > $null
            Log '✅ WinSock temizlendi.'
            
            Log '2/3: TCP/IP yığını sıfırlanıyor...'
            # Windows'un meşhur sahte "Erişim Engellendi" hatasını ve gereksiz OK mesajlarını gizliyoruz.
            & netsh int ip reset > $null
            Log '✅ TCP/IP sıfırlandı.'
            
            Log '3/3: DNS Önbelleği boşaltılıyor...'
            & ipconfig /flushdns > $null
            Log '✅ DNS önbelleği boşaltıldı.'
            
            Log '----------------------------------------'
            Log '⚠️ İŞLEM TAMAMLANDI: Lütfen değişikliklerin uygulanması için BİLGİSAYARINIZI YENİDEN BAŞLATIN.'
        } catch { 
            Log "❌ HATA: $_" 
        }
'@
        Start-Worker-Process $s $btnResetNet "AĞ SIFIRLAMA"
    }
})

$btnSfcScan.Add_Click({
    # --- ARAYÜZ HAZIRLIĞI ---
    $btnSfcScan.IsEnabled = $false
    $btnSfcScan.Content = "⏳ %0"
    $txtLog.Text = ""
    $pbMain.IsIndeterminate = $false
    $pbMain.Value = 0

    WpfLog "--- SISTEM TARAMASI (SFC) ---"
    WpfLog "SFC /Scannow (Profesyonel Motor) arka planda başlatıldı."
    WpfLog "⏳ Bu işlem sisteminize bağlı olarak 5-15 dakika sürebilir. İlerleme yüzdesi butonda gösterilir."
    $lblStatus.Text = "SFC Taraması yapılıyor... %0"

    # --- TEMP LOG DOSYASI: SFC ciktisini buraya yaz, timer parse etsin ---
    $script:sfcLogPath = Join-Path $env:TEMP "geminicare_sfc_progress.log"
    Remove-Item -Path $script:sfcLogPath -Force -ErrorAction SilentlyContinue
    "" | Out-File -FilePath $script:sfcLogPath -Encoding UTF8 -Force

    # Surec baslangic zamani (geren sure hesabi icin)
    $script:sfcStartTime = Get-Date
    $script:sfcLastPct = 0

    try {
        # 1. İŞİ BAŞLAT (ciktiyi temp file'a pipe et — pipeline her satiri ayri yazar,
        #    SFC'nin \r-bazli "Verification X% complete" cikarsalari yeni satir olarak file'a girer)
        $script:sfcJob = Start-Job -ArgumentList $script:sfcLogPath -ScriptBlock {
            param($logFile)
            # Pipeline cikarsasi: SFC her percentage update yeni satir olur
            & sfc /scannow 2>&1 | ForEach-Object {
                # Bazi satirlarda null karakterler olabilir, temizle
                $line = ($_ -replace "`0", "").Trim()
                if ($line) {
                    Add-Content -Path $logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
                }
            }
            return $LASTEXITCODE
        }

        # 2. PROGRESS PARSER + COMPLETION CHECKER TIMER
        $script:SfcTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:SfcTimer.Interval = [TimeSpan]::FromMilliseconds(1500)

        $script:SfcTimer.Add_Tick({
            # --- PROGRESS PARSE ---
            try {
                if (Test-Path $script:sfcLogPath) {
                    # Sadece son 4 KB oku (yeni satirlari icerir, performans)
                    $fi = Get-Item $script:sfcLogPath
                    if ($fi.Length -gt 4KB) {
                        $reader = [System.IO.File]::Open($script:sfcLogPath, 'Open', 'Read', 'ReadWrite')
                        $reader.Seek(-4KB, 'End') | Out-Null
                        $sr = New-Object System.IO.StreamReader($reader)
                        $tail = $sr.ReadToEnd()
                        $sr.Dispose(); $reader.Dispose()
                    } else {
                        $tail = Get-Content -Path $script:sfcLogPath -Raw -ErrorAction SilentlyContinue
                    }

                    if ($tail) {
                        # Son "Verification X% complete" satirini bul
                        $lastMatch = [regex]::Matches($tail, "Verification\s+(\d+)%\s+complete") | Select-Object -Last 1
                        if ($lastMatch) {
                            $pct = [int]$lastMatch.Groups[1].Value
                            if ($pct -ne $script:sfcLastPct) {
                                $script:sfcLastPct = $pct
                                $btnSfcScan.Content = "⏳ %$pct"
                                $pbMain.Value = $pct
                                $elapsed = [int]((Get-Date) - $script:sfcStartTime).TotalSeconds
                                $mm = [int]([Math]::Floor($elapsed / 60))
                                $ss = [int]($elapsed % 60)
                                $lblStatus.Text = ("SFC Taraması: %{0} (geçen: {1:D2}:{2:D2})" -f $pct, $mm, $ss)
                            }
                        } else {
                            # Henuz % cikmadi — "Beginning verification phase" gibi durum mesajlari
                            $elapsed = [int]((Get-Date) - $script:sfcStartTime).TotalSeconds
                            $mm = [int]([Math]::Floor($elapsed / 60))
                            $ss = [int]($elapsed % 60)
                            $lblStatus.Text = ("SFC Taraması: hazırlanıyor (geçen: {0:D2}:{1:D2})" -f $mm, $ss)
                        }
                    }
                }
            } catch {
                # Parse hatasi — sessizce devam et, progress okunamazsa son deger kalir
            }

            # --- COMPLETION CHECK ---
            if ($script:sfcJob.State -ne 'Running') {
                $script:SfcTimer.Stop()

                # Cikis kodunu al
                $code = Receive-Job -Job $script:sfcJob

                # Log dosyasinda kritik mesajlari arayip ozetle
                $logTail = $null
                try { $logTail = Get-Content -Path $script:sfcLogPath -Raw -ErrorAction SilentlyContinue } catch {}

                if ($null -ne $code) {
                    if ($code -eq 0) {
                        if ($logTail -and $logTail -match "did not find any integrity violations") {
                            WpfLog "✅ İŞLEM BAŞARILI (Sistem Kodu: 0)"
                            WpfLog "Sistem temiz. Hiçbir bütünlük ihlali bulunmadı."
                        } elseif ($logTail -and $logTail -match "successfully repaired") {
                            WpfLog "✅ İŞLEM BAŞARILI (Sistem Kodu: 0)"
                            WpfLog "Bozuk dosyalar bulundu ve başarıyla onarıldı."
                        } else {
                            WpfLog "✅ İŞLEM BAŞARILI (Sistem Kodu: 0)"
                            WpfLog "Sistem temiz veya bozuk dosyalar onarıldı."
                        }
                    } else {
                        WpfLog "❌ HATA VEYA ONARILAMAYAN DOSYALAR (Sistem Kodu: $code)"
                        WpfLog "SFC bazı dosyaları onaramadı."
                        WpfLog "Lütfen onarım menüsünden 'DISM RestoreHealth' işlemini çalıştırın."
                        WpfLog "Hata detayları C:\Windows\Logs\CBS\CBS.log dosyasına kaydedildi."
                    }
                } else {
                    WpfLog "⚠️ İşlem tamamlandı ancak sistemden yanıt kodu alınamadı."
                }

                # Toplam sure
                $totalSec = [int]((Get-Date) - $script:sfcStartTime).TotalSeconds
                $tm = [int]([Math]::Floor($totalSec / 60))
                $ts = [int]($totalSec % 60)
                WpfLog ("⏱ Toplam süre: {0:D2}:{1:D2}" -f $tm, $ts)

                # --- BİTİŞ VE TEMİZLİK ---
                Remove-Job -Job $script:sfcJob -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $script:sfcLogPath -Force -ErrorAction SilentlyContinue

                $pbMain.IsIndeterminate = $false
                $pbMain.Value = 100
                $lblStatus.Text = "SFC Taraması Bitti."
                $btnSfcScan.IsEnabled = $true
                $btnSfcScan.Content = "🔍 SFC / Scannow"
            }
        })

        $script:SfcTimer.Start()

    } catch {
        WpfLog "❌ BAŞLATMA HATASI: $($_.Exception.Message)"
        $btnSfcScan.IsEnabled = $true
        $btnSfcScan.Content = "🔍 SFC / Scannow"
        $pbMain.IsIndeterminate = $false
        $pbMain.Value = 0
    }
})

# Seçim Butonları
if ($btnSelectAll) { $btnSelectAll.Add_Click({ foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvShellBags)) { if ($tree) { foreach ($it in $tree.Items) { (Get-CheckFromItem $it).IsChecked = $true; Sync-Children $it $true } } } }) }
if ($btnUnselectAll) { $btnUnselectAll.Add_Click({ foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvRepair, $tvShellBags)) { if ($tree) { foreach ($it in $tree.Items) { (Get-CheckFromItem $it).IsChecked = $false; Sync-Children $it $false } } } }) }

if ($btnSelectTab) {
    $btnSelectTab.Add_Click({
        if ($tabControl.SelectedItem) {
            $header = $tabControl.SelectedItem.Header
            $target = $null
            switch ($header) { 
                "Tarayıcılar" { $target = $tvBrowser } 
                "Sistem" { $target = $tvSystem } 
                "Uygulamalar" { $target = $tvApps } 
                "Onarım" { $target = $tvRepair } 
                "ShellBags" { $target = $tvShellBags } 
                "Tweaks" { $target = $tvTweaks } 
            }
            if ($target) { foreach ($it in $target.Items) { (Get-CheckFromItem $it).IsChecked = $true; Sync-Children $it $true } }
        }
    })
}

# Diğer Butonlar
if ($btnOpenData) { $btnOpenData.Add_Click({ Invoke-Item $AppDataPath }) }

if ($btnWinget) { 
    $btnWinget.Add_Click({ 
        $btnWinget.IsEnabled = $false
        WpfLog "--- WINGET TOPLU GÜNCELLEME ---"
        Run-CMD-Realtime "winget upgrade --all --force --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity"
        $btnWinget.IsEnabled = $true 
    }) 
}

if ($btnRefreshApp) { # GÜNCELLE BUTONU (YENİ POPUP İLE)
$btnRefreshApp.Add_Click({ 
    Show-UpdateWindow 
}) }

# Log Butonları
if ($btnCopyLog) { $btnCopyLog.Add_Click({ if ($txtLog.Text) { [System.Windows.Clipboard]::SetText($txtLog.Text) } }) }
if ($btnClearLog) { $btnClearLog.Add_Click({ $txtLog.Text = "" }) }

# Tweak Butonları
if ($btnApplyTweaks) { $btnApplyTweaks.Add_Click({ Apply-System-Tweaks }) }
if ($btnManageTweaks) { $btnManageTweaks.Add_Click({ Show-TweakManager }) }
if ($btnCheckTweaks) { $btnCheckTweaks.Add_Click({ Check-Tweak-Status -ForceRefresh }) }
$btnQuickUndo = $Win.FindName('btnQuickUndo')
if ($btnQuickUndo) { $btnQuickUndo.Add_Click({ Invoke-QuickUndo }) }
# Detaylı Donanım Butonu
$btnHardwareDetail = $Win.FindName('btnHardwareDetail')
$btnPingTest    = $Win.FindName('btnPingTest')
$txtPingGoogle  = $Win.FindName('txtPingGoogle')
$txtDashDNS = $Win.FindName('txtDashDNS')
$txtPingCF      = $Win.FindName('txtPingCF')
$txtPingGW      = $Win.FindName('txtPingGW')
# --- PİNG / LATENCİ TESTİ ---
$btnPingTest.Add_Click({
    $btnPingTest.IsEnabled = $false
    $btnPingTest.Content = "⏳"
    $txtPingGoogle.Text = "Google ..."
    $txtPingCF.Text     = "Cloudflare ..."
    $txtPingGW.Text     = "Ağ Geçidi ..."

    $script:PingRS = [powershell]::Create()
    $script:PingRS.AddScript({
        function Ping-IP([string]$ip, [int]$count=4) {
            $times = @()
            $pinger = New-Object System.Net.NetworkInformation.Ping
            $opts   = New-Object System.Net.NetworkInformation.PingOptions
            $opts.Ttl = 64
            $buf = [byte[]](1..32)
            for ($i = 0; $i -lt $count; $i++) {
                try {
                    $reply = $pinger.Send($ip, 1500, $buf, $opts)
                    if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        $times += $reply.RoundtripTime
                    }
                } catch {}
            }
            $pinger.Dispose()
            if ($times.Count -gt 0) {
                $avg = [Math]::Round(($times | Measure-Object -Average).Average)
                $min = ($times | Measure-Object -Minimum).Minimum
                $max = ($times | Measure-Object -Maximum).Maximum
                return [PSCustomObject]@{ OK=$true; Avg=$avg; Min=$min; Max=$max }
            }
            return [PSCustomObject]@{ OK=$false; Avg=0; Min=0; Max=0 }
        }

        # Ağ geçidini bul
        $gw = $null
        try {
            $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                   Sort-Object RouteMetric | Select-Object -First 1).NextHop
        } catch {}

        $google = Ping-IP "8.8.8.8"
        $cf     = Ping-IP "1.1.1.1"
        $gwRes  = if ($gw -and $gw -ne "0.0.0.0") { Ping-IP $gw 4 } else { [PSCustomObject]@{OK=$false;Avg=0;Min=0;Max=0} }

        return [PSCustomObject]@{ Google=$google; CF=$cf; GW=$gwRes; GWAddr=$gw }
    })
    $script:PingAsync = $script:PingRS.BeginInvoke()

# 2. ZAMANLAYICI (PING SONUÇLANDIRICI)
    $script:PingTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:PingTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    
    $script:PingTimer.Add_Tick({
        # Sadece işlem tamamlandıysa içeri gir
        if ($null -ne $script:PingAsync -and $script:PingAsync.IsCompleted) {
            $script:PingTimer.Stop()
            
            try {
                # Sonucu al
                $r = $script:PingRS.EndInvoke($script:PingAsync)

                # Yardımcı Formatlayıcı (ScriptBlock olarak kullanmak daha hızlıdır)
                $FormatPingResult = {
                    param($p, $label)
                    if ($p -and $p.OK) {
                        $color = if ($p.Avg -lt 20) { "#00CC00" } elseif ($p.Avg -lt 60) { "#E68A00" } else { "#FF5555" }
                        return @{ Text="$label $($p.Avg)ms (min:$($p.Min) max:$($p.Max))"; Color=$color }
                    }
                    return @{ Text="$label —"; Color="#666666" }
                }

                # Sonuçları işle
                $g  = &$FormatPingResult $r.Google "Google"
                $cf = &$FormatPingResult $r.CF     "CF"
                $gwLabel = if ($r.GWAddr) { "GW($($r.GWAddr))" } else { "GW" }
                $gw = &$FormatPingResult $r.GW     $gwLabel

                # UI Güncelleme (Hata korumalı)
                $txtPingGoogle.Text       = $g.Text
                $txtPingGoogle.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($g.Color)
                $txtPingCF.Text           = $cf.Text
                $txtPingCF.Foreground     = [System.Windows.Media.BrushConverter]::new().ConvertFromString($cf.Color)
                $txtPingGW.Text           = $gw.Text
                $txtPingGW.Foreground     = [System.Windows.Media.BrushConverter]::new().ConvertFromString($gw.Color)

                WpfLog "📡 [PİNG] $($g.Text) | $($cf.Text) | $($gw.Text)"
            } 
            catch {
                WpfLog "⚠️ Ping Sonuç Hatası: $($_.Exception.Message)"
            } 
            finally {
                # KRİTİK BELLEK TEMİZLİĞİ (B1 Çözümü)
                if ($null -ne $script:PingRS) { 
                    $script:PingRS.Dispose()
                    $script:PingRS = $null
                    $script:PingAsync = $null
                }
                # Butonu eski haline getir
                $btnPingTest.IsEnabled = $true
                $btnPingTest.Content = "📡 Test Et"
            }
        }
    }) # <--- Hata buradaki parantezdeydi, düzeltildi.
	
    $script:PingTimer.Start()
})

if ($btnHardwareDetail) { $btnHardwareDetail.Add_Click({ Show-HardwareDetail }) }

# Winget Sekmesi Butonları
if ($btnRefreshWinget) { $btnRefreshWinget.Add_Click({ Refresh-Winget-Status -Silent $false }) }

# --- WINGET INSTALL/UNINSTALL (OPTIMIZE EDİLDİ) ---
$btnInstallWinget.Add_Click({
    # 1. UI Thread: Seçilenleri Bul
    $list = New-Object System.Collections.ArrayList
    function Find($items) { 
        foreach ($i in $items) { 
            if ((Get-CheckFromItem $i).IsChecked -and $i.Tag -match '^WINGET_INSTALL:(.*)' -and (Get-CheckFromItem $i).Content -notmatch "\(Yüklü\)") { 
                $list.Add(@{N=(Get-CheckFromItem $i).Content;I=$Matches[1]}) 
            }; 
            if ($i.Items.Count) { Find $i.Items } 
        } 
    }
    Find $tvWinget.Items
    
    # Kontroller
    if ($list.Count -eq 0) {[System.Windows.MessageBox]::Show("Kurulacak uygulama seçilmedi.") | Out-Null; return }
    if ([System.Windows.MessageBox]::Show("$($list.Count) uygulama kurulacak. Onaylıyor musunuz?", "Onay",[System.Windows.MessageBoxButton]::YesNo) -ne 'Yes') { return }
    
    # 2. UI Hazırlık
    $txtLog.Text = ""

    # 3. Dinamik Script Oluşturma (EKSİK FONKSİYON BURAYA EKLENDİ)
    $s = @"
    `$w='winget'; if(Test-Path "`$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"){`$w="`$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"}

    # --- EKSİK OLAN FİLTRELEME FONKSİYONU ---
    function Process-Output(`$line) {
        `$clean = `$line.ToString().Trim()
        if (-not[string]::IsNullOrWhiteSpace(`$clean)) {
            # Progress barlarını ve anlamsız KB/MB yazılarını gizle
            if (`$clean -match '^[█▒\|\/\\\-\s\d\.]+(KB|MB|%)*') { return }
            Log ">> `$clean"
        }
    }

    try {
        WS 'Kaynaklar güncelleniyor (Sessiz)...'
        & `$w source update --disable-interactivity > `$null 2>&1
"@
    
    foreach ($a in $list) {
        $s += "`n    WS 'Kuruluyor: $($a.N)'" 
        $s += "`n    Log '----------------------------------------'"
        $s += "`n    Log 'BASLATILIYOR: $($a.N) (ID: $($a.I))'"
        
        $s += "`n    & `$w install --id `"$($a.I)`" -s winget -e --silent --accept-source-agreements --accept-package-agreements --disable-interactivity --force --include-unknown 2>&1 | ForEach-Object { Process-Output `$_ }"
        
        $s += "`n    if (`$LASTEXITCODE -eq 0) { Log '✅ Kurulum Başarıyla Tamamlandı.' }"
        $s += "`n    else { Log '⚠️ Kurulum Hata ile Sonlandı (Kod: ' + `$LASTEXITCODE + ')' }"
        
        $s += "`n    Start-Sleep -Seconds 1"
    }
    
    $s += @"
    } catch { 
        Log "!!! KRITIK HATA: `$_"
    }
"@
    
    # 4. Yeni motora gönder
    Start-Worker-Process $s $btnInstallWinget "KURULUM"
})

$btnUninstallWinget.Add_Click({
    # 1. UI Thread: Seçilenleri Bul
    $list = New-Object System.Collections.ArrayList
    function Find($items) { 
        foreach ($i in $items) { 
            if ((Get-CheckFromItem $i).IsChecked) { 
                if ($i.Tag -match '^WINGET_INSTALL:(.*)' -and (Get-CheckFromItem $i).Content -match "\(Yüklü\)") { 
                    $list.Add(@{Type="WINGET"; Name=(Get-CheckFromItem $i).Content; ID=$Matches[1]}) 
                }; 
                if ($i.Tag -match '^APPX:(.*)') { 
                    $list.Add(@{Type="APPX"; Name=(Get-CheckFromItem $i).Content; ID=$Matches[1]}) 
                } 
            }; 
            if ($i.Items.Count) { Find $i.Items } 
        } 
    }
    Find $tvWinget.Items
    
    # Kontroller
    if ($list.Count -eq 0) {[System.Windows.MessageBox]::Show("Seçim yok.")|Out-Null; return }
    if ([System.Windows.MessageBox]::Show("Seçili öğeler silinecek. Emin misiniz?", "Uyarı",[System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -ne 'Yes') { return }
    
    $txtLog.Text = ""
    # Base64 Kodlama (Veri Transferi İçin)
    $jsonRaw = $list | ConvertTo-Json -Depth 2 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonRaw)
    $encodedList =[Convert]::ToBase64String($bytes)
    
    # --- GÜVENLİ SCRIPT OLUŞTURMA ---
    $s = @'
    # --- İÇ FONKSİYONLAR ---
    function Process-Output($line) {
        $clean = $line.ToString().Trim()
        if (-not[string]::IsNullOrWhiteSpace($clean)) {
            if ($clean -match '^[█▒\|\/\\\-\s\d\.]+(KB|MB|%)*') { return }
            Log ">> $clean"
        }
    }

    function Uninstall-FromRegistry($AppName) {
        Log "   [INFO] Registry taraması: $AppName"
        $regPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
        $found = $false
        
        foreach ($path in $regPaths) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue | ForEach-Object {
                if ($found) { return }
                if ($null -ne $_.DisplayName -and $_.DisplayName -match "(?i)$AppName" -and $null -ne $_.UninstallString) {
                    $cmd = $_.UninstallString
                    Log "   -> BULUNDU: $($_.DisplayName)"
                    
                    $exe = ""; $args = ""
                    if ($cmd -match '^\"(.*?)\"(.*)') {
                        $exe = $Matches[1]; $args = $Matches[2].Trim()
                    } else {
                        $split = $cmd.Split(' '); $exe = $split[0]
                        if ($split.Count -gt 1) { $args = $cmd.Substring($exe.Length).Trim() }
                    }

                    # Parametreleri düzgün ayarla
                    if ($exe -match "msiexec" -or $cmd -match "msiexec") {
                        if ($args -notmatch "/q") { $args = "$args /qn /norestart" }
                    } else {
                        if ($args -notmatch "/VERYSILENT") {
                            $args = "$args /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
                        }
                    }

                    Log "   -> Çalıştırılıyor: $exe $args"
                    try {
                        $psi = New-Object System.Diagnostics.ProcessStartInfo
                        $psi.FileName               = $exe
                        $psi.Arguments              = $args
                        $psi.UseShellExecute        = $false
                        $psi.CreateNoWindow         = $true
                        $psi.WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden
                        $proc = [System.Diagnostics.Process]::Start($psi)
                        $finished = $proc.WaitForExit(60000) # Max 60 saniye bekle
                        if (-not $finished) {
                            $proc.Kill()
                            Log "   -> [UYARI] 60 saniye timeout - Görev sonlandırıldı."
                        } else {
                            Log "   ✅ [BAŞARILI] Registry ile kaldırıldı. (Exit: $($proc.ExitCode))"
                        }
                        $found = $true
                    } catch { Log "   ❌ [HATA] $_" }
                }
            }
        }
        if (-not $found) { Log "   ⚠️ [BİLGİ] Registry'de bulunamadı." }
    }

    function Remove-WinUtilAPPX($FullName) {
        try {
            Log "   -> APPX Siliniyor: $FullName"
            Remove-AppxPackage -Package $FullName -AllUsers -ErrorAction Stop
            $simpleName = $FullName.Split('_')[0]
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $simpleName | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Log "   ✅ [BAŞARILI] Uygulama kaldırıldı."
        } catch { Log "   ❌ [HATA] Silinemedi: $($_.Exception.Message)" }
    }

    # --- ANA İŞLEM ---
    try {
        $w='winget'; if(Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"){$w="$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"}
        
        $encodedData = "
'@
    
    $s += $encodedList
    
    $s += @'
"
        $decodedBytes = [Convert]::FromBase64String($encodedData)
        $decodedJson = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
        $targetList = $decodedJson | ConvertFrom-Json
        
        # Eğer sadece 1 tane program seçildiyse, JSON nesneyi dizi yapmıyor, onu düzeltelim:
        if ($targetList -isnot [array]) { $targetList = @($targetList) }
        
        foreach ($item in $targetList) {
            $cl = $item.Name -replace " \(Yüklü\)", ""
            $cleanSearchName = $cl -replace " v\d+.*", "" -replace " \d+\.\d+.*", ""
            
            WS "Kaldırılıyor: $cl"
            Log "----------------------------------------"
            Log ">> HEDEF: $cl"
            
            if ($item.Type -eq "WINGET") {
                & $w uninstall --id "$($item.ID)" -e --silent --accept-source-agreements --disable-interactivity 2>&1 | ForEach-Object { Process-Output $_ }
                
                if ($LASTEXITCODE -eq 0) { 
                    Log "✅ [BAŞARILI] Winget ile kaldırıldı." 
                } else { 
                    Log "⚠️ [UYARI] Winget kaldırılamadı. Kayıt Defteri (Registry) yöntemi deneniyor..."
                    Uninstall-FromRegistry -AppName "$cleanSearchName"
                }
            }
            elseif ($item.Type -eq "APPX") {
                Remove-WinUtilAPPX -FullName "$($item.ID)"
            }
            Start-Sleep -Milliseconds 500
        }
        
        Log "----------------------------------------"
        Log "✅ TÜM İŞLEMLER TAMAMLANDI."

    } catch {
        Log "!!! GENEL HATA: $_"
    }
'@
    
    Start-Worker-Process $s $btnUninstallWinget "KALDIRMA"
})

# --- DİĞER YÖNETİCİ PENCERELERİ ---

# --- EVRENSEL VE AKILLI WEB SCRAPER (DÜZELTİLMİŞ) ---


# --- GÖMÜLÜ ARAÇ (GITHUB) ÇALIŞTIRMA MANTIĞI (V3 - RAM KUYRUĞU İLE) ---

# --- YÖNETİCİ PENCERESİ FONKSİYONU ---

# --- ANA BUTON TIKLAMA ---
$btnTools.Add_Click({
    # Menü boşsa (ilk açılış) veya sadece Yönet varsa doldur
    if ($ctxToolsMenu.Items.Count -eq 0) { Refresh-Tools-Menu }
    $ctxToolsMenu.PlacementTarget = $btnTools
    $ctxToolsMenu.IsOpen = $true
})

$btnManageWinget.Add_Click({
    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlWingetMgr); $winW = [Windows.Markup.XamlReader]::Load($reader)
        # Kontroller
        $tn = $winW.FindName('txtName'); $ti = $winW.FindName('txtID'); $lst = $winW.FindName('lstWinget'); $lblID = $winW.FindName('lblID')
        $bA = $winW.FindName('btnAddW'); $bD = $winW.FindName('btnDelW'); $bC = $winW.FindName('btnCloseW'); $bE = $winW.FindName('btnEditW')
        $rbW = $winW.FindName('rbModeWinget'); $rbA = $winW.FindName('rbModeAppx')
        
        $script:editIndex = -1
        $currentList = [ordered]@{}

        # --- LİSTE YENİLEME FONKSİYONU ---
        $RefreshUI = {
            $lst.Items.Clear(); $tn.Text=""; $ti.Text=""; $script:editIndex=-1; $bA.Content="EKLE"; $bA.Background="#006600"
            
            if ($rbW.IsChecked) {
                $lblID.Text = "Winget ID (Örn: Valve.Steam)"
                $currentList = $global:WingetApps
            } else {
                $lblID.Text = "Paket Adı (Örn: *xbox* veya tam isim)"
                $currentList = $global:CustomAppx
            }
            
            if ($currentList) {
                foreach ($k in $currentList.Keys) { $lst.Items.Add("$k | $($currentList[$k])") | Out-Null }
            }
        }
        
        # Olaylar
        $rbW.Add_Checked({ & $RefreshUI }); $rbA.Add_Checked({ & $RefreshUI })
        
        # İlk Yükleme
        & $RefreshUI 

        # DÜZENLE
        $bE.Add_Click({ 
            if ($lst.SelectedIndex -ne -1) { 
                $p = $lst.SelectedItem.ToString() -split ' \| '; $tn.Text = $p[0]; $ti.Text = $p[1]
                $script:editIndex = $lst.SelectedIndex; $bA.Content = "GÜNCELLE"; $bA.Background = "#E68A00" 
            } 
        })
        
        # EKLE / GÜNCELLE
        $bA.Add_Click({ 
            if ($tn.Text -and $ti.Text) { 
                $s = "$($tn.Text) | $($ti.Text)"
                if ($script:editIndex -gt -1) { 
                    $lst.Items.RemoveAt($script:editIndex); $lst.Items.Insert($script:editIndex, $s)
                    $script:editIndex = -1; $bA.Content = "EKLE"; $bA.Background = "#006600" 
                } else { $lst.Items.Add($s)|Out-Null }
                $tn.Text=""; $ti.Text="" 
            } 
        })
        
        # SİL
        $bD.Add_Click({ 
            if ($lst.SelectedIndex -ge 0) { 
                if ($script:editIndex -eq $lst.SelectedIndex) { $script:editIndex=-1; $bA.Content="EKLE"; $bA.Background="#006600"; $tn.Text=""; $ti.Text="" }
                $lst.Items.RemoveAt($lst.SelectedIndex) 
            } 
        })
        
        # KAYDET VE ÇIK
        $bC.Add_Click({ 
            $newList = [ordered]@{}
            foreach ($i in $lst.Items) { $p = $i -split ' \| '; if ($p.Count -eq 2) { $newList[$p[0]] = $p[1] } }
            
            if ($rbW.IsChecked) { $global:WingetApps = $newList } 
            else { $global:CustomAppx = $newList }
            
            Mark-ConfigDirty; Load-Winget-Tree; $winW.Close() 
        })
        
        $winW.ShowDialog() | Out-Null
    } catch {}
})

# =============================================================
# BÖLÜM 2 — POWERSHELL FONKSİYONLARI
# Eski $btnProfile.Add_Click bloğunu tamamen sil, bunları ekle
# =============================================================

# Profil tanımları — her profil tweak isimlerinin listesi


$btnWingetUpdateAll.Add_Click({ 
    # DİKKAT: Butonu kilitlemeye veya ismini değiştirmeye gerek YOK!
    # Start-Worker-Process bunu zaten hafızaya alarak otomatik yapıyor.
    
    $txtLog.Text = ""
    WpfLog "--- WINGET TOPLU GUNCELLEME (RAM) ---"
    
    # Çalıştırılacak kod bloğu
    $s = @'
    $w='winget'; if(Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"){$w="$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"}

    # --- FİLTRELEME FONKSİYONU ---
    function Process-Output($line) {
        $clean = $line.ToString().Trim()
        if (-not [string]::IsNullOrWhiteSpace($clean)) {
            # Progress barlarını ve anlamsız KB/MB yazılarını gizle
            if ($clean -match '^[█▒\|\/\\\-\s\d\.]+(KB|MB|%)*') { return }
            Log ">> $clean"
        }
    }

    try {
        WS 'Kaynaklar guncelleniyor...'
        Log 'BILGI: Kaynaklar guncelleniyor...'
        
        & $w source update --disable-interactivity 2>&1 | ForEach-Object { Process-Output $_ }
        
        WS 'Guncellemeler yapiliyor...'
        Log 'BILGI: Toplu guncelleme baslatildi. Bu islem biraz surebilir...'
        Log '----------------------------------------'
        
        # Güncelleme komutu
        & $w upgrade --all --force --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1 | ForEach-Object { Process-Output $_ }
        
        Log '----------------------------------------'
        $emojiCheck =[char]::ConvertFromUtf32(0x2705)
        Log "$emojiCheck TUM GUNCELLEME ISLEMLERI TAMAMLANDI."

    } catch { 
        Log "!! KRITIK HATA: $_" 
    }
'@
    
    # Yeni motora gönder
    Start-Worker-Process $s $btnWingetUpdateAll "GÜNCELLEME"
})

$btnSettings.Add_Click({
    try {
        $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlSettings)
        $winSet = [Windows.Markup.XamlReader]::Load($reader)
        
        # Kontroller
        $chkDev = $winSet.FindName('chkDisableCache')
        $lstF = $winSet.FindName('lstFiles')
        $bDel = $winSet.FindName('btnDeleteFiles')
        $bImp = $winSet.FindName('btnImportUI'); $bExp = $winSet.FindName('btnExportUI')
        $rbL = $winSet.FindName('rbLayoutLeft'); $rbT = $winSet.FindName('rbLayoutTop')
        
        # Yeni Butonlar
        $bOpenBlk = $winSet.FindName('btnOpenBlacklist')
        $bOpenCus = $winSet.FindName('btnOpenCustom')
		$btnWinEdit = $winSet.FindName('btnEditWinapp2')
		$btnWinEdit.Add_Click({ Show-Winapp2Editor })

        # --- SİSTEM GERİ YÜKLEME PANELİ ---
        $rbRPAsk           = $winSet.FindName('rbRPAsk')
        $rbRPAuto          = $winSet.FindName('rbRPAuto')
        $rbRPNever         = $winSet.FindName('rbRPNever')
        $txtRPInfo         = $winSet.FindName('txtRPInfo')
        $btnRPManualCreate = $winSet.FindName('btnRPManualCreate')
        $btnRPWindowsPanel = $winSet.FindName('btnRPWindowsPanel')

        # Mevcut modu yükle (default Ask)
        switch ($global:RestorePointMode) {
            "Auto"  { $rbRPAuto.IsChecked  = $true }
            "Never" { $rbRPNever.IsChecked = $true }
            default { $rbRPAsk.IsChecked   = $true }
        }

        # Bilgi metnini güncelleyen local helper (son nokta + VSS durumu)
        $updateRPInfo = {
            $last = Get-LastRestorePointDate
            $lastStr = if ($last) { $last.ToString("dd.MM.yyyy HH:mm") } else { "hiç yok" }
            $vss = if (Test-VssServiceRunning) { "Çalışıyor ✅" } else { "Kapalı ⚠️" }
            $txtRPInfo.Text = "Son nokta: $lastStr  •  VSS servisi: $vss"
        }
        & $updateRPInfo

        # Mod değişimleri (radio Checked event'i)
        $rbRPAsk.Add_Checked({
            $global:RestorePointMode = "Ask"; Mark-ConfigDirty
            WpfLog "[AYAR] Sistem Geri Yükleme: Her seferinde sor."
        })
        $rbRPAuto.Add_Checked({
            $global:RestorePointMode = "Auto"; Mark-ConfigDirty
            WpfLog "[AYAR] Sistem Geri Yükleme: Sormadan otomatik oluştur."
        })
        $rbRPNever.Add_Checked({
            $global:RestorePointMode = "Never"; Mark-ConfigDirty
            WpfLog "[AYAR] Sistem Geri Yükleme: Asla oluşturma."
        })

        # Manuel oluştur (mod/throttle'i atla, kullanıcı bilinçli tıklıyor)
        $btnRPManualCreate.Add_Click({
            $btnRPManualCreate.IsEnabled = $false
            try {
                [void](Create-Restore-Point -Description "Manuel Oluşturma (Ayarlar)" -ForceManual)
                & $updateRPInfo
            } finally {
                $btnRPManualCreate.IsEnabled = $true
            }
        }.GetNewClosure())

        # Windows'un kendi Sistem Koruması paneli
        $btnRPWindowsPanel.Add_Click({
            try {
                Start-Process -FilePath "SystemPropertiesProtection.exe" -ErrorAction Stop
            } catch {
                WpfLog "[HATA] Windows Sistem Koruması paneli açılamadı: $($_.Exception.Message)"
            }
        })
        
        # Cache Durumu
        $chkDev.IsChecked = $global:IsCacheDisabled
        $chkDev.Add_Click({
            if ($chkDev.IsChecked) { New-Item -Path $NoCacheFlag -ItemType File -Force | Out-Null; $global:IsCacheDisabled=$true }
            else { Remove-Item $NoCacheFlag -Force -ErrorAction SilentlyContinue; $global:IsCacheDisabled=$false }
        })

        # --- LAYOUT MANTIĞI (GÜNCELLENDİ) ---
        if ($global:AppLayout -eq "Top") { $rbT.IsChecked = $true } else { $rbL.IsChecked = $true }

        $rbT.Add_Checked({ 
            $tabControl.TabStripPlacement = "Top" 
            foreach ($tab in $tabControl.Items) { $tab.Width = [double]::NaN; $tab.Height = 30 }
            $global:AppLayout = "Top" # Değişkeni güncelle
            Mark-ConfigDirty # Anlık kaydet
        })
        
        $rbL.Add_Checked({ 
            $tabControl.TabStripPlacement = "Left" 
            foreach ($tab in $tabControl.Items) { $tab.Width = 140; $tab.Height = 40 }
            $global:AppLayout = "Left" # Değişkeni güncelle
            Mark-ConfigDirty # Anlık kaydet
        })

        # --- YENİ EKLENEN: BLACKLIST YÖNETİCİSİ AÇMA ---
        $bOpenBlk.Add_Click({
            try {
                $rBlk = New-Object System.Xml.XmlNodeReader ([xml]$xamlBlacklist)
                $wBlk = [Windows.Markup.XamlReader]::Load($rBlk)
                $lBlk = $wBlk.FindName('lstBlacklist'); $bR = $wBlk.FindName('btnRestore'); $bC = $wBlk.FindName('btnClose')
                
                foreach ($item in $global:Blacklist) { if ($item) { $lBlk.Items.Add($item) | Out-Null } }
                
                $bR.Add_Click({ 
                    if ($lBlk.SelectedItems.Count) { 
                        $sel = @($lBlk.SelectedItems)
                        foreach ($s in $sel) { $global:Blacklist = $global:Blacklist | Where { $_ -ne $s }; $lBlk.Items.Remove($s) }
                        Mark-ConfigDirty; WpfLog "Yoksayılanlar güncellendi." 
                    } 
                })
                $bC.Add_Click({ $wBlk.Close() })
                $wBlk.ShowDialog() | Out-Null
            } catch { WpfLog "Blacklist Hatası: $_" }
        })

        # --- YENİ EKLENEN: CUSTOM RULES YÖNETİCİSİ AÇMA ---
        $bOpenCus.Add_Click({
            try {
                $rCus = New-Object System.Xml.XmlNodeReader ([xml]$xamlCustomMgr)
                $wCus = [Windows.Markup.XamlReader]::Load($rCus)
                $lCus = $wCus.FindName('lstCustomRules'); $bA = $wCus.FindName('btnAddCustom')
                $bD = $wCus.FindName('btnDeleteCustom'); $bC = $wCus.FindName('btnCloseCustom'); $bE = $wCus.FindName('btnEditCustom')
                
                if ($global:CustomRules) { foreach ($r in $global:CustomRules) { $lCus.Items.Add($r.Name) | Out-Null } }
                
                # Helper: Ekleme/Düzenleme Penceresi
                $ShowAddEdit = {
                    param($EditMode = $false)
                    try {
                        $rAdd = New-Object System.Xml.XmlNodeReader ([xml]$xamlAddCustom); $wAdd = [Windows.Markup.XamlReader]::Load($rAdd)
                        $tP = $wAdd.FindName('txtCustomPath'); $bB = $wAdd.FindName('btnBrowse'); $tF = $wAdd.FindName('txtFilter')
                        $cR = $wAdd.FindName('chkRecurse'); $cDel = $wAdd.FindName('chkDeleteFolder'); $bOk = $wAdd.FindName('btnAdd'); $bCan = $wAdd.FindName('btnCancel')
                        
                        $oldName = ""
                        if ($EditMode -and $lCus.SelectedItem) {
                            $oldName = $lCus.SelectedItem.ToString()
                            $ruleObj = $global:CustomRules | Where-Object { $_.Name -eq $oldName } | Select-Object -First 1
                            if ($ruleObj) {
                                $parts = $ruleObj.Rule -split '\|'
                                $tP.Text = $parts[0]
                                if ($parts.Count -gt 1) { $tF.Text = $parts[1] }
                                if ($parts.Count -gt 2) { 
                                    if ($parts[2] -match "RECURSE") { $cR.IsChecked = $true } else { $cR.IsChecked = $false }
                                    if ($parts[2] -match "REMOVESELF") { $cDel.IsChecked = $true } else { $cDel.IsChecked = $false }
                                }
                            }
                        }

                        $bB.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if ($d.ShowDialog() -eq 'OK') { $tP.Text = $d.SelectedPath } })
                        $bOk.Add_Click({ 
                            if ($tP.Text) { 
                                $fol = $tP.Text; $fil = if ($tF.Text) { $tF.Text } else { "*" }
                                $flg = @(); if ($cR.IsChecked) { $flg+="RECURSE" }; if ($cDel.IsChecked) { $flg+="REMOVESELF" }; $flgStr=$flg -join ";"
                                $nm = "Custom: " + (Split-Path $fol -Leaf)
                                if ($EditMode -and $oldName) { $global:CustomRules = $global:CustomRules | Where-Object { $_.Name -ne $oldName }; $lCus.Items.Remove($oldName) }
                                $global:CustomRules += @{ Name=$nm; Rule="$fol|$fil|$flgStr"; IsChecked=$true }
                                $lCus.Items.Add($nm)|Out-Null; Mark-ConfigDirty; Load-System-Tree; $wAdd.Close() 
                            } 
                        })
                        $bCan.Add_Click({ $wAdd.Close() })
                        $wAdd.ShowDialog() | Out-Null
                    } catch { WpfLog "CustomAdd Hatası: $_" }
                }

                $bA.Add_Click({ & $ShowAddEdit -EditMode $false })
                $bE.Add_Click({ if ($lCus.SelectedIndex -ne -1) { & $ShowAddEdit -EditMode $true } })
                $bD.Add_Click({ if ($lCus.SelectedItems.Count) { $sel = @($lCus.SelectedItems); foreach ($s in $sel) { $global:CustomRules = $global:CustomRules | Where { $_.Name -ne $s }; $lCus.Items.Remove($s) }; Mark-ConfigDirty; Load-System-Tree } })
                $bC.Add_Click({ $wCus.Close() })
                
                $wCus.ShowDialog() | Out-Null
            } catch { WpfLog "CustomMgr Hatası: $_" }
        })

        # Dosya Listesi ve Diğerleri
        function Refresh-FileList {
            $lstF.Items.Clear()
            $files = @($UserConfigPath, $AppStatePath, $CachePath, $NoCacheFlag)
            foreach ($f in $files) {
                if (Test-Path $f) {
                    $info = Get-Item $f
                    $sizeKB = "{0:N2} KB" -f ($info.Length / 1KB)
                    $lstF.Items.Add("$($info.Name)  ($sizeKB)") | Out-Null
                }
            }
        }
        Refresh-FileList
        
        $bDel.Add_Click({
            if ($lstF.SelectedItems.Count -eq 0) { return }
            if ([System.Windows.MessageBox]::Show("Seçili dosyalar silinecek. Onaylıyor musunuz?", "Sil", [System.Windows.MessageBoxButton]::YesNo) -eq 'Yes') {
                foreach ($item in $lstF.SelectedItems) {
                    $fname = $item.ToString().Split(' ')[0]; $fullPath = "$AppDataPath\$fname"
                    Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
                }
                Refresh-FileList; WpfLog "[BİLGİ] Dosyalar silindi."
            }
        })
        
        # İçe Aktar
        $bImp.Add_Click({
            $ofd = New-Object Microsoft.Win32.OpenFileDialog; $ofd.Filter = "Gemini Ayar Dosyası (*.json)|*.json"
            if ($ofd.ShowDialog() -eq $true) {
                try {
                    $json = Get-Content $ofd.FileName -Raw | ConvertFrom-Json
                    $count = 0
                    if ($json.Blacklist) { $global:Blacklist = $json.Blacklist; $count++ }
                    if ($json.PathOverrides) { $global:PathOverrides = @{}; $json.PathOverrides.PSObject.Properties | ForEach-Object { $global:PathOverrides[$_.Name] = $_.Value }; $count++ }
                    if ($json.CustomRules) { $global:CustomRules = @($json.CustomRules); $count++ }
                    if ($json.WingetApps) { $temp = [ordered]@{}; $json.WingetApps.PSObject.Properties | ForEach-Object { $temp[$_.Name] = $_.Value }; $global:WingetApps = $temp; $count++ }
                    if ($json.Tweaks) { $tempTw = [ordered]@{}; foreach ($prop in $json.Tweaks.PSObject.Properties) { $tempTw[$prop.Name] = $prop.Value }; $global:TweakList = $tempTw; $count++ }
                    if ($json.CustomTools) { $global:CustomTools = @($json.CustomTools); $count++ }
                    if ($json.ToolDownloadPath) { $global:ToolDownloadPath = $json.ToolDownloadPath }
                    if ($json.MyProfile) { $global:MyProfile = $json.MyProfile; $count++ }
                    
                    Mark-ConfigDirty; Load-All-Settings; Start-Winapp2-Process; Load-Winget-Tree; Load-Tweak-Tree
                    if (Get-Command "Refresh-Tools-Menu" -ErrorAction SilentlyContinue) { Refresh-Tools-Menu }
                    [System.Windows.MessageBox]::Show("$count kategori başarıyla birleştirildi.", "Bilgi") | Out-Null
                } catch { [System.Windows.MessageBox]::Show("Dosya hatası: $_", "Hata") | Out-Null }
            }
        })
        
        # Dışa Aktar
        $bExp.Add_Click({
            try {
                $rExp = New-Object System.Xml.XmlNodeReader ([xml]$xamlExport); $winExp = [Windows.Markup.XamlReader]::Load($rExp)
                $cBl = $winExp.FindName('chkBlacklist'); $cPo = $winExp.FindName('chkPathOverrides')
                $cCr = $winExp.FindName('chkCustomRules'); $cWi = $winExp.FindName('chkWinget')
                $cTw = $winExp.FindName('chkTweaks'); $cTo = $winExp.FindName('chkTools')
                $cPr = $winExp.FindName('chkMyProfile'); $bDoEx = $winExp.FindName('btnDoExport')
                
                $bDoEx.Add_Click({
                    $sfd = New-Object Microsoft.Win32.SaveFileDialog; $sfd.Filter = "Gemini Ayar Dosyası (*.json)|*.json"; $sfd.FileName = "Gemini_Settings.json"
                    if ($sfd.ShowDialog() -eq $true) {
                        $exportData = [ordered]@{}
                        if ($cBl.IsChecked) { $exportData["Blacklist"] = $global:Blacklist }
                        if ($cPo.IsChecked) { $exportData["PathOverrides"] = $global:PathOverrides }
                        if ($cCr.IsChecked) { $exportData["CustomRules"] = $global:CustomRules }
                        if ($cWi.IsChecked) { $exportData["WingetApps"] = $global:WingetApps }
                        if ($cTw.IsChecked) { $exportData["Tweaks"] = $global:TweakList }
                        if ($cTo.IsChecked) { $exportData["CustomTools"] = $global:CustomTools }
                        if ($cPr.IsChecked) { $exportData["MyProfile"] = $global:MyProfile }
                        $exportData["ToolDownloadPath"] = $global:ToolDownloadPath
                        
                        $exportData | ConvertTo-Json -Depth 10 | Set-Content $sfd.FileName -Encoding UTF8
                        [System.Windows.MessageBox]::Show("Kaydedildi.", "Başarılı") | Out-Null
                        $winExp.Close()
                    }
                })
                $winExp.ShowDialog() | Out-Null
            } catch { WpfLog "Export pencere hatası: $_" }
        })
        
        $winSet.ShowDialog() | Out-Null
    } catch { WpfLog "Ayarlar penceresi hatası: $_" }
})



$btnCleanRAM.Add_Click({
    $btnCleanRAM.IsEnabled = $false
    $btnCleanRAM.Content = "⏳ Temizleniyor..."
    
    # 1. GÖRSEL EFEKT (Parlak Camgöbeği Mavi)
    $pbDashRAM.Foreground =[System.Windows.Media.Brushes]::Cyan
    $txtDashRAM.Foreground =[System.Windows.Media.Brushes]::Cyan

    # 2. TEMİZLİK İŞLEMİ (Satır atlamalara dikkat)
    [RamCleaner]::CleanAll() | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # 3. GÜNCELLEME İÇİN BEKLEME (UI'yi dondurmadan)
    $script:RamEffectTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:RamEffectTimer.Interval =[TimeSpan]::FromMilliseconds(700)
    $script:RamEffectTimer.Add_Tick({
        $script:RamEffectTimer.Stop()

        # En taze RAM verisini ÇEK!
        $ramData =[RamInfo]::GetRamUsageGB()
        $total = [Math]::Round($ramData[0], 1)
        $used  = [Math]::Round($ramData[1], 1)
        $load  = [Math]::Round($ramData[2])

        # Değerleri Yapıştır
        $txtDashRAM.Text = "Kullanılan: $used GB / $total GB"
        $pbDashRAM.Value = $load
        
        # Renkleri Normale Döndür
        $pbDashRAM.Foreground = if ($load -gt 85) { [System.Windows.Media.Brushes]::Red } else {[System.Windows.Media.Brushes]::LimeGreen }
        $txtDashRAM.Foreground =[System.Windows.Media.Brushes]::White

        # Butonu Geri Aç
        $btnCleanRAM.Content = "🧠 Clean RAM"
        $btnCleanRAM.IsEnabled = $true
        
        # LOG ve EKRAN artık 1'e 1 aynı değeri basacak!
        WpfLog "🧠[RAM TEMİZLENDİ] Anlık kullanım %$load ($used GB) seviyesine düştü."
    })
    $script:RamEffectTimer.Start()
})

$btnAnalyze.Add_Click({
    # --- DURDURMA ---
    if ($btnAnalyze.Content -eq "DURDUR") {
        $global:StopOperation = $true
        $btnAnalyze.IsEnabled = $false
        return
    }

    # --- ÖN KONTROL ---
    if ((Check-Browser-Safety) -eq "STOP") { return }
    Check-And-Close-Browsers

    # --- HAZIRLIK ---
    $global:StopOperation = $false
    $btnAnalyze.Content = "DURDUR"
    $btnAnalyze.Background = [System.Windows.Media.Brushes]::Firebrick
    $btnRun.IsEnabled = $false
    $pbMain.IsIndeterminate = $true
    $txtLog.Text = ''
    $script:TotalBytes = 0
    $script:TotalFiles = 0

    WpfLog "--- ANALİZ BAŞLATILIYOR ---"
    WpfLog ("{0,-45} {1,12} {2,10}" -f "ÖĞE", "BOYUT", "DOSYA")
    WpfLog ("─" * 70)

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # --- ANALİZ: UI thread'de çalışır, Do-Events ile UI canlı kalır ---
    # Neden UI thread? Çünkü Resolve-ComplexPath ve $global:Winapp2Rules
    # ana scriptte tanımlıdır, worker runspace'e taşınamaz.
    foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvShellBags)) {
        if ($global:StopOperation) { break }
        Process-Tree $tree.Items 'Analyze'
    }

    $stopwatch.Stop()

    # --- SONUÇ ---
    $pbMain.IsIndeterminate = $false
    $pbMain.Value = 100

    if ($global:StopOperation) {
        WpfLog "!!! ANALİZ DURDURULDU !!!"
        $lblStatus.Text = "Durduruldu."
    } else {
        $duration = "{0:N2} sn" -f $stopwatch.Elapsed.TotalSeconds
        WpfLog ("─" * 70)
        WpfLog ("✅ Analiz Tamamlandı  ({0})" -f $duration)
        WpfLog ("📦 Toplam Silinebilir : {0}" -f (Format-Size $script:TotalBytes))
        WpfLog ("📄 Toplam Dosya/Kayıt: {0}" -f $script:TotalFiles)
        $lblStatus.Text = "Analiz Bitti."
        $lblDetail.Text = "Toplam: $(Format-Size $script:TotalBytes) — $($script:TotalFiles) öğe"
    }

    # --- UI Resetle ---
    $btnAnalyze.Content = "ANALİZ ET"
    $btnAnalyze.Background = [System.Windows.Media.Brushes]::DimGray
    $btnAnalyze.IsEnabled = $true
    $btnRun.IsEnabled = $true
})

$btnRun.Add_Click({
    # --- DURDURMA ---
    if ($btnRun.Content -eq "DURDUR") {
        $global:StopOperation = $true
        $btnRun.IsEnabled = $false
        return
    }

    # --- ÖN KONTROLLER (UI thread'de kalır — messagebox açıyorlar) ---
    $global:ShellBagsTargets = @()
    $global:IsDesktopResetSelected = $false

    if ((Check-Browser-Safety) -eq "STOP") { return }
    Check-And-Close-Browsers
    # NOT: Sistem Geri Yukleme noktasi temizlik icin olusturulmuyor — silinen
    # cache/temp dosyalari zaten restore kapsaminda degil. Sadece Tweaks oncesinde olusturulur.

    # --- HAZIRLIK ---
    $global:StopOperation = $false
    $btnRun.Content = "DURDUR"
    $btnRun.Background = [System.Windows.Media.Brushes]::Firebrick
    $btnAnalyze.IsEnabled = $false
    Save-App-State
    Save-User-Config
    $pbMain.Value = 0
    $txtLog.Text = ''
    WpfLog '--- TEMİZLİK BAŞLIYOR ---'

    # --- TEMİZLİK: UI thread'de çalışır, Do-Events ile UI canlı kalır ---
    # Neden UI thread? Process-Tree, Resolve-ComplexPath, $global:Winapp2Rules,
    # WpfLog, Secure-Remove-Item — hepsi ana scriptte tanımlı, worker'a taşınamaz.
    foreach ($tree in @($tvBrowser, $tvSystem, $tvApps, $tvRepair, $tvShellBags)) {
        if ($global:StopOperation) { break }
        Process-Tree $tree.Items 'Run'
    }

    # --- SHELLBAGS ÖZEL İŞLEMİ ---
    if ($global:ShellBagsTargets.Count -gt 0 -and -not $global:StopOperation) {
        $doReset = $false
        if ($global:IsDesktopResetSelected) {
            $r = [System.Windows.MessageBox]::Show(
                "Masaüstü simgeleri sola yaslanacak. Onaylıyor musunuz?",
                "Uyarı",
                [System.Windows.MessageBoxButton]::YesNoCancel,
                [System.Windows.MessageBoxImage]::Warning)
            if ($r -eq 'Cancel') { $global:ShellBagsTargets = @() }
            elseif ($r -eq 'Yes') { $doReset = $true }
        }

        if ($global:ShellBagsTargets.Count -gt 0) {
            WpfLog "[SİSTEM] Explorer yeniden başlatılıyor (ShellBags)..."
            Start-Process cmd.exe -Arg '/c taskkill /F /IM explorer.exe /IM sihost.exe' -WindowStyle Hidden -Wait
            Start-Sleep -Milliseconds 500

            $batch = ""
            foreach ($t in $global:ShellBagsTargets) {
                if ($t.Name -match "Masaüstü" -and -not $doReset) {
                    try {
                        Get-ChildItem $t.PsPath -Recurse |
                            Where-Object { $_.PSChildName -ne "1" } |
                            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-ItemProperty $t.PsPath * -ErrorAction SilentlyContinue
                        WpfLog "[KORUNDU] Masaüstü düzeni sıfırlanmadı."
                    } catch {}
                } else {
                    $batch += "reg delete `"$($t.Path)`" /f & "
                    WpfLog "[SİLİNDİ] $($t.Name)"
                }
            }
            if ($batch) {
                Start-Process cmd.exe -Arg "/c $batch echo Done" -WindowStyle Hidden -Wait
            }
            if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
                Start-Process explorer.exe
            }
        }
    }

    # --- BİTİŞ ---
    $pbMain.Value = 100

    if ($global:StopOperation) {
        WpfLog "!!! İŞLEM DURDURULDU !!!"
        $lblStatus.Text = "Durduruldu."
    } else {
        WpfLog "----------------------------------------"
        WpfLog "✅ İŞLEM TAMAMLANDI."
        WpfLog "----------------------------------------"
        $lblStatus.Text = "Bitti."
        $lblDetail.Text = "İşlem Başarılı."
    }

    $btnRun.Content = "BAŞLAT"
    $btnRun.Background = [System.Windows.Media.Brushes]::SteelBlue
    $btnRun.IsEnabled = $true
    $btnAnalyze.IsEnabled = $true
})

# Debug Checkbox
if ($chkDebug) { 
    $chkDebug.Add_Click({ 
        if ($chkDebug.IsChecked) { [NativeMethods]::ShowWindow($global:ConsoleHandle, 5) } 
        else { [NativeMethods]::ShowWindow($global:ConsoleHandle, 0) } 
    }) 
}

# --- GÜVENLİ KAPANIŞ VE BELLEK TEMİZLİĞİ (V2 - POOL DESTEKLİ) ---

# #endregion 14 -- EVENT HANDLERS (Butonlar, Context Menus, Tab Selection)


# =========================================================================
# #region 15 -- PENCERE YASAM DONGUSU (Add_Closing, Add_Loaded, ShowDialog)
# =========================================================================

$Win.Add_Closing({
    WpfLog "[SİSTEM] Kapatılıyor, bellek temizleniyor..."
    
    # 1. Tüm Zamanlayıcıları (Timers) Durdur
    # Timer'lar durdurulmazsa arka planda UI nesnelerine erişmeye çalışıp hata fırlatabilirler.
    $allTimers = @(
        $script:WorkerTimer, $script:CrashTimer, $script:DashTimer, 
        $script:FileTimer, $script:GhTimer, $script:UpdTimer, 
        $script:UpdateTimer, $script:PingTimer, $script:WatcherTimer
    )
    foreach ($timer in $allTimers) {
        if ($null -ne $timer -and $timer.IsEnabled) { try { $timer.Stop() } catch {} }
    }

    # 2. Statik Runspace'leri Temizle
    $allRunspaces = @(
        $script:DashRunspace, $script:CrashRunspace, $script:WatcherRunspace, 
        $script:WatcherRunspace2, $script:UpdRunspace
    )
    foreach ($rs in $allRunspaces) {
        if ($null -ne $rs) {
            try {
                # Çalışıyorsa önce durdur, sonra imha et
                $rs.Stop() 
                $rs.Dispose()
            } catch {}
        }
    }

    # 3. YENİ: GLOBAL RUNSPACE POOL KAPATMA (ÇOK KRİTİK)
    # Claude'un P5 maddesi için eklediğimiz havuzu burada tahliye ediyoruz.
    if ($null -ne $global:GeminiPool) {
        try {
            $global:GeminiPool.Close()
            $global:GeminiPool.Dispose()
            $global:GeminiPool = $null
        } catch {}
    }

    # 4. Dinamik Runspace Takip Listesi
    if ($global:ActiveRunspaces) {
        foreach ($rs in $global:ActiveRunspaces) {
            try {
                if ($null -ne $rs) {
                    $rs.Stop()
                    $rs.Dispose()
                }
            } catch {}
        }
        $global:ActiveRunspaces.Clear()
    }

    # 5. Son Durumu Kaydet
    try { Save-App-State } catch {}

    # 6. Geçici Dosya Temizliği (Redundant ama güvenli)
    $tempFiles = @(
        "$env:TEMP\Gemini_W1.txt", "$env:TEMP\Gemini_W2.txt",
        "$env:TEMP\Gemini_Log.txt", "$env:TEMP\Gemini_Status.txt",
        "$env:TEMP\Gemini_Done.flag", "$env:TEMP\Gemini_Worker.ps1"
    )
    foreach ($tf in $tempFiles) {
        if (Test-Path $tf) { try { Remove-Item $tf -Force -ErrorAction SilentlyContinue } catch {} }
    }

    # 7. İşlemciye Kısa Bir Mola (Tüm threadlerin ölmesi için)
    Start-Sleep -Milliseconds 100
})

# --- BİRLEŞTİRİLMİŞ TAB DEĞİŞİM OLAYI (TEK HANDLER) ---
$global:TweaksLoaded = $false 
$global:StartupTabLoaded = $false
# $script:ContextTabLoaded kaldırıldı — "Sağ Tık" TabItem henüz XAML'da yok

$tabControl.Add_SelectionChanged({
    if ($args[1].OriginalSource -is [System.Windows.Controls.TabControl]) {
        $header = $tabControl.SelectedItem.Header

        # 1. Arama Kutusunu Sıfırla
        if ($txtSearch.Text -ne "Uygulama Ara..." -and $txtSearch.Text -ne "") {
            $txtSearch.Text = "Uygulama Ara..."
            $txtSearch.Foreground =[System.Windows.Media.Brushes]::Gray
        }

        # 2. TWEAKS SEKME KONTROLÜ (OTOMATİK DENETLEME EKLENDİ)
        if ($header -eq "Tweaks") {
            if (-not $global:TweaksLoaded) {
                $global:TweaksLoaded = $true
                Show-Privacy-Warning
                Check-Tweak-Status # Tıklandığı an sistemi otomatik tarar!
            }
        }
        # 3. BAŞLANGIÇ SEKME KONTROLÜ
        elseif ($header -eq "Başlangıç") {
            if (-not $global:StartupTabLoaded) {
                $global:StartupTabLoaded = $true
                Refresh-StartupView
            }
        }
        # 4. SAĞ TIK SEKME KONTROLÜ (Gelecekte eklenirse buraya yazılacak)
        # Not: "Sağ Tık" TabItem XAML'da henüz tanımlı değil.
		# 5. Çökme Analizi Sekmesi Açıldığında Durum Kontrolü
        if ($tabControl.SelectedItem.Header -eq "Çökme Analizi") {
            Check-BlackBoxStatus
        }
    }
})

# =========================================================
# KARA KUTU (BLACK BOX) DURUM KONTROLÜ
# =========================================================

# --- GECE MODU DEĞİŞKENLERİ ---
$global:NightModeTimer = $null
$global:NightModeActive = $false
$script:timeLeft = 60 # Geri sayım sayacının donmaması için eklendi

# --- GERİ SAYIM (UYANDIRMA) EKRANI ---

# --- GECE MODU YÖNETİCİSİ (PENCERE) ---
$btnNightMode.Add_Click({
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlNightMode)
    $winNM =[Windows.Markup.XamlReader]::Load($reader)
    $winNM.Owner = $Win

    $tc = $winNM.FindName('tcNightMode')
    $txtH = $winNM.FindName('txtHours'); $txtM = $winNM.FindName('txtMins')
    $cbNS = $winNM.FindName('cbNetSpeed'); $cbNW = $winNM.FindName('cbNetWait')
    $cbP = $winNM.FindName('cbProcess')
    $btnStart = $winNM.FindName('btnStart'); $btnStop = $winNM.FindName('btnStop')
    $txtStat = $winNM.FindName('txtStatus')

    # Aktif programları çek
    Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -or $_.Name -match 'steam|epic|ea|battle|riot|qitt|xbox' } | Select-Object -Unique Name | Sort-Object Name | ForEach-Object {
        $cbP.Items.Add("$($_.Name).exe") | Out-Null
    }
    if ($cbP.Items.Count -gt 0) { $cbP.SelectedIndex = 0 }

    # Eğer halihazırda çalışıyorsa UI'ı güncelle
    if ($global:NightModeActive) {
        $btnStart.IsEnabled = $false; $btnStop.IsEnabled = $true
        $txtStat.Text = "Gece Modu arka planda aktif çalışıyor!"
        $txtStat.Foreground =[System.Windows.Media.Brushes]::LimeGreen
    }

    $btnStart.Add_Click({
        $global:NightModeActive = $true
        $mode = $tc.SelectedIndex
        $btnStart.IsEnabled = $false; $btnStop.IsEnabled = $true
        $btnNightMode.Content = "🌙 Gece Modu (Aktif)"
        $btnNightMode.Foreground =[System.Windows.Media.Brushes]::LimeGreen

        $script:nmMode = $mode
        $script:nmTargetTime = $null
        $script:nmIdleTicks = 0
        $script:nmThreshold = 0
        $script:nmDurationSecs = 0
        $script:nmPID = 0
        $script:nmLastNetBytes = 0
        $script:nmLastIOBytes = 0

        # --- 1. SÜRE MODU (KUTU BOŞ BIRAKILMA SORUNU ÇÖZÜLDÜ) ---
        if ($mode -eq 0) {
            # Kutular boşsa "0" olarak kabul et
            $hVal = if ([string]::IsNullOrWhiteSpace($txtH.Text)) { "0" } else { $txtH.Text }
            $mVal = if ([string]::IsNullOrWhiteSpace($txtM.Text)) { "0" } else { $txtM.Text }

            $h = 0; $m = 0
            if ([int]::TryParse($hVal, [ref]$h) -and [int]::TryParse($mVal,[ref]$m) -and ($h -gt 0 -or $m -gt 0)) {
                $script:nmTargetTime = (Get-Date).AddHours($h).AddMinutes($m)
                $txtStat.Text = "Sistem şu saatte kapanacak: $($script:nmTargetTime.ToString('HH:mm:ss'))"
                WpfLog "🌙 [GECE MODU] Saat $($script:nmTargetTime.ToString('HH:mm:ss')) olarak ayarlandı."
            } else {
                $txtStat.Text = "Lütfen geçerli bir süre girin (Örn: Sadece 5 dk)."
                $global:NightModeActive = $false; $btnStart.IsEnabled = $true; $btnStop.IsEnabled = $false; return
            }
        }
        # --- 2. AĞ MODU ---
        elseif ($mode -eq 1) {
            $script:nmThreshold = [double]$cbNS.SelectedItem.Tag # Mbps
            $script:nmDurationSecs = [int]$cbNW.SelectedItem.Tag * 60
            $txtStat.Text = "İndirme hızı $($script:nmThreshold) Mbps altına $($cbNW.SelectedItem.Tag) dk düşerse kapanacak."
            WpfLog "🌙 [GECE MODU] Ağ hızı limiti: $($script:nmThreshold) Mbps."
            
            $adapters = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' }
            foreach ($a in $adapters) { $script:nmLastNetBytes += $a.GetIPv4Statistics().BytesReceived }
        }
        # --- 3. UYGULAMA (I/O) MODU ---
        elseif ($mode -eq 2) {
            $pName = $cbP.SelectedItem.ToString() -replace '\.exe$',''
            $proc = Get-Process -Name $pName -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $proc) {
                $txtStat.Text = "Uygulama çalışmıyor veya bulunamadı!"
                $global:NightModeActive = $false; $btnStart.IsEnabled = $true; $btnStop.IsEnabled = $false; return
            }
            $script:nmPID = $proc.Id
            $script:nmDurationSecs = 300 
            $script:nmLastIOBytes = [ProcessMonitor]::GetProcessTotalIo($script:nmPID)
            
            $txtStat.Text = "$pName izleniyor. İndirme/Kurulum bittiğinde sistem kapanacak."
            WpfLog "🌙 [GECE MODU] Uygulama takibi başlatıldı: $pName"
        }

        # --- ANA TAKİP ZAMANLAYICISI ---
        if ($global:NightModeTimer) { $global:NightModeTimer.Stop() }
        $global:NightModeTimer = New-Object System.Windows.Threading.DispatcherTimer
        $global:NightModeTimer.Interval =[TimeSpan]::FromSeconds(5) 
        
        $global:NightModeTimer.Add_Tick({
            if (-not $global:NightModeActive) { $global:NightModeTimer.Stop(); return }

            # 1. Süre Kontrolü
            if ($script:nmMode -eq 0) {
                if ((Get-Date) -ge $script:nmTargetTime) { Start-ShutdownCountdown }
            }
            # 2. Ağ Kontrolü
            elseif ($script:nmMode -eq 1) {
                $adapters = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' }
                $currentBytes = 0
                foreach ($a in $adapters) { $currentBytes += $a.GetIPv4Statistics().BytesReceived }
                
                $diff = $currentBytes - $script:nmLastNetBytes
                $mbps = ($diff * 8) / (5 * 1024 * 1024) 
                $script:nmLastNetBytes = $currentBytes

                if ($mbps -lt $script:nmThreshold) { $script:nmIdleTicks += 5 } else { $script:nmIdleTicks = 0 }
                if ($script:nmIdleTicks -ge $script:nmDurationSecs) { Start-ShutdownCountdown }
            }
            # 3. Uygulama I/O Kontrolü
            elseif ($script:nmMode -eq 2) {
                $currentIO = [ProcessMonitor]::GetProcessTotalIo($script:nmPID)
                
                if ($currentIO -eq -1) { 
                    Start-ShutdownCountdown
                    return 
                }

                $diffIO = $currentIO - $script:nmLastIOBytes
                $script:nmLastIOBytes = $currentIO

                if ($diffIO -lt 1048576) { $script:nmIdleTicks += 5 } else { $script:nmIdleTicks = 0 }
                if ($script:nmIdleTicks -ge $script:nmDurationSecs) { Start-ShutdownCountdown }
            }
        })
        $global:NightModeTimer.Start()
    })

    $btnStop.Add_Click({
        $global:NightModeActive = $false
        if ($global:NightModeTimer) { $global:NightModeTimer.Stop() }
        $btnNightMode.Content = "🌙 Shutdown"
        $btnNightMode.Foreground = [System.Windows.Media.Brushes]::Cyan
        
        $btnStart.IsEnabled = $true; $btnStop.IsEnabled = $false
        $txtStat.Text = "Gece Modu durduruldu."
        WpfLog "🌙 [GECE MODU] İptal edildi."
    })

    $winNM.ShowDialog() | Out-Null
})

# Winapp2 Editör Penceresi


# --- CANLI RAM İZLEYİCİ (GÖREV YÖNETİCİSİ HIZINDA) ---
$script:LiveRamTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:LiveRamTimer.Interval = [TimeSpan]::FromSeconds(1)
$script:LiveRamTimer.Add_Tick({
    # Eğer temizlik yapılıyorsa araya girmesin diye "IsEnabled" kontrolü eklendi
    if ($tabDashboard.IsSelected -and $btnCleanRAM.IsEnabled) {
        $ramData = [RamInfo]::GetRamUsageGB()
        if ($ramData[0] -gt 0) {
            $total = [Math]::Round($ramData[0], 1)
            $used  = [Math]::Round($ramData[1], 1)
            $load  = [Math]::Round($ramData[2]) # Kusursuz yüzdemiz
            
            $txtDashRAM.Text = "Kullanılan: $used GB / $total GB"
            $pbDashRAM.Value = $load
            $pbDashRAM.Foreground = if ($load -gt 85) { [System.Windows.Media.Brushes]::Red } else {[System.Windows.Media.Brushes]::LimeGreen }
        }
    }
})
$script:LiveRamTimer.Start()

# =========================================================
# DETAYLI DONANIM BILGISI PENCERESI (v4)
# - RAM: JEDEC satiri kaldirildi
# - GPU: PCI SUBSYS SubVendor ID ile AIB tespiti (ASUS, MSI, vb.)
# =========================================================



# =========================================================
# ANA KONTROL PANELİ MOTORU (ASENKRON YÜKLEME)
# =========================================================

# =========================================================
# BÜYÜK DOSYA TARAMA MOTORU (HIGH PERFORMANCE + SORTING)
# =========================================================


# --- BÜYÜK DOSYA OLAYLARI ---

$btnScanFiles.Add_Click({ Start-LargeFileScan })

# --- SÜTUN BAŞLIĞINA TIKLAYINCA SIRALAMA (COLUMN SORTING) ---
$script:LastSortCol = ""
$script:SortDirection = "Ascending"

# ListView Header Tıklama Olayını Yakala
$lvLargeFiles.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    
    # Tıklanan şey bir Sütun Başlığı mı?
    if ($e.OriginalSource -is [System.Windows.Controls.GridViewColumnHeader]) {
        $header = $e.OriginalSource
        
        # Boşluğa (Padding) tıklanırsa işlem yapma
        if ($header.Role -ne "Padding") {
            $colName = $header.Content.ToString()
            $sortBy = ""

            # Başlık ismine göre hangi veriye göre sıralayacağını seç
            switch ($colName) {
                "DOSYA ADI" { $sortBy = "Name" }
                "BOYUT"     { $sortBy = "SizeRaw" } # Metne göre değil, BAYT değerine göre sırala!
                "TÜR"       { $sortBy = "Extension" }
                "KONUM"     { $sortBy = "Folder" }
                "TARİH"     { $sortBy = "Date" }
            }

            if ($sortBy) {
                # Yönü Belirle (Aynı sütuna tıklarsan tersine çevir)
                $direction = "Ascending"
                if ($script:LastSortCol -eq $sortBy -and $script:SortDirection -eq "Ascending") {
                    $direction = "Descending"
                }
                
                $script:LastSortCol = $sortBy
                $script:SortDirection = $direction

                # Sıralamayı Uygula
                $view = $lvLargeFiles.Items
                $view.SortDescriptions.Clear()
                $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription $sortBy, $direction))
            }
        }
    }
})

# SAĞ TIK: KONUMU AÇ (API İLE KESİN SEÇİM)
$ctxOpenLargeFile.Add_Click({
    if ($lvLargeFiles.SelectedItem) {
        $path = $lvLargeFiles.SelectedItem.FullName
        if (Test-Path $path) { 
            # Eski yöntem yerine API kullanıyoruz
            [FileSelector]::Select($path)
        }
    }
})

# SAĞ TIK: YOLU KOPYALA
$ctxCopyLargePath.Add_Click({
    if ($lvLargeFiles.SelectedItem) {
        [System.Windows.Clipboard]::SetText($lvLargeFiles.SelectedItem.FullName)
    }
})

# SAĞ TIK: KALICI SİL
$ctxDeleteLargeFile.Add_Click({
    if ($lvLargeFiles.SelectedItem) {
        $item = $lvLargeFiles.SelectedItem
        $msg = "Dosya: $($item.Name)`nBoyut: $($item.SizeStr)`n`nBu dosya KALICI OLARAK silinecek. Geri dönüşüm kutusuna gitmez!`nEmin misiniz?"
        
        if ([System.Windows.MessageBox]::Show($msg, "Dosya Silme", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning) -eq 'Yes') {
            try {
                Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                $lvLargeFiles.Items.Remove($item)
                WpfLog "🗑️ [SİLİNDİ] $($item.FullName)"
            } catch {
                [System.Windows.MessageBox]::Show("Silinemedi. Dosya kullanımda olabilir veya yetki yok.", "Hata") | Out-Null
            }
        }
    }
})

# --- OLAYLAR (EVENTS) ---
# (SelectionChanged handler'ları yukarıda birleştirildi)

$Win.Add_Loaded({
    # === DEBUG: tüm açılış adımlarını try/catch ile sarmal, hataları log'a yaz ===
    # Boyle bir hata cikarsa MessageBox yerine WpfLog'da gorunur (PS2EXE NoConsole'da MessageBox spam onlenir)
    function Invoke-InitStep {
        param([string]$StepName, [scriptblock]$Action)
        try {
            & $Action
            WpfLog "[INIT] ✓ $StepName"
        } catch {
            WpfLog "[INIT-ERR] ✗ ${StepName}: $($_.Exception.Message)"
            WpfLog "[INIT-ERR]    StackTrace: $($_.ScriptStackTrace -split "`n" | Select-Object -First 3 | Out-String)"
        }
    }

    WpfLog "═══ AÇILIŞ DEBUG LOG (v$($global:AppVersion)) ═══"

    # 1. Onceki dosyalardan kalan .old/staging temizligi (Auto-update icin)
    Invoke-InitStep "Cleanup-OldUpdateFiles" { Cleanup-OldUpdateFiles }

    # 2. Ayarlar ve Veritabani
    Invoke-InitStep "Start-Winapp2-Process" { Start-Winapp2-Process }
    Invoke-InitStep "Load-DashboardData"    { Load-DashboardData }

    # 3. Layout tercihi
    Invoke-InitStep "Layout uygula" {
        if ($global:AppLayout -eq "Top") {
            $tabControl.TabStripPlacement = "Top"
            foreach ($tab in $tabControl.Items) {
                $tab.Width = [double]::NaN
                $tab.Height = 30
            }
        } else {
            $tabControl.TabStripPlacement = "Left"
        }
    }

    # 4. Listeler
    Invoke-InitStep "Load-Winget-Tree"  { Load-Winget-Tree }
    Invoke-InitStep "Load-Tweak-Tree"   { Load-Tweak-Tree }
    Invoke-InitStep "Load-Repair-Tree"  { Load-Repair-Tree }
    Invoke-InitStep "Refresh-Tools-Menu" { Refresh-Tools-Menu }

    # 5. Auto-update kontrol (async)
    Invoke-InitStep "Test-AppUpdate (async)" { Test-AppUpdate }

    WpfLog "═══ AÇILIŞ TAMAMLANDI ═══"
})
$Win.ShowDialog() | Out-Null

# #endregion 15 -- PENCERE YASAM DONGUSU (Add_Closing, Add_Loaded, ShowDialog)

