import 'package:flutter/material.dart';

import 'calendar_service.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  if (CalendarService.activeCalendar == CalendarService.gregorian) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _SolarDateDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: helpText ?? 'Select date',
      locale: locale,
    ),
  );
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) async {
  if (CalendarService.activeCalendar == CalendarService.gregorian) {
    return showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
    );
  }
  final start = await showAppDatePicker(
    context: context,
    initialDate: initialDateRange?.start ?? lastDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: 'From date',
  );
  if (start == null || !context.mounted) return null;
  final end = await showAppDatePicker(
    context: context,
    initialDate: initialDateRange?.end ?? lastDate,
    firstDate: start,
    lastDate: lastDate,
    helpText: 'To date',
  );
  if (end == null) return null;
  return DateTimeRange(start: start, end: end);
}

class _SolarDateDialog extends StatefulWidget {
  const _SolarDateDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.locale,
  });
  final DateTime initialDate, firstDate, lastDate;
  final String title, locale;
  @override
  State<_SolarDateDialog> createState() => _SolarDateDialogState();
}

class _SolarDateDialogState extends State<_SolarDateDialog> {
  late SolarDate _month = CalendarService.fromGregorian(widget.initialDate);
  @override
  Widget build(BuildContext context) {
    final count = CalendarService.monthLength(_month.year, _month.month);
    final first = CalendarService.toGregorian(
      SolarDate(_month.year, _month.month, 1),
    );
    final offset = (first.weekday + 1) % 7; // Afghan week begins on Saturday.
    final cells = ((offset + count + 6) ~/ 7) * 7;
    final language = widget.locale.split(RegExp('[-_]')).first;
    final weekdays = language == 'fa'
        ? const [
            'شنبه',
            'یکشنبه',
            'دوشنبه',
            'سه‌شنبه',
            'چهارشنبه',
            'پنجشنبه',
            'جمعه',
          ]
        : language == 'ps'
        ? const [
            'شنبه',
            'یکشنبه',
            'دوشنبه',
            'سې‌شنبه',
            'چهارشنبه',
            'پنجشنبه',
            'جمعه',
          ]
        : const ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${CalendarService.solarMonthName(_month.month, widget.locale)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final day in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > count) return const SizedBox.shrink();
                final date = CalendarService.toGregorian(
                  SolarDate(_month.year, _month.month, day),
                );
                final valid =
                    !date.isBefore(_dateOnly(widget.firstDate)) &&
                    !date.isAfter(_dateOnly(widget.lastDate));
                final selected = _same(date, widget.initialDate);
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: TextButton(
                    onPressed: valid
                        ? () => Navigator.pop(context, date)
                        : null,
                    style: selected
                        ? TextButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                          )
                        : null,
                    child: Text('$day'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }

  void _shift(int delta) {
    var year = _month.year, month = _month.month + delta;
    if (month < 1) {
      year--;
      month = 12;
    }
    if (month > 12) {
      year++;
      month = 1;
    }
    setState(() => _month = SolarDate(year, month, 1));
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
