import 'package:finalproject/model/member.dart';

class TripSummaryresult {
  final int tripId;
  final String tripName;
  final String tripDetail;
  final String emailowner;
  final List<MemberBalance> memberBalances;

  TripSummaryresult({
    required this.tripId,
    required this.tripName,
    required this.tripDetail,
    required this.emailowner,
    required this.memberBalances,
  });

  factory TripSummaryresult.fromJson(Map<String, dynamic> json) {
    var list = json['memberBalances'] as List<dynamic>? ?? [];
    List<MemberBalance> membersList =
        list.map((item) => MemberBalance.fromJson(item)).toList();

    return TripSummaryresult(
      tripId: json['tripId'] ?? 0,
      tripName: json['tripName'] ?? '',
      tripDetail: json['tripDetail'] ?? '',
      emailowner: json['emailowner'] ?? '',
      memberBalances: membersList,
    );
  }

  double totalBalance() {
    return memberBalances.fold(0.0, (sum, mb) => sum + mb.balance);
  }
}

class MemberBalance {
  final int memberTripId;
  final Member member;               // ชื่อตรงกับ JSON คือ 'member'
  final double totalPayment;
  final double totalPricePerPerson;
  final double balance;

  // ✅ ใหม่: สถานะและยอด “เรียกเก็บเพิ่มที่ยังไม่ชำระ”
  final String extraPaymentStatus;   // "pending" | "complete" (หรือว่าง)
  final double unpaidExtraAmount;    // รวมเฉพาะ pending

  MemberBalance({
    required this.memberTripId,
    required this.member,
    required this.totalPayment,
    required this.totalPricePerPerson,
    required this.balance,
    this.extraPaymentStatus = '',
    this.unpaidExtraAmount = 0.0,
  });

  bool get isEmpty => memberTripId == 0 && (member.email?.isEmpty ?? true);

  factory MemberBalance.empty() {
    return MemberBalance(
      memberTripId: 0,
      member: Member.empty(),
      totalPayment: 0,
      totalPricePerPerson: 0,
      balance: 0,
      extraPaymentStatus: '',
      unpaidExtraAmount: 0.0,
    );
  }

  factory MemberBalance.fromJson(Map<String, dynamic> json) {
    return MemberBalance(
      memberTripId: json['memberTripId'] ?? 0,
      member: json['member'] != null ? Member.fromJson(json['member']) : Member.empty(),
      totalPayment: (json['totalPayment'] as num?)?.toDouble() ?? 0.0,
      totalPricePerPerson: (json['totalPricePerPerson'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      extraPaymentStatus: (json['extraPaymentStatus'] as String?) ?? '',
      unpaidExtraAmount: (json['unpaidExtraAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
