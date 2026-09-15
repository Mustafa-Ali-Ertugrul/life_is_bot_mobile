# Life Is Bot — Mobil Uygulama İncelemesi

**Tarih:** 2026-09-13 · **Commit:** `ef3d81e` (branch `arena/01a09c21-life-is-bot-mobile`)
**Kapsam:** `lib/` (23 dosya, 6.249 satır), `test/` (5 dosya, 692 satır), `android/`, `ios/`, `pubspec.yaml`, `.github/workflows/ci.yml`, `assets/`

---

## 1. Nasıl inceledim (ve neyi doğrulayamadım)

Bu sandbox'ta **Flutter/Dart SDK kurulamıyor** — nedenleri tek tek denendi ve kanıtlandı:

| Yol | Sonuç |
|---|---|
| SDK dosya sisteminde hazır mı | `find / -name dart -o -name flutter` → sadece projenin `linux/flutter`, `windows/flutter` klasörleri |
| `pub.dev` | TLS ClientHello'dan sonra proxy düşürüyor: `SSL_ERROR_SYSCALL` (curl 35) |
| `storage.googleapis.com` (Flutter/Dart SDK indirme) | Aynı şekilde engelli |
| GitHub release asset'leri | `objects.githubusercontent.com`'a 302 → host erişilemez, 0 byte |
| `codeload.github.com` (kaynak tarball) | 200, ama Flutter kaynağı Dart SDK binary'sini içermez; onu ilk çalıştırmada storage.googleapis.com'dan indirir |
| npm / PyPI mirror | `dart-sdk`, `flutter-sdk` paketi yok |

**Çözüm:** projenin kendi koşucusu olan `mobile-ci` workflow'u tetiklendi (PR #3, run [34937411514](https://github.com/Mustafa-Ali-Ertugrul/life_is_bot_mobile/actions/runs/34937411514)). Sonuç — **kod gerçekten derlendi ve testler gerçekten koştu**:

```
job: analyze-and-test → success  (06:32:44Z → 06:34:06Z, 1m22s)
  3. Setup Flutter: success   4. Pub dependencies: success
  5. Analyze: success         (flutter analyze --fatal-infos)
  6. Test: success            (flutter test)
```

Yani: **analyzer temiz** (`--fatal-infos` ile, yani tek bir info bile olsa kırmızı olurdu) ve **49 test case'in tamamı geçti** (`api_client_sport_supplement` 14, `sport_supplement_contract` 15, `app_navigator_payload` 8, `auth_retry_regression` 8, `model_contract` 4). Adım sonuçları `api.github.com`'dan doğrulandı; ham log metni ise `results-receiver.actions.githubusercontent.com` / `blob.core.windows.net` allowlist dışında kaldığı için buradan okunamıyor.

**Koşturulamayan tek şey uygulamanın kendisi:** `flutter build apk` Android SDK + Gradle + `repo1.maven.org`/`dl.google.com`/`services.gradle.org` gerektiriyor (üçü de engelli) ve sandbox'ta ne emülatör ne backend var. Aşağıdaki bulguların tamamı bu yüzden statik; K1/K3/Y1/Y2 gibi maddeler cihazda doğrulanmadı.

Bunun yerine kod üzerinde **çalıştırılabilir statik kontroller** yaptım (Python ile `lib/` tarandı) ve her bulguyu dosya:satır ile doğruladım:

| Kontrol | Sonuç |
|---|---|
| Dart kodundaki asset referansları ↔ `assets/images/` içeriği | Eksik dosya yok; **6,29 MB kullanılmayan asset** (toplam 28,72 MB) |
| Üretilen bildirim actionId'leri ↔ `handleAction` içinde işlenenler | 8/8 eşleşiyor, yetim yok |
| Üretilen `payload:` değerleri ↔ `AppNavigator.parsePayload` ekran listesi | 5/5 eşleşiyor |
| Kullanılmayan relative import taraması | Temiz |
| `await` sonrası `mounted` kontrolsüz `setState` | **4 gerçek risk** (bkz. Y3) |
| Manifest / gradle / Info.plist grep (cleartext, HealthKit, imza) | 3 bulgu (K1, K3, Y1) |
| Git'te izlenen secret (`key.properties`, `*.jks`) | Yok — `.gitignore` doğru |

