import 'package:finalproject/model/tripsummaryresult.dart';
import 'package:flutter/material.dart';
import 'package:finalproject/controller/refundController.dart';
import 'package:finalproject/model/member.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/screens/RefundPaymentScreen.dart';
import 'package:intl/intl.dart';

class ListRefundMemberScreen extends StatefulWidget {
  final int tripId;

  const ListRefundMemberScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  _ListRefundMemberScreenState createState() => _ListRefundMemberScreenState();
}

class _ListRefundMemberScreenState extends State<ListRefundMemberScreen> {
  bool isLoading = true;
  String? errorMessage;
  late TripSummaryresult tripSummary;

  final RefundController _controller = RefundController();

  @override
  void initState() {
    super.initState();
    _loadTripSummary();
  }

  Future<void> _loadTripSummary() async {
    try {
      final data = await _controller.getMemberTrip(widget.tripId);
      setState(() {
        tripSummary = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ฟอร์แมตราคาทศนิยม 2 ตำแหน่ง + มีคอมม่า
    final moneyFmt = NumberFormat("#,##0.00", "th_TH");

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('สรุปการชำระเงิน')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('สรุปการชำระเงิน')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปการชำระเงิน'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tripSummary.tripName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              tripSummary.tripDetail,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดเงินรวม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('฿${moneyFmt.format(tripSummary.totalBalance())}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('ผู้จัดตั้ง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildOwner(moneyFmt),
            const SizedBox(height: 24),
            const Text('ผู้เข้าร่วม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: _buildParticipantsList(moneyFmt)),
          ],
        ),
      ),
    );
  }

  Widget _buildOwner(NumberFormat moneyFmt) {
    final owner = tripSummary.memberBalances.firstWhere(
      (mb) => mb.member.email == tripSummary.emailowner,
      orElse: () => MemberBalance.empty(),
    );

    if (owner.isEmpty) {
      return const Text('ไม่พบผู้จัดตั้ง');
    }

    final hasImage = owner.member.memberImage?.isNotEmpty ?? false;
    final imageUrl = hasImage ? '$baseURL/images/${owner.member.memberImage}' : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
        child: !hasImage ? const Icon(Icons.person) : null,
      ),
      title: Text(owner.member.email ?? '-'),
      trailing: Text('฿${moneyFmt.format(owner.balance)}'),
    );
  }

  Widget _buildParticipantsList(NumberFormat moneyFmt) {
    final participants = tripSummary.memberBalances
        .where((mb) => mb.member.email != tripSummary.emailowner)
        .toList();

    if (participants.isEmpty) {
      return const Center(child: Text('ยังไม่มีผู้เข้าร่วม'));
    }

    return ListView.separated(
      itemCount: participants.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final participant = participants[index];
        final hasImage = participant.member.memberImage?.isNotEmpty ?? false;
        final imageUrl = hasImage ? '$baseURL/images/${participant.member.memberImage}' : null;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
            child: !hasImage ? const Icon(Icons.person) : null,
          ),
          title: Text(participant.member.email ?? '-'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('฿${moneyFmt.format(participant.balance)}'),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final refreshed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RefundPaymentScreen(
                        memberTripId: participant.memberTripId!,
                      ),
                    ),
                  );
                  if (refreshed == true) {
                    _loadTripSummary();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Icon(Icons.payment, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }
}
