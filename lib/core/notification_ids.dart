// lib/core/notification_ids.dart

/// Bildirim ID'lerinin TEK doğruluk kaynağı.
///
/// Android bildirim ID'leri 32-bit işaretli tamsayıdır (max 2.147.483.647).
/// Şema: her modül kendi ayrık bandını kullanır; modül içinde
/// planId başına 10 slot (haftanın 7 günü + pay) ayrılır.
/// Bir ID'yi hesaplayan TEK formül buradadır — schedule ve cancel
/// çağrıları doğrudan sabit/formül kopyalamaz, bu sınıfı kullanır.
class NotificationIds {
  NotificationIds._();

  // ---- Bantlar (çakışmasız, 1M aralıklarla) ----
  //   med:      [ 1_000_000,  2_000_000)
  //   habit:    [ 2_000_000,  3_000_000)
  //   sport:    [ 3_000_000,  4_000_000)
  //   supplement:[ 4_000_000,  5_000_000)
  //   step:     500_000_000 (tek slot, hiçbir banda denk gelmez)
  static const int _medBase = 1000000;
  static const int _habitBase = 2000000;
  static const int _sportBase = 3000000;
  static const int _supplementBase = 4000000;
  static const int _stepBase = 500000000;

  /// PlanId başına ayrılan slot sayısı (gün 1-7 + pay).
  static const int _slotsPerId = 10;

  static const int _maxAndroidId = 2147483647;

  static int _inBand(int base, int id, int day) {
    assert(id >= 0, 'plan id negatif olamaz');
    assert(day >= 1 && day <= 7, 'gün 1-7 aralığında olmalı');
    final n = base + id * _slotsPerId + day;
    assert(n <= _maxAndroidId, 'ID Android 32-bit sınırını aştı: $n');
    return n;
  }

  static int medication(int id) {
    assert(id >= 0, 'medication id negatif olamaz');
    final n = _medBase + id;
    assert(n < _habitBase, 'med ID habit bandına taşmasın');
    return n;
  }

  static int habit(int id, int day) => _inBand(_habitBase, id, day);
  static int sport(int id, int day) => _inBand(_sportBase, id, day);
  static int supplement(int id, int day) => _inBand(_supplementBase, id, day);

  static int get step => _stepBase;
}
