import 'dart:convert';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/model/member.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path/path.dart';
import 'package:finalproject/model/membersearchresult.dart';

class MemberController {
  // Function to add a new member
  Future<dynamic> doRegister(
    String username,
    String password,
    String firstName,
    String lastName,
    String email,
    File memberImage,
    String phone,
    String promptpayNumber,
  ) async {
    try {
      final uri = Uri.parse(baseURL + '/members');
      final request = http.MultipartRequest('POST', uri);
      request.fields['username'] = username;
      request.fields['password'] = password;
      request.fields['firstName'] = firstName;
      request.fields['lastName'] = lastName;
      request.fields['email'] = email;
      request.fields['tel'] = phone;
      request.fields['promptpay_number'] = promptpayNumber;

      final stream = http.ByteStream(memberImage.openRead());
      final length = await memberImage.length();
      final multipartFile = http.MultipartFile(
        'member_image',
        stream,
        length,
        filename: basename(memberImage.path),
      );
      request.files.add(multipartFile);
      request.headers.addAll(headers);

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"status": "ok", "code": response.statusCode};
      } else {
        String message = 'สมัครไม่สำเร็จ';
        try {
          final json = jsonDecode(respStr);
          message = json is Map && json['message'] is String ? json['message'] : respStr;
        } catch (_) {
          message = respStr;
        }
        return {"status": "error", "code": response.statusCode, "message": message};
      }
    } catch (e) {
      return {"status": "error", "code": 0, "message": e.toString()};
    }
  }

  // Function to login a member
  Future<dynamic> doLogin(String email, String password) async {
    Map<String, dynamic> data = {"email": email, "password": password};

    var body = json.encode(data);
    var url = Uri.parse(baseURL + '/members/login');

    http.Response response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      var responseData = json.decode(response.body);
      return {"status": "ok", "data": responseData};
    } else if (response.statusCode == 401) {
      return {"status": "error", "message": "อีเมลหรือรหัสผ่านไม่ถูกต้อง"};
    } else {
      return {"status": "error", "message": "อีเมลหรือรหัสผ่านไม่ถูกต้อง"};
    }
  }

  // Function to search members
  Future<List<MemberSearchResult>> getListMember(String keyword, int tripId) async {
    try {
      var url = Uri.parse('$baseURL/members/search');
      var body = json.encode({
        'keyword': keyword,
        'tripId': tripId,
      });

      var response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        List<MemberSearchResult> results =
            data.map((e) => MemberSearchResult.fromJson(e)).toList();
        return results;
      } else {
        throw Exception('ค้นหาไม่สำเร็จ: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // Function to invite a member
  Future<void> doInviteMember(String email, int tripId) async {
    final url = Uri.parse('$baseURL/membertrips/invite');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'tripId': tripId}),
    );

    if (response.statusCode != 201) {
      throw Exception('เชิญสมาชิกไม่สำเร็จ: ${response.body}');
    }
  }
}