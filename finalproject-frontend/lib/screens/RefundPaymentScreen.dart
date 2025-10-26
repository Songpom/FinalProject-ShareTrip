import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finalproject/controller/refundController.dart';
import 'package:finalproject/constant/constant_value.dart';

class RefundPaymentScreen extends StatefulWidget {
  final int memberTripId;

  const RefundPaymentScreen({
    Key? key,
    required this.memberTripId,
  }) : super(key: key);

  @override
  State<RefundPaymentScreen> createState() => _RefundPaymentScreenState();
}

class _RefundPaymentScreenState extends State<RefundPaymentScreen> {
  final RefundController _refundController = RefundController();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  Map<String, dynamic>? _memberTripLite;

  // เงิน+QR
  double _amount = 0.0;
  Uint8List? _qrBytes;

  // สลิป
  File? _slipImageFile;
  double? _imgW;
  double? _imgH;

  // นับถอยหลัง 15 นาที (ให้เหมือนหน้า PaymentForJoin)
  late DateTime _expiresAt;
  Duration _remain = const Duration(minutes: 15);
  Timer? _ticker;

  // UI states
  bool _submitting = false;
  bool _showDetails = true;
  String? _inlineError; // แสดงอินไลน์เหนือปุ่มล่าง (แทน snackbar)

  @override
  void initState() {
    super.initState();
    _loadRefundData();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------- Utilities ----------
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

  // ---------- Data ----------
  Future<void> _loadRefundData() async {
    setState(() {
      _isLoading = true;
      _inlineError = null;
    });

    try {
      final resp = await _refundController.getViewRefund(memberTripId: widget.memberTripId);
      final base64Str = (resp['qrcode'] as String?) ?? '';
      final amount = (resp['amount'] as num?)?.toDouble() ?? 0.0;
      final memberTrip = resp['memberTrip'] as Map<String, dynamic>?;

      Uint8List? qrBytes;
      if (base64Str.isNotEmpty) {
        qrBytes = base64Decode(base64Str);
      }

      setState(() {
        _amount = amount;
        _qrBytes = qrBytes;
        _memberTripLite = memberTrip;
        _isLoading = false;
      });

      // เริ่มนับถอยหลังหลังได้ข้อมูล QR (ให้เหมือน PaymentForJoin)
      _startCountdown();

      if (amount <= 0) {
        _inlineError = 'ไม่มียอดที่ต้องคืน';
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _inlineError = 'ไม่สามารถโหลดข้อมูลได้';
      });
    }
  }

