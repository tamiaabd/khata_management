import '../database/app_database.dart';

class LedgerTotals {
  const LedgerTotals({
    required this.pending,
    required this.value1,
    required this.value2,
    required this.value3,
  });

  static const zero = LedgerTotals(pending: 0, value1: 0, value2: 0, value3: 0);

  final double pending;
  final double value1;
  final double value2;
  final double value3;

  factory LedgerTotals.fromEntries(Iterable<LedgerEntry> entries) {
    var pending = 0.0;
    var value1 = 0.0;
    var value2 = 0.0;
    var value3 = 0.0;

    for (final entry in entries) {
      pending += entry.pendingPayment;
      value1 += entry.value1;
      value2 += entry.value2;
      value3 += entry.value3;
    }

    return LedgerTotals(
      pending: pending,
      value1: value1,
      value2: value2,
      value3: value3,
    );
  }

  LedgerTotals copyWith({
    double? pending,
    double? value1,
    double? value2,
    double? value3,
  }) {
    return LedgerTotals(
      pending: pending ?? this.pending,
      value1: value1 ?? this.value1,
      value2: value2 ?? this.value2,
      value3: value3 ?? this.value3,
    );
  }

  LedgerTotals operator +(LedgerTotals other) {
    return LedgerTotals(
      pending: pending + other.pending,
      value1: value1 + other.value1,
      value2: value2 + other.value2,
      value3: value3 + other.value3,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LedgerTotals &&
        other.pending == pending &&
        other.value1 == value1 &&
        other.value2 == value2 &&
        other.value3 == value3;
  }

  @override
  int get hashCode => Object.hash(pending, value1, value2, value3);
}
