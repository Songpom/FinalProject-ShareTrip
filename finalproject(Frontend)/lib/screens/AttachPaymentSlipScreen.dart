import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finalproject/constant/constant_value.dart';
import '../controller/expendController.dart';

class AttachPaymentSlipScreen extends StatefulWidget {
  final int memberTripId;
  final int tripId;

  const AttachPaymentSlipScreen({
    super.key,
    required this.memberTripId,
    required this.tripId,
  });

  @override
  State<AttachPaymentSlipScreen> createState() => _AttachPaymentSlipScreenState();
}

class _AttachPaymentSlipScreenState extends State<AttachPaymentSlipScreen> {
  final ExpendController _expendController = ExpendController();
  final ImagePicker _picker = ImagePicker();

  // ข้อมูลจ่าย
  double? amount;
  String? qrCodeBase64;

  // สถานะ UI
  bool showDetails = true;
  File? slipImageFile;
  double? _imgW; // สัดส่วนภาพจริง (กว้าง)
  double? _imgH; // สัดส่วนภาพจริง (สูง)
  String? _inlineError;

  // โหลดข้อมูล
  bool _isLoadingPage = false;

  // นับถอยหลัง 15 นาที เหมือน PaymentForJoin
  late DateTime _expiresAt;
  Duration _remain = const Duration(minutes: 15);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _fetchPaymentDetail();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---- Helpers ----
  bool _isAllowedImageExt(String filename) {
    final ok = RegExp(r'\.(jpg|jpeg|png|gif|bmp)$', caseSensitive: false);
    return ok.hasMatch(filename);
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
    if (hh > 0) return '$hh:$mm:$ss';
    return '$mm:$ss';
  }

  // ---- Load Data ----
  Future<void> _fetchPaymentDetail() async {
    setState(() {
      _isLoadingPage = true;
      _inlineError = null;
    });
    try {
      final data = await _expendController.getExpendDetail(
        memberTripId: widget.memberTripId,
        tripId: widget.tripId,
      );

      final amt = (data['amount'] != null) ? (data['amount'] as num).toDouble() : null;
      final qr = (data['qrcode'] ?? '') as String;

      setState(() {
        amount = amt;
        qrCodeBase64 = qr.isNotEmpty ? qr : null;
        _isLoadingPage = false;
      });

      // เริ่มนับถอยหลังหลังได้ QR แล้ว (จัดให้เหมือนหน้าชำระเข้าร่วม)
      _startCountdown();
    } catch (e) {
      setState(() {
        _isLoadingPage = false;
        _inlineError = 'ไม่สามารถโหลดข้อมูลได้';
      });
    }
  }

  // ---- Image Picking ----
  Future<void> _pickSlipImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
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
      // หากอ่านขนาดไม่สำเร็จ ก็ยังแนบได้
      setState(() {
        slipImageFile = file;
        _imgW = null;
        _imgH = null;
        _inlineError = null;
      });
    }
  }

  void _removeSlipImage() {
    setState(() {
      slipImageFile = null;
      _imgW = null;
      _imgH = null;
      _inlineError = null;
    });
  }

  // ---- Upload ----
  Future<void> _uploadSlip() async {
    final isExpired = _remain == Duration.zero;

    if (isExpired) {
      setState(() => _inlineError = 'QR หมดอายุ กรุณารีเฟรช QR แล้วลองใหม่');
      return;
    }
    if (slipImageFile == null) {
      setState(() => _inlineError = 'กรุณาแนบหลักฐานการชำระเงิน');
      return;
    }
    if (amount == null) {
      setState(() => _inlineError = 'จำนวนเงินไม่ถูกต้อง');
      return;
    }

    setState(() => _inlineError = null);

    // แสดง loading ตรงกลาง (เหมือนหน้า paymentforjoin)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _expendController.doPaymentExpend(
        slipImage: slipImageFile!,
        amount: amount!,
        memberTripId: widget.memberTripId,
        tripId: widget.tripId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // ปิด loading

      final status = (result['status'] ?? '').toString().toLowerCase();
      if (status == 'success' || status == 'ok') {
        Navigator.of(context).pop(true); // ปิดหน้านี้พร้อมส่ง true
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
      Navigator.of(context).pop(); // ปิด loading
      setState(() => _inlineError = 'ชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    }
  }

  // (ถ้าต้องการต่อยอด refresh QR ให้เรียก API แล้วอัปเดต qrCodeBase64 ตรงนี้)
  void _refreshQRCode() {
    setState(() {
      _inlineError = null;
      // TODO: ถ้ามี API refresh ให้เรียกและอัปเดต qrCodeBase64
    });
    _startCountdown();
  }

@override
Widget build(BuildContext context) {
  final feeText = amount != null ? amount!.toStringAsFixed(2) : '-';
  final isExpired = _remain == Duration.zero;
  final double aspect =
      (_imgW != null && _imgH != null && _imgH! > 0) ? (_imgW! / _imgH!) : (16 / 9);

  return Scaffold(
    appBar: AppBar(
      title: const Text('แนบสลิปเพิ่มเติม'),
      centerTitle: true,
    ),
    backgroundColor: const Color(0xFFF9FAFB),
    body: _isLoadingPage
        // โหมดกำลังโหลดก็ยังลากรีเฟรชได้
        ? SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchPaymentDetail,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          )
        : SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchPaymentDetail,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                    const Text('ยอดที่ต้องจ่ายเพิ่มเติม', style: TextStyle(fontSize: 16)),
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
                                  child: qrCodeBase64 != null
                                      ? Column(
                                          children: [
                                            Image.memory(
                                              base64Decode(qrCodeBase64!),
                                              width: 180,
                                              height: 180,
                                            ),
                                            const SizedBox(height: 10),
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
                                      const Expanded(child: Text('จำนวนเงิน')),
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
                                          Icon(Icons.image_outlined,
                                              color: Colors.grey.shade500, size: 36),
                                          const SizedBox(height: 10),
                                          ElevatedButton(
                                            onPressed: _pickSlipImage,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              elevation: 0,
                                              side: BorderSide(color: Colors.grey.shade300),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: const Text('แนบรูปภาพ',
                                                style: TextStyle(color: Colors.black87)),
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
                                          onTap: _pickSlipImage,
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
                                              child: const Icon(Icons.close,
                                                  color: Colors.white, size: 20),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 8,
                                          bottom: 8,
                                          child: ElevatedButton.icon(
                                            onPressed: _pickSlipImage,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white.withOpacity(0.9),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                            icon: const Icon(Icons.image_rounded,
                                                size: 18, color: Colors.black87),
                                            label: const Text('เลือกใหม่',
                                                style: TextStyle(color: Colors.black87)),
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
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (amount == null || isExpired) ? null : _uploadSlip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (amount == null || isExpired) ? Colors.grey : const Color(0xFF1A6DDB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            isExpired ? 'QR หมดอายุแล้ว' : 'ยืนยันการแนบสลิป ฿$feeText',
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

}
