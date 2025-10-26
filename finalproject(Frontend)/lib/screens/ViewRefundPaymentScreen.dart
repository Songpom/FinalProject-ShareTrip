import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/controller/tripcontroller.dart';

class ViewRefundPaymentScreen extends StatefulWidget {
  final int tripId;
  final String email; // email ของผู้เข้าร่วมที่อยากดูหลักฐานการคืนเงิน

  const ViewRefundPaymentScreen({
    Key? key,
    required this.tripId,
    required this.email,
  }) : super(key: key);

  @override
  State<ViewRefundPaymentScreen> createState() => _ViewRefundPaymentScreenState();
}

class _ViewRefundPaymentScreenState extends State<ViewRefundPaymentScreen> {
  final TripController _tripController = TripController();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _memberTrip; // memberTrip (มี participant)
  Map<String, dynamic>? _payment;    // payment สำหรับ "refund_member" (ตัวเดียว)

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // เรียก backend ผ่าน TripController
      final data = await _tripController.getViewRefundPayment(
        tripId: widget.tripId,
        email: widget.email,
      );

      Map<String, dynamic>? memberTripJson;
      Map<String, dynamic>? refundPaymentJson;

      if (data.containsKey('memberTrip')) {
        memberTripJson = Map<String, dynamic>.from(data['memberTrip'] as Map);
      } else {
        // กันกรณี backend ไม่ส่ง memberTrip (ไม่ควรเกิด)
        memberTripJson = Map<String, dynamic>.from(data);
      }

      if (data['payment'] != null) {
        refundPaymentJson = Map<String, dynamic>.from(data['payment'] as Map);
      } else {
        refundPaymentJson = null; // ยังไม่มีการคืนเงิน
      }

      if (!mounted) return;
      setState(() {
        _memberTrip = memberTripJson;
        _payment = refundPaymentJson;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    DateTime? dt;
    try {
      dt = DateTime.parse(raw).toLocal();
    } catch (_) {
      try {
        dt = DateFormat('yyyy-MM-dd').parse(raw).toLocal();
      } catch (_) {}
    }
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('ดูหลักฐานการคืนเงิน')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ดูหลักฐานการคืนเงิน')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('เกิดข้อผิดพลาด: $_error'),
          ),
        ),
      );
    }

    final participant = (_memberTrip?['participant'] as Map?)?.cast<String, dynamic>();
    final fullName = [
      participant?['firstName'] ?? '',
      participant?['lastName'] ?? '',
    ].where((e) => (e as String).isNotEmpty).join(' ');
    final username = (participant?['username'] ?? '').toString();
    final email = (participant?['email'] ?? '').toString();
    final avatar = (participant?['member_image'] ?? '').toString();
    final avatarUrl = avatar.isNotEmpty ? '$baseURL/images/$avatar' : null;

    final price = (_payment?['price'] as num?)?.toDouble() ?? 0.0;
    final displayAmount = price.abs(); // แสดงเป็นบวกเสมอ
    final paymentStatus = (_payment?['paymentStatus'] ?? '').toString();
    final paymentSlip = (_payment?['paymentSlip'] ?? '').toString();
    final paymentSlipUrl = paymentSlip.isNotEmpty ? '$baseURL/images/$paymentSlip' : null;
    final dateStrRaw = (_payment?['datetimePayment'] ?? '').toString();
    final dateStr = _payment != null ? _formatDate(dateStrRaw) : '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ดูหลักฐานการคืนเงิน'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ผู้ใช้
          const Text('ผู้ใช้', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person, size: 28) : null,
              ),
              title: Text(
                fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : '-'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(email.isNotEmpty ? email : '-'),
            ),
          ),

          const SizedBox(height: 16),

          // Refund Payment
          const Text('ข้อมูลการคืนเงิน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _payment == null
                  ? const Text('ยังไม่มีรายการคืนเงิน')
                  : Column(
                      children: [
                        Row(
                          children: [
                            const Text('จำนวนเงิน',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Text(
                              '฿${displayAmount.toStringAsFixed(2)}', // ใช้ abs()
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            _StatusChip(status: paymentStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(dateStr),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Slip (Full Screen & Zoom) + จำกัดความกว้างไม่ให้ล้น
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'หลักฐานการคืนเงิน',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (paymentSlipUrl != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _FullScreenImage(url: paymentSlipUrl),
                                ),
                              );
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth, // ไม่เกินความกว้างการ์ด
                                    ),
                                    child: Image.network(
                                      paymentSlipUrl,
                                      fit: BoxFit.fitWidth, // กว้างเต็มได้, สูงตามสัดส่วน
                                      errorBuilder: (_, __, ___) => _brokenImage(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          _noSlip(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brokenImage() => Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.broken_image, size: 38, color: Colors.grey),
        ),
      );

  Widget _noSlip() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 42, color: Colors.grey),
            const SizedBox(height: 6),
            Text('ไม่มีหลักฐานการคืนเงิน', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _bg {
    switch (status.toLowerCase()) {
      case 'correct':
      case 'complete':
        return Colors.green.shade100;
      case 'pending':
        return Colors.orange.shade100;
      case 'reject':
      case 'failed':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color get _fg {
    switch (status.toLowerCase()) {
      case 'correct':
      case 'complete':
        return Colors.green.shade800;
      case 'pending':
        return Colors.orange.shade800;
      case 'reject':
      case 'failed':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = status.isEmpty ? '-' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: _fg, fontWeight: FontWeight.w600)),
    );
  }
}

/// หน้าดูรูป “เต็มจอ” + ซูม/เลื่อน
class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
          AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            url,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain, // เต็มจอแบบรักษาสัดส่วน ไม่ครอป
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white70, size: 48),
          ),
        ),
      ),
    );
  }
}
