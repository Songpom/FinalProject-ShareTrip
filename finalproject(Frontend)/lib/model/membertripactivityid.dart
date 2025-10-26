class MemberTripActivityId {
  int? memberTrip;
  int? activity;

  MemberTripActivityId({
    this.memberTrip,
    this.activity,
  });

  factory MemberTripActivityId.fromJson(Map<String, dynamic> json) => MemberTripActivityId(
    memberTrip: json['memberTrip'],
    activity: json['activity'],
  );

  Map<String, dynamic> toJson() => {
    'memberTrip': memberTrip,
    'activity': activity,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberTripActivityId &&
          runtimeType == other.runtimeType &&
          memberTrip == other.memberTrip &&
          activity == other.activity;

  @override
  int get hashCode => Object.hash(memberTrip, activity);
}
