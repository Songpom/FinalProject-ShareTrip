// lib/screens/ViewTripDetailScreen.dart
// หน้ารายละเอียดทริป — แสดงชื่อสถานที่ตัวหนา + ที่อยู่บรรทัดถัดไป และแตะเพื่อเปิด TripMapPage

import 'dart:convert';
import 'package:finalproject/boxs/userlog.dart';
import 'package:finalproject/screens/ListActivityScreen.dart';
import 'package:finalproject/screens/ListExpendScreen.dart';
import 'package:flutter/material.dart';
import 'package:finalproject/model/trip.dart';
import 'package:intl/intl.dart';
import 'package:finalproject/model/membertrip.dart';
import 'package:finalproject/constant/constant_value.dart';
import 'package:finalproject/screens/PaymentForJoinScreen.dart';
import 'package:finalproject/controller/tripcontroller.dart';
import 'package:finalproject/screens/CheckPaymentJoinScreen.dart';
import 'package:finalproject/screens/tripmappage.dart';

class ViewTripDetailScreen extends StatefulWidget {
  final Trip trip;
  const ViewTripDetailScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<ViewTripDetailScreen> createState() => _ViewTripDetailScreenState();
}

class _ViewTripDetailScreenState extends State<ViewTripDetailScreen> {
  late Trip trip;
  final String userEmail = UserLog().email;
  final TripController _tripController = TripController();

  final _moneyFmt = NumberFormat('#,##0.00');
  final _intFmt = NumberFormat('#,##0');

  // Longdo JS Key (สำหรับ TripMapPage)
  static const String _longdoJsKey = '2fda6462e44be22918f1bb3e1fc8dc79';

  @override
  void initState() {
    super.initState();
    trip = widget.trip;
  }

  Future<void> reloadTripData() async {
    final detail = await _tripController.getTripDetail(trip.tripId!);
    if (!mounted) return;
    if (detail != null) setState(() => trip = detail);
  }

