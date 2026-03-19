String formatTimestamp(String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }

  final dateTime = DateTime.tryParse(value)?.toLocal();
  if (dateTime == null) {
    return value;
  }

  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