---

## 2. Mimari özet

```
main.dart ──► NotificationService.init() → SharedPreferences → tema/cinsiyet
          ──► ilk açılışta: api.init() + checkHealth → Onboarding | HomeScreen
          ──► ForegroundService.init()  (MIUI keepalive, dataSync FGS)
          ──► _postLaunchInit(): bildirim izni + adım hatırlatması

HomeScreen (4 tab: Koşu / Spor / Rutin / İlaç)
  ├── _loadBackendData(): 7 paralel API çağrısı + tüm bildirimleri yeniden zamanla
  └── SportScreen / HabitsScreen / MedicationsScreen (embedded)

core/api_client.dart   : 23 URL şablonu, JWT + 401-retry sarmalayıcı, grup bazlı hata bayrağı
core/notification_ids.dart : bildirim ID bantları (tek doğruluk kaynağı)
services/notification_service.dart : kanallar, alarmClock zamanlama, aksiyon butonları
services/google_fit_service.dart + core/database.dart : Health Connect → sqflite step_logs
```

Durum yönetimi yok (provider/riverpod/bloc yok); her ekran kendi `ApiClient` singleton'ı üzerinden doğrudan fetch ediyor. Uygulama "backend varsa anlamlı" bir istemci; offline'da yalnızca adımlar yerel DB'den okunuyor.

---

## 3. İyi yapılmış olanlar

- **`NotificationIds`** (`lib/core/notification_ids.dart`): bant şeması tek yerde, formüller kopyalanmamış, assert'ler + açıklayıcı yorumlar. ID çakışması regresyon testi (`test/auth_retry_regression_test.dart`) 0–10.000 id uzayını gerçekten tarıyor.
- **Şema migrasyonu**: `_purgeLegacyNotificationIds()` (notification_service.dart:67) eski ID şemasıyla kalan yetim bildirimleri tek seferlik temizliyor — genelde atlanan bir detay.
- **401 retry tasarımı**: `_AuthRetryClient` token isteğini sarmalayıcının *dışındaki* raw client'tan akıtıyor (sonsuz döngü koruması) ve retry klonuna **yeni** token'ı basıyor. Testler bu iki bug'ı isimleriyle kilitliyor.
- **MIUI/Doze farkındalığı**: `AndroidScheduleMode.alarmClock` + `canScheduleExactNotifications()` fallback, boot/`MY_PACKAGE_REPLACED`/`QUICKBOOT` receiver'ları, `USE_EXACT_ALARM` kullanılmamış (Play politikası doğru).
- **Güvenlik hijyeni**: `key.properties`/`*.jks` gitignore'da ve repoda izlenmiyor; FGS `exported="false"` + `tools:replace`; CI'da action'lar SHA ile pinlenmiş, `persist-credentials: false`.
- **Açılış yolu**: UI ilk frame'de gösteriliyor, ağ işi arka planda (`main.dart:29-45` yorumlarıyla birlikte).

---

## 4. Bulgular

### 🔴 Kritik

**K1 — Release build'de HTTP backend'e hiç ulaşılamaz (cleartext engeli)**
`AppConfig.baseUrl` varsayılanı `http://10.0.2.2:8080/api` (`lib/core/config.dart:6-9`). `android:usesCleartextTraffic="true"` **yalnızca** `android/app/src/debug/AndroidManifest.xml:7`'de var; ana manifest'te (`android/app/src/main/AndroidManifest.xml`) ne `usesCleartextTraffic` ne `networkSecurityConfig` var (grep ile doğrulandı). API 28+ varsayılan olarak cleartext'i engellediği için, `--dart-define=API_BASE_URL=http://...` ile alınan **release** APK backend'e bağlanamaz; hata `debugPrint`'te kalır, kullanıcı sadece "cloud_off" görür.
→ *Öneri:* release'ta HTTPS zorunlu tut; dev için `res/xml/network_security_config.xml` + `debug` manifest'e domain bazlı istisna. Ayrıca `config.dart`'a "baseUrl http ise release'ta uyar" kontrolü.

