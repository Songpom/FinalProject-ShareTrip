import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/controller/tripcontroller.dart';


class CheckPaymentJoinScreen extends StatefulWidget {
  final int memberTripId;
  const CheckPaymentJoinScreen({Key? key, required this.memberTripId}) : super(key: key);

  @override
  State<CheckPaymentJoinScreen> createState() => _CheckPaymentJoinScreenState();
}

class _CheckPaymentJoinScreenState extends State<CheckPaymentJoinScreen> {
  final TripController _tripController = TripController();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _memberTrip; // memberTrip (มี participant, payments)
  Map<String, dynamic>? _payment;    // payment สำหรับ "ค่าเข้าร่วม" (ตัวเดียว)

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
      final data = await _tripController.getPaymentJoin(memberTripId: widget.memberTripId);

      Map<String, dynamic>? memberTripJson;
      Map<String, dynamic>? joinPaymentJson;

      if (data.containsKey('memberTrip')) {
        memberTripJson = Map<String, dynamic>.from(data['memberTrip'] as Map);
        if (data['payment'] != null) {
          joinPaymentJson = Map<String, dynamic>.from(data['payment'] as Map);
        } else {
          final pmts = (memberTripJson['payments'] as List?) ?? [];
          joinPaymentJson = _pickJoinPayment(pmts);
        }
      } else {
        memberTripJson = Map<String, dynamic>.from(data);
        final pmts = (memberTripJson['payments'] as List?) ?? [];
        joinPaymentJson = _pickJoinPayment(pmts);
      }

      if (!mounted) return;
      setState(() {
        _memberTrip = memberTripJson;
        _payment = joinPaymentJson;
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

  Map<String, dynamic>? _pickJoinPayment(List payments) {
    for (final p in payments) {
      final m = Map<String, dynamic>.from(p as Map);
      if ((m['paymentDetail'] ?? '').toString() == 'ค่าเข้าร่วม') return m;
    }
    return null;
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
  // สถานะ: กำลังโหลด
  if (_loading) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจสอบการชำระค่าเข้าร่วม')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  // สถานะ: มี error
  if (_error != null) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสอบการชำระค่าเข้าร่วม'),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('เกิดข้อผิดพลาด: $_error'),
          ],
        ),
      ),
    );
  }

  // ข้อมูลพร้อมแสดง
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
  final paymentStatus = (_payment?['paymentStatus'] ?? '').toString();
  final paymentSlip = (_payment?['paymentSlip'] ?? '').toString();
  final paymentSlipUrl = paymentSlip.isNotEmpty ? '$baseURL/images/$paymentSlip' : null;

  final dateStrRaw = (_payment?['datetimePayment'] ?? '').toString();
  final dateStr = _formatDate(dateStrRaw);

  return Scaffold(
    appBar: AppBar(
      title: const Text('ตรวจสอบการชำระค่าเข้าร่วม'),
      actions: [
        IconButton(
          tooltip: 'รีเฟรช',
          onPressed: _fetch,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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

          // Payment
          const Text('ข้อมูลการชำระ "ค่าเข้าร่วม"',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('จำนวนเงิน',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Text(
                        '฿${price.toStringAsFixed(2)}',
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

                  // Slip (Full Screen & Zoom)
// Slip (Full Width, No Horizontal Overflow)
Align(
  alignment: Alignment.centerLeft,
  child: Text(
    'หลักฐานการชำระเงิน',
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
        MaterialPageRoute(builder: (_) => _FullScreenImage(url: paymentSlipUrl!)),
      );
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth; // ความกว้างจริงภายในการ์ดนี้
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: w), // ล็อกกว้าง = การ์ด
            child: Image.network(
              paymentSlipUrl!,
              fit: BoxFit.fitWidth,             // ขยายเต็มแนวกว้าง "พอดี"
              alignment: Alignment.topCenter,   // จัดชิดบนเวลาแนวตั้งยาว
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
            Text('ไม่มีหลักฐานการชำระ', style: TextStyle(color: Colors.grey.shade700)),
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
class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth; // กว้างจริงของหน้าจอ

          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            constrained: true,              // ให้ยึดตามขนาดพ่อ
            boundaryMargin: EdgeInsets.zero,
            clipBehavior: Clip.hardEdge,    // กันล้นภาพตอนแพน
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,  // เลื่อนเฉพาะแนวตั้ง
              physics: const BouncingScrollPhysics(),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints.tightFor(width: screenW), // ล็อกกว้าง = จอ
                  child: Image.network(
                    url,
                    fit: BoxFit.fitWidth,   // ขยายเต็มแนวกว้างพอดี
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
