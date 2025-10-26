import 'package:finalproject/model/membertrip.dart';
import 'package:finalproject/model/activity.dart';

class Trip {
  int? tripId;
  String? tripName;
  DateTime? startDate;
  DateTime? dueDate;
  double? budget;
  String? image;
  String? tripDetail;
  String? location;
  String? tripStatus;
  List<MemberTrip>? memberTrips;
  List<Activity>? activity;

  Trip({
    this.tripId,
    this.tripName,
    this.startDate,
    this.dueDate,
    this.budget,
    this.image,
    this.tripDetail,
    this.location,
    this.tripStatus,
    this.memberTrips,
    this.activity,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    tripId: json['tripId'],
    tripName: json['tripName'] ?? '',
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    budget: json['budget'] != null ? double.tryParse(json['budget'].toString()) ?? 0.0 : 0.0,
    image: json['image'] ?? '',
    tripDetail: json['tripDetail'] ?? '',
    location: json['location'] ?? '',
    tripStatus: json['tripStatus'] ?? '',
    memberTrips: json['memberTrips'] != null
        ? List<MemberTrip>.from(json['memberTrips'].map((x) => MemberTrip.fromJson(x)))
        : [],
    activity: json['activity'] != null
        ? List<Activity>.from(json['activity'].map((x) => Activity.fromJson(x)))
        : [],
  );

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'tripName': tripName,
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'budget': budget,
    'image': image,
    'tripDetail': tripDetail,
    'location': location,
    'tripStatus': tripStatus,
    'memberTrips': memberTrips?.map((e) => e.toJson()).toList(),
    'activity': activity?.map((e) => e.toJson()).toList(),
  };
}
