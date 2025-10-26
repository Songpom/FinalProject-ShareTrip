import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finalproject/model/activity.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:intl/intl.dart';




class ActivityController {
  // ✅ ดึงกิจกรรมทั้งหมดของทริป
  Future<List<Activity>> getListActivity(int tripId) async {
    try {
      var url = Uri.parse('$baseURL/activities/trip/$tripId');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((e) => Activity.fromJson(e)).toList();
      } else {
        throw Exception('โหลดกิจกรรมไม่สำเร็จ: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  String _formatForBackendNoTzBug(DateTime localDateTime) {
    final local = localDateTime.toLocal();
    // บวก timeZoneOffset (เช่น +07:00) เพื่อชดเชยกรณี backend ตีความเป็น UTC
    final shifted = local.add(local.timeZoneOffset);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(shifted);
  }

Future<bool> doAddActivity({
  required String activityName,
  required String activityDetail,
  required double activityPrice,
  required String activityDateTime, // <- รับเป็น String
  required int tripId,
  required File imageFile,
  required List<int> memberTripIds,
  required List<double> pricePerPersons,
}) async {
  final dio = Dio();

  final formData = FormData.fromMap({
    'activityName': activityName,
    'activityDetail': activityDetail,
    'activityPrice': activityPrice.toString(),
    'activityDateTime': activityDateTime, // <- ใช้ตรงๆ ไม่ต้องแปลงอีก
    'tripId': tripId.toString(),
    'memberTripIds': memberTripIds.map((e) => e.toString()).toList(),
    'pricePerPersons': pricePerPersons.map((e) => e.toString()).toList(),
    'image': await MultipartFile.fromFile(
      imageFile.path,
      filename: basename(imageFile.path),
    ),
  });

  try {
    final response = await dio.post(
      '$baseURL/activities/create',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  } catch (e) {
    print('Error while creating activity: $e');
    return false;
  }
}

Future<Activity> getActivityDetail(int activityId) async {
  try {
    final url = Uri.parse('$baseURL/activities/$activityId');
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Activity.fromJson(jsonData);
    } else {
      throw Exception('ไม่สามารถโหลดกิจกรรมได้ (${response.statusCode})');
    }
  } catch (e) {
    throw Exception('เกิดข้อผิดพลาดในการโหลดกิจกรรม: $e');
  }
}
Future<bool> doEditActivity({
  required int activityId,
  required String activityName,
  required String activityDetail,
  required double activityPrice,
  required DateTime activityDateTime,
  required int tripId,
  File? imageFile,
  required List<int> memberTripIds,
  required List<double> pricePerPersons,
}) async {
  final dio = Dio();

  final formData = FormData();

  // ✅ ข้อมูลหลัก
  formData.fields.addAll([
    MapEntry('activityName', activityName),
    MapEntry('activityDetail', activityDetail),
    MapEntry('activityPrice', activityPrice.toString()),
    MapEntry('activityDateTime', activityDateTime.toString().substring(0, 19)),
    MapEntry('tripId', tripId.toString()),
  ]);

  // ✅ รองรับ key ซ้ำ
  for (int i = 0; i < memberTripIds.length; i++) {
    formData.fields.add(MapEntry('memberTripIds', memberTripIds[i].toString()));
    formData.fields.add(MapEntry('pricePerPersons', pricePerPersons[i].toString()));
  }

  // ✅ แนบรูปถ้ามี
  if (imageFile != null) {
    formData.files.add(
      MapEntry(
        'image',
        await MultipartFile.fromFile(imageFile.path, filename: basename(imageFile.path)),
      ),
    );
  }

  try {
    final response = await dio.put(
      '$baseURL/activities/update/$activityId',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print('Update failed: ${response.statusCode} - ${response.data}');
      return false;
    }
  } catch (e) {
    print('Error updating activity: $e');
    return false;
  }
}





  // ✅ ลบกิจกรรม
  Future<void> doRemoveActivity(int activityId) async {
    try {
      final url = Uri.parse('$baseURL/activities/$activityId');
      final response = await http.delete(url, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('ลบกิจกรรมไม่สำเร็จ: ${response.body}');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดขณะลบ: $e');
    }
  }

  // ✅ (ต่อไปสามารถเพิ่ม: createActivity, updateActivity ได้เช่นกัน)
}
