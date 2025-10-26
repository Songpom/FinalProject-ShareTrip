import 'package:flutter/material.dart';
import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/model/trip.dart';
import 'package:finalproject/model/membertrip.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/screens/ViewTripDetailScreen.dart';
import 'package:finalproject/screens/ListActivityScreen.dart';
import 'package:finalproject/screens/PaymentForJoinScreen.dart';
import 'package:finalproject/boxs/userlog.dart';
import 'package:finalproject/screens/LoginScreen.dart';

// ใช้แถบล่าง/ปุ่มเพิ่มร่วมกัน
import 'package:finalproject/widgets/app_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ชุดข้อมูลเต็ม + ชุดที่ถูกกรองแล้ว
  List<Trip> _allTrips = [];
  List<Trip> trips = [];

  bool isLoading = true;
  final TripController _tripController = TripController();

  // ค้นหา (เหลือแค่ช่องเดียว)
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserTrips();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchUserTrips() async {
    try {
      final email = UserLog()?.email;
      if (email == null) {
        setState(() {
          _allTrips = [];
          trips = [];
          isLoading = false;
        });
        return;
      }
      final data = await _tripController.getListMyTrip(email);

      // เรียงจาก startDate ล่าสุดก่อน
      data.sort((a, b) => (b.startDate ?? DateTime(1900))
          .compareTo(a.startDate ?? DateTime(1900)));

      setState(() {
        _allTrips = data;
        isLoading = false;
      });
      _applyFilter(); // กรองตาม query ปัจจุบัน
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<Trip> result;

    if (q.isEmpty) {
      result = List<Trip>.from(_allTrips);
    } else {
      final numQuery = double.tryParse(q); // ถ้าเป็นตัวเลข → ใช้เป็นงบไม่เกิน

      result = _allTrips.where((t) {
        final name = (t.tripName ?? '').toLowerCase();
        final detail = (t.tripDetail ?? '').toLowerCase();
        final matchText = name.contains(q) || detail.contains(q);

        if (numQuery != null) {
          final budget = t.budget ?? 0.0;
          final matchBudget = budget <= numQuery;
          // จับคู่ถ้าอย่างใดอย่างหนึ่งตรง (เผื่อผู้ใช้พิมพ์ “2000 เขาหลวง” ก็ยังควรมีผล)
          return matchText || matchBudget;
        }
        return matchText;
      }).toList();
    }

    // เรียงอีกครั้งหลังกรอง
    result.sort((a, b) => (b.startDate ?? DateTime(1900))
        .compareTo(a.startDate ?? DateTime(1900)));

    setState(() {
      trips = result;
    });
  }

  bool _isJoined(String? s) {
    final v = (s ?? '').toLowerCase();
    return v == 'owner' || v == 'participant';
  }

  bool _isInvited(String? s) {
    final v = (s ?? '').toLowerCase();
    return v == 'invited' || v == 'invite';
  }

  MemberTrip? _myMemberTrip(Trip trip) {
    final myEmail = UserLog()?.email;
    if (trip.memberTrips == null || myEmail == null) return null;
    for (final m in trip.memberTrips!) {
      if (m.participant?.email == myEmail) return m;
    }
    return null;
  }

  void joinTrip(BuildContext context, Trip trip) async {
    final result = await _tripController.getPaymentDetail(
      email: UserLog().email,
      tripId: trip.tripId!,
    );
    final status = (result['status'] ?? '').toString().toLowerCase();
    if (status == 'success' || status == 'ok') {
      final Trip t = result['trip'];
      final String qr = result['qrcode'];
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentForJoinScreen(
            fee: t.budget ?? 0,
            qrCodeBase64: qr,
            tripName: t.tripName ?? '',
            tripId: t.tripId!,
          ),
        ),
      );
      if (ok == true) fetchUserTrips();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเข้าร่วมทริปได้: ${result['message']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const hint = 'ค้นหาทริป, สถานที่ (รายละเอียด)';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('ค้นหาทริป',
              style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              UserLog().clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ช่องค้นหาอย่างเดียว
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: (_searchCtrl.text.isEmpty)
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilter();
                            setState(() {}); // ซ่อนปุ่มเคลียร์
                          },
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => _applyFilter(),
              ),
            ),

Expanded(
  child: RefreshIndicator(
    onRefresh: fetchUserTrips, // ลากลงแล้วรีเฟรช
    child: isLoading
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: CircularProgressIndicator()),
            ],
          )
        : trips.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'ไม่พบทริปที่ตรงเงื่อนไข',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  final imageUrl = (trip.image != null && trip.image!.isNotEmpty)
                      ? '$baseURL/images/${trip.image}'
                      : 'https://via.placeholder.com/400x180?text=No+Image';

                  final joined = trip.memberTrips
                          ?.where((m) => _isJoined(m.memberTripStatus))
                          .length ??
                      0;
                  final total = trip.memberTrips
                          ?.where((m) =>
                              _isJoined(m.memberTripStatus) ||
                              _isInvited(m.memberTripStatus))
                          .length ??
                      0;
                  final countText = '$joined/$total คน';

                  final myStatus =
                      _myMemberTrip(trip)?.memberTripStatus?.toLowerCase();
                  final alreadyJoined = _isJoined(myStatus);
                  final canJoin = !alreadyJoined;

                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewTripDetailScreen(trip: trip),
                        ),
                      );
                      if (result == true) fetchUserTrips();
                    },
                    child: _buildTripCard(
                      imageUrl: imageUrl,
                      title: trip.tripName ?? 'ไม่มีชื่อทริป',
                      desc: trip.tripDetail ?? '-',
                      date:
                          'วันที่ ${trip.startDate?.day ?? '-'} / ${trip.startDate?.month ?? '-'} - ${trip.dueDate?.day ?? '-'} / ${trip.dueDate?.month ?? '-'}',
                      memberCount: countText,
                      actionButton: alreadyJoined
                          ? ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListActivityScreen(trip: trip),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: const Color(0xFF4FC3F7), // light blue

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text('รายละเอียดกิจกรรม', style: TextStyle(color: Colors.white),),
                            )
                          : (canJoin
                              ? ElevatedButton(
                                  onPressed: () => joinTrip(context, trip),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    minimumSize: const Size(0, 36),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: const Color.fromARGB(255, 115, 251, 122), 
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                   child: const Text(
    'Join Trip',
    style: TextStyle(color: Color.fromARGB(255, 30, 113, 3)), // ✅ ตัวหนังสือสีขาว
  ),
                                )
                              : const SizedBox.shrink()),
                    ),
                  );
                },
              ),
  ),
)

          ],
        ),
      ),

      // แถบล่างและปุ่มรีเฟรช
      bottomNavigationBar: AppShell.bottomNav(context: context, currentIndex: 0),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AppShell.fab(context: context, onRefresh: fetchUserTrips),
    );
  }

  Widget _buildTripCard({
    required String imageUrl,
    required String title,
    required String desc,
    required String date,
    required String memberCount,
    required Widget actionButton,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: Colors.grey.shade300,
                child: const Center(
                    child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        memberCount,
                        style: const TextStyle(
                            color: Color(0xFF00B4F1), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                          minHeight: 36, maxHeight: 36, maxWidth: 160),
                      child: FittedBox(fit: BoxFit.scaleDown, child: actionButton),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
