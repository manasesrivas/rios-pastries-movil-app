String formatTime(String value) {
  final time = DateTime.tryParse('2000-01-01T$value');
  if (time == null) return value;

  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}