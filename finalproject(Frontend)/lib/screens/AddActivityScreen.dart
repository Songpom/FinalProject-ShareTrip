// lib/screens/addactivity.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/controller/activitycontroller.dart';
import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/model/membertrip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddActivityScreen extends StatefulWidget {
  final int tripId;

  const AddActivityScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final TripController _tripController = TripController();
  final ActivityController _activityController = ActivityController();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailController = TextEditingController();
  final _priceController = TextEditingController();

  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  // โชว์ข้อความเตือนแบบอินไลน์ (เหนือปุ่ม)
  final ScrollController _scrollCtrl = ScrollController();
  String? _inlineError;

  void _setError(String? message) {
    setState(() => _inlineError = message);
    if (message != null) _scrollToBottom();
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  bool _loading = true;

  /// สมาชิกที่ “เลือกได้” (owner + participant)
  List<MemberTrip> _pickableMembers = [];

  /// สมาชิกที่ถูกเลือก
  List<MemberTrip> _selectedMembers = [];
  int get _participantCount => _selectedMembers.length;

  /// โหมดแบ่งเงิน: 0 = หารเท่ากัน, 1 = กำหนดเอง
  int _splitMode = 0;

  /// หารเท่ากัน: เก็บยอดต่อคนตามลำดับ _selectedMembers
  List<double> _equalPerPersons = [];

  /// กำหนดเอง
  List<TextEditingController> _customPriceControllers = [];
  double _remainingAmount = 0.0;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  File? _imageFile;
  double? _imgW; // ความกว้างจริงของรูป
  double? _imgH; // ความสูงจริงของรูป
  final ImagePicker _picker = ImagePicker();

  // ==================== Lifecycle ====================
  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    for (var c in _customPriceControllers) {
      c.dispose();
    }
    _nameController.dispose();
    _detailController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await _tripController.getTripDetail(widget.tripId);

      // กรองเฉพาะ owner + participant
      final filtered = (trip?.memberTrips ?? [])
          .where((m) {
            final s = (m.memberTripStatus ?? '').toLowerCase();
            return s == 'owner' || s == 'participant';
          })
          .toList();

      // ค่าเริ่มต้น: เลือกทุกคน
      _selectedMembers = List<MemberTrip>.from(filtered);

      // ตั้งค่า equal split เริ่มต้น (ยังไม่รู้ราคา => 0 ก่อน)
      _equalPerPersons = List<double>.filled(_selectedMembers.length, 0.0);

      setState(() {
        _pickableMembers = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      _setError('โหลดข้อมูลทริปล้มเหลว: $e');
    }
  }

  // ==================== Date & Time helpers ====================
  DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _combineDateTime(DateTime? d, TimeOfDay? t) {
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  // ===== เลือกวัน (อนุญาต "วันนี้" หรือ "อดีต" เท่านั้น) =====
  Future<void> _pickDate() async {
    final today = _todayDateOnly();
    final initial = _selectedDate ?? today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: today, // ❗ห้ามเกินวันนี้
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

        // ถ้าเลือกวันนี้ และเวลาเดิมเกิน "ตอนนี้" → เคลียร์เวลา
        if (_selectedTime != null) {
          final combined = _combineDateTime(_selectedDate, _selectedTime);
          if (combined != null && combined.isAfter(DateTime.now())) {
            _selectedTime = null;
            _timeController.clear();
          }
        }
      });
    }
  }

  // ===== เลือกเวลา (ถ้าวันเป็น "วันนี้" ห้ามเกินเวลาปัจจุบัน) =====
  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      _setError('กรุณาเลือกวันก่อน');
      return;
    }

    final initial = _selectedTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked != null) {
      final candidate = _combineDateTime(_selectedDate, picked);
      final now = DateTime.now();

      final isToday = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      ).isAtSameMomentAs(_todayDateOnly());

      if (candidate != null && isToday && candidate.isAfter(now)) {
        _setError('เวลาในวันนี้ต้องไม่เกินเวลาปัจจุบัน');
        return;
      }

      setState(() {
        _selectedTime = picked;
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  // ==================== Split helpers ====================
  void _recomputeEqualSplit() {
    final total = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (_participantCount > 0) {
      final per = total / _participantCount;
      _equalPerPersons = List<double>.filled(_participantCount, per);
    } else {
      _equalPerPersons = [];
    }
    setState(() {});
  }

  void _updateCustomPrices() {
    double total = 0;
    for (var c in _customPriceControllers) {
      total += double.tryParse(c.text) ?? 0.0;
    }
    final grand = double.tryParse(_priceController.text.trim()) ?? 0.0;
    setState(() => _remainingAmount = grand - total);
  }

  double _currentAssignedTotal() {
    if (_splitMode == 0) {
      final total = double.tryParse(_priceController.text.trim()) ?? 0.0;
      return (_participantCount == 0) ? 0.0 : total;
    } else {
      return _customPriceControllers
          .fold(0.0, (sum, c) => sum + (double.tryParse(c.text) ?? 0.0));
    }
  }

  void _toggleMemberSelection(MemberTrip member) {
    setState(() {
      final idx =
          _selectedMembers.indexWhere((m) => m.memberTripId == member.memberTripId);
      if (idx >= 0) {
        _selectedMembers.removeAt(idx);
        if (_splitMode == 1 && idx < _customPriceControllers.length) {
          final ctrl = _customPriceControllers.removeAt(idx);
          ctrl.dispose();
        }
      } else {
        _selectedMembers.add(member);
        if (_splitMode == 1) {
          _customPriceControllers.add(TextEditingController());
        }
      }

      if (_splitMode == 0) {
        _recomputeEqualSplit();
      } else {
        _updateCustomPrices();
      }
    });
  }

  // ==================== Image helpers ====================
  bool _isValidImageExt(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => c.complete(img));
    return c.future;
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      if (!_isValidImageExt(file.path)) {
        _setError('ไฟล์รูปภาพต้องเป็น .jpg, .jpeg, .png');
        return;
      }

      final bytes = await picked.readAsBytes();
      final img = await _decodeUiImage(bytes); // ✅ ได้ขนาดจริงของรูป

      setState(() {
        _imageFile = file;
        _imgW = img.width.toDouble();
        _imgH = img.height.toDouble();
      });
    }
  }

  void _clearImage() => setState(() {
        _imageFile = null;
        _imgW = null;
        _imgH = null;
      });

  // ==================== Validators (ตาม Requirement) ====================
  // ชื่อกิจกรรม:
  // - ไทย/อังกฤษเท่านั้น (อนุญาตช่องว่าง)
  // - 3–100 ตัวอักษร
  // - ห้ามขึ้นต้น/ท้ายด้วยช่องว่าง
  // - ห้ามว่าง
  final RegExp _thaiEngOnly =
      RegExp(r'^[A-Za-z\u0E01-\u0E2E\u0E30-\u0E3A\u0E40-\u0E44\u0E46\u0E47-\u0E4E\s]+$');
  String? _validateActivityName(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return 'กรุณากรอกชื่อกิจกรรม';
    if (s != s.trim()) return 'ห้ามขึ้นต้นหรือท้ายด้วยช่องว่าง';
    if (s.trim().runes.length < 3 || s.trim().runes.length > 100) {
      return 'ความยาวต้อง 3–100 ตัวอักษร';
    }
    if (!_thaiEngOnly.hasMatch(s)) {
      return 'กรอกได้เฉพาะตัวอักษรไทยหรืออังกฤษเท่านั้น';
    }
    return null;
  }

  // แปลงสตริงเลขที่อาจเป็น scientific notation ให้เป็นเลขเต็ม (ไม่มี e/E)
  String _toPlainNumberString(String s) {
    s = s.trim();
    if (!(s.contains('e') || s.contains('E'))) return s;

    final m = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$').firstMatch(s);
    if (m == null) return s; // parse ไม่ได้ก็คืนค่าเดิม

    final sign = m.group(1) ?? '';
    final intPart = m.group(2) ?? '0';
    final fracPart = m.group(3) ?? '';
    final exp = int.tryParse(m.group(4) ?? '0') ?? 0;

    var digits = intPart + fracPart; // รวมตัวเลข (ตัดจุด)
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

    // ตัดศูนย์ท้ายทศนิยม & จุดที่เกิน
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

  // แปลงเลขวิทยาศาสตร์ -> ตัวเลขปกติ + เก็บเฉพาะตัวเลข/จุด + จำกัดทศนิยม 2 หลัก
  String _sanitizeMoney(String s) {
    final plain = _toPlainNumberString(s);
    final cleaned = plain.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return '';

    final m = RegExp(r'^(\d+)(?:\.(\d{0,2}))?').firstMatch(cleaned);
    if (m == null) return '';

    final whole = m.group(1) ?? '0';
    final frac = m.group(2);
    return frac == null ? whole : '$whole.$frac';
  }

  static const double _maxMoney = 1000000.0;

  // sanitize แล้วคุมเพดาน 1,000,000
  String _sanitizeAndCap(String s, {double max = _maxMoney}) {
    final clean = _sanitizeMoney(s);
    if (clean.isEmpty) return '';
    final v = double.tryParse(clean) ?? 0.0;
    if (v > max) {
      return max
          .toStringAsFixed(clean.contains('.') ? 2 : 0)
          .replaceAll(RegExp(r'\.0+$'), '');
    }
    return clean;
  }

  // รายละเอียดค่าใช้จ่าย:
  // - อนุญาตว่างได้
  // - ถ้าไม่ว่าง: อย่างน้อย 10–500 ตัวอักษร และห้ามขึ้นต้น/ท้ายด้วยช่องว่าง
  String? _validateDetail(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return null; // ตาม requirement: สามารถเป็นค่าว่างได้
    if (s != s.trim()) return 'ห้ามขึ้นต้นหรือท้ายด้วยช่องว่าง';
    final len = s.trim().runes.length;
    if (len < 10 || len > 500) return 'รายละเอียดอย่างน้อย 10–500 ตัวอักษร หรือเว้นว่าง';
    return null;
  }

  // ราคา:
  // - ทศนิยม > 0.00
  // - ไม่เกิน 2 ตำแหน่ง
  // - ห้ามว่าง
  final RegExp _pricePattern = RegExp(r'^\d+(\.\d{1,2})?$');
  String? _validatePrice(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกราคา';
    if (!_pricePattern.hasMatch(s)) return 'ทศนิยมไม่เกิน 2 ตำแหน่ง';
    final val = double.tryParse(s) ?? 0.0;
    if (val < 0) return 'ราคาต้องมากกว่าหรือเท่ากับ 0.00';
    if (val > _maxMoney) return 'จำนวนเงินต้องไม่เกิน 1,000,000 บาท';
    return null;
  }

  // รูปหลักฐาน: ต้องไม่ว่าง และต้องเป็นไฟล์ภาพที่ระบุ
  String? _validateImage() {
    if (_imageFile == null) return 'กรุณาแนบรูปหลักฐาน';
    if (!_isValidImageExt(_imageFile!.path)) {
      return 'ไฟล์รูปภาพต้องเป็น .jpg, .jpeg, .png';
    }
    return null;
  }

  // วัน/เวลา:
  // - ต้องไม่ว่าง
  // - ต้องเป็น “วันนี้หรืออดีต” (ห้ามอนาคต)
  // - ถ้าวันเป็น “วันนี้” เวลา “ต้องไม่เกินเวลาปัจจุบัน”
  String? _validateDateField(String? v) {
    if (_selectedDate == null || (v ?? '').isEmpty) {
      return 'กรุณาเลือกวัน';
    }
    final today = _todayDateOnly();
    if (_selectedDate!.isAfter(today)) {
      return 'วันกิจกรรมต้องเป็นวันนี้หรืออดีต';
    }
    return null;
  }

  String? _validateTimeField(String? v) {
    if (_selectedTime == null || (v ?? '').isEmpty) {
      return 'กรุณาเลือกเวลา';
    }
    final combined = _combineDateTime(_selectedDate, _selectedTime);
    if (combined == null) return 'กรุณาเลือกวันและเวลา';
    if (combined.isAfter(DateTime.now())) {
      return 'วัน–เวลา กิจกรรมต้องไม่เกินเวลาปัจจุบัน';
    }
    return null;
  }

  // ==================== Submit ====================
  Future<void> _saveActivity() async {
    final imgErr = _validateImage();
    final ok = _formKey.currentState?.validate() ?? false;

    if (imgErr != null || !ok) {
      _setError(imgErr ?? 'กรุณากรอกให้ครบถ้วน');
      return;
    }

    if (_selectedMembers.isEmpty) {
      _setError('กรุณาเลือกผู้เข้าร่วมกิจกรรม');
      return;
    }

    final combined = _combineDateTime(_selectedDate, _selectedTime);
    if (combined == null || combined.isAfter(DateTime.now())) {
      _setError('วัน–เวลา กิจกรรมต้องไม่เกินเวลาปัจจุบัน');
      return;
    }

    final name = _nameController.text.trim();
    final detail = _detailController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    // รวมวัน-เวลา (local) แล้วชดเชย offset ให้สอดคล้อง backend/หน้าแก้ไข
    final local = combined.toLocal();
    final adjusted = local.add(local.timeZoneOffset);
    final dateTimeString = DateFormat('yyyy-MM-dd HH:mm:ss').format(adjusted);

    // ราคาต่อคน
    late List<double> pricePerPersons;
    if (_splitMode == 0) {
      if (_participantCount == 0) {
        _setError('ยังไม่มีผู้เข้าร่วมเพื่อหารค่าใช้จ่าย');
        return;
      }
      final per = price / _participantCount;
      pricePerPersons = List<double>.filled(_participantCount, per);
    } else {
      pricePerPersons =
          _customPriceControllers.map((c) => double.tryParse(c.text) ?? 0.0).toList();
      final sum = pricePerPersons.fold(0.0, (a, b) => a + b);
      if ((sum - price).abs() > 0.009) {
        _setError('ยอดรวมแต่ละคนไม่เท่าราคารวมที่กำหนดไว้');
        return;
      }
    }

    final memberTripIds = _selectedMembers
        .map((m) => m.memberTripId ?? 0)
        .where((id) => id != 0)
        .toList();

    try {
      final success = await _activityController.doAddActivity(
        activityName: name,
        activityDetail: detail,
        activityPrice: price,
        activityDateTime: dateTimeString,
        tripId: widget.tripId,
        imageFile: _imageFile!, // รูปต้องมี (ตาม requirement)
        memberTripIds: memberTripIds,
        pricePerPersons: pricePerPersons,
      );

      if (!mounted) return;
      if (success) {
        _setError(null); // ล้างข้อความเตือน
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มกิจกรรมสำเร็จ')),
        );
        Navigator.pop(context, true);
      } else {
        _setError('เพิ่มกิจกรรมไม่สำเร็จ');
      }
    } catch (e) {
      if (!mounted) return;
      _setError('เพิ่มกิจกรรมไม่สำเร็จ: $e');
    }
  }

  // ==================== UI Helpers ====================
  InputDecoration _filledInput({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      );

  Widget _sectionCard({required Widget child}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child);
  }

  // ---------- Image preview “เต็มภาพ ไม่โดนครอป” ----------
  Widget _buildImagePreview(double availWidth) {
    if (_imageFile != null) {
      // ถ้ามีขนาดจริงของรูป คำนวณความสูงตามสัดส่วน เพื่อไม่ให้โดนครอป
      final double previewH = (_imgW != null && _imgH != null)
          ? (availWidth * (_imgH! / _imgW!))
          : 180.0;

      return Stack(
        alignment: Alignment.topRight,
        children: [
          SizedBox(
            width: double.infinity,
            height: previewH.clamp(160.0, 600.0),
            child: Center(
              child: Image.file(
                _imageFile!,
                fit: BoxFit.contain, // ✅ แสดงเต็มรูป ไม่ตัดขอบ
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          _iconBadge(icon: Icons.close, onTap: _clearImage),
          _cornerTag(text: 'รูปใหม่', color: Colors.green),
        ],
      );
    }

    // ไม่มีรูป — โชว์ placeholder สูงมาตรฐาน
    return const SizedBox(
      height: 180,
      child: Center(
        child: Icon(Icons.image_outlined, size: 42, color: Colors.grey),
      ),
    );
  }

  Widget _imageCard() {
    final imgErr = _validateImage();
    final screenW = MediaQuery.of(context).size.width;
    // กะความกว้างภายในการ์ด (ลบ padding ข้างละ ~4)
    final innerW = screenW - 16 - 16;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('แนบรูปกิจกรรม'),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: (imgErr == null) ? Colors.grey.shade100 : Colors.red.shade50,
              child: _buildImagePreview(innerW),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library, color: Colors.blue),
                label: Text(
                  _imageFile != null ? 'เปลี่ยนรูปใหม่' : 'เลือกรูปใหม่',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (_imageFile != null)
                TextButton.icon(
                  onPressed: _clearImage,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('ลบรูปใหม่', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          if (imgErr != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(imgErr, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _participantsCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Colors.cyan),
              const SizedBox(width: 8),
              const Text('ผู้เข้าร่วมกิจกรรม',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '$_participantCount คน',
                style: TextStyle(color: Colors.cyan.shade700, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Toggle โหมดแบ่งเงิน
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _splitMode = 0;
                        _recomputeEqualSplit();
                        for (var c in _customPriceControllers) {
                          c.dispose();
                        }
                        _customPriceControllers = [];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _splitMode == 0 ? Colors.cyan : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        'หารเท่ากัน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _splitMode == 0 ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _splitMode = 1;
                        _customPriceControllers = List.generate(
                          _selectedMembers.length,
                          (i) {
                            String seed = '';
                            if (_equalPerPersons.isNotEmpty &&
                                i < _equalPerPersons.length) {
                              seed = _sanitizeAndCap(_equalPerPersons[i].toString());
                            }
                            return TextEditingController(text: seed);
                          },
                        );
                        _updateCustomPrices();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _splitMode == 1 ? Colors.cyan : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Text(
                        'กำหนดเอง',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _splitMode == 1 ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_splitMode == 1) ...[
            const SizedBox(height: 8),
            Text(
              _remainingAmount > 0
                  ? 'เหลืออีก ฿${_remainingAmount.toStringAsFixed(2)}'
                  : 'ครบยอดแล้ว',
              style: TextStyle(
                color: _remainingAmount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // รายชื่อสมาชิก
          ..._pickableMembers.map((member) {
            final isSelected =
                _selectedMembers.any((m) => m.memberTripId == member.memberTripId);

            final avatarUrl = (member.participant?.memberImage != null &&
                    (member.participant!.memberImage?.isNotEmpty ?? false))
                ? '$baseURL/images/${member.participant!.memberImage}'
                : null;

            final selIdx =
                _selectedMembers.indexWhere((m) => m.memberTripId == member.memberTripId);

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.cyan.withOpacity(0.06) : const Color.fromARGB(0, 255, 255, 255),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        backgroundColor: Colors.grey.shade300,
                        child: avatarUrl == null
                            ? Text(
                                (member.participant?.username ?? 'U').characters.first,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.participant?.username ?? 'ไม่มีชื่อ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            if (member.participant?.email != null)
                              Text(
                                member.participant!.email!,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      if (_splitMode == 0 && isSelected)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '฿${(selIdx >= 0 && selIdx < _equalPerPersons.length ? _equalPerPersons[selIdx] : 0.0).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleMemberSelection(member),
                        activeColor: Colors.cyan,
                      ),
                    ],
                  ),
                ),

                if (_splitMode == 1 && isSelected && selIdx >= 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 56, right: 8, bottom: 8),
                    child: TextFormField(
                      controller: (selIdx < _customPriceControllers.length)
                          ? _customPriceControllers[selIdx]
                          : TextEditingController(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'จำนวนเงิน (บาท)',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        suffixText: 'บาท',
                      ),
                      onChanged: (val) {
                        final clean = _sanitizeMoney(val);
                        if (val != clean) {
                          final ctrl = _customPriceControllers[selIdx];
                          ctrl.value = TextEditingValue(
                            text: clean,
                            selection: TextSelection.collapsed(offset: clean.length),
                          );
                        }
                        _updateCustomPrices();
                      },
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _iconBadge({required IconData icon, required VoidCallback onTap}) {
    return Positioned(
      top: 8,
      right: 8,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.black54,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: Colors.white, size: 18),
          onPressed: onTap,
        ),
      ),
    );
  }

  Widget _cornerTag({required String text, required Color color}) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final assigned = _currentAssignedTotal();

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xfff4f6f8),
        foregroundColor: Colors.black87,
        title: const Text('เพิ่มกิจกรรม',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTrip,
          child: _loading
              ? ListView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // ===== ฟอร์มหลัก =====
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('ชื่อกิจกรรม'),
                            TextFormField(
                              controller: _nameController,
                              decoration: _filledInput(hint: 'เช่น เช่ารถตู้เหมา'),
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              validator: _validateActivityName,
                              onChanged: (_) {
                                if (_inlineError != null) _setError(null);
                              },
                            ),
                            const SizedBox(height: 12),

                            _label('จำนวนเงิน'),
                            TextFormField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                              ],
                              decoration: _filledInput(hint: 'เช่น 500.00 บาท'),
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              validator: _validatePrice,
                              onChanged: (val) {
                                final clean = _sanitizeAndCap(val);
                                if (val != clean) {
                                  _priceController.value = TextEditingValue(
                                    text: clean,
                                    selection: TextSelection.collapsed(offset: clean.length),
                                  );
                                }
                                if (_splitMode == 0) _recomputeEqualSplit();
                                if (_splitMode == 1) _updateCustomPrices();
                                setState(() {});
                                if (_inlineError != null) _setError(null);
                              },
                            ),

                            const SizedBox(height: 12),

                            _label('เลือกวันและเวลา'),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateController,
                                    readOnly: true,
                                    onTap: _pickDate,
                                    decoration: _filledInput(
                                      hint: 'เลือกวัน (วันนี้หรืออดีต)',
                                      suffixIcon: const Icon(Icons.date_range),
                                    ),
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    validator: _validateDateField,
                                    onChanged: (_) {
                                      if (_inlineError != null) _setError(null);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _timeController,
                                    readOnly: true,
                                    onTap: _pickTime,
                                    decoration: _filledInput(
                                      hint: 'เลือกเวลา',
                                      suffixIcon: const Icon(Icons.access_time),
                                    ),
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    validator: _validateTimeField,
                                    onChanged: (_) {
                                      if (_inlineError != null) _setError(null);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            _label('รายละเอียดกิจกรรม'),
                            TextFormField(
                              controller: _detailController,
                              maxLines: 4,
                              decoration: _filledInput(
                                  hint:
                                      'รายละเอียดเพิ่มเติม เช่น ค่ามัดจำ/ค่าบริการ (เว้นว่างได้)'),
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              validator: _validateDetail,
                              onChanged: (_) {
                                if (_inlineError != null) _setError(null);
                              },
                            ),
                          ],
                        ),
                      ),

                      // รูปภาพ
                      _imageCard(),

                      // ผู้เข้าร่วม + แบ่งจ่าย
                      _participantsCard(),

                      const SizedBox(height: 8),

                      // ===== สรุปด้านล่าง =====
                      Row(
                        children: [
                          Text(
                            '฿${assigned.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'จาก ฿${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_splitMode == 1)
                            Text(
                              _remainingAmount > 0
                                  ? 'เหลือ ฿${_remainingAmount.toStringAsFixed(2)}'
                                  : 'ครบยอดแล้ว',
                              style: TextStyle(
                                color: _remainingAmount > 0
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // <<< แสดงข้อความ error สีแดงเหนือปุ่ม >>>
                      if (_inlineError != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _inlineError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: _saveActivity,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'บันทึกกิจกรรม',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
