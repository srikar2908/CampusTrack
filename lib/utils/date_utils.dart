import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DateUtilsHelper {
  static String formatTime(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Unknown';
      if (timestamp is Timestamp) return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
      if (timestamp is String) return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(timestamp));
      if (timestamp is DateTime) return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
      return 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }
}
