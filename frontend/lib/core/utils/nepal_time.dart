import 'package:intl/intl.dart';

/// Nepal timezone is UTC+5:45. These helpers treat a date/time as "Nepal local".
///
/// This is useful when the device timezone is not set to Nepal but the app
/// should always show times in Nepal.
const Duration _kNepalOffset = Duration(hours: 5, minutes: 45);

/// Returns the current time in Nepal.
DateTime nepalNow() => DateTime.now().toUtc().add(_kNepalOffset);

/// Converts [dt] to Nepal time, assuming [dt] is in UTC or local time.
DateTime toNepal(DateTime dt) => dt.toUtc().add(_kNepalOffset);

/// Parses a booking date/time that is stored as separate strings.
///
/// [date] is expected to be in `yyyy-MM-dd` format.
/// [time] is expected to be in `HH:mm:ss` (or `HH:mm`) format.
///
/// If parsing fails, returns null.
DateTime? parseBookingDateTime(String? date, String? time) {
  if (date == null || date.isEmpty) return null;

  try {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);

    int hour = 0;
    int minute = 0;
    if (time != null && time.isNotEmpty) {
      final timeParts = time.split(':');
      if (timeParts.length >= 2) {
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }
    }

    final utc = DateTime.utc(y, m, d, hour, minute);
    return toNepal(utc);
  } catch (_) {
    return null;
  }
}

/// Formats a date/time in Nepal time. If parsing fails, returns [fallback].
String formatNepalDateTime(String? date, String? time,
    {String fallback = '—'}) {
  final dt = parseBookingDateTime(date, time);
  if (dt == null) return fallback;
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
}

/// Formats only the date portion in Nepal time.
String formatNepalDate(String? date, String? time, {String fallback = '—'}) {
  final dt = parseBookingDateTime(date, time);
  if (dt == null) return fallback;
  return DateFormat('yyyy-MM-dd').format(dt);
}

/// Formats only the time portion in Nepal time.
String formatNepalTime(String? date, String? time, {String fallback = '—'}) {
  final dt = parseBookingDateTime(date, time);
  if (dt == null) return fallback;
  return DateFormat('HH:mm:ss').format(dt);
}
