// editactivity.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:finalproject/controller/activitycontroller.dart';
import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/model/activity.dart';
import 'package:finalproject/model/membertrip.dart';
import 'package:finalproject/model/trip.dart';
import 'package:finalproject/constant/constant_value.dart';

class EditActivityScreen extends StatefulWidget {
  final int activityId;
  final int tripId;

  const EditActivityScreen({
    Key? key,
    required this.activityId,
    required this.tripId,
  }) : super(key: key);

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  final ActivityController _activityController = ActivityController();
  final TripController _tripController = TripController();

  Trip? _trip;
  Activity? _activity;
  bool _loading = true;

  // เลือกได้: owner + participant
  List<MemberTrip> _pickableMembers = [];
  List<MemberTrip> _selectedMembers = [];
  int _participantCount = 0;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailController = TextEditingController();
  final _priceController = TextEditingController();

  // วันที่/เวลา (ค่าที่ผู้ใช้แก้ไข)
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  DateTime? _selectedDate; // 00:00
  TimeOfDay? _selectedTime; // HH:mm

  // ค่าเดิม (ใช้เป็นเพดาน)
  DateTime? _originalDate;       // ตัดเวลา
  TimeOfDay? _originalTime;      // เวลาเดิม
  DateTime? _originalDateTime;   // วัน-เวลาเดิมรวม

  // รูป
  File? _imageFile;
  String? _oldImageUrl;
  final ImagePicker _picker = ImagePicker();
  double? _imgW, _imgH;   // ขนาดรูปใหม่
  double? _oldW, _oldH;   // ขนาดรูปเก่า

  // โหมดแบ่งเงิน
  int _splitMode = 0; // 0=หารเท่ากัน, 1=กำหนดเอง
  List<double> _equalPerPersons = [];
  List<TextEditingController> _customPriceControllers = [];
  double _remainingAmount = 0.0;

  // ==================== Validators & Sanitizers (เหมือนหน้า add) ====================
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

  String _sanitizeMoney(String s) {
    final plain = _toPlainNumberString(s);
    final cleaned = plain.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return '';
    final m = RegExp(r'^(\d+)(?:\.(\d{0,2}))?').firstMatch(cleaned);
    if (m == null) return '';
    final whole = m.group(1) ?? '0';
    final frac  = m.group(2);
    return frac == null ? whole : '$whole.$frac';
  }

  static const double _maxMoney = 1000000.0;
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

  String? _validateDetail(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return null; // เว้นว่างได้
    if (s != s.trim()) return 'ห้ามขึ้นต้นหรือท้ายด้วยช่องว่าง';
    final len = s.trim().runes.length;
    if (len < 10 || len > 500) return 'รายละเอียดอย่างน้อย 10–500 ตัวอักษร หรือเว้นว่าง';
    return null;
  }

  final RegExp _pricePattern = RegExp(r'^\d+(\.\d{1,2})?$');
  String? _validatePrice(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'กรุณากรอกราคา';
    if (!_pricePattern.hasMatch(s)) return 'ทศนิยมไม่เกิน 2 ตำแหน่ง';
    final val = double.tryParse(s) ?? 0.0;
    if (val < 0) return 'ราคาต้องมากกว่า 0.00';
    if (val > _maxMoney) return 'จำนวนเงินต้องไม่เกิน 1,000,000 บาท';
    return null;
  }