  Future<void> _joinTrip(BuildContext context) async {
    final result = await _tripController.getPaymentDetail(
      email: userEmail,
      tripId: trip.tripId!,
    );

    final status = (result['status'] ?? '').toString().toLowerCase();

    // ฟรี (ไม่มี qrcode)
    if (status == 'ok' || status == 'free' || (result['qrcode'] == null)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'เข้าร่วมสำเร็จ (ไม่ต้องชำระเงิน)')),
      );
      await reloadTripData();
      return;
    }

    // ต้องชำระเงิน (มี qrcode)
    if (status == 'success') {
      final Trip joinedTrip = result['trip'];
      final String qrCodeBase64 = result['qrcode'];

      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentForJoinScreen(
            fee: joinedTrip.budget ?? 0,
            qrCodeBase64: qrCodeBase64,
            tripName: joinedTrip.tripName ?? '',
            tripId: joinedTrip.tripId!,
          ),
        ),
      );

      if (paymentResult == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ชำระเงินสำเร็จ')),
        );
        await reloadTripData();
      }
      return;
    }

    // ผิดพลาด
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ไม่สามารถเข้าร่วมทริปได้: ${result['message'] ?? 'Unknown error'}')),
    );
  }

  bool get _isOwner {
    final owner = trip.memberTrips?.firstWhere(
      (m) => (m.memberTripStatus ?? '').toLowerCase() == 'owner',
      orElse: () => MemberTrip(),
    );
    return owner?.participant?.email == userEmail;
  }

  bool _isJoinedStatus(String? s) {
    final v = (s ?? '').toLowerCase();
    return v == 'owner' || v == 'participant';
  }

  bool _validImg(String? name) {
    if (name == null) return false;
    final v = name.trim().toLowerCase();
    return v.isNotEmpty && v != 'a' && v != 'null' && v.contains('.');
  }

  // ---------- Location helpers ----------
  // แยก name / address จาก trip.location ที่อาจเป็น JSON {id,name,address,lat,lon} หรือสตริงธรรมดา
  String get _locName {
    final raw = trip.location ?? '';
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        final name = (m['name'] ?? '').toString().trim();
        final addr = (m['address'] ?? '').toString().trim();
        // ถ้าไม่มี name ให้ใช้ address เป็นชื่อแทน
        if (name.isNotEmpty) return name;
        if (addr.isNotEmpty) return addr;
      }
    } catch (_) {}
    return raw.isNotEmpty ? raw : '-';
  }

  String get _locAddress {
    final raw = trip.location ?? '';
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        final addr = (m['address'] ?? '').toString().trim();
        return addr;
      }
    } catch (_) {}
    // กรณีเป็นสตริงธรรมดา ให้ไม่ซ้ำกับชื่อ: ไม่แสดง address
    return '';
  }

  Map<String, double>? get _latLonFromLocation {
    try {
      final m = jsonDecode(trip.location ?? '') as Map<String, dynamic>;
      final lat = (m['lat'] as num?)?.toDouble();
      final lon = (m['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return {'lat': lat, 'lon': lon};
    } catch (_) {
      return null;
    }
  }

  void _openTripMap() {
    final pos = _latLonFromLocation;
    final title = _locName.isEmpty ? (trip.tripName ?? 'แผนที่') : _locName;

    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ทริปนี้ยังไม่มีพิกัด (lat/lon)')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripMapPage(
          lat: pos['lat']!,
          lon: pos['lon']!,
          title: title,
          longdoJsKey: _longdoJsKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerImageUrl = (trip.image != null && trip.image!.isNotEmpty)
        ? '$baseURL/images/${trip.image}'
        : 'https://via.placeholder.com/600x280?text=No+Image';

    final organizer = trip.memberTrips?.firstWhere(
      (m) => (m.memberTripStatus ?? '').toLowerCase() == 'owner',
      orElse: () => MemberTrip(),
    );

    final participants = trip.memberTrips
            ?.where((m) => (m.memberTripStatus ?? '').toLowerCase() == 'participant')
            .toList() ??
        [];

    final isAlreadyJoined = trip.memberTrips?.any((m) =>
            m.participant?.email == userEmail && _isJoinedStatus(m.memberTripStatus)) ??
        false;

    final joinedCount =
        trip.memberTrips?.where((m) => _isJoinedStatus(m.memberTripStatus)).length ?? 0;

    final perPerson = trip.budget ?? 0;
    final totalAmount = perPerson * joinedCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'ทริปท่องเที่ยว',
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero Image
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Image.network(
              headerImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, color: Colors.white70, size: 64),
              ),
            ),
          ),

          // Content
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trip Name
                Text(
                  trip.tripName ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trip.tripDetail ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),

                // Budget
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'งบประมาณที่คาดการณ์',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${_intFmt.format(perPerson)} บาท/คน',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF00BCD4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Location (กดเพื่อเปิดแผนที่) — ชื่อ(ตัวหนา) + ที่อยู่(บรรทัดล่าง)
                InkWell(
                  onTap: _openTripMap,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ชื่อ — ตัวหนา
                            Text(
                              _locName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // ที่อยู่ — บรรทัดล่าง (ถ้ามี)
                            if (_locAddress.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _locAddress,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.map_outlined, color: Colors.blueGrey),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Total Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ยอดรวม',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${_intFmt.format(totalAmount)} บาท',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF00BCD4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Organizer
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ผู้จัดตั้ง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                if (organizer != null && organizer.participant != null)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: _validImg(organizer.participant?.memberImage)
                            ? NetworkImage(
                                '$baseURL/images/${organizer.participant!.memberImage}')
                            : null,
                        child: !_validImg(organizer.participant?.memberImage)
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        organizer.participant?.username ?? 'ไม่ทราบชื่อ',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'ไม่พบผู้จัดตั้ง',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Participants
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    'ผู้เข้าร่วม',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (participants.isNotEmpty)
                  ...participants.map((memberTrip) {
                    final member = memberTrip.participant;
                    final img = member?.memberImage;
                    final hasImg = _validImg(img);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: hasImg
                                ? NetworkImage('$baseURL/images/$img')
                                : null,
                            child: !hasImg
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              member?.username ?? 'ไม่ทราบชื่อ',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (_isOwner || userEmail == member?.email)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BCD4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  final id = memberTrip.memberTripId;
                                  if (id != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CheckPaymentJoinScreen(memberTripId: id),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('ไม่พบข้อมูลสมาชิกในทริป')),
                                    );
                                  }
                                },
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList()
                else
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'ยังไม่มีผู้เข้าร่วม',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Bottom Buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
            backgroundColor: isAlreadyJoined
                ? const Color(0xFF00BCD4)                  // ✅ ฟ้าเหมือนปุ่มสรุปค่าใช้จ่าย
                : const Color.fromARGB(255, 115, 251, 122),// ✅ เขียวอ่อน
            foregroundColor: isAlreadyJoined
                ? Colors.white                             // รายละเอียดกิจกรรม = ขาว
                : const Color.fromARGB(255, 30, 113, 3), 
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      if (isAlreadyJoined) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ListActivityScreen(trip: trip),
                          ),
                        );
                      } else {
                        await _joinTrip(context);
                      }
                    },
                    child: Text(
                      isAlreadyJoined ? 'รายละเอียดกิจกรรม' : 'เข้าร่วมทริป',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                if (isAlreadyJoined)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListExpendScreen(trip: trip),
                            ),
                          );
                        },
                        child: const Text(
                          'รายละเอียดค่าใช้จ่าย',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
