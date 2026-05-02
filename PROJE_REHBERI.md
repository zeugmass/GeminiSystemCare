# GEMINI SİSTEM BAKIM ARACI — PROJE REHBERİ

> Bu dosya projeyi tekrar tekrar okumak yerine satır numaralarıyla doğrudan ilgili yere gidebilmek için referanstır.
> Kullanıcı bir değişiklik istediğinde önce buraya bak → region numarasını/satır numarasını bul → sadece o bölümü oku ve düzenle.

**Son güncelleme:** Faz 2 tamamlandı — tüm dosya `#region` başlıklarıyla 15 bölüme ayrıldı, dağınık 15 fonksiyon tek bir UI/MODAL kümesine toplandı.

---

## 0. DOSYALAR

| Dosya | Satır | Görev |
|---|---|---|
| `TemizlikAsistani.ps1` | **~13.500** | Ana uygulama (PowerShell + WPF XAML + C# P/Invoke) |
| `.github/workflows/build-release.yml` | 110 | CI/CD — tag push'unda PS2EXE compile + Release |
| `README.md` | 165 | Kullanıcı + geliştirici dokümantasyonu |
| `Launcher.ps1` | 36 | EXE/PS1 köprü launcher (öncelik: EXE) |
| `TemizlikAsistani.ps1.backup` | 11.305 | Faz 1 öncesi (NVIDIA'lı) yedek |
| `TemizlikAsistani.ps1.phase1_backup` | 10.425 | Faz 1 sonrası / Faz 2 öncesi yedek |
| `Baslat.cmd` | 59 | UAC elevation + çoklu çalışma engeli + başlatıcı |
| `Launcher.ps1` | 47 | GitHub versiyon kontrol (URL'ler placeholder, aktif değil) |
| `BeniOku.txt` | 52 | Kullanıcı rehberi (TR) |

Teknoloji: **PowerShell 5.1+ · WPF (XAML) · C# (Add-Type) · Runspace Pool (4 thread)**

---

## 1. REGION HARİTASI (15 Bölüm)

Dosya başında TOC var. VS Code'da `Ctrl+K Ctrl+0` ile tüm region'ları katlarsın, istediğini açarsın.

| # | Region | Satır Aralığı | İçindekiler |
|---|---|---|---|
| 01 | **C# INTEROP** | 28–183 | `$nativeCode` (Add-Type) — `NativeMethods`, `FileSelector`, `SecureWiper`, `RamCleaner`, `RamInfo`, `ProcessMonitor` |
| 02 | **YÖNETİCİ KONTROL, RUNSPACE POOL, TEMA** | 187–219 | `Refresh-WindowsTheme`, `Refresh-Wallpaper`, admin check, GeminiPool |
| 03 | **GLOBAL DEĞİŞKENLER & DOSYA YOLLARI** | 223–280 | `$AppDataPath`, `$global:*` (Blacklist, MyProfile, StopOperation, vb.) |
| 04 | **VARSAYILAN VERİLER** | 284–1075 | `Get-Default-Tweaks` (106 tweak), `Get-Default-WingetApps`, `Load-Repair-Tree`, `Get-SelectedTasks` |
| 05 | **XAML TANIMLARI** | 1079–2467 | Ana pencere + 12 alt pencere heredoc (ToolMgr, Settings, NightMode, Countdown, Export, WingetMgr, TweakMgr, PrivacyWarn, Blacklist, CustomMgr, AddCustom, PathEdit) |
| 06 | **XAML YÜKLEME & FINDNAME BAĞLAMALARI** | 2471–2670 | `$Win = XamlReader.Load`, 150+ `$xxx = $Win.FindName(...)` satırı, Logo/İkon, DoEventsTimer |
| 07 | **ÇEKİRDEK HELPERLAR** | 2675–2725 | `Do-Events`, `WpfLog`, `Format-Size` |
| 08 | **AYAR YÖNETİMİ** | 2729–2924 | `Save-App-State`, `Load-All-Settings`, `Save-User-Config`, `Mark-ConfigDirty`, `Restore-Checkboxes` |
| 09 | **TWEAK SİSTEMİ** | 2929–3862 | `Create-Restore-Point`, `Refresh-PowerCfg-Cache`, `Get-Tweak-IsActive`, `Load-Tweak-Tree`, `Apply-System-Tweaks`, `Show-TweakManager`, `Check-Tweak-Status` |
| 10 | **TEMİZLİK MOTORU** | 3866–4597 | `Check-And-Close-Browsers`, `Start-Winapp2-Process`, `Parse-Winapp2`, `Load-Winget-Tree`, `Secure-Remove-Item`, `Resolve-ComplexPath`, `Run-CMD-Realtime`, `Process-Tree` |
| 11 | **WORKER & KOMUT ÇALIŞTIRMA** | 4601–4783 | `Start-Worker-Process` (timeout+stop), `Refresh-Winget-Status` |
| 12 | **BAŞLANGIÇ YÖNETİCİSİ** | 4788–5002 | `Refresh-StartupView` |
| 13 | **UI / MODAL FONKSİYONLARI** | 5004–7891 | Fill-WatcherComboBox, Get-WebLink, Refresh-Tools-Menu, Show-ToolManager, Show-RecommendedProfiles, Show-ProfileManager, Check-BlackBoxStatus, Start-ShutdownCountdown, Show-Winapp2Editor, Show-UpdateWindow, Show-RestartDialog, Show-HardwareDetail, Load-DashboardData, Show-BloatwareManager, Start-LargeFileScan + 4 tool script block ($script:RunEmbeddedToolBlock, vb.) |
| 14 | **EVENT HANDLERS** | 7898–10168 | Tüm buton click'leri, context menu handler'ları, tab selection, window closing |
| 15 | **PENCERE YAŞAM DÖNGÜSÜ** | 10172–10593 | `$Win.Add_Loaded`, `$Win.ShowDialog()` + bazı handler devamları |

---

## 2. KRİTİK FONKSİYONLAR (yerini hızlı bulmak için)

### Core / Helpers
| Fonksiyon | Satır | Region |
|---|---|---|
| `Do-Events` | 2677 | 07 |
| `WpfLog` | 2689 | 07 |
| `Format-Size` | 2716 | 07 |

### Config
| Fonksiyon | Satır | Region |
|---|---|---|
| `Save-App-State` | 2731 | 08 |
| `Load-All-Settings` | 2755 | 08 |
| `Save-User-Config` | 2876 | 08 |
| `Restore-Checkboxes` | 2903 | 08 |

### Tweak
| Fonksiyon | Satır | Region |
|---|---|---|
| `Get-Default-Tweaks` | ~290 | 04 |
| `Create-Restore-Point` | ~2930 | 09 |
| `Get-Tweak-IsActive` | ~2985 | 09 |
| `Apply-System-Tweaks` | ~3360 | 09 |
| `Check-Tweak-Status` | ~3765 | 09 |

### Temizlik Motoru
| Fonksiyon | Satır | Region |
|---|---|---|
| `Resolve-ComplexPath` | ~4305 | 10 |
| `Process-Tree` | ~4537 | 10 |
| `Run-CMD-Realtime` | ~4421 | 10 |

### Worker (Faz 1'de yenilendi: timeout + stop + race önleme)
| Fonksiyon | Satır | Region |
|---|---|---|
| `Start-Worker-Process` | ~4610 | 11 |
| `Refresh-Winget-Status` | ~4750 | 11 |

### UI / Modal (hepsi region 13'te)
| Fonksiyon | Satır | Region |
|---|---|---|
| `Fill-WatcherComboBox` | ~5010 | 13 |
| `Get-WebLink` | ~5055 | 13 |
| `Refresh-Tools-Menu` | ~5105 | 13 |
| `Show-ToolManager` | ~5585 | 13 |
| `Show-RecommendedProfiles` | ~5745 | 13 |
| `Show-ProfileManager` | ~6140 | 13 |
| `Check-BlackBoxStatus` | ~6375 | 13 |
| `Start-ShutdownCountdown` | ~6425 | 13 |
| `Show-Winapp2Editor` | ~6465 | 13 |
| `Show-UpdateWindow` | ~6585 | 13 |
| `Show-RestartDialog` | ~6840 | 13 |
| `Show-HardwareDetail` | ~6900 | 13 |
| `Load-DashboardData` | ~7320 | 13 |
| `Show-BloatwareManager` | ~7615 | 13 |
| `Start-LargeFileScan` | ~7735 | 13 |

(Satır numaraları ± birkaç satır oynayabilir, Grep ile kesin konum doğrula.)

---

## 3. XAML SEKMELER (11 tab — Driver kaldırıldı)

Ana pencere region 05 içinde (L1079–2467):

| # | Sekme | x:Name | Tree/List |
|---|---|---|---|
| 1 | Genel Bakış | `tabDashboard` | TextBlock'lar + ping |
| 2 | Tarayıcılar | `tabBrowsers` | `tvBrowser` |
| 3 | Uygulamalar | `tabApps` | `tvApps` |
| 4 | Sistem | `tabSystem` | `tvSystem` |
| 5 | ShellBags | `tabShellBags` | registry |
| 6 | Onarım | `tabRepair` | `tvRepair` |
| 7 | Winget | `tabWinget` | `tvWinget` |
| 8 | Tweaks | `tabTweaks` | `tvTweaks` |
| 9 | Başlangıç | `tabStartup` | `lvStartup` |
| 10 | Dosya Boyutu | `tabLargeFiles` | `lvLargeFiles` |
| 11 | Çökme Analizi | `tabCrash` | `lvCrashes` |

22 XAML heredoc bloğu var (ana + alt pencereler). Hepsi testle XamlReader.Load ile doğrulandı.

---

## 4. DOSYA YOLLARI (sabit)

```
$AppDataPath    = %APPDATA%\GeminiCare
$UserConfigPath = $AppDataPath\user_config.json
$AppStatePath   = $AppDataPath\app_state.json
$CachePath      = $AppDataPath\app_cache.json
$Winapp2Path    = $AppDataPath\Winapp2.ini
$NoCacheFlag    = $AppDataPath\no_cache.flag
```

---

## 5. DEĞİŞİKLİK GEÇMİŞİ

### Faz 1 (bug fix + NVIDIA kaldırma)
- NVIDIA Driver sekmesi + TempMonitor tamamen silindi (920 satır)
- `Start-Worker-Process` yenilendi: `$TimeoutSeconds` (default 30 dk) + stop mekanizması + race önleme (`$finishedRef`) + ActiveRunspaces tracking
- `Process-Tree` her iterasyonda `Do-Events` çağırıyor (UI donma + stop button fix)
- Ultimate Performance regex: `@(...) | Select-First 1` edge case
- Kritik catch log'ları (Registry cleanup, Privacy Warning)

### Faz 2 (reorganizasyon)
- 15 dağınık fonksiyon region 13'e toplandı (~2,852 satır taşıma)
- 15 `#region`/`#endregion` çifti eklendi
- Dosya başına İçindekiler Tablosu (TOC) eklendi
- Syntax + 22 XAML bloğu testlerden temiz geçti

### MSI Utility V3: Base64 → GitHub download (Faz 2 sonrası)
- `$global:MsiUtilityBase64` (~60 KB base64 string) dosyadan silindi
- `$script:RunBase64ToolBlock` → `$script:RunMsiUtilityBlock` olarak yenilendi:
  - İlk kullanımda `https://raw.githubusercontent.com/zeugmass/MSI_Utility_v3/main/MSI_util_v3.exe` → `%APPDATA%\GeminiCare\MSI_Utility_V3.exe`
  - Sonraki kullanımlarda cache'den direkt çalıştırır (download yok)
  - `Start-Worker-Process` ile async (UI donmaz)
- Tools menüsündeki `if ($global:MsiUtilityBase64...)` check'i kaldırıldı, her zaman gösterir
- **Sonuç:** Dosya 614 KB → 552 KB, antivirüs dostu

### Tweaks Sekmesi Büyük Revizyonu (Sprint 1-4 + E1 + E2)
**Sprint 1 — Restart Explorer + Performans:**
- `RestartExplorer` field artık 3 değerli: `$false` / `"Soft"` / `"Hard"` (geriye uyumlu: eski `$true` = Hard)
- HideFileExt, Hidden, Bu Bilgisayar Simgesi → "Soft" (artık Explorer kapanıp açılmıyor, açık pencereler refresh oluyor)
- Görsel Efektler, Başlat Önerilenler, Klasik Sağ Tık → "Hard"
- Yeni helper'lar: `Invoke-ShellSoftRefresh` (SHChangeNotify+WM_SETTINGCHANGE) ve `Invoke-ExplorerHardRestart` (`/factory,{75dff2b7-...}` ile boş pencere açmaz)
- **`Check-Tweak-Status` async/chunked + cache** (Tweaks sekmesi açıldığında donma yok). Cache `%APPDATA%\GeminiCare\tweak_status_cache.json`, 30 dk TTL, her 20ms'de 10 tweak işlenir, UI canlı kalır

**Sprint 2 — Config Güvenliği:**
- `Save-User-Config`: atomic write (.tmp → verify → backup rotate → rename)
- 5 seviyeli rotating backup: `config.json.bak1` (en yeni) … `.bak5` (en eski)
- `_schema = 2` versioning + future migration desteği
- Bozuk config tespitinde `Show-ConfigRecoveryDialog`: Yedekten yükle / Varsayılana dön / Kapat

**Sprint 3 — Tweak Manager (Yönet):**
- **🔁 Klonla butonu**: Seçili tweak'i base alarak yeni tweak yarat
- **JSON schema validation save'de**: zorunlu alanlar, registry path formatı (HKCU:\\…), eksik tip uyarısı
- **📋 Önizleme paneli**: Selection değişince/yenile butonuna basınca form içeriği yeşil-on-black readonly TextBox'ta gösterilir
- **Conflict detection**: Aynı Key+ValueName'i farklı tweak değiştiriyorsa save'de uyarı (Batch içleri dahil)
- **`chkRestart` → `cbRestartMode`** (Yok / Soft / Hard) + **`cbRiskLevel`** (🟢 Düşük / 🟡 Orta / 🔴 Yüksek) dropdownları
- **BUG FIX**: Sağ tık → Açıklama Düzenle artık mevcut açıklamayı yüklüyor (Load-All-Settings'te `ItemDescriptions` yüklenmiyordu)

**Sprint 4 — Ana Sekme UX:**
- **Search/filter geliştirme**: Header + Registry Key + ValueName + Group + Description + ItemDescriptions hepsinde arar, 250ms debounce
- **Tooltip**: Sprint 3.5 sayesinde ItemDescriptions yüklendiği için tüm tweak'lerde tooltip çalışıyor
- **↶ Quick Undo butonu**: Tweaks sekmesi altında. Apply sonrası aktif olur, tıklanırsa son apply'ı tersine çevirir (`Invoke-QuickUndo`)
- **Yüksek risk uyarısı**: Apply sırasında `Risk="High"` tweak'ler için ekstra onay penceresi

**Bonus:**
- **E1 — Audit log**: `%APPDATA%\GeminiCare\tweak_history.log` her Apply ve QuickUndo işlemini timestamp'li yazar (5 MB üzeri otomatik yarıya kesilir)
- **E2 — Profil diff**: Recommended Profiles uygulanırken onay mesajında "X zaten aktif, Y yeni uygulanacak" diff bilgisi

**Yeni global'ler:**
- `$global:LastTweakOperation` (Quick Undo için snapshot)
- `$global:TweakStatusCache` + `$global:TweakStatusCachePath` + `$global:TweakStatusCacheTTL`

### Sprint: GPU Tweak'leri + Vendor Altyapısı + Background Apps + MSI Mode
**Yeni eklenenler:**

**1) Vendor altyapısı (region 9)**
- `$global:DetectedGpuVendors` (lazy-loaded array, region 3)
- `Get-System-Gpu-Vendors` helper (region 9 başı): Win32_VideoController'dan NVIDIA/AMD/Intel parse eder, hibrit destekli
- `Apply-System-Tweaks` içinde **Vendor uyumsuzluk uyarısı** (Risk="High" altında, mevcut MessageBox patterniyle aynı): Tweak'in `Vendor` field'ı sistemdeki GPU'larla eşleşmiyorsa Apply'da uyarı verilir, kullanıcı Yes/No seçer

**2) Yeni tweak'ler (Get-Default-Tweaks, region 4)**
- **Gizlilik ve Telemetri** kategorisine: `Arka Plan Uygulamalarını Kapat (Sistem Politikası)` — `LetAppsRunInBackground=2` (Group Policy, mevcut "(UWP)" tweak'inden farklı: HKLM-wide)
- **🎮 Low Latency (Espor)** kategorisine: `MSI Mode (GPU Interrupt) Aç` — tüm Display class GPU'lara `MSISupported=1` (Get-PnpDevice loop). DetectScript yok, IsActive special-case eklendi (Get-Tweak-IsActive Command/Batch dalı, "MSI Mode" name match)
- **Yeni kategori "🎮 GPU Ayarları (Manuel)"** — Vendor-specific, profile'a dahil değil:
  - `AMD Adrenalin Optimizasyonu` (Vendor="AMD"): Reklam/popup/bildirim/auto-update kapat + grafik profil custom + UMD/power_v1 binary writes. Adrenalin yazılımını 30 sn açıp kapatır (registry commit zorunlu).
  - `NVIDIA Optimizasyonu` (Vendor="NVIDIA"): Registry tweak'leri (PhysX→GPU, DevTools, RmProfilingAdminOnly, NvTray off, EnableGR535) + NVIDIA Profile Inspector ile Control Panel auto-config. **Otomatik backup**: Apply öncesi mevcut .nip yedeklenir (`%APPDATA%\GeminiCare\nvidia_profile_backup.nip`), Undo'da geri yüklenir → kullanıcının custom profilleri korunur.

**3) NVIDIA Inspector helper (region 9)**
- `Get-NvidiaInspectorPath`: 2-kademeli download (cache yoksa)
  - Kademe 1: `https://github.com/FR33THYFR33THY/Ultimate-Files/raw/...inspector.exe` (tek .exe, ~1 MB) — MSI Utility V3 ile aynı pattern
  - Kademe 2: `Orbmu2k/nvidiaProfileInspector` Releases API → en son stabil .zip → Expand-Archive → exe extract
  - Cache: `%APPDATA%\GeminiCare\nvidiaProfileInspector.exe`
  - Hata durumunda `$null` döner — caller registry tweak'lerini yine de uygular (graceful degradation)

**4) Recommended Profiles güncellemesi (region 13, `$script:RecommendedProfiles`)**
- Oyun profile: 14 → **15 tweak** (MSI Mode eklendi)
- Gizlilik profile: 15 → **16 tweak** (Background Apps eklendi)
- Hız profile: değişmedi (9 tweak)
- XAML kart "tweak sayısı" Run elementleri güncellendi
- NVIDIA/AMD vendor-tagged tweak'ler **profile'a DAHİL DEĞİL** — kullanıcı manuel seçer

**5) NVIDIA .nip XML (region 3 globalleri)**
- `$global:NvidiaInspectorOptimizedNip` — FR33THY tabanlı 30 NVCpl ayarı
- `$global:NvidiaInspectorEmptyNip` — Undo backup yoksa fallback (boş profil)
- "Preferred OpenGL GPU" string RTX 4090 ID'si — NVIDIA sürücüsü farklı GPU'da otomatik seçime düşer (resmi belge yok, ampirik). Description'da uyarı var.

