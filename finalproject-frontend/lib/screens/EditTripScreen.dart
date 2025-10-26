// lib/screens/edit_trip_screen.dart
// ทำให้หน้าแก้ไขทริป ใช้งานเหมือนหน้า create:
// - เลือกสถานที่ด้วย PlacePickerPage (Longdo Map) แล้วเก็บเป็น JSON ฟิลด์เดียว
// - มี money formatter ภายในไฟล์นี้ (ไม่ต้องแยกไฟล์)
// - โหลด location เดิม (ถ้าเป็น JSON) มาแสดงเป็นการ์ด พร้อมปัก lat/lon

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/screens/place_picker_page.dart';

class EditTripScreen extends StatefulWidget {
  final int tripId;

  const EditTripScreen({super.key, required this.tripId});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
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
  File? _imageFile;          // รูปใหม่ (ถ้ามี)
  String? _imageUrl;         // รูปเดิมจาก server (ถ้ามี)
  bool _loading = true;

  // ขนาดรูปสำหรับคำนวณพรีวิวเต็ม (ไม่ตัดขอบ)
  double? _fileW, _fileH; // จากไฟล์ที่เลือกใหม่
  double? _netW, _netH;   // จากรูปเดิมที่โหลดจาก server

  // Place picker (แบบเดียวกับหน้า create)
  Map<String, dynamic>? _pickedPlace; // {id,name,address,lat,lon}
  static const String _longdoJsKey = '2fda6462e44be22918f1bb3e1fc8dc79';

  // money formatter (แบบเดียวกับหน้า create)
  late final TextInputFormatter _moneyFormatter;

