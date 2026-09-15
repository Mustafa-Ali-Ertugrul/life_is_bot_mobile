#!/usr/bin/env bash
# Life Is Bot — gerçek cihaz smoke testi.
#
# Emülatör içinde çalışan uygulamayı kurar, başlatır, sekmelerde gezdirir ve
# GERÇEK ekran dökümlerini (uiautomator), logcat'i, AlarmManager durumunu ve
# bildirim kanallarını toplar. Ayrıca mock backend'e giden istekleri sayar.
#
#   SMOKE_PHASE=debug   → app-debug.apk   (cleartext serbest)
#   SMOKE_PHASE=release → app-release.apk (cleartext Android 9+ engelli)
set -uo pipefail

PKG=com.lifeisbot.life_is_bot
PHASE="${SMOKE_PHASE:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="/tmp/smoke/$PHASE"
APK="$ROOT/build/app/outputs/flutter-apk/app-$PHASE.apk"
REPORT="$OUT/report.txt"
mkdir -p "$OUT"
: > "$REPORT"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$REPORT"; }
section() { printf '\n===== %s =====\n' "$*" | tee -a "$REPORT"; }

# ekrandaki metinleri rapora ekle
dump() {
  local name="$1"
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml "$OUT/$name.xml" >/dev/null 2>&1
  section "EKRAN: $name"
  python3 "$ROOT/tool/uia.py" "$OUT/$name.xml" 2>&1 | tee -a "$REPORT"
}

tap() { # tap "Ayarlar" → metni eşleşen ilk node'a dokun
  local needle="$1" coords
  coords=$(python3 "$ROOT/tool/uia.py" "$OUT/last.xml" --find "$needle" 2>/dev/null)
  if [[ -n "${coords:-}" ]]; then
    log "dokunuluyor: '$needle' → $coords"
    adb shell input tap $coords
    return 0
  fi
  log "UYARI: '$needle' ekranda bulunamadı"
  return 1
}

dump_last() { # son dökümü last.xml olarak da sakla (tap için)
  local name="$1"
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml "$OUT/$name.xml" >/dev/null 2>&1
  cp "$OUT/$name.xml" "$OUT/last.xml"
  section "EKRAN: $name"
  python3 "$ROOT/tool/uia.py" "$OUT/$name.xml" 2>&1 | tee -a "$REPORT"
}

log "PHASE=$PHASE  APK=$APK"
[[ -f "$APK" ]] && log "APK boyutu: $(du -h "$APK" | cut -f1)" || log "HATA: APK yok!"

section "CİHAZ"
adb wait-for-device
for _ in $(seq 1 90); do
  [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
  sleep 2
done
{
  echo "Android : $(adb shell getprop ro.build.version.release | tr -d '\r')"
  echo "SDK     : $(adb shell getprop ro.build.version.sdk | tr -d '\r')"
  echo "Model   : $(adb shell getprop ro.product.model | tr -d '\r')"
  echo "Ekran   : $(adb shell wm size | tr -d '\r')"
  echo "ABI     : $(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
} | tee -a "$REPORT"

log "eski kurulum kaldırılıyor (imza uyuşmazlığı olmasın)"
adb uninstall "$PKG" >/dev/null 2>&1

log "APK kuruluyor"
adb install -r -g "$APK" 2>&1 | tee -a "$REPORT"

adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
adb shell settings put global window_animation_scale 0 >/dev/null 2>&1
adb shell settings put global transition_animation_scale 0 >/dev/null 2>&1
adb shell settings put global animator_duration_scale 0 >/dev/null 2>&1
adb logcat -c >/dev/null 2>&1

section "SOĞUK AÇILIŞ (am start -W)"
adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee -a "$REPORT"

log "40 sn bekleniyor (Google Fit 3+5sn timeout + backend çağrıları)"
sleep 40
dump_last "01_home_kosu"

section "SEKMELER (sola kaydır)"
for tab in 02_spor 03_rutin 04_ilac; do
  adb shell input swipe 900 1200 100 1200 250
  sleep 6
  dump_last "$tab"
done

section "FAB → 'İlaç Ekle' diyaloğu"
SZ=$(adb shell wm size | tr -d '\r' | sed 's/.*: //')
W=${SZ%x*}; H=${SZ#*x}
log "ekran ${W}x${H} → FAB tahmini $((W - 100)),$((H - 160))"
adb shell input tap $((W - 100)) $((H - 160))
sleep 4
dump_last "05_ilac_ekle_dialog"
adb shell input keyevent 4
sleep 2

section "AYARLAR EKRANI"
if tap "Ayarlar"; then
  sleep 6
  dump_last "06_ayarlar"
  adb shell input keyevent 4
  sleep 2
fi

section "BACKEND BAĞLANTI DURUMU (AppBar ikonunun content-desc'i)"
python3 "$ROOT/tool/uia.py" "$OUT/last.xml" --find "Backend" 2>/dev/null && log "→ AppBar'da backend ikonu var" || log "backend ikonu bulunamadı"
adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
adb pull /sdcard/ui.xml "$OUT/last.xml" >/dev/null 2>&1
python3 "$ROOT/tool/uia.py" "$OUT/last.xml" 2>/dev/null | grep -i "backend" | tee -a "$REPORT" || echo "(backend metni yok)" | tee -a "$REPORT"

section "logcat — Flutter satırları"
adb logcat -d > "$OUT/logcat_full.txt" 2>&1
grep -aE "flutter|AndroidRuntime|FATAL|lifeisbot" "$OUT/logcat_full.txt" \
  | grep -avE "ViewRootImpl|InsetsController|Choreographer" \
  | tail -60 | tee -a "$REPORT"

section "logcat — hata/istisna özeti"
grep -acE "Exception|Error|❌|⚠️" "$OUT/logcat_full.txt" | sed 's/^/eşleşen satır: /' | tee -a "$REPORT"
grep -aE "Exception|❌|⚠️|Cleartext|cleartext" "$OUT/logcat_full.txt" | tail -25 | tee -a "$REPORT"

section "AlarmManager — gerçekten zamanlanmış hatırlatma var mı?"
adb shell dumpsys alarm > "$OUT/alarms.txt" 2>&1
ALARM_COUNT=$(grep -ac "$PKG" "$OUT/alarms.txt")
log "alarm dökümünde pakete ait satır sayısı: $ALARM_COUNT"
grep -aA2 "$PKG" "$OUT/alarms.txt" | grep -aE "type=|when=|tag=|RTC" | head -20 | tee -a "$REPORT"

section "Bildirim kanalları oluşturulmuş mu?"
adb shell dumpsys notification --noredact > "$OUT/notif.txt" 2>&1
grep -aoE "medications_v4|habits_v4|sport_v4|supplement_v4|steps_v4|lifeisbot_foreground" "$OUT/notif.txt" \
  | sort | uniq -c | tee -a "$REPORT"

section "MOCK BACKEND'E GİDEN İSTEKLER (soğuk açılış + gezinme)"
if [[ -f /tmp/mock_backend.log ]]; then
  REQ_TOTAL=$(grep -ac "^REQ" /tmp/mock_backend.log)
  log "TOPLAM İSTEK: $REQ_TOTAL"
  grep -a "^REQ" /tmp/mock_backend.log | awk '{print $2, $3}' | sort | uniq -c | sort -rn | tee -a "$REPORT"
else
  log "mock backend logu yok"
fi

log "BİTTİ phase=$PHASE"
