import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:finalproject/controller/expendcontroller.dart';
import 'package:finalproject/model/expenddetailresult.dart';
import 'package:finalproject/constant/constant_value.dart';

class RequestExtraPaymentScreen extends StatefulWidget {
  final List<ExpendDetailResult> members;
  final int tripId;

  const RequestExtraPaymentScreen({
    super.key,
    required this.members,
    required this.tripId,
  });

  @override
  State<RequestExtraPaymentScreen> createState() => _RequestExtraPaymentScreenState();
}

class _RequestExtraPaymentScreenState extends State<RequestExtraPaymentScreen> {
  final Map<int, double> extraAmounts = {}; // memberTripId -> amount
  bool _isLoading = false;
  late ExpendController _expendController;

  @override
  void initState() {
    super.initState();
    _expendController = ExpendController();
    // ให้ค่าเริ่มต้น 0 ทุกคน (กัน null)
    for (final m in widget.members) {
      extraAmounts.putIfAbsent(m.memberTripId, () => 0.0);
    }
  }

 Future<void> _submitPayments() async {
  setState(() => _isLoading = true);

  final List<Map<String, dynamic>> payments = widget.members.map((m) {
    final amount = extraAmounts[m.memberTripId] ?? 0.0;
    return {
      'memberTripId': m.memberTripId,
      'amount': amount,
    };
  }).toList();

  // ✅ กันเพดานก่อนส่ง
  for (final p in payments) {
    final amt = (p['amount'] as double?) ?? 0.0;
    if (amt > 100000.0) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยอดเรียกเก็บต่อคนต้องไม่เกิน 100,000 บาท')),
      );
      return;
    }
  }

  try {
    await _expendController.doRequestExtraPayment(
      tripId: widget.tripId,
      payments: payments,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เรียกเก็บเงินสำเร็จ')),
    );
    Navigator.of(context).pop(true);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ส่งข้อมูลไม่สำเร็จ: $e')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,##0.00", "en_US");

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการเรียกเก็บเงิน'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.members.length,
                itemBuilder: (context, index) {
                  final member = widget.members[index];

                  return MemberPaymentCard(
                    key: ValueKey(member.memberTripId), // คง state controller
                    member: member,
                    // ส่งค่าเริ่มต้นแค่ครั้งแรก ไม่ต้องเขียนทับทุกครั้ง
                    initialExtraAmount: extraAmounts[member.memberTripId] ?? 0.0,
                    onExtraChanged: (value) {
                      setState(() {
                        extraAmounts[member.memberTripId] = value;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // รวมเรียกเก็บเพิ่มทั้งหมด (รอบนี้)
            Builder(
              builder: (_) {
                final totalExtra = widget.members.fold<double>(
                  0.0,
                  (sum, m) => sum + (extraAmounts[m.memberTripId] ?? 0.0),
                );
                return Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    child: Text(
                      'รวมเรียกเก็บเพิ่ม (รอบนี้): ฿${fmt.format(totalExtra)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
            ),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitPayments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'ยืนยันการเรียกเก็บ',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formatter แบบ “ปฏิเสธ”
/// อนุญาตเฉพาะตัวเลข + จุด และทศนิยมไม่เกิน 2 ตำแหน่ง
class TwoDecimalsRejectFormatter extends TextInputFormatter {


  final int decimalDigits;
  TwoDecimalsRejectFormatter({this.decimalDigits = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // ว่างได้
    if (text.isEmpty) return newValue;

    // ตรงตามรูปแบบ: ตัวเลข (อาจมีจุด) + ทศนิยมไม่เกิน decimalDigits
    final reg = RegExp(r'^\d*\.?\d{0,' + decimalDigits.toString() + r'}$');
    if (reg.hasMatch(text)) {
      return newValue; // ยอมรับโดยไม่แก้สตริง => caret ไม่เด้ง
    }
    // ถ้าเกินเงื่อนไข ให้ “ปฏิเสธ” โดยคงค่าเดิมไว้
    return oldValue;
  }
}
class MaxMoneyRejectFormatter extends TextInputFormatter {
  final double max;
  MaxMoneyRejectFormatter({required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;

    // normalize ให้พาร์สได้เสมอ
    String toParse = t;
    if (toParse == '.') {
      toParse = '0.0';
    } else if (toParse.startsWith('.')) {
      toParse = '0$toParse';       // ".5" -> "0.5"
    } else if (toParse.endsWith('.')) {
      toParse = '${toParse}0';     // "100." -> "100.0"
    }

    final parsed = double.tryParse(toParse);
    if (parsed == null) return newValue; // ปล่อยผ่านให้ formatter ตัวอื่นคุมรูปแบบ

    // เกินเพดาน => ปฏิเสธ (คงค่าเดิม)
    if (parsed > max) return oldValue;

    return newValue;
  }
}


class MemberPaymentCard extends StatefulWidget {
  final ExpendDetailResult member;
  final double initialExtraAmount;
  final ValueChanged<double> onExtraChanged;

  const MemberPaymentCard({
    super.key,
    required this.member,
    required this.onExtraChanged,
    this.initialExtraAmount = 0.0,
  });

  @override
  State<MemberPaymentCard> createState() => _MemberPaymentCardState();
}

class _MemberPaymentCardState extends State<MemberPaymentCard> {
  bool _collectMore = false;
  late TextEditingController _extraController;

  @override
  void initState() {
    super.initState();
    // ตั้งค่าเริ่มต้นครั้งเดียว
    _collectMore = widget.initialExtraAmount > 0;
    _extraController = TextEditingController(
      // ถ้า 0 ให้เว้นว่าง เพื่อไม่ให้มี ".0" โผล่มากวน
      text: widget.initialExtraAmount > 0
          ? widget.initialExtraAmount.toString()
          : '',
    );
  }

  // ✅ ลบ didUpdateWidget ที่เขียนทับ controller.text ทุกครั้งทิ้งไป
  // เพราะมันทำให้เคอร์เซอร์เด้งและแปลงเป็น 1.0

  @override
  void dispose() {
    _extraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final info = m.member;
    final imageUrl = (info?.memberImage?.isNotEmpty ?? false)
        ? '$baseURL/images/${info!.memberImage}'
        : null;

    final fullName = '${info?.firstName ?? ''} ${info?.lastName ?? ''}'.trim().isEmpty
        ? (info?.email ?? '')
        : '${info?.firstName ?? ''} ${info?.lastName ?? ''}';

    final activityCount = m.activities.length;
    final fmt = NumberFormat("#,##0.00", "en_US");

    final status = m.extraPaymentStatus.toLowerCase();
    final double pendingExtra = status == 'pending' ? m.unpaidExtraAmount : 0.0;

    // ยอดที่กำลังกรอกรอบนี้
    final extraAmount = _collectMore
        ? double.tryParse(_extraController.text.isEmpty ? '0' : _extraController.text) ?? 0.0
        : 0.0;

    // รวมใหม่ (อ้างอิง balance เดิม + เรียกเพิ่มรอบนี้) — ไม่รวมค้างเก่า
    final total = m.balance + extraAmount;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('จำนวนกิจกรรม: $activityCount'),
                    ],
                  ),
                ),
                Text(
                  '฿${fmt.format(m.balance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: m.balance < 0 ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // กล่องแจ้งยอดค้างชำระจากการเรียกเก็บก่อนหน้า
            if (pendingExtra > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ค้างชำระจากก่อนหน้า: ฿${fmt.format(pendingExtra)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text(
                      'ยังไม่ชำระ',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // ช่องกรอกเรียกเก็บเพิ่มรอบนี้
            Row(
              children: [
                Checkbox(
                  value: _collectMore,
                  onChanged: (value) {
                    setState(() {
                      _collectMore = value ?? false;
                      if (!_collectMore) {
                        _extraController.text = '';
                        widget.onExtraChanged(0);
                      }
                    });
                  },
                ),
                const Text('เก็บเพิ่ม'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _extraController,
                    enabled: _collectMore,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                     FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  // จำกัดทศนิยมไม่เกิน 2 ตำแหน่ง (แบบปฏิเสธ ไม่ทำให้ caret เด้ง)
  TwoDecimalsRejectFormatter(decimalDigits: 2),
  // ❗คุมเพดานไม่เกิน 100,000 บาท
  MaxMoneyRejectFormatter(max: 100000.0),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '฿0.00',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final val = double.tryParse(value.isEmpty ? '0' : value) ?? 0.0;
                      widget.onExtraChanged(val);
                      setState(() {}); // อัปเดตยอดรวมด้านล่าง
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // สรุปด้านล่าง
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'เรียกเก็บเพิ่มรอบนี้: ฿${fmt.format(extraAmount)}   ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text('รวม ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '฿${fmt.format(total)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: total < 0 ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
