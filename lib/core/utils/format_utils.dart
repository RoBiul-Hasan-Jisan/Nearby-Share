String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

String formatSpeed(double bytesPerSecond) => '${formatBytes(bytesPerSecond.round())}/s';

String formatEta(Duration? d) {
  if (d == null) return 'Calculating…';
  final s = d.inSeconds;
  if (s <= 0) return 'A moment';
  if (s < 60) return '$s ${s == 1 ? 'second' : 'seconds'}';
  if (s < 3600) return '${s ~/ 60} min ${s % 60} sec';
  return '${s ~/ 3600} h ${(s % 3600) ~/ 60} min';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${_two(t.minute)} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime t) {
  final now = DateTime.now();
  if (_sameDay(t, now)) return 'Today';
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${_months[t.month - 1]} ${t.day}, ${t.year}';
}

String formatWhen(DateTime t) => '${dayLabel(t)}, ${formatClock(t)}';
