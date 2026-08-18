import 'package:intl/intl.dart';

import '../models/activity.dart';

/// Locale `intl` correspondant au code UI (fr, en, es, …).
String intlLocale(String locale) {
  final code = locale.split(RegExp('[_-]')).first.toLowerCase();
  return switch (code) {
    'fr' => 'fr_FR',
    'en' => 'en_US',
    'es' => 'es',
    'de' => 'de',
    'it' => 'it',
    'pt' => 'pt',
    'zh' => 'zh_CN',
    'ar' => 'ar',
    _ => 'en_US',
  };
}

String formatFullDate(DateTime day, String locale) {
  return DateFormat('EEEE d MMMM yyyy', intlLocale(locale)).format(day);
}

String formatShortDate(DateTime day, String locale) {
  return DateFormat('EEE d MMM', intlLocale(locale)).format(day);
}

String formatTime(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String formatMonth(DateTime day, String locale) {
  return DateFormat('MMMM yyyy', intlLocale(locale)).format(day);
}

String dateKey(DateTime day) => Activity.dateKey(day);