  // ---------- Slip ----------
  Future<void> _pickSlipImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted || picked == null) return;

    if (!_isAllowedImageExt(picked.name)) {
      setState(() => _inlineError = 'กรุณาเลือกรูป .jpg .jpeg .png .gif .bmp');
      return;
    }

    final file = File(picked.path);
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _slipImageFile = file;
        _imgW = frame.image.width.toDouble();
        _imgH = frame.image.height.toDouble();
        _inlineError = null;
      });
    } catch (_) {
      setState(() {
        _slipImageFile = file;
        _imgW = null;
        _imgH = null;
        _inlineError = null;
      });
    }
  }

  void _clearSlip() {
    setState(() {
      _slipImageFile = null;
      _imgW = null;
      _imgH = null;
    });
  }

  // ---------- Submit ----------
  Future<void> _submitRefundSlip() async {
    final isExpired = _remain == Duration.zero;

    if (isExpired) {
      setState(() => _inlineError = 'QR หมดอายุ กรุณารีเฟรช QR แล้วลองใหม่');
      return;
    }
    if (_slipImageFile == null) {
      setState(() => _inlineError = 'กรุณาแนบรูปภาพสลิปก่อนยืนยันการคืนเงิน');
      return;
    }
    if (_amount <= 0) {
      setState(() => _inlineError = 'จำนวนเงินไม่ถูกต้อง');
      return;
    }

    setState(() => _inlineError = null);

    setState(() => _submitting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _refundController.doRefundPayment(
        slipImage: _slipImageFile!,
        amount: _amount,
        memberTripId: widget.memberTripId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // ปิด loading

      final status = (result['status'] ?? '').toString().toLowerCase();
      if (status == 'success' || status == 'ok') {
        Navigator.of(context).pop(true);
      } else {
        final msg = (result['message'] ?? 'ส่งหลักฐานไม่สำเร็จ').toString();
        _clearSlip();
        setState(() {
          _inlineError = '$msg\nโปรดแนบสลิปใหม่อีกครั้ง';
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _clearSlip();
      setState(() => _inlineError = 'เกิดข้อผิดพลาด: $e\nโปรดแนบสลิปใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // (ถ้าจะต่อยอดให้เหมือน refresh QR จริง ๆ ให้เชื่อม API แล้วอัปเดต _qrBytes ที่นี่)
  void _refreshQRCode() {
    setState(() {
      _inlineError = null;
    });
    _startCountdown();
    // TODO: เรียก API refresh QR และอัปเดต _qrBytes หากมี
  }

  @override
  Widget build(BuildContext context) {
    final amountText = _amount.toStringAsFixed(2);
    final isExpired = _remain == Duration.zero;
    final double aspect =
        (_imgW != null && _imgH != null && _imgH! > 0) ? (_imgW! / _imgH!) : (16 / 9);

    final member = _memberTripLite?['member'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('คืนเงินสมาชิก'),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      children: [
                        // ===== ผู้รับเงิน (คงไว้ตามเดิม) =====
                        if (member != null) _buildMemberHeader(member),
                        if (member != null) const SizedBox(height: 12),

                        // ===== การ์ดยอด + QR (เหมือน PaymentForJoin) =====
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
                                    const Text('ยอดที่จะคืน', style: TextStyle(fontSize: 16)),
                                    const Spacer(),
                                    Text(
                                      amountText,
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
                                  child: _qrBytes != null
                                      ? Column(
                                          children: [
                                            Image.memory(_qrBytes!, width: 180, height: 180),
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
                                // ตั้งใจ “ไม่ใส่ปุ่มรีเฟรช” เพื่อให้เหมือนหน้า PaymentForJoin เวอร์ชันล่าสุด
                                // ถ้าอยากมีปุ่ม ให้ใช้ _refreshQRCode()
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ===== รายละเอียดการชำระเงิน (ExpansionTile เหมือนกัน) =====
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
                              title: const Text('รายละเอียดการคืนเงิน',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              initiallyExpanded: _showDetails,
                              onExpansionChanged: (v) => setState(() => _showDetails = v),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Row(
                                    children: [
                                      const Expanded(child: Text('จำนวนเงินที่จะคืน')),
                                      Text(amountText),
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
                                        '฿$amountText',
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

                        // ===== แนบรูปสลิป (เหมือน PaymentForJoin) =====
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
                            child: _slipImageFile == null
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
                                              _slipImageFile!,
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
                                            onTap: _clearSlip,
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
                                                  borderRadius: BorderRadius.circular(20)),
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
                                  color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_amount <= 0 || isExpired || _submitting)
                                ? null
                                : _submitRefundSlip,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_amount <= 0 || isExpired)
                                  ? Colors.grey
                                  : const Color(0xFF1A6DDB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isExpired
                                  ? 'QR หมดอายุแล้ว'
                                  : 'ยืนยันการคืนเงิน ฿$amountText',
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

  Widget _buildMemberHeader(Map<String, dynamic> member) {
    final email = member['email'] as String? ?? '';
    final username = member['username'] as String? ?? '';
    final memberImage = member['member_image'] as String?;
    final hasImage = memberImage != null && memberImage.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundImage: hasImage ? NetworkImage('$baseURL/images/$memberImage') : null,
          child: !hasImage ? const Icon(Icons.person) : null,
        ),
        title: Text(email.isNotEmpty ? email : 'ไม่มีอีเมล'),
        subtitle: Text(username.isNotEmpty ? username : '-'),
      ),
    );
  }
}
