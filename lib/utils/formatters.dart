import 'package:intl/intl.dart';

final DateFormat ledgerDateFormat = DateFormat('dd-MM-yyyy');

String formatDecimal(num value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
