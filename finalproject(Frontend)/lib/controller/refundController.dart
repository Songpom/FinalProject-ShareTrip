import 'dart:convert';
import 'package:finalproject/model/tripsummaryresult.dart';
import 'package:http/http.dart' as http;
import 'package:finalproject/constant/constant_value.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart'; 

class RefundController {

  Future<TripSummaryresult> getMemberTrip(int tripId) async {
    // แก้ไข path string ที่ผิดพลาด
    final url = Uri.parse('$baseURL/refund/listrefundmember/$tripId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return TripSummaryresult.fromJson(data);
    } else {
      throw Exception('เกิดข้อผิดพลาด: ${response.statusCode}');
    }
  }
  Future<Map<String, dynamic>> getViewRefund({required int memberTripId}) async {
    final url = Uri.parse('$baseURL/refund/refundmember/qrcode');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }, // หรือใช้ headers จาก constant_value.dart ถ้าคุณมี
      body: jsonEncode({
        'memberTripId': memberTripId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // โยนรายละเอียด error ออกไปให้ UI แสดง
      throw Exception('เรียก QR คืนเงินไม่สำเร็จ (${response.statusCode}): ${response.body}');
    }
  }
Future<Map<String, dynamic>> doRefundPayment({
  required File slipImage,
  required double amount,
  required int memberTripId,
}) async {
  final uri = Uri.parse('$baseURL/refund/upload-refund-slip');

  final mimeType = lookupMimeType(slipImage.path) ?? 'application/octet-stream';
  final parts = mimeType.split('/');

  final request = http.MultipartRequest('POST', uri)
    ..fields['amount'] = amount.toString()
    ..fields['memberTripId'] = memberTripId.toString()
    ..files.add(
      await http.MultipartFile.fromPath(
        'slip_image',
        slipImage.path,
        contentType: MediaType(parts[0], parts[1]),
      ),
    );

  try {
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    // ✅ ยอมรับทั้ง 200 และ 201 (หรือช่วง 2xx)
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    // บางกรณี backend ส่งข้อความธรรมดา ไม่ใช่ JSON
    String message;
    try {
      final body = jsonDecode(response.body);
      message = body is Map && body['message'] != null
          ? body['message'].toString()
          : response.body;
    } catch (_) {
      message = response.body;
    }

    if (ok) {
      return {'status': 'success', 'message': message};
    } else {
      return {'status': 'error', 'message': message};
    }
  } catch (e) {
    return {'status': 'error', 'message': 'เกิดข้อผิดพลาด: $e'};
  }
}

  // ฟังก์ชันอื่นๆ ที่เกี่ยวข้องกับ trip/api เช่น requestExtraPayment, getCheckSlip
}
