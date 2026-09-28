import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String currency(num amount) => _inr.format(amount);

  static String date(DateTime dt) => DateFormat('d MMM yyyy').format(dt.toLocal());

  static String dateTime(DateTime dt) =>
      DateFormat('d MMM yyyy, h:mm a').format(dt.toLocal());

  static String relativeShort(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(dt);
  }

  /// "9876543210" -> "98765 43210"
  static String phoneGrouped(String tenDigits) {
    if (tenDigits.length != 10) return tenDigits;
    return '${tenDigits.substring(0, 5)} ${tenDigits.substring(5)}';
  }

  static String tenureDays(int days) {
    if (days % 30 == 0 && days >= 30) {
      final months = days ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'}';
    }
    return '$days days';
  }
}