**Toplam:** 77 → **79 tweak** (hesaplı, bazı kategoride sayı değişti), 12 → **13 kategori**, 0 → **2 Vendor tagged**.

#### FR33THY birebir uyumluluk düzeltmeleri (sprint sonu)
İlk implementasyondan sonra orijinal FR33THY scriptleriyle byte-level karşılaştırma yapıldı, 6 sapma düzeltildi:

1. **NVIDIA Legacy Sharpen** — orijinal 3 yola yazıyor (ControlSet001 + 2× CurrentControlSet), ben 2 yazıyordum. 3. yol eklendi (Apply ve Undo).
2. **AMD Undo'da silmek yerine spesifik default değerleri yaz** (orijinal ne yapıyorsa):
   - `IsAutoDefault` → REG_DWORD 1 (orijinal REG_BINARY'den DWORD'a tip değiştiriyor — birebir uygulandı)
   - `VSyncControl` → REG_BINARY `31000000`
   - `Tessellation` → REG_BINARY `360034000000` (6 byte)
   - `Tessellation_OPTION` → REG_BINARY `30000000`
   - `IsComponentControl` → REG_BINARY `00000000`
   - `TFQ`, `abmlevel`, Notification subkey'leri ise orijinalde de silinerek geri alınıyor → mantık korundu
