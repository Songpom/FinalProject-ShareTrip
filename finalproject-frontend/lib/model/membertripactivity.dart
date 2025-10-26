import 'membertrip.dart'; // โมเดล MemberTrip

class MemberTripActivity {
  MemberTrip? memberTrip;
  // สมมติไม่ได้ใช้ activity detail ที่นี่เลยใส่เป็น dynamic หรือสร้างโมเดลถ้ามี
  dynamic activity; 
  double? pricePerPerson;

  MemberTripActivity({
    this.memberTrip,
    this.activity,
    this.pricePerPerson,
  });

  factory MemberTripActivity.fromJson(Map<String, dynamic> json) => MemberTripActivity(
        memberTrip: json['memberTrip'] != null
            ? MemberTrip.fromJson(json['memberTrip'])
            : null,
        activity: json['activity'], // แก้ไขถ้าจำเป็น
        pricePerPerson: (json['pricePerPerson'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'memberTrip': memberTrip?.toJson(),
        'activity': activity,
        'pricePerPerson': pricePerPerson ?? 0.0,
      };
}