**K2 — `PROVISIONING_KEY` istemciye gömülü, yani sır değil**
`lib/core/config.dart:11-17` anahtarı `String.fromEnvironment` ile alıyor; dart-define değerleri binary'ye sabit olarak derlenir → APK'yı açan herkes anahtarı çıkarıp `/auth/token`'dan cihaz JWT'si üretebilir. Token da düz metin olarak SharedPreferences'ta duruyor (`api_client.dart:20`, `:116`).
→ *Öneri:* provisioning key'i build sunucusunda tut + install başına kayıt akışı (backend'in ilk açılışta cihaz kimliği vermesi); token'ı `flutter_secure_storage`/Keystore'a taşı.

**K3 — Release imzası sessizce debug key'e düşüyor**
`android/app/build.gradle.kts:52-62`: `key.properties` yoksa `signingConfig = signingConfigs.getByName("debug")`. `verify.ps1` bunu yakalıyor ama **yalnızca Windows'ta ve elle çalıştırılınca**; CI (`ci.yml`) APK build etmiyor. Başka bir makinede/CI'da alınan "release" build debug imzalı çıkar → Play'de imza uyuşmazlığı.
→ *Öneri:* fallback yerine `throw GradleException("key.properties missing")`; imza kontrolünü CI'a taşı.

### 🟠 Yüksek

**Y1 — iOS tarafında HealthKit yapılandırması yok**
`ios/Runner/Info.plist` içinde `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` yok (dosyanın tamamı okundu) ve `find ios -name "*.entitlements"` → **sonuç yok**. `health` paketi iOS'ta her ikisini de ister; olmadan izin diyaloğu açılmaz/istek başarısız olur. Repo `ios/`, `macos/`, `linux/`, `windows/` klasörlerini taşıdığı için "çok platformlu" izlenimi veriyor ama adım takibi iOS'ta çalışmaz.
→ *Öneri:* ya usage string + HealthKit entitlement ekle, ya da desteklenmeyen platform klasörlerini kaldırıp README'de "Android-only" de.

**Y2 — `dataSync` foreground service Android 15'te 6 saatte kesilir**
`lib/services/foreground_service.dart:63` → `foregroundServiceTypes: [AndroidForegroundType.dataSync]`, `compileSdk = 35` (`build.gradle.kts:17`), `targetSdk = flutter.targetSdkVersion` (`:37`). Android 15, API 35 hedefleyen uygulamalarda `dataSync` FGS'e **24 saatte toplam 6 saat** sınırı koyar; süre dolunca `onTimeout()` çağrılır ve servis birkaç saniye içinde `stopSelf()` etmezse `RemoteServiceException` fırlatılır ([Android 15 behavior changes](https://developer.android.google.cn/about/versions/15/behavior-changes-15)). Bu servis tam tersine kalıcı keepalive (60 sn'lik `Timer.periodic`) ve hiç durmuyor → MIUI koruması gün içinde ölür, ayrıca crash log üretir.
→ *Öneri:* `onTimeout` destekleyen bir plugin sürümü/fork, ya da keepalive yerine `WorkManager` + exact alarm stratejisi; `specialUse` tipi Play'de gerekçe formu gerektirir.

**Y3 — `await` sonrası `mounted` kontrolsüz `setState` → "setState() called after dispose()"**
Doğrulanan 4 yer:
- `lib/screens/reports_screen.dart:53` — 4 paralel API çağrısı (her biri 10 sn timeout) sonra guard'sız `setState`; ReportsScreen push edilen bir ekran, kullanıcı geri basarsa patlar.
- `lib/screens/habits_screen.dart:118`, `lib/screens/medications_screen.dart:105` — `await getHabits()/getMedications()` + bildirim zamanlaması sonrası guard yok.
- `lib/screens/home_screen.dart:77` — `_initData()` sonundaki `setState(() => _loading = false)`.

