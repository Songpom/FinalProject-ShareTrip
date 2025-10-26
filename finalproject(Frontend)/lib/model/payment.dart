import 'package:finalproject/model/membertrip.dart';

class Payment {
  int? paymentId;
  String? paymentStatus;
  double? price;
  String? paymentDetail;
  String? paymentSlip;
  DateTime? datetimePayment;
  MemberTrip? membertrip;

  Payment({
    this.paymentId,
    this.paymentStatus,
    this.price,
    this.paymentDetail,
    this.paymentSlip,
    this.datetimePayment,
    this.membertrip,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    paymentId: json['paymentId'],
    paymentStatus: json['paymentStatus'] ?? '',
    price: json['price']?.toDouble() ?? 0.0,
    paymentDetail: json['paymentDetail'] ?? '',
    paymentSlip: json['paymentSlip'] ?? '',
    datetimePayment: json['datetimePayment'] != null ? DateTime.parse(json['datetimePayment']) : null,
    membertrip: json['membertrip'] != null ? MemberTrip.fromJson(json['membertrip']) : null,
  );

  Map<String, dynamic> toJson() => {
    'paymentId': paymentId,
    'paymentStatus': paymentStatus,
    'price': price,
    'paymentDetail': paymentDetail,
    'paymentSlip': paymentSlip,
    'datetimePayment': datetimePayment?.toIso8601String(),
    'membertrip': membertrip?.toJson(),
  };
}
