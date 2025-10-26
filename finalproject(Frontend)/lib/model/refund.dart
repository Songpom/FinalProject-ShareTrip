import 'package:finalproject/model/membertrip.dart';

class Refund {
  int? refundId;
  double? amount;
  DateTime? datetimeRefund;
  String? refundSlipImage;
  MemberTrip? memberTrip;

  Refund({
    this.refundId,
    this.amount,
    this.datetimeRefund,
    this.refundSlipImage,
    this.memberTrip,
  });

  factory Refund.fromJson(Map<String, dynamic> json) => Refund(
    refundId: json['refundId'],
    amount: json['amount']?.toDouble() ?? 0.0,
    datetimeRefund: json['datetimeRefund'] != null ? DateTime.parse(json['datetimeRefund']) : null,
    refundSlipImage: json['refundSlipImage'] ?? '',
    memberTrip: json['memberTrip'] != null ? MemberTrip.fromJson(json['memberTrip']) : null,
  );

  Map<String, dynamic> toJson() => {
    'refundId': refundId,
    'amount': amount,
    'datetimeRefund': datetimeRefund?.toIso8601String(),
    'refundSlipImage': refundSlipImage,
    'memberTrip': memberTrip?.toJson(),
  };
}