Karşı örnek doğru yazılmış: `lib/screens/sport_screen.dart:166` (`if (mounted) setState(...)`). → Tüm load metodlarına `if (!mounted) return;` ekle; bu tek satırlık bir düzeltme ve `flutter analyze`'in `use_build_context_synchronously` ailesiyle de uyumlu.

**Y4 — Aynı veriler tekrar tekrar çekiliyor (cold start ≈ 19 istek)**
`getMonthlyReport()` dört ayrı ekrandan çağrılıyor: `habits_screen.dart:83`, `medications_screen.dart:82`, `sport_screen.dart:111`, `reports_screen.dart:49`. HomeScreen ayrıca `checkHealth` + 7 paralel çağrı yapıyor (`home_screen.dart:120-128`), sekmeler de kendi listelerini + `getMonthDays`'i çekiyor. Cache/repository katmanı yok.
→ *Öneri:* basit bir `Repository` + TTL cache (veya provider/riverpod) ile tek kaynak; ay raporu bir kez çekilip paylaşılabilir.

**Y5 — Listeleme endpoint'lerine sayfalama parametresi gönderilmiyor**
`getMedications/getHabits/getSportPlans/getSupplementPlans` yanıtları `{"items": [...], "total": N}` biçiminde ayrıştırıyor (`api_client.dart:168-186` vb.) ama isteklerde `page`/`limit` yok. Backend varsayılan sayfa boyutuyla dönerse uygulama **sessizce ilk sayfayı** gösterir.
→ *Öneri:* backend sözleşmesini netleştir; `?limit=` gönder ya da `total > items.length` ise uyar.

### 🟡 Orta

**O1 — `focusId` spor/supplement arasında çakışıyor.** `AppNavigator.openForPayload` hem `sport_*` hem `supplement_*` payload'ını `SportScreen(focusId: id)` ile açıyor (`app_navigator.dart:38-41`); `SportScreen._isFocused(id)` hem spor kartlarında hem supplement kartlarında kullanılıyor → `supplement_9` bildirimi, id'si 9 olan **spor planını da** vurgular.
→ *Öneri:* `SportScreen`'e `focusType` parametresi ekle.

**O2 — Cinsiyet değişimi tema rengini güncellemiyor.** `main.dart:21-23` `user_gender`'ı `runApp`'ten **önce** okuyup `MyApp(female:)` olarak sabitliyor. Onboarding cinsiyeti daha sonra yazıyor (`onboarding_screen.dart:87-92`, `:124-131`), Settings'teki `_changeGender` ise yalnızca kendi `setState`'ini çağırıyor (`settings_screen.dart:114-121`) — `_changeTheme`'in aksine `MyApp.setThemeMode` benzeri bir çağrı yok. Sonuç: Material seed rengi yeniden başlatana kadar erkek turkuazı kalıyor (ekran AppBar'ları `AppTheme.of(_gender)` ile güncellendiği için tutarsız görünüm).

**O3 — 6,29 MB kullanılmayan asset; GIF yerine WebP ile ~20 MB kazanç.**
`pubspec.yaml` tüm `assets/images/` klasörünü paketlediği için kodda hiç referans olmayan şu dosyalar APK'ya giriyor (script çıktısı):

```
runner_male.png            2575 KB      runner_phase_2.webp        11 KB
runner_female.png           586 KB      runner_phase_3.webp        14 KB
runner_phase_1_dark.webp    636 KB      runner_phase_4.webp        10 KB
runner_phase_2_dark.webp   1016 KB      runner_phase_1_test.webp   12 KB
runner_phase_3_dark.webp    846 KB      runner_phase_4_dark.webp   728 KB
```
Ayrıca `_dark.webp` varyantları üretilmiş ama hiçbir yerde kullanılmıyor → **koyu temada açık tema görselleri** gösteriliyor. Karşılaştırma: `runner_phase_1.gif` 1.112 KB, `runner_phase_1.webp` **12 KB**. Commit mesajındaki 80,1 MB'lık release APK'nın ana nedeni bu.
→ *Öneri:* kullanılmayanları sil, GIF'leri animasyonlu WebP'ye çevir, dark varyantları `Theme.of(context).brightness` ile bağla.

