import 'package:timezone/timezone.dart' as tz;

class DayStartTimeService {
  const DayStartTimeService();

  String localDateKeyForUtcInstant({
    required DateTime instantUtc,
    required String timezone,
    required int dayStartHour,
  }) {
    _validateDayStart(dayStartHour);

    final location = tz.getLocation(timezone);
    final localTime = tz.TZDateTime.from(instantUtc.toUtc(), location);
    final logicalDateTime = localTime.subtract(Duration(hours: dayStartHour));

    return _dateKey(
      logicalDateTime.year,
      logicalDateTime.month,
      logicalDateTime.day,
    );
  }

  bool isSameLogicalDay({
    required DateTime firstUtc,
    required DateTime secondUtc,
    required String timezone,
    required int dayStartHour,
  }) {
    final first = localDateKeyForUtcInstant(
      instantUtc: firstUtc,
      timezone: timezone,
      dayStartHour: dayStartHour,
    );

    final second = localDateKeyForUtcInstant(
      instantUtc: secondUtc,
      timezone: timezone,
      dayStartHour: dayStartHour,
    );

    return first == second;
  }

  DateTime convertOwnerLocalTimeToUtc({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required String timezone,
  }) {
    final location = tz.getLocation(timezone);
    final localDateTime = tz.TZDateTime(
      location,
      year,
      month,
      day,
      hour,
      minute,
    );
    return localDateTime.toUtc();
  }

  void _validateDayStart(int dayStartHour) {
    if (dayStartHour < 0 || dayStartHour > 23) {
      throw ArgumentError.value(
        dayStartHour,
        'dayStartHour',
        'Must be from 0 to 23.',
      );
    }
  }

  String _dateKey(int year, int month, int day) {
    final monthText = month.toString().padLeft(2, '0');
    final dayText = day.toString().padLeft(2, '0');
    return '$year-$monthText-$dayText';
  }
}
