import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Recur's own date picker — a bottom sheet built from the same month-grid
/// language as the Calendar tab (`calendar_screen.dart`'s `_MonthGrid`),
/// rather than Flutter's stock `showDatePicker`. The stock picker's year
/// dropdown, oval CANCEL/OK buttons, and default Material layout have no
/// relationship to the ledger-paper look everywhere else in this app; a
/// second, unrelated calendar grammar living one tap away from the real
/// one reads as unfinished. This reuses the same cell shape, selection
/// treatment, and weekday header so picking a date feels like the same app.
///
/// Tapping a day selects and closes immediately — there's nothing left to
/// confirm once the date is visibly highlighted, and the main Calendar tab
/// already behaves the same way (tap a day, see it selected).
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'Select a date',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppDatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      title: title,
    ),
  );
}

class _AppDatePickerSheet extends StatefulWidget {
  const _AppDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late DateTime _month = DateTime(widget.initialDate.year, widget.initialDate.month);
  late DateTime _selected = widget.initialDate;

  bool get _canGoBack => DateTime(_month.year, _month.month - 1)
      .isAfter(DateTime(widget.firstDate.year, widget.firstDate.month - 1));
  bool get _canGoForward => DateTime(_month.year, _month.month + 1)
      .isBefore(DateTime(widget.lastDate.year, widget.lastDate.month + 1));

  void _changeMonth(int dir) {
    setState(() => _month = DateTime(_month.year, _month.month + dir));
  }

  bool _inRange(DateTime day) => !day.isBefore(_dayOnly(widget.firstDate)) && !day.isAfter(_dayOnly(widget.lastDate));

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _select(DateTime day) {
    setState(() => _selected = day);
    Navigator.of(context).pop(day);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isCurrentMonth = _month.year == today.year && _month.month == today.month;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              ),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 20, color: AppColors.neutral400),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- month switcher ----
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: _canGoBack ? () => _changeMonth(-1) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink(context)),
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: _canGoForward ? () => _changeMonth(1) : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- weekday header ----
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutral400),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ---- grid ----
          _DatePickerGrid(
            month: _month,
            selected: _selected,
            today: isCurrentMonth ? today : null,
            inRange: _inRange,
            onSelect: _select,
          ),
        ],
      ),
    );
  }
}

class _DatePickerGrid extends StatelessWidget {
  const _DatePickerGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.inRange,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime? today;
  final bool Function(DateTime day) inRange;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: Monday=1..Sunday=7. Grid header starts on Sunday,
    // so convert to a Sunday-first offset — same convention as the
    // Calendar tab's month grid, so the two never disagree about which
    // column a given weekday falls in.
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows * 7,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemBuilder: (context, i) {
        final dayNum = i - leadingBlanks + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

        final day = DateTime(month.year, month.month, dayNum);
        final enabled = inRange(day);
        final isToday = today != null && today!.day == dayNum && today!.month == month.month && today!.year == month.year;
        final isSelected = selected.year == day.year && selected.month == day.month && selected.day == dayNum;

        return Padding(
          padding: const EdgeInsets.all(2),
          child: GestureDetector(
            onTap: enabled ? () => onSelect(day) : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primaryLight
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                  color: !enabled
                      ? AppColors.neutral300
                      : isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primaryDark
                              : AppColors.inkSoft(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: AppColors.neutral100,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: disabled ? AppColors.neutral300 : AppColors.neutral700),
        ),
      ),
    );
  }
}