**O4 — Yazma işlemlerinde hata kullanıcıya hiç yansımıyor.** `createMedication`/`createHabit`/`updateStepGoal`/`updatePreference`/`postSteps`/`submitResponse` hata durumunda sadece `debugPrint` + `null/false` dönüyor. Örn. `medications_screen.dart:170-177`: `created == null` ise dialog **hiçbir mesaj vermeden açık kalıyor**. `groupFailed` yalnızca liste endpoint'lerinde var.
→ *Öneri:* `Result<T, ApiError>` tipi; dialog'da SnackBar ile "kaydedilemedi".

**O5 — Bildirim aksiyonu (İçtim/Yapıldı) offline'da kayboluyor.** `notification_service.dart:113` background isolate'ta `ApiClient().submitResponse(...)` çağırıyor; o isolate'ta token yok → 401 → `_authRetry` → `PROVISIONING_KEY` gerekiyo. Başarısızsa yalnızca `debugPrint` (`:117`). Kullanıcının "İçtim" dediği kayıt sessizce düşer.
→ *Öneri:* yerel outbox tablosu (sqflite zaten var) + uygulama açılınca retry.

**O6 — `_AuthRetryClient` 401 yanıt gövdesini tüketmiyor.** `api_client.dart` içindeki `send()`: ilk `StreamedResponse` okunmadan/`cancel()` edilmeden retry'a geçiliyor → bağlantı pool'a dönmüyor. Küçük ama gerçek sızıntı.

### 🟢 Düşük / bakım

- **D1 — README hâlâ Flutter şablonu** ("A new Flutter project"). Zorunlu `--dart-define`'lar (`API_BASE_URL`, `PROVISIONING_KEY`, `TEST_BOT_NOTIFICATIONS`), build adımları ve mimari yok. `verify.ps1` yalnızca PowerShell; aynı kontrolleri yapan bir `verify.sh` veya CI adımı yok (CI sadece analyze+test).
- **D2 — Uygulama adı tutarsız:** Android `android:label="life_is_bot"`, iOS `CFBundleDisplayName="Life Is Bot"`.
- **D3 — `NotificationIds` bant taşması sadece debug assert'i:** `id ≥ 100.000` için `habit(id,7)` spor bandına (3.000.000) taşar; regresyon testi 0–10.000 aralığını tarıyor (`auth_retry_regression_test.dart`). Ucuz koruma: `id % 100000` ya da release'te de çalışan bir sınır kontrolü.
- **D4 — Test kapsamı:** 5 dosyanın tamamı model/api/navigator düzeyinde. Widget testi yok; `NotificationService` (zamanlama, ID, `_nextInstanceOfDay`) ve `handleAction` actionId ayrıştırma (`'med_taken_5'.split('_').last`) test edilmiyor — ikisi de saf Dart ile test edilebilir.
- **D5 — Sürüm pinleme tutarsız:** `permission_handler: 11.3.1` tam pinli, diğerleri caret. `health ^13.1.3` ile uyumu burada çözümlenemedi (pub erişimi yok) — `flutter pub outdated` ile doğrulanmalı.

---

## 5. Önerilen sıra (etki/effort)

| # | İş | Etki |
|---|---|---|
| 1 | Y3: 4 load metoduna `if (!mounted) return;` | 10 dk, crash riski kapanır |
| 2 | K1: release için HTTPS + network security config | Kritik dağıtım blokajı |
| 3 | K3: gradle imza fallback'ini `throw`'a çevir + CI'a taşı | Yanlış imzalı build imkânsızlaşır |
| 4 | O3: kullanılmayan asset'leri sil, GIF→WebP | APK ~%25–50 küçülür |
| 5 | Y4: repository + TTL cache, `getMonthlyReport` tekilleştir | Cold start isteği yarıya iner |
| 6 | Y2: FGS tipini/timeout stratejisini yeniden tasarla | Android 15'te keepalive gerçekten çalışır |
| 7 | K2: provisioning key + token saklama modeli | Güvenlik |
| 8 | D1/D2: README, verify.sh, app label | Bakım kalitesi |
