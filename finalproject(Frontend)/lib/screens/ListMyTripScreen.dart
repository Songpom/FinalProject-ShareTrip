import 'dart:convert'; // <-- เพิ่มเพื่อ decode JSON
import 'package:flutter/material.dart';
import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/model/trip.dart';
import 'package:finalproject/model/membertrip.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/screens/ViewTripDetailScreen.dart';
import 'package:finalproject/screens/EditTripScreen.dart';
import 'package:finalproject/boxs/userlog.dart';
import 'package:finalproject/screens/ListRefundMemberScreen.dart';
import 'package:finalproject/screens/ViewRefundPaymentScreen.dart';

// แถบล่าง + FAB ร่วมกัน
import 'package:finalproject/widgets/app_shell.dart';

class ListMyTripScreen extends StatefulWidget {
  @override
  _ListMyTripScreenState createState() => _ListMyTripScreenState();
}

class _ListMyTripScreenState extends State<ListMyTripScreen>
    with TickerProviderStateMixin {
  String? userEmail;
  List<Trip> _allTrips = [];
  String _selectedStatus = 'ทั้งหมด';
  bool _initialLoading = true;

  Future<void> _refreshAll() async {
    await _loadTrips();
  }

  @override
  void initState() {
    super.initState();
    userEmail = UserLog().email;
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      if (userEmail != null && userEmail!.isNotEmpty) {
        final trips = await TripController().getListMyTrip(userEmail!);
        trips.sort((a, b) =>
            (b.startDate ?? DateTime.now()).compareTo(a.startDate ?? DateTime.now()));
        setState(() {
          _allTrips = trips;
          _initialLoading = false;
        });
      } else {
        setState(() {
          _allTrips = [];
          _initialLoading = false;
        });
      }
    } catch (e) {
      setState(() => _initialLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดทริปล้มเหลว: $e')),
        );
      }
    }
  }

  bool _joinedThisTrip(Trip trip) {
    final me = userEmail;
    if (me == null || me.isEmpty) return false;
    final myMt = trip.memberTrips?.firstWhere(
      (m) => m.participant?.email == me,
      orElse: () => MemberTrip(),
    );
    final status = (myMt?.memberTripStatus ?? '').toLowerCase();
    return status == 'participant' || status == 'owner';
  }

  int _joinedCount(Trip trip) {
    return (trip.memberTrips ?? [])
        .where((m) {
          final s = (m.memberTripStatus ?? '').toLowerCase();
          return s == 'owner' || s == 'participant';
        })
        .length;
  }

  String calculateStatus(Trip trip) {
    final now = DateTime.now();
    final DateTime rawStart = (trip.startDate ?? now).toLocal();
    final DateTime rawEnd = (trip.dueDate ?? rawStart).toLocal();
    final DateTime startOfDay = DateTime(rawStart.year, rawStart.month, rawStart.day);
    final DateTime endOfDay =
        DateTime(rawEnd.year, rawEnd.month, rawEnd.day, 23, 59, 59, 999);

    if (now.isBefore(startOfDay)) {
      return 'ยังไม่เริ่ม';
    } else if (now.isAfter(endOfDay)) {
      return 'จบแล้ว';
    } else {
      return 'กำลังดำเนิน';
    }
  }

  List<Trip> _filteredTrips() {
    final visible = _allTrips.where(_joinedThisTrip).toList();
    return visible.where((trip) {
      final status = calculateStatus(trip);
      if (_selectedStatus == 'ทั้งหมด') return true;
      return status == _selectedStatus;
    }).toList();
  }

  // ---------- แปลง location (JSON -> ชื่อ/ที่อยู่สั้น ๆ) ----------
  String _prettyLocation(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    // พยายามแปลงเป็น JSON ก่อน
    try {
      final data = jsonDecode(raw);
      if (data is Map) {
        final name = (data['name'] ?? '').toString().trim();
        final addr = (data['address'] ?? '').toString().trim();
        if (name.isNotEmpty && addr.isNotEmpty) {
          // ถ้าชื่อกับที่อยู่เหมือนกันก็โชว์อย่างใดอย่างหนึ่ง
          if (name.toLowerCase() == addr.toLowerCase()) return name;
          return '$name, $addr';
        }
        if (name.isNotEmpty) return name;
        if (addr.isNotEmpty) return addr;
      }
    } catch (_) {
      // ไม่ใช่ JSON → ปล่อยให้เป็นสตริงเดิม
    }
    return raw;
  }

  void _onEditSuccess() async {
    await _loadTrips();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('อัปเดตสำเร็จ'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      ),
    );
  }

  Future<void> _confirmDelete(Trip trip) async {
    // กันพลาด: ถ้าทริปสิ้นสุดแล้ว หรือมีผู้เข้าร่วมแล้ว (participant >= 1) ห้ามลบ
    final bool isEnded = ((trip.tripStatus ?? '').trim() == 'ทริปสิ้นสุด') ||
        (calculateStatus(trip) == 'จบแล้ว');
    final bool hasParticipants = (trip.memberTrips ?? []).any(
      (m) => (m.memberTripStatus ?? '').toLowerCase() == 'participant',
    );

    if (isEnded || hasParticipants) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEnded
                  ? 'ไม่สามารถลบทริปที่สิ้นสุดแล้วได้'
                  : 'ไม่สามารถลบทริปที่มีผู้เข้าร่วมแล้วได้',
            ),
          ),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบทริป'),
        content: Text('คุณต้องการลบทริป "${trip.tripName ?? '-'}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await TripController().doRemoveTrip(trip.tripId!);
      if (!mounted) return;
      Navigator.of(context).pop();

      final status = (result['status'] as String?) ?? '';
      final needRefund =
          status == 'need_refund' || result['hasOtherParticipants'] == true;

      if (needRefund) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListRefundMemberScreen(tripId: trip.tripId!),
          ),
        );
        _loadTrips();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบทริปสำเร็จ')),
        );
        _loadTrips();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบทริปไม่สำเร็จ: $e')),
      );
    }
  }

  // ---------- UI Helpers ----------
  PreferredSizeWidget _segmentedTabs(List<String> tabs) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: TabBar(
            onTap: (index) => setState(() => _selectedStatus = tabs[index]),
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey[600],
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(child: _SegItem(icon: Icons.filter_list_rounded, text: 'ทั้งหมด')),
              Tab(child: _SegItem(icon: Icons.play_arrow_rounded, text: 'กำลังดำเนิน')),
              Tab(child: _SegItem(icon: Icons.check_rounded, text: 'จบแล้ว')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['ทั้งหมด', 'กำลังดำเนิน', 'จบแล้ว'];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'ทริปของฉัน',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
          bottom: _segmentedTabs(tabs),
          actions: [
            IconButton(
              tooltip: 'รีเฟรช',
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

        body: RefreshIndicator(
          onRefresh: _refreshAll,
          child: _initialLoading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : _filteredTrips().isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flight_takeoff, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'ไม่มีรายการแผนการท่องเที่ยวของคุณ',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: _filteredTrips().length,
                      itemBuilder: (context, index) {
                        final trip = _filteredTrips()[index];
                        return GestureDetector(
                          onTap: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ViewTripDetailScreen(trip: trip)),
                            );
                            if (changed == true) _loadTrips();
                          },
                          child: _buildTripCard(trip),
                        );
                      },
                    ),
        ),

        bottomNavigationBar: AppShell.bottomNav(context: context, currentIndex: 1),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: AppShell.fab(context: context, onRefresh: _loadTrips),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final imageUrl = (trip.image != null && trip.image!.isNotEmpty)
        ? '$baseURL/images/${trip.image}'
        : 'https://via.placeholder.com/80x80?text=No+Image';

    final dynamicStatus = calculateStatus(trip);
    final tripStatus = (trip.tripStatus ?? '').trim();
    final bool isTripEndedStatus = tripStatus == 'ทริปสิ้นสุด';

    final ownerEmail = trip.memberTrips
        ?.firstWhere((m) => m.memberTripStatus == 'owner', orElse: () => MemberTrip())
        .participant
        ?.email;

    final bool amOwner = (userEmail != null && userEmail == ownerEmail);

    // มีผู้เข้าร่วมอย่างน้อย 1 คน (ไม่นับ owner)
    final bool hasParticipants = (trip.memberTrips ?? []).any(
      (m) => (m.memberTripStatus ?? '').toLowerCase() == 'participant',
    );

    // สี/ข้อความสถานะ (ด้านขวา)
    Color statusColor;
    String statusText;
    if (dynamicStatus == 'จบแล้ว' || isTripEndedStatus) {
      statusColor = const Color(0xFF22C55E); // green-500
      statusText = 'จบแล้ว';
    } else if (dynamicStatus == 'กำลังดำเนิน') {
      statusColor = const Color(0xFF0EA5E9); // sky-500
      statusText = 'กำลังดำเนิน';
    } else {
      statusColor = const Color(0xFFF59E0B); // amber-500
      statusText = 'ยังไม่เริ่ม';
    }

    final joined = _joinedCount(trip);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // รูป
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey[200],
                  child: Icon(Icons.image, color: Colors.grey[400]),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // เนื้อหา
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อทริป + สถานะทางขวา
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          trip.tripName ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // <<< ชื่อ/ที่อยู่แบบอ่านง่าย >>>
                  Text(
                    _prettyLocation(trip.location),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    trip.startDate != null && trip.dueDate != null
                        ? 'วันที่ ${_formatDate(trip.startDate!)} - ${_formatDate(trip.dueDate!)}'
                        : '-',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 10),

                  // ปุ่ม/ชิปด้านล่าง
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // ผู้เข้าร่วม
                      _chipButton(
                        label: '$joined คน',
                        icon: Icons.people_alt_rounded,
                        bg: const Color(0xFFEFF6FF), // blue-50
                        fg: const Color(0xFF0EA5E9), // sky-500
                        onTap: null,
                      ),

                      // แก้ไข (เฉพาะ owner และยังไม่สิ้นสุด)
                      if (amOwner && !isTripEndedStatus)
                        _chipButton(
                          label: 'แก้ไข',
                          icon: Icons.settings,
                          bg: Colors.grey[100]!,
                          fg: Colors.black87,
                          onTap: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditTripScreen(tripId: trip.tripId!),
                              ),
                            );
                            if (updated == true) _onEditSuccess();
                          },
                        ),

                      // ลบ (เฉพาะ owner, ทริปยังไม่สิ้นสุด และยังไม่มีผู้เข้าร่วม)
                      if (amOwner && !isTripEndedStatus && !hasParticipants)
                        _chipButton(
                          label: 'ลบ',
                          icon: Icons.delete_forever_rounded,
                          bg: const Color(0xFFFEE2E2), // red-100
                          fg: const Color(0xFFDC2626), // red-600
                          onTap: () => _confirmDelete(trip),
                        ),

                      // คืนเงิน/ดูหลักฐาน
                      _buildActionButton(trip, amOwner, isTripEndedStatus),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipButton({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Trip trip, bool amOwner, bool isTripEndedStatus) {
    late String label;
    late Color bg;
    late Color fg;
    VoidCallback? action;

    // หมายเหตุ: ปุ่ม "คืนเงิน/ดูหลักฐาน" ไม่เกี่ยวกับการลบทริป
    if (isTripEndedStatus) {
      if (amOwner) {
        label = 'คืนแล้ว';
        bg = const Color(0xFFD1FAE5); // green-100
        fg = const Color(0xFF059669); // green-600
        action = () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListRefundMemberScreen(tripId: trip.tripId!),
            ),
          );
          if (mounted) await _loadTrips();
        };
      } else {
        label = 'ดูหลักฐาน';
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        action = () async {
          final email = UserLog().email;
          if (email == null || email.isEmpty) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewRefundPaymentScreen(
                tripId: trip.tripId!,
                email: email,
              ),
            ),
          );
        };
      }
    } else {
      if (amOwner) {
        label = 'คืนเงิน';
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        action = () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListRefundMemberScreen(tripId: trip.tripId!),
            ),
          );
          if (mounted) await _loadTrips();
        };
      } else {
        label = 'ดูหลักฐาน';
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        action = () async {
          final email = UserLog().email;
          if (email == null || email.isEmpty) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewRefundPaymentScreen(
                tripId: trip.tripId!,
                email: email,
              ),
            ),
          );
        };
      }
    }

    return _chipButton(
      label: label,
      icon: Icons.receipt_long,
      bg: bg,
      fg: fg,
      onTap: action,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}-${_monthShort(date.month)}';
  }

  String _monthShort(int month) {
    const months = [
      'ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.',
      'ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'
    ];
    return months[month - 1];
  }
}

class _SegItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SegItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
