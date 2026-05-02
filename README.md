# Gemini Sistem Bakım Aracı

Windows için kapsamlı sistem temizliği, optimizasyon ve tweak aracı. PowerShell + WPF ile yazılmış, tek dosya EXE olarak dağıtılır.

## 🚀 Kullanıcılar İçin

### Kurulum
1. [GitHub Releases](https://github.com/zeugmass/GeminiSystemCare/releases) sayfasından **en son sürüm**ün asset'lerini indir:
   - `TemizlikAsistani.exe` — tek dosya executable (önerilen)
   - `TemizlikAsistani.ps1` — kaynak kodu (geliştirici/ileri kullanıcı için)
   - `SHA256SUMS.txt` — dosya bütünlüğü doğrulama
   - `Baslat.cmd` — UAC elevation launcher (opsiyonel)

2. **Hash doğrulama (önerilen)**:
   ```powershell
   Get-FileHash TemizlikAsistani.exe -Algorithm SHA256
   # SHA256SUMS.txt içindeki değerle karşılaştır
   ```

3. EXE'yi çalıştır. UAC onayı gerekir (yönetici hakları zorunlu).

### Otomatik Güncelleme
Program açıldığında **arkaplanda** GitHub'dan yeni sürüm kontrol eder:
- Yeni sürüm varsa: status bar'da `🔔 Yeni sürüm: vX.Y.Z` bildirimi
- **Tools menüsü → 🔔 Programı Güncelle** ile modal açılır
- "Güncelle" butonuyla otomatik indir + SHA256 doğrula + yeniden başlat
- Beğenmediğin sürümü "Bu sürümü atla" ile sürekli sessizliğe alabilirsin

### SmartScreen Uyarısı
EXE imzasız olduğu için ilk açılışta `Windows korudu` uyarısı çıkabilir:
- "Daha fazla bilgi" → "Yine de çalıştır"

Antivirüs yanlış pozitif veriyorsa: `%APPDATA%\GeminiCare` klasörünü AV istisnasına ekle.

## 🛠️ Geliştiriciler İçin

### Repo Setup (ilk kurulum)

1. **GitHub'da yeni public repo oluştur**: `zeugmass/GeminiSystemCare` (veya kendi adın)

2. **Bu repo'yu lokale klonla**:
   ```bash
   git clone https://github.com/zeugmass/GeminiSystemCare.git
   cd GeminiSystemCare
   ```

3. **Mevcut dosyaları kopyala** (TemizlikAsistani.ps1, Baslat.cmd, vs).

4. **`TemizlikAsistani.ps1` içinde repo adını değiştir** (region 3 globals):
   ```powershell
   $global:AppRepo = "kendi_kullanici_adin/repo_adin"
   ```

5. **İlk commit + push**:
   ```bash
   git add .
   git commit -m "Initial release"
   git push origin main
   ```

### Yeni Sürüm Yayınlama (her release için)

```bash
# 1. PS1'de versiyonu güncelle:
#    $global:AppVersion = "1.2.0"
git add TemizlikAsistani.ps1
git commit -m "v1.2.0: yeni özellikler / fix'ler"
git push

# 2. Tag at — bu workflow'u tetikler
git tag v1.2.0
git push --tags
```

3 dakika sonra GitHub Releases'ta yeni release otomatik oluşur:
- `TemizlikAsistani.exe` (PS2EXE ile derlenmiş)
- `TemizlikAsistani.ps1` (kaynak)
- `SHA256SUMS.txt` (otomatik hash)
- `Baslat.cmd`, `BeniOku.txt`

Kullanıcılarda program açılışında otomatik "🔔 Yeni sürüm" bildirimi görünür.

### Versiyonlama Kuralı

[SemVer](https://semver.org/lang/tr/) kullanılır:
- **Major** (`2.0.0`): geriye uyumsuz büyük değişiklik
- **Minor** (`1.3.0`): yeni özellik, geriye uyumlu
- **Patch** (`1.2.3`): bug fix

PS1 içindeki `$global:AppVersion` değeri ile git tag'i (örn. `v1.2.3`) **eşleşmeli**.

### Geliştirme Workflow'u

```
PS1'i edit et
    ↓
PowerShell ile direkt çalıştır (test)
    ↓
Sentaks check: powershell -Command "[void][System.Management.Automation.Language.Parser]::ParseFile(...)"
    ↓
Versiyonu artır + commit + push
    ↓
git tag vX.Y.Z + git push --tags
    ↓
[GitHub Actions otomatik 3 dk]
    ↓
Release hazır → kullanıcılarda bildirim
```

### CI/CD (GitHub Actions)

`.github/workflows/build-release.yml` dosyası `v*` tag push'unda tetiklenir:
1. PowerShell sentaks check
2. PS2EXE ile `TemizlikAsistani.ps1` → `.exe` derleme
3. SHA256 hash hesaplama → `SHA256SUMS.txt`
4. GitHub Release oluşturma + asset upload + auto-generated changelog

Workflow ücretsiz GitHub Actions runner (windows-latest) kullanır. Ayda 2000 dakika ücretsiz kontenjan; her release ~3 dk → ayda ~600 release'e kadar bedava.

## 🔒 Güvenlik

| Katman | Açıklama |
|---|---|
| **HTTPS** | GitHub API + asset download tamamen TLS |
| **TLS 1.2+ zorla** | Eski PowerShell default'larına karşı |
| **SHA256 doğrulama** | İndirilen EXE'nin hash'i `SHA256SUMS.txt`'tekiyle karşılaştırılır, eşleşmezse abort |
| **Boyut sanity check** | Asset 50 KB-100 MB aralığında olmalı |
| **MoTW unblock** | İndirilen dosyaların İnternet Damgası temizlenir |
| **Atomik replace** | Eski dosya `.old`'a rename, yeni dosya yerleştirilir, ana program restart |
| **Kullanıcı atlama** | "Bu sürümü atla" → tekrar bildirim gösterilmez |

⚠️ **EXE imzasız** — code signing certificate alınırsa SmartScreen uyarısı kaybolur. Şahsi proje için imzasız mantıklı, kurumsal dağıtım için EV cert ($250-500/yıl) gerekli.

## 📁 Repo Yapısı

```
GeminiSystemCare/
├── TemizlikAsistani.ps1      # Ana script (~13K satır)
├── Baslat.cmd                # UAC elevation launcher
├── Launcher.ps1              # EXE/PS1 köprü launcher
├── BeniOku.txt               # TR kullanıcı rehberi
├── README.md                 # Bu dosya
├── PROJE_REHBERI.md          # Geliştirici referans (region/satır haritası)
└── .github/workflows/
    └── build-release.yml     # CI/CD: tag → EXE + Release
```

## 📜 Lisans

(Lisansını buraya ekleyebilirsin — MIT, GPL, vs.)