3. **`-silent` flag'i** — orijinal `inspector.exe -silentImport -silent` kullanıyor; tek başına `-silentImport` yetersiz olabilir → eklendi (3 çağrı: optimize, backup restore, empty)
4. **`CurrentControlSet` → `ControlSet001`** — orijinal hangi pattern'i kullanıyorsa o:
   - `nvlddmkm\Parameters\Global\NVTweak` (PhysX, DevTools, RmProfilingAdminOnly nvlddmkm) → ControlSet001
   - Class GUID subkey iterator'ları → CurrentControlSet (orijinalle aynı)
   - Legacy Sharpen 3 yol → 2× CurrentControlSet + 1× ControlSet001 (orijinalle aynı, mixed)
   - AMD `basePath` (`Class\{4d36e968-...}`) → ControlSet001
   - MSI Mode `Enum\$instId` → ControlSet001
5. **MSI Mode `-Status OK` filtresi kaldırıldı** — orijinal disabled GPU'lara da yazıyor; ben aktif olanları filtreliyordum, artık tüm Display GPU'lara yazıyor (Apply, Undo, IsActive)
6. **Auto-open settings/Control Panel** — orijinal Apply sonunda görsel doğrulama için açıyor:
   - Background Apps: tweak Key/Value yapısından Command/UndoCommand+DetectScript'e dönüştürüldü → `Start-Process ms-settings:privacy-backgroundapps` Apply ve Undo'da
   - NVIDIA: `Start-Process "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_..."` Apply ve Undo'da

