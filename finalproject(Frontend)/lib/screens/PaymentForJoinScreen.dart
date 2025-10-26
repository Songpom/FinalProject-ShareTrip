import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controller/tripcontroller.dart';
import '../boxs/userlog.dart';

class PaymentForJoinScreen extends StatefulWidget {
  final double fee;
  final String qrCodeBase64;
  final String tripName;
  final int tripId;

  const PaymentForJoinScreen({
    Key? key,
    required this.fee,
    required this.qrCodeBase64,
    required this.tripName,
    required this.tripId,
  }) : super(key: key);

  @override
  State<PaymentForJoinScreen> createState() => _PaymentForJoinScreenState();
}

class _PaymentForJoinScreenState extends State<PaymentForJoinScreen> {
  bool showDetails = true;
  Uint8List? qrCodeBytes;
  File? slipImageFile;
  final TripController _tripController = TripController();

  // สัดส่วนรูปสลิปจริง
  double? _imgW;
  double? _imgH;

  // ข้อความแจ้งเตือนสีแดง (อินไลน์เหนือปุ่มล่างสุด)
  String? _inlineError;

  // นับถอยหลัง 15 นาที
  late DateTime _expiresAt;
  Duration _remain = const Duration(minutes: 15);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // โหลด QR
    try {
      qrCodeBytes = base64Decode(widget.qrCodeBase64);
    } catch (_) {
      // ไม่ใช้ snackbar แล้ว ปล่อยเป็น error inline ตอนกดปุ่ม
      _inlineError = 'ไม่พบข้อมูลในการชำระเงิน';
    }

    // เริ่มจับเวลา 15 นาที
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _expiresAt = DateTime.now().add(const Duration(minutes: 15));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _expiresAt.difference(DateTime.now());
      setState(() {
        _remain = left.isNegative ? Duration.zero : left;
      });
      if (left.isNegative) {
        _ticker?.cancel();
      }
    });
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    if (hh > 0) {
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  // ลบรูปสลิป
  void _removeSlipImage() {
    setState(() {
      slipImageFile = null;
      _imgW = null;
      _imgH = null;
      _inlineError = null;
    });
  }

  // ตรวจสกุลไฟล์
  bool _isAllowedImageExt(String filename) {
    final ok = RegExp(r'\.(jpg|jpeg|png|gif|bmp)$', caseSensitive: false);
    return ok.hasMatch(filename);
  }

  Future<void> pickSlipImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (!_isAllowedImageExt(picked.name)) {
      setState(() => _inlineError = 'กรุณาเลือกรูป .jpg .jpeg .png .gif .bmp');
      return;
    }

    final file = File(picked.path);
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      setState(() {
        slipImageFile = file;
        _imgW = w;
        _imgH = h;
        _inlineError = null;
      });
    } catch (_) {
      setState(() {
        slipImageFile = file;
        _imgW = null;
        _imgH = null;
        _inlineError = null;
      });
    }
  }

  Future<void> notifyPayment() async {
    // ถ้าหมดเวลา
    if (_remain == Duration.zero) {
      setState(() => _inlineError = 'QR หมดอายุ กรุณารีเฟรช QR แล้วลองใหม่');
      return;
    }

    if (slipImageFile == null) {
      setState(() => _inlineError = 'กรุณาแนบหลักฐานการชำระเงิน');
      return;
    }

    setState(() => _inlineError = null);

    final email = UserLog().email;
    final amount = widget.fee;
    final tripId = widget.tripId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _tripController.getCheckSlip(
        slipImage: slipImageFile!,
        amount: amount,
        tripId: tripId,
        email: email,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // ปิด loading

      final status = (result['status'] ?? '').toString().toLowerCase();
      if (status == 'success' || status == 'ok') {
        // สำเร็จ: ปิดหน้านี้พร้อมส่ง true กลับ
        Navigator.of(context).pop(true);
      } else {
        final msg = (result['message'] ?? '').toString();
        setState(() {
          _inlineError = msg.isNotEmpty
              ? msg
              : 'ไม่สามารถตรวจสอบหลักฐานได้ กรุณาตรวจสอบไฟล์และลองใหม่อีกครั้ง';
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _inlineError = 'ชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    }
  }

  // รีเฟรช QR: เริ่มนับใหม่ + เคลียร์ error (ถ้าต้องการจะเรียก API โหลด QR ใหม่ ก็เพิ่มได้ตรงนี้)
  void refreshQRCode() {
    setState(() {
      _inlineError = null;
      // ถ้าคุณมี API refresh QR ให้ไป call ที่นี่ แล้วอัปเดต qrCodeBytes ตามผลลัพธ์
    });
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final feeText = widget.fee.toStringAsFixed(2);
    final double aspect =
        (_imgW != null && _imgH != null && _imgH! > 0) ? (_imgW! / _imgH!) : (16 / 9);

    final bool isExpired = _remain == Duration.zero;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ชำระเงิน'),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  // ===== การ์ด QR + ยอดเงิน =====
                  Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [
      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('ค่าเข้าร่วม', style: TextStyle(fontSize: 16)),
            const Spacer(),
            Text(
              feeText,
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF1F7AE0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          child: qrCodeBytes != null
              ? Column(
                  children: [
                    Image.memory(qrCodeBytes!, width: 180, height: 180),
                    const SizedBox(height: 10),
                    // นับถอยหลังใต้ QR
                    Text(
                      isExpired
                          ? 'QR หมดอายุแล้ว'
                          : 'เวลาคงเหลือ ${_fmt(_remain)} นาที',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isExpired ? Colors.red : Colors.black87,
                      ),
                    ),
                  ],
                )
              : const SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
        ),
        const SizedBox(height: 8),
        // ❌ เอา Row ปุ่ม refresh ออก
      ],
    ),
  ),
),

                  const SizedBox(height: 14),

                  // ===== รายละเอียดการชำระเงิน =====
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: const Text('รายละเอียดการชำระเงิน',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        initiallyExpanded: showDetails,
                        onExpansionChanged: (v) => setState(() => showDetails = v),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                const Expanded(child: Text('ค่าสมาชิก')),
                                Text(feeText),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FAFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'ยอดรวมทั้งสิ้น',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const Spacer(),
                                Text(
                                  '฿$feeText',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF1F7AE0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ===== แนบรูปสลิป =====
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      child: slipImageFile == null
                          ? Container(
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_outlined, color: Colors.grey.shade500, size: 36),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: pickSlipImage,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        elevation: 0,
                                        side: BorderSide(color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text('แนบรูปภาพ', style: TextStyle(color: Colors.black87)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: pickSlipImage,
                                    child: AspectRatio(
                                      aspectRatio: aspect,
                                      child: Image.file(
                                        slipImageFile!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: InkWell(
                                      onTap: _removeSlipImage,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: ElevatedButton.icon(
                                      onPressed: pickSlipImage,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.9),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      icon: const Icon(Icons.image_rounded, size: 18, color: Colors.black87),
                                      label: const Text('เลือกใหม่', style: TextStyle(color: Colors.black87)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 90),
                ],
              ),
            ),

            // ===== แถบล่าง: error inline + ปุ่มยืนยัน =====
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: const Color(0xFFF9FAFB),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_inlineError != null && _inlineError!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _inlineError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isExpired ? null : notifyPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExpired ? Colors.grey : const Color(0xFF1A6DDB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isExpired ? 'QR หมดอายุแล้ว' : 'แจ้งชำระเงิน ฿$feeText',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPill(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE9EDF3)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

