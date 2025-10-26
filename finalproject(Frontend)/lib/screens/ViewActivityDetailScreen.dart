import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finalproject/model/activity.dart';
import 'package:finalproject/controller/activitycontroller.dart';
import 'package:finalproject/constant/constant_value.dart'; // import baseURL

class ViewActivityDetailScreen extends StatefulWidget {
  final int activityId;

  const ViewActivityDetailScreen({Key? key, required this.activityId})
    : super(key: key);

  @override
  State<ViewActivityDetailScreen> createState() => _ViewActivityDetailScreenState();
}

class _ViewActivityDetailScreenState extends State<ViewActivityDetailScreen> {
  final ActivityController _activityController = ActivityController();
  Activity? _activity;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      final activity = await _activityController.getActivityDetail(
        widget.activityId,
      );
      setState(() {
        _activity = activity;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('โหลดกิจกรรมล้มเหลว: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
    if (_activity == null)
      return const Scaffold(
        body: Center(child: Text("ไม่พบข้อมูลกิจกรรม")),
      );

    // แก้ไขเวลาโดยลบ 7 ชั่วโมง
    final correctedDateTime = _activity!.activityDateTime!.subtract(const Duration(hours: 7));
    final dateFormat = DateFormat('dd ก.ค. yyyy - HH:mm');
    final dateStr = dateFormat.format(correctedDateTime);
    final total = _activity!.activityPrice?.toStringAsFixed(2) ?? "0.00";

    final imageUrl = (_activity!.imagePaymentActivity != null && _activity!.imagePaymentActivity!.isNotEmpty)
      ? '$baseURL/images/${_activity!.imagePaymentActivity}'
      : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "กิจกรรมการเดินทาง",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "กิจกรรม",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Activity Card
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                          ),
                          child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.image, color: Colors.grey),
                                  );
                                },
                              )
                            : const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activity!.activityName ?? '-',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "ค่าใช้จ่าย ${_activity!.activityPrice?.toStringAsFixed(2) ?? "0.00"} บาท",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 8,
              color: Colors.grey.shade100,
            ),

            // Details Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "รายละเอียดกิจกรรม",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _activity!.activityDetail ?? '-',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              height: 8,
              color: Colors.grey.shade100,
            ),

            // Image Section - Full Width
            if (imageUrl != null)
              Container(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Divider
            Container(
              height: 8,
              color: Colors.grey.shade100,
            ),

            // Summary Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Summary",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Member list
                  ...?_activity!.memberTripActivity?.map((mta) {
                    final participantName = 
                      '${mta.memberTrip?.participant?.firstName ?? ''} ${mta.memberTrip?.participant?.lastName ?? ''}'.trim();
                    final price = mta.pricePerPerson ?? 0.0;
                    
                    // Get avatar URL
                    final avatarUrl = (mta.memberTrip?.participant?.memberImage != null && 
                                      mta.memberTrip!.participant!.memberImage!.isNotEmpty)
                        ? '$baseURL/images/${mta.memberTrip!.participant!.memberImage}'
                        : null;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: avatarUrl != null 
                                ? NetworkImage(avatarUrl) 
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    participantName.isNotEmpty 
                                        ? participantName.characters.first.toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              participantName.isEmpty ? '-' : participantName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            "฿${price.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ยอดรวม",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "฿${total.split('.')[0]}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom spacing
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}