import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finalproject/model/expenddetailresult.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:http_parser/http_parser.dart'; 
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;





class ExpendController {
  final String baseUrl = baseURL;
  

Future<List<ExpendDetailResult>> getCheckStatusMemberTrip(int tripId) async {
  final url = Uri.parse('$baseUrl/expend/member-trips-balances/$tripId');
  final response = await http.get(url);

  final body = response.body;
  debugPrint('--- RAW BODY (${body.length} chars) ---');
  debugPrint(body.substring(0, math.min(body.length, 800)));

  if (response.statusCode == 200) {
    final jsonList = json.decode(body) as List<dynamic>;

    for (final it in jsonList) {
      final map = it as Map<String, dynamic>;
      debugPrint(
        'raw unpaid=${map['unpaidExtraAmount']} '
        'status=${map['extraPaymentStatus']} '
        'mtId=${map['memberTripId']}',
      );
    }

    return jsonList.map((j) => ExpendDetailResult.fromJson(j)).toList();
  } else {
    throw Exception('ไม่สามารถโหลดข้อมูลสมาชิกได้ (สถานะ ${response.statusCode})');
  }
}


  Future<bool> doRequestExtraPayment({
    required int tripId,
    required List<Map<String, dynamic>> payments,
  }) async {
    final url = Uri.parse('$baseUrl/expend/request-payment-extra');

    final body = jsonEncode({
      'tripId': tripId,
      'payments': payments,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('เรียกเก็บเงินล้มเหลว (สถานะ ${response.statusCode})');
    }
  }
Future<Map<String, dynamic>> getExpendDetail({
  required int memberTripId,
  required int tripId,
}) async {
  final url = Uri.parse('$baseUrl/expend/getpaymentextradetail');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'memberTripId': memberTripId.toString(),
      'tripId': tripId.toString(),
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('ไม่สามารถดึงข้อมูลเพิ่มเติม: ${response.body}');
  }
}Future<Map<String, dynamic>> doPaymentExpend({
  required File slipImage,
  required double amount,
  required int memberTripId,
  required int tripId,
}) async {
  final uri = Uri.parse("$baseUrl/expend/uploadextraslippayment");

  // หา MIME type ของไฟล์
  final mimeType = lookupMimeType(slipImage.path) ?? 'application/octet-stream';
  final mimeSplit = mimeType.split('/'); // เช่น ['image', 'jpeg']

  final request = http.MultipartRequest("POST", uri)
    ..fields['amount'] = amount.toString()
    ..fields['memberTripId'] = memberTripId.toString()
    ..fields['tripId'] = tripId.toString()
    ..files.add(
      await http.MultipartFile.fromPath(
        'slip_image',
        slipImage.path,
        filename: basename(slipImage.path),
        contentType: MediaType(mimeSplit[0], mimeSplit[1]),
      ),
    );

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return {"status": "success", "message": response.body};
    } else {
      return {"status": "error", "message": response.body};
    }
  } catch (e) {
    return {"status": "error", "message": "บันทึกข้อมูลการชำระเงินเพิ่มเติมไม่สำเร็จ: $e"};
  }
}

}
