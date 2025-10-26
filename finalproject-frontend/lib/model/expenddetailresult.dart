import 'member.dart';

class ExpendDetailResult {
  final int memberTripId;
  final Member? member;
  final double totalPayment;
  final double totalPricePerPerson;
  final double balance;
  final List<ActivitySummary> activities;

  /// "pending" | "complete"
  final String extraPaymentStatus;

  /// ✅ ยอดเรียกเก็บเพิ่มที่ค้างชำระจากก่อนหน้า (pending)
  final double unpaidExtraAmount;

  ExpendDetailResult({
    required this.memberTripId,
    this.member,
    required this.totalPayment,
    required this.totalPricePerPerson,
    required this.balance,
    required this.activities,
    this.extraPaymentStatus = "complete",
    this.unpaidExtraAmount = 0.0,
  });

  factory ExpendDetailResult.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final activitiesJson = (json['activities'] as List<dynamic>?) ?? const [];

    return ExpendDetailResult(
      memberTripId: (json['memberTripId'] as num?)?.toInt() ?? 0,
      member: json['member'] != null ? Member.fromJson(json['member']) : null,
      totalPayment: _toDouble(json['totalPayment']),
      totalPricePerPerson: _toDouble(json['totalPricePerPerson']),
      balance: _toDouble(json['balance']),
      activities: activitiesJson.map((e) => ActivitySummary.fromJson(e)).toList(),
      extraPaymentStatus: (json['extraPaymentStatus'] as String?)?.trim() ?? "complete",
      unpaidExtraAmount: _toDouble(json['unpaidExtraAmount']), // 👈 สำคัญ
      
    );
  }
}

class ActivitySummary {
  final int activityId;
  final String activityName;
  final double pricePerPerson;
  final DateTime activityDate;

  ActivitySummary({
    required this.activityId,
    required this.activityName,
    required this.pricePerPerson,
    required this.activityDate,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    final raw = json['activityDate']?.toString();
    DateTime parsed;
    try {
      parsed = raw != null ? DateTime.parse(raw) : DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      parsed = DateTime.fromMillisecondsSinceEpoch(0);
    }
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    return ActivitySummary(
      activityId: (json['activityId'] as num?)?.toInt() ?? 0,
      activityName: (json['activityName'] as String?) ?? '',
      pricePerPerson: _toDouble(json['pricePerPerson']),
      activityDate: parsed,
    );
  }
}
