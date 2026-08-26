// lib/widgets/monthly_calendar_card.dart
import 'package:flutter/material.dart';

/// Koşu sekmesindeki adım kartı deseninde, ortadan ikiye bölünmüş
/// aylık takvim kartı. Sol yarıda ay takvimi, sağ yarıda [rightChild]
/// (varsayılan: animasyon yer tutucusu) gösterilir.
class MonthlyCalendarCard extends StatelessWidget {
  const MonthlyCalendarCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    this.markedWeekdays = const {},
    this.scheduledDays = const {},
    this.completedDays = const {},
    this.rightChild,
    this.headerTrailing,
    this.month,
  });

  final String title;
  final IconData icon;
  final Color accentColor;

  /// İşaretlenecek hafta içi günler (1=Pazartesi, 7=Pazar).
  final Set<int> markedWeekdays;

  /// Bu aya ait, backend'den gelen planlı günler (ayın kaçı).
  final Set<int> scheduledDays;

  /// Bu aya ait, tamamlanmış (pozitif) günler (ayın kaçı).
  final Set<int> completedDays;

  /// Sağ yarıdaki içerik; null ise "Animasyon yakında" yer tutucusu.
  final Widget? rightChild;
  final String? headerTrailing;

  /// Gösterilecek ay (varsayılan: içinde bulunulan ay).
  final DateTime? month;

  static const List<String> _monthNames = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  static const List<String> _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final current = month ?? now;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (headerTrailing != null)
                  Text(
                    headerTrailing!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: _CalendarGrid(
                          month: current,
                          markedWeekdays: markedWeekdays,
                          scheduledDays: scheduledDays,
                          completedDays: completedDays,
                          accentColor: accentColor,
                          monthLabel: '${_monthNames[current.month - 1]} ${current.year}',
                          weekdayNames: _weekdays,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: rightChild ??
                            _AnimationPlaceholder(icon: icon, accentColor: accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.markedWeekdays,
    required this.scheduledDays,
    required this.completedDays,
    required this.accentColor,
    required this.monthLabel,
    required this.weekdayNames,
  });

  final DateTime month;
  final Set<int> markedWeekdays;
  final Set<int> scheduledDays;
  final Set<int> completedDays;
  final Color accentColor;
  final String monthLabel;
  final List<String> weekdayNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;

    final dayNumbers = <int?>[];
    for (int i = 0; i < leadingBlanks; i++) {
      dayNumbers.add(null);
    }
    for (int day = 1; day <= daysInMonth; day++) {
      dayNumbers.add(day);
    }
    while (dayNumbers.length % 7 != 0) {
      dayNumbers.add(null);
    }

    final weekRows = <Widget>[];
    for (int i = 0; i < dayNumbers.length; i += 7) {
      weekRows.add(Row(
        children: [
          for (final day in dayNumbers.sublist(i, i + 7))
            Expanded(
              child: _DayCell(
                day: day,
                isToday: day != null &&
                    month.year == now.year &&
                    month.month == now.month &&
                    day == now.day,
                isCompleted: day != null && completedDays.contains(day),
                isScheduled: day != null &&
                    (scheduledDays.contains(day) ||
                        markedWeekdays.contains(
                          DateTime(month.year, month.month, day).weekday,
                        )),
                accentColor: accentColor,
              ),
            ),
        ],
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final name in weekdayNames)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final row in weekRows) ...[row, const SizedBox(height: 2)],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isCompleted,
    required this.isScheduled,
    required this.accentColor,
  });

  final int? day;
  final bool isToday;
  final bool isCompleted;
  final bool isScheduled;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (day == null) {
      return const SizedBox(height: 26);
    }

    Widget content;
    if (isCompleted) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    } else if (isScheduled) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accentColor.withValues(alpha: 0.55)),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        ),
      );
    } else if (isToday) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    } else {
      content = Text(
        '$day',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.normal,
          color: theme.colorScheme.onSurface,
        ),
      );
    }

    return SizedBox(height: 26, child: Center(child: content));
  }
}

class _AnimationPlaceholder extends StatelessWidget {
  const _AnimationPlaceholder({required this.icon, required this.accentColor});

  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: accentColor.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            'Animasyon yakında',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: accentColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
