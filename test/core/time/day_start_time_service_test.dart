import 'package:coworkplace/core/time/day_start_time_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  const service = DayStartTimeService();

  test('localDateKeyForUtcInstant respects dayStartHour boundary', () {
    const timezone = 'Asia/Dhaka';

    // 2026-03-13 03:30 in Dhaka, with day start at 04:00, belongs to previous logical day.
    final utcBeforeBoundary = DateTime.utc(2026, 3, 12, 21, 30);

    final dateKey = service.localDateKeyForUtcInstant(
      instantUtc: utcBeforeBoundary,
      timezone: timezone,
      dayStartHour: 4,
    );

    expect(dateKey, '2026-03-12');
  });

  test('isSameLogicalDay returns false when crossing logical day boundary', () {
    const timezone = 'America/New_York';

    final firstUtc = DateTime.utc(2026, 3, 13, 8, 0); // 04:00 local (EDT)
    final secondUtc = DateTime.utc(2026, 3, 14, 8, 1); // 04:01 next local day

    final result = service.isSameLogicalDay(
      firstUtc: firstUtc,
      secondUtc: secondUtc,
      timezone: timezone,
      dayStartHour: 4,
    );

    expect(result, false);
  });

  test(
    'convertOwnerLocalTimeToUtc converts timezone local date-time to UTC',
    () {
      const timezone = 'Europe/Berlin';

      final utc = service.convertOwnerLocalTimeToUtc(
        year: 2026,
        month: 7,
        day: 6,
        hour: 9,
        minute: 30,
        timezone: timezone,
      );

      final berlin = tz.TZDateTime.from(utc, tz.getLocation(timezone));
      expect(berlin.year, 2026);
      expect(berlin.month, 7);
      expect(berlin.day, 6);
      expect(berlin.hour, 9);
      expect(berlin.minute, 30);
    },
  );

  test('localDateKeyForUtcInstant throws for invalid dayStartHour', () {
    expect(
      () => service.localDateKeyForUtcInstant(
        instantUtc: DateTime.utc(2026, 1, 1),
        timezone: 'UTC',
        dayStartHour: 24,
      ),
      throwsArgumentError,
    );
  });
}
