import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finalproject/model/trip.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';


class TripController {
  // Future<List<Trip>> getAllTrips() async {
  //   final url = Uri.parse(baseURL + '/trips');
  //   final response = await http.get(url, headers: headers);

  //   if (response.statusCode == 200) {
  //     List<dynamic> jsonList = json.decode(response.body);
  //     return jsonList.map((item) => Trip.fromJson(item)).toList();
  //   } else {
  //     throw Exception('โหลดทริปไม่สำเร็จ');
  //   }
  // }
  Future<dynamic> doCreateTrip({
  required String tripName,
  required DateTime startDate,
  required DateTime dueDate,
  required double budget,
  required String tripDetail,
  required String location,
  required String tripStatus,
  required File image,
  required String memberEmail,
}) async {
  try {
    final df = DateFormat('yyyy-MM-dd'); // ✅ ฟอร์แมตคงที่
    final uri = Uri.parse(baseURL + '/trips/create');
    final request = http.MultipartRequest('POST', uri);

    request.fields['tripName']   = tripName;
    request.fields['startDate']  = df.format(startDate); // ✅
    request.fields['dueDate']    = df.format(dueDate);   // ✅
    request.fields['budget']     = budget.toString();
    request.fields['tripDetail'] = tripDetail;
    request.fields['location']   = location;
    request.fields['tripStatus'] = tripStatus;
    request.fields['memberName'] = memberEmail;

    final stream = http.ByteStream(image.openRead());
    final length = await image.length();
    final multipartFile = http.MultipartFile(
      'image', stream, length, filename: basename(image.path),
    );
    request.files.add(multipartFile);

    // ไม่ต้อง set Content-Type เอง MultipartRequest จะจัดการให้

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {"status": "ok", "data": jsonDecode(body)};
    } else {
      return {"status": "error", "message": "ไม่สามารถสร้างทริปได้: $body"};
    }
  } catch (e) {
    return {"status": "error", "message": e.toString()};
  }
}

  Future<Trip> getTripDetail(int id) async {
  final url = Uri.parse('$baseURL/trips/$id');
  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    return Trip.fromJson(json.decode(response.body));
  } else {
    throw Exception('ไม่สามารถโหลดข้อมูลทริปได้');
  }
}
Future<List<Trip>> getListMyTrip(String email) async {
  final url = Uri.parse('$baseURL/membertrips/byEmail');

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      // ถ้ามี header พิเศษเช่น Authorization ให้เพิ่มในนี้
      // 'Authorization': 'Bearer your_token',
    },
    body: jsonEncode({'email': email}),
  );

  if (response.statusCode == 200) {
    // สมมติว่า response.body เป็น JSON array ของ trip objects
    List<dynamic> jsonList = json.decode(response.body);

    // แปลงแต่ละ JSON object ใน list เป็น Trip instance
    List<Trip> trips = jsonList.map((item) => Trip.fromJson(item)).toList();

    return trips;
  } else {
    throw Exception('ไม่สามารถโหลดทริปของผู้ใช้ $email ได้ (status code: ${response.statusCode})');
  }
}

