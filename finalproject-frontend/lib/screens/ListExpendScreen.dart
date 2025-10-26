import 'package:finalproject/model/trip.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finalproject/controller/expendcontroller.dart';
import 'package:finalproject/model/expenddetailresult.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/screens/AttachPaymentSlipScreen.dart';
import 'package:finalproject/screens/RequestExtraPaymentScreen.dart';
import 'package:finalproject/screens/ViewActivityDetailScreen.dart';
import 'package:finalproject/boxs/userlog.dart';

class ListExpendScreen extends StatefulWidget {
  final Trip trip;

  const ListExpendScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<ListExpendScreen> createState() => _ListExpendScreenState();
}

class _ListExpendScreenState extends State<ListExpendScreen> {
  String get userEmail => UserLog().email;

  late Future<List<ExpendDetailResult>> _futureMembers;
  late ExpendController _expendController;

  bool get isOwner {
    final memberTrips = widget.trip.memberTrips ?? [];
    return memberTrips.any((mt) =>
        mt.participant?.email == userEmail &&
        (mt.memberTripStatus?.toLowerCase() ?? '') == 'owner');
  }

  Future<void> _refreshAll() async {
    final f = _expendController.getCheckStatusMemberTrip(widget.trip.tripId!);
    setState(() {
      _futureMembers = f;
    });
    await f;
  }

  bool get isTripEndedStatus =>
      (widget.trip.tripStatus ?? '').trim() == 'ทริปสิ้นสุด';

  Set<String> get _allowedMemberEmails {
    final m = widget.trip.memberTrips ?? [];
    return m
        .where((mt) {
          final status = (mt.memberTripStatus ?? '').toLowerCase();
          return status == 'owner' || status == 'participant';
        })
        .map((mt) => (mt.participant?.email ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  @override
  void initState() {
    super.initState();
    _expendController = ExpendController();
    _futureMembers = _expendController.getCheckStatusMemberTrip(widget.trip.tripId!);
  }

  void reloadData() {
    setState(() {
      _futureMembers = _expendController.getCheckStatusMemberTrip(widget.trip.tripId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปค่าใช้จ่าย'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6FA),

      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: FutureBuilder<List<ExpendDetailResult>>(
          future: _futureMembers,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                ],
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('ไม่มีข้อมูลสมาชิก')),
                ],
              );
            }

            final allowedMembers = snapshot.data!
                .where((mb) => _allowedMemberEmails.contains(mb.member?.email ?? ''))
                .toList();

            if (allowedMembers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('ไม่มีผู้เข้าร่วมที่เป็น owner หรือ participant')),
                ],
              );
            }

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'จำนวนคน: ${allowedMembers.length} คน',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allowedMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final member = allowedMembers[index];
                      return MemberCard(
                        member: member,
                        tripId: widget.trip.tripId!,
                        userEmail: userEmail,
                      );
                    },
                  ),
                ),

                if (isOwner && !isTripEndedStatus)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RequestExtraPaymentScreen(
                                members: allowedMembers,
                                tripId: widget.trip.tripId!,
                              ),
                            ),
                          );
                          if (result == true) {
                            await _refreshAll();
                          }
                        },
                        icon: const Icon(Icons.payment, color: Colors.white),
                        label: const Text(
                          'เรียกเก็บเงิน',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  final ExpendDetailResult member;
  final int tripId;
  final String userEmail;

  const MemberCard({
    Key? key,
    required this.member,
    required this.tripId,
    required this.userEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final memberInfo = member.member;
    final isCurrentUser = (memberInfo?.email == userEmail);
    final balance = member.balance;

    // ฟอร์แมตรูปแบบเงิน 2 ตำแหน่ง + คอมม่า
    final moneyFmt = NumberFormat("#,##0.00", "th_TH");

    Color statusColor;
    String statusText;
    Color statusBgColor;

    if (balance < 0) {
      statusColor = const Color(0xFFFF6B35);
      statusBgColor = const Color(0xFFFFEDE8);
      statusText = 'รอการชำระ';
    } else if (balance == 0) {
      statusColor = const Color(0xFF4CAF50);
      statusBgColor = const Color(0xFFE8F5E8);
      statusText = 'ชำระแล้ว';
    } else {
      statusColor = const Color(0xFF2196F3);
      statusBgColor = const Color(0xFFE3F2FD);
      statusText = 'เครดิต';
    }

    // จำนวนเงินแสดง 2 ตำแหน่ง:
    // - ถ้าติดลบ (ต้องจ่าย) ให้แสดงเป็นค่าบวกของยอดที่ค้าง (ตามพฤติกรรมเดิม)
    String balanceText;
    if (balance < 0) {
      balanceText = '฿${moneyFmt.format(-balance)}';
    } else if (balance == 0) {
      balanceText = '฿${moneyFmt.format(0)}';
    } else {
      balanceText = '฿${moneyFmt.format(balance)}';
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 2)),
                  child: ClipOval(
                    child: (memberInfo?.memberImage != null && memberInfo!.memberImage!.isNotEmpty)
                        ? Image.network('$baseURL/images/${memberInfo.memberImage}', fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(Icons.person, size: 28, color: Colors.grey))
                        : const Icon(Icons.person, size: 28, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${memberInfo?.firstName ?? ''} ${memberInfo?.lastName ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('จำนวนกิจกรรม: ${member.activities.length}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(12)),
                      child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      balanceText,
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: balance < 0 ? const Color(0xFFFF6B35) : balance == 0 ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
                if (isCurrentUser && member.extraPaymentStatus.toLowerCase() == "pending") ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44, height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttachPaymentSlipScreen(
                              tripId: tripId,
                              memberTripId: member.memberTripId,
                            ),
                          ),
                        );
                        if (result == true) {
                          final parentState = context.findAncestorStateOfType<_ListExpendScreenState>();
                          parentState?.reloadData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Icon(Icons.payment, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(Icons.list_alt, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text('ดูรายละเอียดกิจกรรม',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                  ],
                ),
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: member.activities.map((activity) {
                        final formattedDate = DateFormat('dd/MM/yyyy').format(activity.activityDate);
                        final priceText = moneyFmt.format(activity.pricePerPerson); // ⬅️ 2 ตำแหน่ง
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ViewActivityDetailScreen(activityId: activity.activityId),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(activity.activityName,
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('วันที่: $formattedDate',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Text('฿$priceText',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
