// lib/screens/create_trip_screen.dart
// หน้าสร้างทริปแบบเต็ม: เลือกสถานที่ด้วย PlacePickerPage และบันทึกสถานที่เป็น JSON ฟิลด์เดียว
// แก้ช่อง "งบประมาณ" ให้พิมพ์ได้ลื่น โดยใช้ TextInputFormatter.withFunction ภายในไฟล์นี้ (ไม่ต้องแยกไฟล์)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/boxs/userlog.dart';
import 'package:finalproject/screens/InviteMemberScreen.dart';
import 'package:finalproject/screens/place_picker_page.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  // ------------------ Controllers ------------------
  final _tripNameController = TextEditingController();
  final _startDateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationController = TextEditingController();
  final _detailController = TextEditingController();

  // ------------------ State ------------------
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  DateTime? _dueDate;
  File? _imageFile;
  double? _imgW;
  double? _imgH;
  Map<String, dynamic>? _pickedPlace; // {id,name,address,lat,lon}

  static const String _longdoJsKey = '2fda6462e44be22918f1bb3e1fc8dc79';

  // ฟอร์แมตเตอร์สำหรับช่องงบประมาณ (อยู่ในไฟล์นี้ ไม่ต้องแยก)
  late final TextInputFormatter _moneyFormatter;

  @override
  void initState() {
    super.initState();

    _moneyFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text;

      // กัน comma และช่องว่างที่คีย์บอร์ดบางตัวจะใส่มา
      text = text.replaceAll(',', '').replaceAll(' ', '');

      // แปลงเลขไทย -> อารบิก (๐-๙ -> 0-9)
      const th = '๐๑๒๓๔๕๖๗๘๙';
      for (var i = 0; i < th.length; i++) {
        text = text.replaceAll(th[i], '$i');
      }

      // อนุญาตเฉพาะตัวเลขและจุด
      if (!RegExp(r'^[0-9.]*$').hasMatch(text)) {
        return oldValue;
      }

      // ถ้าข้อความว่าง ปล่อยผ่าน
      if (text.isEmpty) {
        return newValue.copyWith(text: '');
      }

      // ถ้าเริ่มด้วยจุด ให้เป็น 0.
      if (text == '.') text = '0.';

      // ห้ามมีจุดเกิน 1 ตัว
      if ('.'.allMatches(text).length > 1) {
        return oldValue;
      }

      // จำกัดทศนิยมไม่เกิน 2 ตำแหน่ง
      final dot = text.indexOf('.');
      if (dot != -1) {
        final frac = text.substring(dot + 1);
        if (frac.length > 2) {
          return oldValue;
        }
      }

      // ป้องกันเลข 0 หลายตัวติดกัน เช่น 00123
      if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
        text = text.replaceFirst(RegExp(r'^0+'), '');
        if (text.isEmpty) text = '0';
      }

      // คืนค่าผลลัพธ์
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  // ------------------ Utils / Validators ------------------
  DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isValidImageExt(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  String? _validateTripName(String? v) {
    final s = (v ?? '');
    if (s.trim().isEmpty) return 'กรุณากรอกชื่อแผนการท่องเที่ยว';
    if (s != s.trim()) return 'ห้ามมีช่องว่างที่ต้นหรือท้ายข้อความ';
    if (s.length < 3 || s.length > 100) return 'ชื่อต้องมีความยาว 3–100 ตัวอักษร';
    return null;
  }

  String? _validateStartDate(String? v) {
    if (_startDate == null) return 'กรุณาเลือกวันที่เริ่มต้น';
    final today = _todayDateOnly();
    final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    if (start.isBefore(today)) return 'วันที่เริ่มต้นต้องเป็นวันนี้หรืออนาคต';
    return null;
  }

  String? _validateDueDate(String? v) {
    if (_dueDate == null) return 'กรุณาเลือกวันที่สิ้นสุด';
    final today = _todayDateOnly();
    final due = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    if (due.isBefore(today)) return 'วันที่สิ้นสุดต้องเป็นวันที่ในอนาคต';
    if (_startDate == null) return 'กรุณาเลือกวันที่เริ่มต้นก่อน';
    final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    if (!due.isAfter(start)) return 'วันที่สิ้นสุดต้องมากกว่าวันที่เริ่มต้นอย่างน้อย 1 วัน';
    return null;
  }

  String? _validateBudget(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกงบประมาณ';
    
    final value = double.tryParse(s);
    if (value == null) return 'งบประมาณต้องเป็นตัวเลขเท่านั้น';
    
    // ตรวจสอบจำนวนทศนิยม
    if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length > 2) return 'รูปแบบตัวเลขไม่ถูกต้อง';
      if (parts[1].length > 2) return 'ทศนิยมไม่เกิน 2 ตำแหน่ง';
    }
    
    if (value < 0) return 'งบประมาณต้องมากกว่าหรือเท่ากับ 0';
    if (value > 1000000) return 'งบประมาณสูงสุด 1,000,000 บาท';
    
    return null; // ผ่านการตรวจสอบ
  }

  String? _validateDetail(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return null;
    if (s != s.trim()) return 'ห้ามขึ้นต้นหรือท้ายด้วยช่องว่าง';
    final len = s.runes.length;
    if (len < 3 || len > 250) return 'รายละเอียดต้องยาว 3–250 ตัวอักษร หรือเว้นว่าง';
    return null;
  }

  String? _validateLocation(String? v) {
    final s = (v ?? '');
    if (s.trim().isEmpty) return 'กรุณาเลือกสถานที่';
    if (s != s.trim()) return 'ห้ามมีช่องว่างที่ต้นหรือท้ายข้อความ';
    if (s.length < 3 || s.length > 100) return 'สถานที่ต้องมีความยาว 3–100 ตัวอักษร';
    return null;
  }

  String? _validateImage() {
    if (_imageFile == null) return 'กรุณาอัปโหลดรูปภาพแผนการท่องเที่ยว';
    if (!_isValidImageExt(_imageFile!.path)) {
      return 'ไฟล์รูปภาพต้องเป็น .jpg, .jpeg, .png, .gif, .bmp';
    }
    return null;
  }

  // ------------------ Helpers ------------------
  Future<ui.Image> _decodeImage(List<int> bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (img) => c.complete(img));
    return c.future;
  }

  Future<void> _selectDate(TextEditingController controller, bool isStartDate) async {
    final today = _todayDateOnly();
    final initial = isStartDate
        ? (_startDate ?? today)
        : (_dueDate ?? (_startDate != null ? _startDate!.add(const Duration(days: 1)) : today.add(const Duration(days: 1))));
    final firstDate = isStartDate
        ? today
        : (_startDate != null ? _startDate!.add(const Duration(days: 1)) : today.add(const Duration(days: 1)));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        controller.text = picked.toString().split(' ')[0];
        if (isStartDate) {
          _startDate = picked;
          if (_dueDate != null) {
            final startOnly = DateTime(picked.year, picked.month, picked.day);
            final dueOnly = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
            if (!dueOnly.isAfter(startOnly)) {
              _dueDate = null;
              _dueDateController.clear();
            }
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    if (!_isValidImageExt(file.path)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไฟล์รูปภาพต้องเป็น .jpg, .jpeg, .png, .gif, .bmp')),
      );
      return;
    }

    final bytes = await picked.readAsBytes();
    final decoded = await _decodeImage(bytes);
    setState(() {
      _imageFile = file;
      _imgW = decoded.width.toDouble();
      _imgH = decoded.height.toDouble();
    });
  }

  Future<void> _openPlacePicker() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlacePickerPage(
          longdoJsKey: _longdoJsKey,
        ),
      ),
    );
    if (res != null && mounted) {
      setState(() {
        _pickedPlace = Map<String, dynamic>.from(res as Map);
        _locationController.text = _pickedPlace?['name'] ?? _pickedPlace?['address'] ?? '';
      });
    }
  }

  Future<void> _saveTrip() async {
    final imgErr = _validateImage();
    final formOk = _formKey.currentState?.validate() ?? false;

    if (imgErr != null || !formOk) {
      if (imgErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(imgErr)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ข้อมูลไม่ถูกต้อง กรุณากรอกให้ถูกต้องและครบถ้วน')),
        );
      }
      return;
    }

    try {
      // เก็บสถานที่เป็น JSON ฟิลด์เดียวถ้ามี (_pickedPlace) ไม่งั้นใช้ข้อความในช่อง
      final String locationPayload =
          _pickedPlace != null ? jsonEncode(_pickedPlace) : _locationController.text.trim();

      final res = await TripController().doCreateTrip(
        tripName: _tripNameController.text.trim(),
        startDate: _startDate!,
        dueDate: _dueDate!,
        budget: double.parse(_budgetController.text.trim()),
        tripDetail: _detailController.text.trim(),
        location: locationPayload,
        tripStatus: 'เปิดเข้าร่วม',
        image: _imageFile!,
        memberEmail: UserLog().email ?? '',
      );

      if (res['status'] == 'ok' && res['data'] != null && res['data']['tripId'] != null) {
        final int tripId = res['data']['tripId'] is int
            ? res['data']['tripId']
            : int.tryParse(res['data']['tripId'].toString()) ?? 0;

        final List<dynamic> initialMembers = res['data']['lastTripMembers'] ?? [];

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InviteMemberScreen(tripId: tripId, initialMembers: initialMembers),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['data']?['message'] ?? 'บันทึกแผนการท่องเที่ยวไม่สำเร็จ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกแผนการท่องเที่ยวไม่สำเร็จ: $e')),
      );
    }
  }

  // ------------------ Widgets ------------------
  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _startDateController.dispose();
    _dueDateController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgErr = _validateImage();
    final screenW = MediaQuery.of(context).size.width;
    final previewH = (_imageFile != null && _imgW != null && _imgH != null)
        ? (screenW - 32) * (_imgH! / _imgW!)
        : 200.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มแผนการท่องเที่ยว'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildFormField(
                  label: 'ชื่อทริป',
                  hint: 'กรอกชื่อทริปของคุณ',
                  controller: _tripNameController,
                  validator: _validateTripName,
                ),
                _buildFormField(
                  label: 'วันที่เริ่มต้น',
                  hint: 'เลือกวันที่เริ่มต้น',
                  controller: _startDateController,
                  validator: _validateStartDate,
                  readOnly: true,
                  onTap: () => _selectDate(_startDateController, true),
                  suffix: const Icon(Icons.event_available),
                ),
                _buildFormField(
                  label: 'วันที่สิ้นสุด',
                  hint: 'เลือกวันที่สิ้นสุด',
                  controller: _dueDateController,
                  validator: _validateDueDate,
                  readOnly: true,
                  onTap: () => _selectDate(_dueDateController, false),
                  suffix: const Icon(Icons.event),
                ),
                _buildFormField(
                  label: 'งบประมาณที่คาดการณ์ต่อคน',
                  hint: 'กรอกงบประมาณ (ตัวเลขเท่านั้นไม่เกิน 1000000 บาท)',
                  controller: _budgetController,
                  validator: _validateBudget,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    _moneyFormatter, // ใช้ฟอร์แมตเตอร์ที่อยู่ในไฟล์นี้
                  ],
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.attach_money),
                  ),
                ),
                _buildFormField(
                  label: 'ชื่อสถานที่',
                  hint: 'แตะเพื่อค้นหาสถานที่',
                  controller: _locationController,
                  validator: _validateLocation,
                  readOnly: true,
                  onTap: _openPlacePicker,
                  suffix: IconButton(
                    tooltip: 'ค้นหาสถานที่',
                    icon: const Icon(Icons.place_outlined),
                    onPressed: _openPlacePicker,
                  ),
                ),
                if (_pickedPlace != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedPlace!['name'] ?? _pickedPlace!['address'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        if ((_pickedPlace!['address'] ?? '').toString().isNotEmpty)
                          Text(_pickedPlace!['address'], style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 6),
                        Text(
                          '(${(_pickedPlace!['lat'] ?? '').toString()}, ${(_pickedPlace!['lon'] ?? '').toString()})',
                          style: const TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() { _pickedPlace = null; _locationController.clear(); }),
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้างสถานที่'),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
                _buildFormField(
                  label: 'รายละเอียดคร่าวๆ',
                  hint: 'อธิบายทริป (3–250 ตัวอักษร) หรือเว้นว่าง',
                  controller: _detailController,
                  validator: _validateDetail,
                  maxLines: 4,
                  inputFormatters: [LengthLimitingTextInputFormatter(250)],
                ),
                const SizedBox(height: 16),

                // ============ อัปโหลดรูปภาพ + พรีวิว "เต็มรูปไม่ตัดขอบ" ============
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('รูปแผนการท่องเที่ยว'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: previewH.clamp(160.0, 600.0).toDouble(),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(
                            color: (imgErr == null) ? Colors.grey.shade300 : Colors.red.shade300,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _imageFile == null
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('แตะเพื่ออัปโหลดรูปภาพ'),
                                  ],
                                ),
                              )
                            : Center(
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                ),
                              ),
                      ),
                    ),
                    if (imgErr != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 8),
                        child: Text(
                          imgErr,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saveTrip,
                    child: const Text('บันทึกทริป', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}