  @override
  void initState() {
    super.initState();
    _moneyFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text;

      // กัน comma/space
      text = text.replaceAll(',', '').replaceAll(' ', '');

      // แปลงเลขไทย -> อารบิก
      const th = '๐๑๒๓๔๕๖๗๘๙';
      for (var i = 0; i < th.length; i++) {
        text = text.replaceAll(th[i], '$i');
      }

      // อนุญาตเฉพาะ 0-9 และ '.'
      if (!RegExp(r'^[0-9.]*$').hasMatch(text)) return oldValue;

      if (text.isEmpty) {
        return newValue.copyWith(text: '');
      }

      if (text == '.') text = '0.'; // เริ่มด้วยจุด -> 0.

      // จุดได้ตัวเดียว
      if ('.'.allMatches(text).length > 1) return oldValue;

      // ทศนิยมไม่เกิน 2 ตำแหน่ง
      final dot = text.indexOf('.');
      if (dot != -1) {
        final frac = text.substring(dot + 1);
        if (frac.length > 2) return oldValue;
      }

      // ตัด 0 นำหน้าที่เกิน (ยกเว้น 0.xxx)
      if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
        text = text.replaceFirst(RegExp(r'^0+'), '');
        if (text.isEmpty) text = '0';
      }

      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });

    _loadTripData();
  }

  // ------------------ Utils ------------------
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isValidImageExt(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  // เอา scientific notation ออก ถ้ามี
  String _toPlainNumberString(String s) {
    s = s.trim();
    if (!(s.contains('e') || s.contains('E'))) return s;

    final m = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$').firstMatch(s);
    if (m == null) return s;

    final sign = m.group(1) ?? '';
    final intPart = m.group(2) ?? '0';
    final fracPart = m.group(3) ?? '';
    final exp = int.tryParse(m.group(4) ?? '0') ?? 0;

    var digits = intPart + fracPart;
    final pointIndex = intPart.length;
    final newPointIndex = pointIndex + exp;

    String out;
    if (exp >= 0) {
      if (newPointIndex >= digits.length) {
        digits += '0' * (newPointIndex - digits.length);
        out = digits;
      } else {
        out = digits.substring(0, newPointIndex) + '.' + digits.substring(newPointIndex);
      }
    } else {
      final shiftLeft = -exp;
      if (shiftLeft >= pointIndex) {
        final zeros = '0' * (shiftLeft - pointIndex);
        out = '0.' + zeros + digits;
      } else {
        final idx = pointIndex - shiftLeft;
        out = digits.substring(0, idx) + '.' + digits.substring(idx);
      }
    }

    if (out.contains('.')) {
      final parts = out.split('.');
      var frac = parts[1];
      while (frac.isNotEmpty && frac.endsWith('0')) {
        frac = frac.substring(0, frac.length - 1);
      }
      out = frac.isEmpty ? parts[0] : '${parts[0]}.$frac';
    }
    return sign + out;
  }

  // decode รูปจาก bytes เพื่ออ่านขนาดจริง
  Future<ui.Image> _decodeImage(List<int> bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (img) => c.complete(img));
    return c.future;
  }

  // อ่านขนาดรูปจาก network โดยไม่ต้องแสดงก่อน
  Future<void> _fetchNetworkImageSize(String url) async {
    try {
      final img = Image.network(url).image;
      final c = Completer<ImageInfo>();
      final listener = ImageStreamListener((info, _) => c.complete(info), onError: (e, _) {
        if (!c.isCompleted) c.completeError(e);
      });
      final stream = img.resolve(const ImageConfiguration());
      stream.addListener(listener);
      final info = await c.future;
      stream.removeListener(listener);

      setState(() {
        _netW = info.image.width.toDouble();
        _netH = info.image.height.toDouble();
      });
    } catch (_) {
      // อ่านไม่ได้ก็ปล่อยไป ใช้ default ความสูง
    }
  }

  // ------------------ Validators ------------------
  String? _validateTripName(String? v) {
    final s = (v ?? '');
    if (s.trim().isEmpty) return 'กรุณากรอกชื่อแผนการท่องเที่ยว';
    if (s != s.trim()) return 'ห้ามมีช่องว่างที่ต้นหรือท้ายข้อความ';
    if (s.length < 3 || s.length > 100) return 'ชื่อต้องมีความยาว 3–100 ตัวอักษร';
    return null;
  }

  String? _validateStartDate(String? v) {
    if (_startDate == null) return 'กรุณาเลือกวันที่เริ่มต้น';
    return null;
  }

  String? _validateDueDate(String? v) {
    if (_dueDate == null) return 'กรุณาเลือกวันที่สิ้นสุด';
    if (_startDate == null) return 'กรุณาเลือกวันที่เริ่มต้นก่อน';

    final today  = _dateOnly(DateTime.now());
    final minDue = _dateOnly(_startDate!.add(const Duration(days: 1)));

    if (_dateOnly(_dueDate!).isBefore(today)) {
      return 'วันที่สิ้นสุดต้องไม่ก่อนวันปัจจุบัน';
    }
    if (!_dateOnly(_dueDate!).isAfter(_dateOnly(_startDate!))) {
      return 'วันที่สิ้นสุดต้องมากกว่าวันเริ่มต้นอย่างน้อย 1 วัน';
    }
    if (_dateOnly(_dueDate!).isBefore(minDue)) {
      return 'วันที่สิ้นสุดต้องไม่น้อยกว่า ${minDue.toString().split(' ').first}';
    }
    return null;
  }

  String? _validateBudget(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกงบประมาณ';
    final value = double.tryParse(s);
    if (value == null) return 'งบประมาณต้องเป็นตัวเลขเท่านั้น';
    // ตรวจจำนวนทศนิยมไม่เกิน 2
    if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length > 2) return 'รูปแบบตัวเลขไม่ถูกต้อง';
      if (parts[1].length > 2) return 'ทศนิยมไม่เกิน 2 ตำแหน่ง';
    }
    if (value < 0) return 'งบประมาณต้องมากกว่าหรือเท่ากับ 0.00';
    if (value > 1000000) return 'งบประมาณสูงสุด 1,000,000 บาท';
    return null;
  }

  String? _validateLocation(String? v) {
    final s = (v ?? '');
    if (s.trim().isEmpty) return 'กรุณาเลือกสถานที่';
    if (s != s.trim()) return 'ห้ามมีช่องว่างที่ต้นหรือท้ายข้อความ';
    if (s.length < 3 || s.length > 100) return 'สถานที่ต้องมีความยาว 3–100 ตัวอักษร';
    return null;
  }

  String? _validateDetail(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return null;
    if (s != s.trim()) return 'ห้ามขึ้นต้นหรือท้ายด้วยช่องว่าง';
    final len = s.runes.length;
    if (len < 3 || len > 250) return 'รายละเอียดต้องยาว 3–250 ตัวอักษร หรือเว้นว่าง';
    return null;
  }

  // ------------------ Load trip ------------------
  Future<void> _loadTripData() async {
    final trip = await TripController().getTripDetail(widget.tripId);

    if (trip != null) {
      // 1) ใส่ค่าฟอร์มพื้นฐาน
      _tripNameController.text = trip.tripName ?? '';
      _startDateController.text = trip.startDate?.toString().split(' ').first ?? '';
      _dueDateController.text   = trip.dueDate?.toString().split(' ').first ?? '';

      final budgetAny = trip.budget;
      _budgetController.text = (budgetAny == null) ? '' : _toPlainNumberString(budgetAny.toString());
      _detailController.text = trip.tripDetail ?? '';

      _startDate = trip.startDate != null ? _dateOnly(trip.startDate!) : null;
      _dueDate   = trip.dueDate   != null ? _dateOnly(trip.dueDate!)   : null;

      if (trip.image != null && trip.image!.isNotEmpty) {
        _imageUrl = '$baseURL/images/${trip.image}';
      }

      // 2) แปลง location ถ้าเป็น JSON -> แสดงสวย + เก็บใน _pickedPlace เหมือนหน้า create
      final loc = trip.location ?? '';
      Map<String, dynamic>? parsed;
      try {
        final obj = jsonDecode(loc);
        if (obj is Map) parsed = obj.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {}
      if (parsed != null && parsed.isNotEmpty) {
        _pickedPlace = parsed;
        _locationController.text = parsed['name'] ?? parsed['address'] ?? '';
      } else {
        _pickedPlace = null;
        _locationController.text = loc;
      }

      setState(() => _loading = false);

      // โหลดขนาดรูปเดิม (ถ้ามี)
      if (_imageUrl != null) {
        unawaited(_fetchNetworkImageSize(_imageUrl!));
      }
    } else {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโหลดข้อมูลทริปได้')),
      );
    }
  }

  // ------------------ Pickers ------------------
  Future<void> _selectStartDate() async {
    final today = _dateOnly(DateTime.now());

    if (_startDate != null && _dateOnly(_startDate!).isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถแก้ไขวันที่เริ่มต้นได้ เนื่องจากวันดังกล่าวผ่านมาแล้ว')),
      );
      return;
    }

    final initial = _startDate != null && !_dateOnly(_startDate!).isBefore(today)
        ? _startDate!
        : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _startDate = _dateOnly(picked);
        _startDateController.text = _startDate!.toString().split(' ').first;

        if (_dueDate != null) {
          final minDue = _dateOnly(_startDate!.add(const Duration(days: 1)));
          final dueOnly = _dateOnly(_dueDate!);
          if (!dueOnly.isAfter(_dateOnly(_startDate!)) || dueOnly.isBefore(minDue)) {
            _dueDate = null;
            _dueDateController.clear();
          }
        }
      });
    }
  }

  Future<void> _selectDueDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันที่เริ่มต้นก่อน')),
      );
      return;
    }

    final today  = _dateOnly(DateTime.now());
    final minDue = _dateOnly(_startDate!.add(const Duration(days: 1)));
    final first  = (today.isAfter(minDue)) ? today : minDue;

    DateTime initial;
    if (_dueDate != null) {
      final dueOnly = _dateOnly(_dueDate!);
      initial = !dueOnly.isBefore(first) ? dueOnly : first;
    } else {
      initial = first;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _dueDate = _dateOnly(picked);
        _dueDateController.text = _dueDate!.toString().split(' ').first;
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

    // อ่านขนาดรูปจากไฟล์เพื่อคำนวณพรีวิวแบบเต็ม
    final bytes = await picked.readAsBytes();
    final decoded = await _decodeImage(bytes);
    setState(() {
      _imageFile = file;
      _fileW = decoded.width.toDouble();
      _fileH = decoded.height.toDouble();
    });
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      _fileW = null;
      _fileH = null;
      // คง _imageUrl เดิมไว้ถ้ามี
    });
  }

  Future<void> _openPlacePicker() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlacePickerPage(longdoJsKey: _longdoJsKey),
      ),
    );
    if (res != null && mounted) {
      setState(() {
        _pickedPlace = Map<String, dynamic>.from(res as Map);
        _locationController.text =
            _pickedPlace?['name'] ?? _pickedPlace?['address'] ?? '';
      });
    }
  }

  // ------------------ Submit ------------------
  Future<void> _saveTrip() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลไม่ถูกต้อง กรุณากรอกให้ถูกต้องและครบถ้วน')),
      );
      return;
    }
    if (_startDate == null || _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันที่ให้ครบถ้วน')),
      );
      return;
    }

    // ถ้ามี _pickedPlace ให้เก็บเป็น JSON เช่นเดียวกับหน้า create
    final String locationPayload =
        _pickedPlace != null ? jsonEncode(_pickedPlace) : _locationController.text.trim();

    final result = await TripController().doEditTrip(
      tripId: widget.tripId,
      tripName: _tripNameController.text.trim(),
      startDate: _startDate!,
      dueDate: _dueDate!,
      budget: double.tryParse(_budgetController.text.trim()) ?? 0,
      tripDetail: _detailController.text.trim(),
      location: locationPayload,
      tripStatus: 'เปิดเข้าร่วม',
      image: _imageFile, // ถ้า null backend ใช้รูปเดิม
    );

    if (!mounted) return;
    if (result['statusCode'] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตสำเร็จ')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตไม่สำเร็จ: ${result['body']}')),
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

  Widget _buildImageBox() {
    final screenW = MediaQuery.of(context).size.width;
    final availW = (screenW - 32).clamp(100.0, 1600.0);

    double? w, h;
    if (_imageFile != null && _fileW != null && _fileH != null) {
      w = _fileW; h = _fileH;
    } else if (_imageFile == null && _imageUrl != null && _netW != null && _netH != null) {
      w = _netW; h = _netH;
    }
    final previewH = (w != null && h != null)
        ? (availW * (h / w)).clamp(160.0, 600.0)
        : 200.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('รูปแผนการท่องเที่ยว'),
        const SizedBox(height: 6),
        Stack(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: previewH,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImagePreview(), // BoxFit.contain ข้างใน
                ),
              ),
            ),
            if (_imageFile != null)
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    tooltip: 'ไม่ใช้รูปใหม่',
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: _clearImage,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('เปลี่ยนรูป'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            if (_imageFile != null)
              TextButton.icon(
                onPressed: _clearImage,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('ไม่ใช้รูปใหม่', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.contain, width: double.infinity);
    } else if (_imageUrl != null) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    } else {
      return _placeholderImage();
    }
  }

  Widget _placeholderImage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('แตะเพื่ออัปโหลด/เปลี่ยนรูป'),
        ],
      ),
    );
  }

  // ------------------ BUILD ------------------
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขทริป'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildFormField(
                        label: 'ชื่อทริป',
                        hint: 'กรอกชื่อทริป',
                        controller: _tripNameController,
                        validator: _validateTripName,
                      ),
                      _buildFormField(
                        label: 'วันที่เริ่มต้น',
                        hint: 'เลือกวันที่เริ่มต้น',
                        controller: _startDateController,
                        validator: _validateStartDate,
                        readOnly: true,
                        onTap: _selectStartDate,
                        suffix: const Icon(Icons.event_available),
                      ),
                      _buildFormField(
                        label: 'วันที่สิ้นสุด',
                        hint: 'เลือกวันที่สิ้นสุด',
                        controller: _dueDateController,
                        validator: _validateDueDate,
                        readOnly: true,
                        onTap: _selectDueDate,
                        suffix: const Icon(Icons.event),
                      ),
                      _buildFormField(
                        label: 'งบประมาณที่คาดการณ์ต่อคน',
                        hint: 'กรอกงบประมาณ (ตัวเลขเท่านั้น ไม่เกิน 1,000,000)',
                        controller: _budgetController,
                        validator: _validateBudget,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [_moneyFormatter],
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
                                  onPressed: () => setState(() {
                                    _pickedPlace = null;
                                    _locationController.clear();
                                  }),
                                  icon: const Icon(Icons.clear),
                                  label: const Text('ล้างสถานที่'),
                                ),
                              ),
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
                      _buildImageBox(),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _saveTrip,
                          child: const Text('อัปเดตทริป', style: TextStyle(fontSize: 16)),
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
