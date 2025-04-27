import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParkUser {
  final DocumentReference<Map<String, dynamic>> _reference;
  double amount;
  DateTime? using;

  ParkUser._(this._reference, this.amount, this.using);

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'using': using?.millisecondsSinceEpoch,
    };
  }

  factory ParkUser.fromMap(
      DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic>? map) {
    return ParkUser._(
      ref,
      (map?['amount'] as num?)?.toDouble() ?? 0.0,
      map?['using'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map?['using'] as int),
    );
  }

  /// Used to calculate cost and display via QR before toggling.
  static double calculateCostFromTimestamp(String timestamp) {
    final start = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    final duration = DateTime.now().difference(start).inMinutes;
    final cost = max(duration, 5) * 0.1;
    return double.parse(cost.toStringAsFixed(2));
  }

  /// Used to generate the string for QR code (lot and start time)
  static String generateQrPayload(int lotNumber, DateTime startTime) {
    return 'lot=$lotNumber;start=${startTime.millisecondsSinceEpoch}';
  }

  /// Optional: Parse QR data if scanned
  static Map<String, String> parseQrPayload(String payload) {
    final parts = payload.split(';');
    return {
      for (var part in parts) part.split('=')[0]: part.split('=')[1],
    };
  }

  /// Toggle parking usage and handle billing
  Future<(bool, String)> toggleUsing() async {
    if (using == null) {
      using = DateTime.now();
      return FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(_reference);
        var user = ParkUser.fromMap(snapshot.reference, snapshot.data());
        if (!snapshot.exists || user.amount < 1) {
          return (true, 'Doesn\'t have enough balance!');
        }
        user.using = using;
        transaction.set(_reference, user.toMap());
        return (false, 'Started using parking');
      }).catchError((error) {
        using = null;
        return (true, 'Something went wrong!');
      });
    } else {
      final start = using!;
      return FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(_reference);
        var user = ParkUser.fromMap(snapshot.reference, snapshot.data());
        user.using = null;

        final durationInMinutes = DateTime.now().difference(start).inMinutes;
        final cost = max(durationInMinutes, 5) * 0.1;

        user.amount -= cost;
        transaction.set(_reference, user.toMap());
        return (
          false,
          'Stopped using parking. Total cost: \$${cost.toStringAsFixed(2)}'
        );
      }).catchError((error) {
        using = start;
        return (true, 'Something went wrong!');
      });
    }
  }
}
