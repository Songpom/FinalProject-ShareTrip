import 'package:finalproject/model/member.dart';

class MemberSearchResult {
  final bool joined;
  final Member member;

  MemberSearchResult({
    required this.joined,
    required this.member,
  });

  factory MemberSearchResult.fromJson(Map<String, dynamic> json) {
    return MemberSearchResult(
      joined: json['joined'] ?? false,
      member: Member.fromJson(json['member']),
    );
  }
}