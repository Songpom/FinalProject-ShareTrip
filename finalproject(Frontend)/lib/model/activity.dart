import 'package:finalproject/model/membertripactivity.dart';

class Activity {
  int? activityId;
  String? activityName;
  String? activityDetail;
  double? activityPrice;
  String? imagePaymentActivity;
  DateTime? activityDateTime;
  List<MemberTripActivity>? memberTripActivity;

  Activity({
    this.activityId,
    this.activityName,
    this.activityDetail,
    this.activityPrice,
    this.imagePaymentActivity,
    this.activityDateTime,
    this.memberTripActivity,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    activityId: json['activityId'],
    activityName: json['activityName'],
    activityDetail: json['activityDetail'],
    activityPrice: (json['activityPrice'] as num?)?.toDouble(),
    imagePaymentActivity: (json['imagePaymentaActivity']), // ชื่อ field สะกดผิดจาก Java
    activityDateTime: json['activityDateTime'] != null
        ? DateTime.parse(json['activityDateTime'])
        : null,
    memberTripActivity: (json['memberTripActivity'] as List<dynamic>?)
        ?.map((e) => MemberTripActivity.fromJson(e))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'activityId': activityId,
    'activityName': activityName,
    'activityDetail': activityDetail,
    'activityPrice': activityPrice,
    'imagePaymentaActivity': imagePaymentActivity, // ใช้ชื่อเดิมตาม backend
    'activityDateTime': activityDateTime?.toIso8601String(),
    'memberTripActivity': memberTripActivity?.map((e) => e.toJson()).toList(),
  };
}
