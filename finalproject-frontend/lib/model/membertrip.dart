import 'package:finalproject/model/member.dart';
import 'package:finalproject/model/payment.dart';
import 'package:finalproject/model/refund.dart';
import 'package:finalproject/model/trip.dart';
class MemberTrip {
  int? memberTripId;
  DateTime? dateJoin;
  String? memberTripStatus;
  Member? participant;
  Refund? refund;
  Trip? trip;
  List<Payment>? payments;

  MemberTrip({
    this.memberTripId,
    this.dateJoin,
    this.memberTripStatus,
    this.participant,
    this.refund,
    this.trip,
    this.payments,
  });

  factory MemberTrip.fromJson(Map<String, dynamic> json) => MemberTrip(
    memberTripId: json['memberTripId'],
    dateJoin: json['dateJoin'] != null ? DateTime.parse(json['dateJoin']) : null,
    memberTripStatus: json['memberTripStatus'] ?? '',
    participant: json['participant'] != null ? Member.fromJson(json['participant']) : null,
    refund: json['refund'] != null ? Refund.fromJson(json['refund']) : null,
    trip: json['trip'] != null ? Trip.fromJson(json['trip']) : null,
    payments: json['payments'] != null
      ? List<Payment>.from(json['payments'].map((x) => Payment.fromJson(x)))
      : [],
  );

  Map<String, dynamic> toJson() => {
    'memberTripId': memberTripId,
    'dateJoin': dateJoin?.toIso8601String(),
    'memberTripStatus': memberTripStatus,
    'participant': participant?.toJson(),
    'refund': refund?.toJson(),
    'trip': trip?.toJson(),
    'payments': payments?.map((e) => e.toJson()).toList(),
  };
}
