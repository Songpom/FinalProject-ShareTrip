import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/activity.dart';
import '../controller/activitycontroller.dart';
import 'AddActivityScreen.dart';
import 'ViewActivityDetailScreen.dart';
import 'EditActivityScreen.dart';
import 'package:finalproject/constant/constant_value.dart';

import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/model/trip.dart';

import 'package:finalproject/boxs/userlog.dart';
import 'package:collection/collection.dart';

class ListActivityScreen extends StatefulWidget {
  final Trip trip;

  const ListActivityScreen({super.key, required this.trip});

  @override
  State<ListActivityScreen> createState() => _ListActivityScreenState();
}

class _ListActivityScreenState extends State<ListActivityScreen> {
  final ActivityController _activityController = ActivityController();
  final TripController _tripController = TripController();
  final NumberFormat _moneyFmt = NumberFormat("#,##0.00", "th_TH");


  List<Activity> activities = [];

  // meta สำหรับควบคุมสิทธิ์และสถานะทริป
  bool _metaLoading = true;
  bool _isOwner = false;
  bool _isTripEnded = false;

  String get _userEmail => UserLog().email;

  @override
  void initState() {
    super.initState();
    _loadMetaAndData();
  }

  Future<void> _loadMetaAndData() async {
    await Future.wait([_loadTripMeta(), loadActivities()]);
  }
Future<void> _refreshAll() async {
  await _loadMetaAndData(); // โหลดทั้ง meta + activities ใหม่
}

  Future<void> _loadTripMeta() async {
    try {
      final Trip? latest = await _tripController.getTripDetail(widget.trip.tripId!);
      final Trip trip = latest ?? widget.trip;

      // หา owner
      final ownerTrip = trip.memberTrips
          ?.firstWhereOrNull((m) => (m.memberTripStatus ?? '').toLowerCase() == 'owner');
      final ownerEmail = ownerTrip?.participant?.email;

      setState(() {
        _isOwner = (ownerEmail != null && ownerEmail == _userEmail);
        _isTripEnded = (trip.tripStatus ?? '').trim() == 'ทริปสิ้นสุด';
        _metaLoading = false;
      });
    } catch (e) {
      // ถ้าโหลด meta พลาด จะซ่อนปุ่มจัดการไว้ก่อน
      setState(() {
        _isOwner = false;
        _isTripEnded = false;
        _metaLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลทริปล้มเหลว: $e')),
        );
      }
    }
  }

  Future<void> loadActivities() async {
    try {
      final result = await _activityController.getListActivity(widget.trip.tripId!);
      if (!mounted) return;
      setState(() {
        activities = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดกิจกรรมล้มเหลว: $e')),
      );
    }
  }

  Future<void> _confirmDeleteActivity(int activityId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.warning, color: Color.fromARGB(255, 0, 0, 0), size: 48),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบรายการนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _activityController.doRemoveActivity(activityId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบกิจกรรมเรียบร้อย')),
        );
        await loadActivities();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบกิจกรรมล้มเหลว: $e')),
        );
      }
    }
  }
Widget buildActivityCard(Activity activity, int index) {
  final canManage = _isOwner && !_isTripEnded; // เฉพาะ owner และทริปยังไม่สิ้นสุด
  final price = activity.activityPrice ?? 0;                       // ป้องกัน null
  final priceText = _moneyFmt.format(price);                       // ฟอร์แมต 2 ตำแหน่ง

  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewActivityDetailScreen(activityId: activity.activityId ?? 0),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // รูปกิจกรรม
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CircleAvatar(
              radius: 30,
              backgroundImage: (activity.imagePaymentActivity != null &&
                      activity.imagePaymentActivity!.isNotEmpty)
                  ? NetworkImage('$baseURL/images/${activity.imagePaymentActivity}')
                  : null,
              child: (activity.imagePaymentActivity == null ||
                      activity.imagePaymentActivity!.isEmpty)
                  ? const Icon(Icons.image_not_supported)
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // ชื่อกิจกรรม + ราคา
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityName ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'ค่าใช้จ่าย: ฿$priceText บาท',           // << ใช้ทศนิยม 2 ตำแหน่ง
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // ปุ่มลบ/แก้ไข — แสดงทุกแถว (ถ้า canManage เป็นจริง)
          if (canManage)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final id = activity.activityId;
                    if (id != null) _confirmDeleteActivity(id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff00cfff),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("ลบ"),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () async {
                    final id = activity.activityId;
                    if (id == null) return;
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditActivityScreen(
                          activityId: id,
                          tripId: widget.trip.tripId!,
                        ),
                      ),
                    );
                    if (result == true) {
                      await loadActivities();
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    ),
  );
}



@override
Widget build(BuildContext context) {
  final canAdd = _isOwner && !_isTripEnded;

  return Scaffold(
    backgroundColor: const Color(0xfff4faff),
    appBar: AppBar(
      title: const Text('รายการกิจกรรม'),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context, true),
      ),
      actions: [
        IconButton(
          tooltip: 'รีเฟรช',
          onPressed: () => _refreshAll(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ปุ่มเพิ่มกิจกรรม (ซ่อนถ้าไม่ใช่ owner หรือทริปสิ้นสุด)
          if (!_metaLoading && canAdd)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddActivityScreen(tripId: widget.trip.tripId!),
                    ),
                  );
                  if (result == true) {
                    await loadActivities();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text("เพิ่มกิจกรรมใหม่"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff00cfff),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ),

          // พื้นที่รายการ + ลากรีเฟรช
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: (activities.isEmpty)
                  // กรณีว่าง/กำลังโหลด: ให้เป็น ListView เพื่อจะ “ลากลง” ได้
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      children: [
                        if (_metaLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          const Center(
                            child: Text(
                              'ไม่พบข้อมูลรายการกิจกรรม',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        return buildActivityCard(activities[index], index);
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

}