  bool _isValidImageExt(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  // ==================== Lifecycle ====================
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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

  Future<void> _loadData() async {
    try {
      final trip = await _tripController.getTripDetail(widget.tripId);
      final activity = await _activityController.getActivityDetail(widget.activityId);

      // กรองสมาชิก
      final filtered = (trip?.memberTrips ?? [])
          .where((m) {
            final s = (m.memberTripStatus ?? '').toLowerCase();
            return s == 'owner' || s == 'participant';
          })
          .toList();

      // เลือกที่ผูกไว้เดิม
      final selectedFromActivity =
          activity.memberTripActivity?.map((e) => e.memberTrip!).toList() ?? [];
      final pickableIds = filtered.map((m) => m.memberTripId).toSet();
      final selected = selectedFromActivity.where((m) => pickableIds.contains(m.memberTripId)).toList();

      // ตรวจหารเท่ากันเดิม
      final prices = activity.memberTripActivity?.map((e) => e.pricePerPerson ?? 0.0).toList() ?? [];
      bool wasEqualSplit = false;
      if (prices.isNotEmpty) {
        final f = prices.first;
        wasEqualSplit = prices.every((p) => (p - f).abs() < 0.01);
      }

      // วันเวลาเดิม (แปลงเป็น local หาก backend เก็บ UTC)
      final dt = activity.activityDateTime;
      if (dt != null) {
        final corrected = dt.subtract(DateTime.now().timeZoneOffset);
        _originalDateTime = corrected;
        _originalDate = DateTime(corrected.year, corrected.month, corrected.day);
        _originalTime = TimeOfDay(hour: corrected.hour, minute: corrected.minute);

        _selectedDate = _originalDate;
        _selectedTime = _originalTime;

        _dateController.text =
            '${corrected.year.toString().padLeft(4, '0')}-${corrected.month.toString().padLeft(2, '0')}-${corrected.day.toString().padLeft(2, '0')}';
        _timeController.text =
            '${corrected.hour.toString().padLeft(2, '0')}:${corrected.minute.toString().padLeft(2, '0')}';
      }

      // รูปเก่า
      final oldName = activity.imagePaymentActivity;
      if (oldName != null && oldName.isNotEmpty) {
        _oldImageUrl = '$baseURL/images/$oldName';
        _resolveOldImageSize(_oldImageUrl!);
      }

      setState(() {
        _trip = trip;
        _activity = activity;

        _pickableMembers = filtered;
        _selectedMembers = selected;
        _participantCount = _selectedMembers.length;

        _nameController.text = activity.activityName ?? '';
        _detailController.text = activity.activityDetail ?? '';
        final ap = activity.activityPrice;
        _priceController.text = ap == null ? '' : _toPlainNumberString(ap.toString());

        if (wasEqualSplit) {
          _splitMode = 0;
          _equalPerPersons = List<double>.from(
            List.generate(_participantCount, (i) => i < prices.length ? prices[i] : 0.0),
          );
          _customPriceControllers = [];
        } else {
          _splitMode = 1;
          _equalPerPersons = [];
          _customPriceControllers = List.generate(
            _participantCount,
            (i) {
              final p = (i < prices.length ? prices[i] : 0.0);
              return TextEditingController(text: _toPlainNumberString(p.toString()));
            },
          );
          _updateCustomPrices();
        }

        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลล้มเหลว: $e')),
      );
    }
  }

  // ---------- Utils ----------
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _combineDateTime(DateTime? d, TimeOfDay? t) {
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  // ---------- Date & Time pickers (ล็อกไม่ให้เกินของเดิม) ----------
  Future<void> _pickDate() async {
    if (_originalDate == null) return;

    final initialRaw = _selectedDate ?? _originalDate!;
    final initial = initialRaw.isAfter(_originalDate!) ? _originalDate! : initialRaw;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: _originalDate!, // ห้ามเกินวันเดิม
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _dateController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

        // ถ้าเป็นวันเดิมและเวลาเดิมถูก set เกิน ให้เคลียร์เวลา
        if (_isSameDay(_selectedDate!, _originalDate!) &&
            _selectedTime != null &&
            _originalTime != null) {
          final cand = _combineDateTime(_selectedDate, _selectedTime)!;
          final limit = _combineDateTime(_originalDate, _originalTime)!;
          if (cand.isAfter(limit)) {
            _selectedTime = null;
            _timeController.clear();
          }
        }
      });
    }
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันก่อน')),
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? (_originalTime ?? TimeOfDay.now()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked != null) {
      // ถ้าวันเดิม → เวลาใหม่ห้ามเกินเวลาเดิม
      if (_originalDate != null &&
          _originalTime != null &&
          _isSameDay(_selectedDate!, _originalDate!)) {
        final candidate = _combineDateTime(_selectedDate, picked)!;
        final limit = _combineDateTime(_originalDate, _originalTime)!;
        if (candidate.isAfter(limit)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เวลาต้องไม่เกินเวลาที่ตั้งไว้')),
          );
          return;
        }
      }
      setState(() {
        _selectedTime = picked;
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  // ---------- Split helpers ----------
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
      return _customPriceControllers.fold(
          0.0, (sum, c) => sum + (double.tryParse(c.text) ?? 0.0));
    }
  }

  void _toggleMemberSelection(MemberTrip member) {
    setState(() {
      final idx = _selectedMembers.indexWhere((m) => m.memberTripId == member.memberTripId);
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
      _participantCount = _selectedMembers.length;

      if (_splitMode == 0) {
        _recomputeEqualSplit();
      } else {
        _updateCustomPrices();
      }
    });
  }

  // ---------- Image helpers ----------
  Future<ui.Image> _decodeUiImage(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => c.complete(img));
    return c.future;
  }

