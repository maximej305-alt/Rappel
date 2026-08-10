import 'package:intl/intl.dart';

import '../models/activity.dart';

String _intlLocale(String locale) =>
    locale.startsWith('fr') ? 'fr_FR' : 'en_US';

String formatFullDate(DateTime day, String locale) {
  return DateFormat('EEEE d MMMM yyyy', _intlLocale(locale)).format(day);
}

String formatShortDate(DateTime day, String locale) {
  return DateFormat('EEE d MMM', _intlLocale(locale)).format(day);
}

String formatTime(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String formatMonth(DateTime day, String locale) {
  return DateFormat('MMMM yyyy', _intlLocale(locale)).format(day);
}

String dateKey(DateTime day) => Activity.dateKey(day);