Future<Map<String, dynamic>> getPaymentDetail({
  required String email,
  required int tripId,
}) async {
  final url = Uri.parse('$baseURL/membertrips/getpaymentdetail');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'tripId': tripId.toString()}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    // ถ้าไม่มี qrcode → ฟรี (เข้าร่วมเรียบร้อย)
    if (data is Map && data['qrcode'] == null) {
      return {
        'status': (data['status'] ?? 'ok').toString(),
        'message': data['message'] ?? 'เข้าร่วมสำเร็จ (ไม่ต้องชำระเงิน)',
      };
    }

    // ต้องชำระเงิน (มี qrcode)
    return {
      'status': 'success',
      'trip': Trip.fromJson(data['trip']),
      'qrcode': data['qrcode'],
    };
  } else {
    return {
      'status': 'error',
      'message': response.body,
    };
  }
}


 Future<Map<String, dynamic>> getCheckSlip({
    required File slipImage,
    required double amount,
    required int tripId,
    required String email,
  }) async {
    try {
      var uri = Uri.parse('$baseURL/membertrips/getcheckslip');

      var request = http.MultipartRequest('POST', uri);

      // ส่งข้อมูล fields ที่ต้องการ
      request.fields['amount'] = amount.toStringAsFixed(0);
      request.fields['tripId'] = tripId.toString();
      request.fields['email'] = email;

      // เพิ่มไฟล์รูปภาพ
      var stream = http.ByteStream(slipImage.openRead());
      var length = await slipImage.length();

      var multipartFile = http.MultipartFile(
  'slip_image',
  http.ByteStream(slipImage.openRead()),
  await slipImage.length(),
  filename: basename(slipImage.path),
  contentType: MediaType('image', 'jpeg'), // 🔥 ใส่ MIME ชัดเจน
);

      request.files.add(multipartFile);

      // อย่าใส่ header Content-Type เอง เพราะ MultipartRequest จะจัดการให้เอง
      // request.headers.addAll({
      //   "Content-Type": "multipart/form-data",
      // });

      var response = await request.send();

      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return {
          "status": "success",
          "data": jsonDecode(responseBody),
        };
      } else {
        return {
          "status": "error",
          "message": responseBody,
        };
      }
    } catch (e) {
      return {
        "status": "error",
        "message": e.toString(),
      };
    }
  }
 Future<Map<String, dynamic>> doEditTrip({
  required int tripId,
  required String tripName,
  required DateTime startDate,
  required DateTime dueDate,
  required double budget,
  required String tripDetail,
  required String location,
  required String tripStatus,
  File? image,
}) async {
  final df = DateFormat('yyyy-MM-dd'); // ✅
  final uri = Uri.parse('$baseURL/trips/update');

  final request = http.MultipartRequest('PUT', uri)
    ..fields['tripId']     = tripId.toString()
    ..fields['tripName']   = tripName
    ..fields['startDate']  = df.format(startDate) // ✅
    ..fields['dueDate']    = df.format(dueDate)   // ✅
    ..fields['budget']     = budget.toString()
    ..fields['tripDetail'] = tripDetail
    ..fields['location']   = location
    ..fields['tripStatus'] = tripStatus;

  if (image != null) {
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
  }

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  return {
    'statusCode': response.statusCode,
    'body': responseBody,
  };
}

 Future<Map<String, dynamic>> doRemoveTrip(int tripId) async {
    // สมมติ backend ทำ endpoint นี้:
    // - ลบสำเร็จ: 200/204 -> {"status":"deleted"}
    // - มีสมาชิกอื่นอยู่: 409 -> {"status":"need_refund","message":"..."} หรือ {"hasOtherParticipants":true}
    final url = Uri.parse('$baseURL/trips/$tripId');

    final response = await http.delete(url, headers: headers);

    if (response.statusCode == 200 || response.statusCode == 204) {
      // ลบสำเร็จ
      return {'status': 'deleted'};
    } else if (response.statusCode == 409) {
      // มีสมาชิกอื่น ต้องไปเคลียร์ refund ก่อน
      try {
        final body = json.decode(response.body);
        return {
          'status': body['status'] ?? 'need_refund',
          'message': body['message'],
          'hasOtherParticipants': body['hasOtherParticipants'] ?? true,
        };
      } catch (_) {
        return {'status': 'need_refund', 'hasOtherParticipants': true};
      }
    } else {
      // กรณีอื่น โยน error ออกไปให้ UI แสดง
      throw Exception(
          'ลบทริปไม่สำเร็จ (HTTP ${response.statusCode}): ${response.body}');
    }
  }
    final Dio _dio = Dio();
Future<Map<String, dynamic>> getPaymentJoin({required int memberTripId}) async {
    final resp = await _dio.get('$baseURL/trips/check-join/$memberTripId');
    if (resp.statusCode == 200 && resp.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(resp.data);
    }
    throw Exception('ไม่พบข้อมูลการชำระค่าเข้าร่วม');
  }


Future<Map<String, dynamic>> getViewRefundPayment({
  required int tripId,
  required String email,
}) async {
  final dio = Dio();
  final resp = await dio.post(
    '$baseURL/refund/view',
    data: {
      'tripId': tripId,
      'email': email,
    },
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
  return Map<String, dynamic>.from(resp.data as Map);
}

}