  void _resolveOldImageSize(String url) {
    final ImageStream stream =
        NetworkImage(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      if (!mounted) return;
      setState(() {
        _oldW = info.image.width.toDouble();
        _oldH = info.image.height.toDouble();
      });
      stream.removeListener(listener);
    }, onError: (_, __) {
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
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
    final img = await _decodeUiImage(Uint8List.fromList(bytes));
    setState(() {
      _imageFile = file;
      _imgW = img.width.toDouble();
      _imgH = img.height.toDouble();
    });
  }

  void _clearImage() => setState(() {
        _imageFile = null;
        _imgW = null;
        _imgH = null;
      });
  void _removeOldImage() => setState(() {
        _oldImageUrl = null;
        _oldW = null;
        _oldH = null;
      });

  // ---------- Submit ----------
  Future<void> _updateActivity() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกผู้เข้าร่วมกิจกรรม')),
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันที่และระบุเวลา')),
      );
      return;
    }

    // ตรวจไม่ให้เกินของเดิม
    if (_originalDate != null) {
      if (_selectedDate!.isAfter(_originalDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('วันกิจกรรมต้องไม่เกินวันที่ตั้งไว้')),
        );
        return;
      }
      if (_isSameDay(_selectedDate!, _originalDate!) && _originalTime != null) {
        final candidate = _combineDateTime(_selectedDate, _selectedTime)!;
        final limit = _combineDateTime(_originalDate, _originalTime)!;
        if (candidate.isAfter(limit)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เวลาต้องไม่เกินเวลาที่ตั้งไว้')),
          );
          return;
        }
      }
    }

    final name = _nameController.text.trim();
    final detail = _detailController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    // รวมวันเวลาท้องถิ่น + ชดเชย offset
    final combined = _combineDateTime(_selectedDate, _selectedTime)!;
    final local = combined.toLocal();
    final adjusted = local.add(local.timeZoneOffset);

    // ราคาต่อคน
    late List<double> pricePerPersons;
    if (_splitMode == 0) {
      if (_participantCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยังไม่มีผู้เข้าร่วมเพื่อหารค่าใช้จ่าย')),
        );
        return;
      }
      final per = price / _participantCount;
      pricePerPersons = List<double>.filled(_participantCount, per);
    } else {
      pricePerPersons =
          _customPriceControllers.map((c) => double.tryParse(c.text) ?? 0.0).toList();
      final sum = pricePerPersons.fold(0.0, (a, b) => a + b);
      if ((sum - price).abs() > 0.009) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยอดรวมแต่ละคนไม่เท่าราคารวมที่กำหนดไว้')),
        );
        return;
      }
    }

    final memberTripIds = _selectedMembers
        .map((m) => m.memberTripId ?? 0)
        .where((id) => id != 0)
        .toList();

    try {
      final ok = await _activityController.doEditActivity(
        activityId: widget.activityId,
        activityName: name,
        activityDetail: detail,
        activityPrice: price,
        activityDateTime: adjusted,
        tripId: widget.tripId,
        imageFile: _imageFile, // ส่งเมื่อเลือกรูปใหม่
        memberTripIds: memberTripIds,
        pricePerPersons: pricePerPersons,
      );

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตกิจกรรมเรียบร้อย')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตไม่สำเร็จ')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตล้มเหลว: $e')),
      );
    }
  }

  // ---------- UI Helpers ----------
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

  Widget _sectionCard({required Widget child}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child);

  // ---------- พรีวิวรูป “เต็มภาพ ไม่โดนครอป” ----------
  Widget _buildImagePreview(double availWidth) {
    // รูปใหม่
    if (_imageFile != null) {
      final double h = (_imgW != null && _imgH != null)
          ? (availWidth * (_imgH! / _imgW!))
          : 200.0;
      return Stack(
        alignment: Alignment.topRight,
        children: [
          SizedBox(
            width: double.infinity,
            height: h.clamp(160.0, 600.0),
            child: Center(
              child: Image.file(
                _imageFile!,
                fit: BoxFit.contain, // ✅ เต็มภาพ ไม่ครอป
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

    // รูปเก่า
    if (_oldImageUrl != null) {
      final double h = (_oldW != null && _oldH != null)
          ? (availWidth * (_oldH! / _oldW!))
          : 200.0;
      return Stack(
        alignment: Alignment.topRight,
        children: [
          SizedBox(
            width: double.infinity,
            height: h.clamp(160.0, 600.0),
            child: Center(
              child: Image.network(
                _oldImageUrl!,
                fit: BoxFit.contain, // ✅ เต็มภาพ ไม่ครอป
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
          _iconBadge(icon: Icons.close, onTap: _removeOldImage),
          _cornerTag(text: 'รูปเก่า', color: Colors.blue),
        ],
      );
    }

    // ไม่มีรูป
    return const SizedBox(
      height: 180,
      child: Center(child: Icon(Icons.image_outlined, size: 42, color: Colors.grey)),
    );
  }

  Widget _imageCard() {
    final screenW = MediaQuery.of(context).size.width;
    final innerW = screenW - 16 - 16; // padding ซ้าย/ขวา ของหน้า

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('แนบรูปกิจกรรม'),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey.shade100,
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
                )
              else if (_oldImageUrl != null)
                TextButton.icon(
                  onPressed: _removeOldImage,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('ไม่ใช้รูปเก่า', style: TextStyle(color: Colors.red)),
                ),
            ],
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
                            if (_equalPerPersons.isNotEmpty && i < _equalPerPersons.length) {
                              seed = _sanitizeAndCap(_equalPerPersons[i].toString());
                            } else if (i < _customPriceControllers.length) {
                              seed = _sanitizeAndCap(_customPriceControllers[i].text);
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
                    color: isSelected ? Colors.cyan.withOpacity(0.06) : Colors.transparent,
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
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final assigned = _currentAssignedTotal();

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xfff4f6f8),
        foregroundColor: Colors.black87,
        title: const Text('แก้ไขกิจกรรม...', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('ชื่อกิจกรรม'),
                    TextFormField(
                      controller: _nameController,
                      decoration: _filledInput(hint: 'เช่น เช่ารถตู้เหมา'),
                      validator: _validateActivityName,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 12),

                    _label('จำนวนเงิน'),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: _filledInput(hint: 'เช่น 500 บาท'),
                      validator: _validatePrice,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            decoration: _filledInput(hint: 'เลือกวัน', suffixIcon: const Icon(Icons.date_range)),
                            validator: (v) => (v == null || v.isEmpty) ? 'กรุณาเลือกวัน' : null,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _timeController,
                            readOnly: true,
                            onTap: _pickTime,
                            decoration: _filledInput(hint: 'เลือกเวลา', suffixIcon: const Icon(Icons.access_time)),
                            validator: (v) => (v == null || v.isEmpty) ? 'กรุณาเลือกเวลา' : null,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _label('รายละเอียดกิจกรรม'),
                    TextFormField(
                      controller: _detailController,
                      maxLines: 4,
                      decoration: _filledInput(hint: 'รายละเอียดเพิ่มเติม เช่น ค่ามัดจำ/ค่าบริการ (เว้นว่างได้)'),
                      validator: _validateDetail,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ],
                ),
              ),

              _imageCard(),
              _participantsCard(),

              const SizedBox(height: 8),

              Row(
                children: [
                  Text('฿${assigned.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Text('จาก ฿${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_splitMode == 1)
                    Text(
                      _remainingAmount > 0 ? 'เหลือ ฿${_remainingAmount.toStringAsFixed(2)}' : 'ครบยอดแล้ว',
                      style: TextStyle(
                        color: _remainingAmount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

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
                    onPressed: _updateActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('บันทึกกิจกรรม', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