**Sonuç:** Apply tarafı %100, Undo tarafı %95+ FR33THY birebir. Geriye kalan farklar bilinçli/onaylı (7zip atlandı, Inspector cache, NVIDIA backup .nip).

---

### Sprint: Auto-Update Altyapısı + GitHub Releases CI/CD + PS2EXE

**Hedef:** Programı GitHub'da host etmek, kullanıcılarda otomatik güncelleme bildirimi + tek tıkla self-update + GitHub Actions ile otomatik EXE compile + release.

#### Mimari kararlar (kullanıcı onayıyla)
| Karar | Seçim |
|---|---|
| EXE compile | **PS2EXE** (PowerShell modülü, ücretsiz) |
| Code signing | **İmzasız** (şahsi proje için yeterli — SmartScreen "yine de çalıştır" uyarısı kaçınılmaz) |
| Self-update mekaniği | **B+C hibrit** (Updater PS1 script + Rename trick) |
| Hosting | **GitHub Releases** (raw URL değil, `api.github.com/repos/.../releases/latest`) |
| Versioning | **SemVer** (`v1.2.3`) |
| Hash | **SHA256SUMS.txt** ayrı asset olarak |
| Build | **GitHub Actions otomatik** (tag push → ~3 dk sonra release hazır) |

#### Eklenen globals (region 3)
- `$global:AppVersion = "1.0.0"` — SemVer, her release'de elle artırılır
- `$global:AppRepo = "zeugmass/GeminiSystemCare"` — README'de placeholder, kullanıcı kendi repo'sunu yazar
- `$global:UpdateAvailable` — yeni sürüm varsa `@{ Tag, CleanTag, Notes, ExeUrl, Ps1Url, HashUrl, ExeSize, Ps1Size, ReleaseUrl }`
- `$global:UpdateSkippedFile = "$AppDataPath\update_skipped_versions.txt"` — kullanıcı atladığı sürümler
- `$global:UpdateStagingDir = "$AppDataPath\update_staging"` — indirme staging
- `$global:UpdaterScriptTemplate` — Updater PS1 string (AppData'ya yazılır + spawn edilir)

#### Eklenen helper'lar (region 9, NPI helper'dan sonra)
- `Compare-Version -Lhs -Rhs` — SemVer karşılaştırma (`[System.Version].CompareTo`)
- `Cleanup-OldUpdateFiles` — açılışta `.old` dosyaları + eski updater script'i siler
- `Test-AppUpdate` — async runspace ile GitHub Releases API çağrısı (5 sn timeout). `$global:UpdateAvailable` doldurur, status bar'da bildirim gösterir
- `Invoke-AppUpdate -ProgressCallback {scriptblock}` — staging klasör yarat → SHA256SUMS indir → asset'leri indir → boyut sanity check + SHA256 hash doğrulama → updater PS1 yaz → updater'ı `Start-Process` ile spawn → ana programı kapatma sinyali
- `Add-SkippedVersion -VersionTag` — atlanan sürümü dosyaya kaydet

#### Eklenen UI (region 13)
- `Show-AppUpdateWindow` — yeni modal (mevcut `Show-UpdateWindow` Winapp2.ini için, dokunulmadı):
  - Sürüm karşılaştırma kartları (mevcut → yeni)
  - Release notes scrollview
  - Progress bar (download + hash + spawn aşamaları için)
  - 4 buton: 🔇 Atla / 💤 Daha Sonra / 📦 Güncelle / 🌐 Release sayfasını aç
  - Custom Style: disabled state okunaklı (PMButton pattern'i)

#### Tools menü item (region 13)
- `Refresh-Tools-Menu` sonuna 4. bölüm eklendi: "🔔 Programı Güncelle"
  - `$global:UpdateAvailable` varsa: yeşil + bold + "(vX.Y.Z hazır)" eki, doğrudan modal açar
  - Yoksa: gri + "(kontrol et)", manuel `Test-AppUpdate` çağırır, 6 sn bekler, sonuca göre modal/messagebox

#### Add_Loaded entegrasyonu (region 15)
```powershell
# 4. Auto-Update Altyapisi
Cleanup-OldUpdateFiles  # .old dosyaları + eski updater sil
Test-AppUpdate          # async check, status bar'a bildirim
```

#### Updater PS1 mantığı (B+C hibrit)
```
[Ana program kapanıyor]
    ↓
[Updater PS1 spawn edilir, parametreler: $TargetPid, $AppDir, $StagingDir, $LaunchExe]
    ↓
1. Wait-Process -Id $TargetPid -Timeout 30  (ana program kapanmasını bekle)
2. Staging'deki dosyalar için:
   • Eski dosyayı .old'a rename et (kullanımda olsa bile çalışır — Windows rename trick)
   • Yeni dosyayı yerleştir (Move-Item)
3. Staging klasörünü temizle
4. $LaunchExe varsa onu, yoksa Baslat.cmd'yi başlat
5. Updater kendi dosyasını sil (self-cleanup)
[Yeni sürüm açılır → Cleanup-OldUpdateFiles .old'ları siler]
```

#### Güvenlik katmanları
| Katman | Uygulama |
|---|---|
| HTTPS | GitHub default |
| TLS 1.2+ | `[Net.ServicePointManager]::SecurityProtocol = ...` |
| User-Agent | `"GeminiCare-App"` (GitHub API zorunlu) |
| SHA256 | `SHA256SUMS.txt` parse + hash karşılaştırma; eşleşmezse abort |
| Boyut check | 50 KB ≤ asset ≤ 100 MB |
| MoTW unblock | `Unblock-File` indirme sonrası |
| Atomik replace | Rename trick (.old) — eski sürüm çalışmaya devam ederken yeni dosya yerleştirilir |
| Atlama | Kullanıcı reddettiği sürümü skip dosyasına yazar |

#### CI/CD: `.github/workflows/build-release.yml` (110 satır)
Tetikleyici: `git push --tags` ile `v*` formatında tag push edildiğinde
1. Checkout repo
2. PS2EXE module install
3. PowerShell sentaks check (parse-time)
4. PS2EXE compile (`-RequireAdmin`, `-Sta`, `-NoConsole`, version metadata gömme)
5. SHA256 hash hesaplama → SHA256SUMS.txt
6. `softprops/action-gh-release@v2` ile Release oluşturma:
   - Auto-generated changelog
   - Asset'ler: TemizlikAsistani.exe, TemizlikAsistani.ps1, SHA256SUMS.txt, Baslat.cmd, BeniOku.txt

**Maliyet:** GitHub Actions windows-latest runner — ayda 2000 dk ücretsiz, her release ~3 dk → ayda ~600 release'e kadar bedava.

#### Geliştirme workflow'u
```
1. PS1'i edit et + test et
2. $global:AppVersion = "X.Y.Z" güncelle
3. git commit + push
4. git tag vX.Y.Z + git push --tags
5. ~3 dakika sonra GitHub'da Release hazır
6. Kullanıcılar açılışta bildirim alır, tek tıkla günceller
```

#### Repo dosyaları
- `Launcher.ps1` — yeni kullanım: EXE/PS1 köprü (eski auto-update mantığı kaldırıldı, tüm güncelleme ana programa gömüldü)
- `README.md` — kullanıcı + geliştirici dokümantasyonu (kurulum, hash doğrulama, repo setup, versiyonlama, CI/CD)

---

### Sprint: FR33THY Toplu Aktarım — DENEYSEL klasörü 10 yeni dosya işlendi

**Hedef:** Format sonrası tek tıkla optimizasyon için DENEYSEL klasöründeki ek 10 ps1 dosyasının tweak'lerini programa aktarmak. 18 yeni tweak eklendi, 1 mevcut tweak güçlendirildi.

#### Görev Çubuğu / Başlat (Kişiselleştirme kategorisi — 8 yeni)
- **Görev Çubuğunu Ortala (Win11)** — `TaskbarAl=1` (sol değil orta)
- **Chat Butonunu Gizle** — `TaskbarMn=0`
- **Copilot Butonunu Gizle** — `ShowCopilotButton=0`
- **Meet Now Butonunu Gizle** — `HideSCAMeetNow=1`
- **Tüm Tray İkonlarını Göster** — `EnableAutoTray=0` + `NotifyIconSettings\IsPromoted=1` loop (DetectScript+Command)
- **Tüm Uygulamalar: Liste Görünümü (Win11)** — `AllAppsViewMode=2`
- **Yeni Başlat Menüsü Düzeni (Win11 22H2+)** — 4 FeatureManagement Override 14 key (`EnabledState=2`)
- **Temiz Başlat Menüsü Düzeni (Layout Import)** — kompozit:
  - Win10: blank LayoutModificationTemplate XML + LockedStartLayout policy 3-aşamalı flow
  - Win11: FR33THY base64-encoded start2.bin → certutil decode → LocalState'e copy
  - Yeni helper: `Invoke-StartMenuLayoutImport -Mode Clean|Default` (region 9)
  - Yeni global: `$global:Win11Start2BinBase64` (~10 KB cert blob, region 3)

#### Uygulama Kaldırma kategorisi (5 yeni)
- **Microsoft GameInput Kaldır** — msiexec /x guid (DetectScript: HKLM uninstall arar)
- **Remote Desktop Connection (mstsc) Kaldır** — `mstsc /Uninstall` + process kill loop
- **Eski Snipping Tool (Win10) Kaldır** — `SnippingTool.exe /Uninstall` + process kill loop
- **Microsoft Update Health Tools Kaldır** — msiexec + uhssvc service silme + PLUGScheduler task delete
- **Şifresiz Giriş Devre Dışı** — `DevicePasswordLessBuildVersion=0`

#### Karanlık Mod güçlendirme (mevcut tweak yerinde değiştirildi)
"Karanlık Modu Aç (Sistem + Uygulamalar)" eski hali sadece 2 registry yazıyordu. FR33THY birebir kodlarla güncellendi:
- HKCU + HKLM Personalize (AppsUseLightTheme, ColorPrevalence, EnableTransparency, SystemUsesLightTheme)
- Explorer\Accent (AccentPalette gri tonlari, StartColorMenu, AccentColorMenu)
- DWM (EnableWindowColorization, AccentColor=0xff191919, ColorizationColor=0xc4191919, ColorizationAfterglow)
- Control Panel\Colors\Background="0 0 0"
- Undo'da default mavi tonlar (FR33THY default branch'i birebir)

#### Gelişmiş Sistem (Batch) kategorisine 1 yeni
- **Copilot Tamamen Kapat (Uninstall + Policy)** — process kill + AppX uninstall + HKCU/HKLM `TurnOffWindowsCopilot=1`. Undo'da AppX yeniden register

#### Sistem ve Oyun kategorisine 3 yeni
- **UAC Kapat** — `EnableLUA=0`. **Risk="High"** (sistem güvenliğini zayıflatır). Vendor uyarısı altyapısıyla aynı pattern.
- **Ses: Loudness EQ Aktif Et** — Tüm Render audio cihazlarına FxProperties altına `{d04e05a6-...},3 = "{5860E1C5-...}"` yazar. Audio servisleri stop/start, mmsys.cpl açılır
- **Masaüstü ve Kilit Ekranı: Tam Siyah** — Add-Type System.Drawing → ekran çözünürlüğünde siyah JPG → C:\Windows\Black.jpg → PersonalizationCSP + HKCU\Desktop\Wallpaper

#### 🎮 Low Latency (Espor) kategorisine 1 yeni
- **Ağ Kartı Güç Tasarrufu ve Uyandırma Kapat** — kompozit, 14 farklı registry value:
  - PnPCapabilities=24 (Power Management 3 seçenek kapali)
  - EEE/AdvancedEEE/EEELinkAdvertisement (Energy Efficient Ethernet)
  - SipsEnabled, ULPMode, GigaLite, EnableGreenEthernet, PowerSavingMode
  - S5WakeOnLan, *WakeOnMagicPacket, *ModernStandbyWoLMagicPacket, *WakeOnPattern, WakeOnLink
  - HKLM Class GUID `{4d36e972-...}` (Net adapters) altındaki tüm 4-haneli adapter subkey'lerine

#### Atlanan (kullanıcı kararı)
- `33 Defender Optimize.ps1` — Defender'ı tamamen kapat (TrustedInstaller + Safe Boot reboot). **Çok riskli**, atlandı.
- `13 Bloatware.ps1` — BRLTTY uninstall (Braille service+takeown, karmaşık), Windows Capabilities/Optional Features whitelist disable (50+ feature, riskli)

**Toplam:** 79 → **95 tweak**, 13 kategori, 2 → **3 Risk="High" tweak** (UAC eklendi)

**Yeni helper'lar (region 9):**
- `Invoke-StartMenuLayoutImport -Mode Clean|Default` — Win10 LockedStartLayout XML flow + Win11 start2.bin decode

**Yeni global'ler (region 3):**
- `$global:Win11Start2BinBase64` — FR33THY clean Win11 start menu cert-encoded blob

---

### Sistem Geri Yükleme — kontrol sistemi
- **Yeni global:** `$global:RestorePointMode` (`"Ask" | "Auto" | "Never"`) — config.json'da persist edilir
- **Temizlik tarafı:** `btnRun.Click` içindeki `Create-Restore-Point "Temizlik"` **kaldırıldı** (restore point temizlik için faydasız — silinen cache/temp dosyaları restore kapsamında değil)
- **Tweaks tarafı:** `Apply-System-Tweaks` çağrı pattern'i: `$rpOK = Create-Restore-Point ...; if (-not $rpOK) { return }` — kullanıcı Cancel derse tweak işlemi iptal
- **Create-Restore-Point yenilendi** (region 09):
  - `Test-VssServiceRunning` helper: VSS servisi kapalıysa uyarı + işlemi engellemeden devam
  - `Get-LastRestorePointDate` helper: son nokta tarihini döndürür
  - `Invoke-RestorePointAsync`: modal "lütfen bekleyin" penceresi + runspace'te `Checkpoint-Computer` → **UI donmuyor**, progress bar indeterminate
  - `-ForceManual` switch: Ayarlar'daki "Şimdi Manuel Oluştur" butonu için mod/throttle atlatır
  - Dönüş: `$true` (devam), `$false` (iptal edildi, caller durmalı)
- **Ayarlar penceresi:** Yeni "Sistem Geri Yükleme" paneli (Row 3):
  - 3 radio: Ask / Auto / Never (seçim anında config'e yazılır)
  - Bilgi satırı: "Son nokta: <tarih> • VSS servisi: Çalışıyor/Kapalı"
  - `btnRPManualCreate` → `Create-Restore-Point -ForceManual`
  - `btnRPWindowsPanel` → `SystemPropertiesProtection.exe` (Windows'un kendi paneli)
- Settings window Height: 550 → 720 (yeni row için)

---

## 6. DÜZENLEME REHBERİ

Bir fonksiyon/özelliği değiştirmek için:
1. Bu dosyada Region veya fonksiyon adını Ctrl+F ile bul
2. Yaklaşık satır numarasına git → Grep ile doğrula (reorganizasyon sonrası ± birkaç satır oynama olabilir)
3. `Read` ile ±30 satır oku, `Edit` ile değişiklik yap
4. Büyük yapısal değişiklikten sonra bu rehberi güncelle
