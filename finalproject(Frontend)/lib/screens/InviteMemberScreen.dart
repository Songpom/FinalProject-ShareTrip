import 'package:flutter/material.dart';
import 'package:finalproject/controller/membercontroller.dart';
import 'package:finalproject/model/membersearchresult.dart';
import 'package:finalproject/model/member.dart';
import 'package:finalproject/boxs/userlog.dart';
import 'package:finalproject/constant/constant_value.dart';

class InviteMemberScreen extends StatefulWidget {
  final int tripId;
  final List<dynamic> initialMembers;

  const InviteMemberScreen({
    super.key,
    required this.tripId,
    this.initialMembers = const [],
  });

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MemberController memberController = MemberController();

  List<MemberSearchResult> displayedMembers = [];
  bool isLoading = false;
  bool hasSearched = false;
  late final String _selfEmail;

  @override
  void initState() {
    super.initState();
    _selfEmail = (UserLog().email).trim();
    _loadInitialMembers();
  }

  void _loadInitialMembers() {
    if (widget.initialMembers.isNotEmpty) {
      final members = widget.initialMembers.map((item) {
        final Map<String, dynamic> memberMap =
            (item['member'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, v));

        // รองรับทั้ง memberImage และ member_image
        memberMap['memberImage'] ??= memberMap['member_image'];

        final member = Member.fromJson(memberMap);
        final String raw = item['status']?.toString().toLowerCase() ?? 'false';
        final bool invited = (raw == 'true');

        return MemberSearchResult(member: member, joined: invited);
      }).toList();

      setState(() {
        displayedMembers = _dedupeByEmail(members);
        hasSearched = false;
      });
    } else {
      setState(() {
        displayedMembers = [];
        hasSearched = false;
      });
    }
  }

  List<MemberSearchResult> _dedupeByEmail(List<MemberSearchResult> list) {
    final seen = <String>{};
    final result = <MemberSearchResult>[];
    for (final e in list) {
      final email = (e.member.email ?? '').toLowerCase().trim();
      if (email.isEmpty || seen.contains(email)) continue;
      if (_isSelf(email)) continue;
      seen.add(email);
      result.add(e);
    }
    return result;
  }

  Future<void> _refreshFromServer() async {
    setState(() => isLoading = true);
    try {
      final results =
          await memberController.getListMember('', widget.tripId);
      setState(() {
        displayedMembers = _dedupeByEmail(results);
        hasSearched = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      await _refreshFromServer();
      return;
    }

    setState(() {
      isLoading = true;
      hasSearched = true;
    });

    try {
      final results =
          await memberController.getListMember(keyword, widget.tripId);
      setState(() {
        displayedMembers = _dedupeByEmail(results);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _invite(String email) async {
    try {
      await memberController.doInviteMember(email, widget.tripId);

      setState(() {
        final i = displayedMembers.indexWhere(
          (e) =>
              (e.member.email ?? '').toLowerCase().trim() ==
              email.toLowerCase().trim(),
        );
        if (i != -1) {
          displayedMembers[i] = MemberSearchResult(
            member: displayedMembers[i].member,
            joined: true,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เชิญ $email เข้าทริปแล้ว')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
      );
    }
  }

  bool _isSelf(String? email) {
    if (email == null) return false;
    return email.toLowerCase().trim() == _selfEmail.toLowerCase().trim();
  }

  String _imageUrlFor(Member m) {
    final fileName = (m.memberImage ?? '').trim();
    if (fileName.isEmpty) {
      return 'https://via.placeholder.com/44x44?text=No+Image';
    }
    return '$baseURL/images/$fileName';
  }

  Widget _buildAvatar(Member m) {
    final imageUrl = _imageUrlFor(m);
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, err, __) {
            debugPrint('⚠️ Image load failed: $imageUrl err=$err');
            return Image.network(
              'https://via.placeholder.com/44x44?text=No+Image',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เชิญสมาชิก'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshFromServer,
            tooltip: 'โหลดสถานะล่าสุด',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหารายชื่อ',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('ค้นหา'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (displayedMembers.isEmpty)
              Text(hasSearched ? 'ไม่พบสมาชิกที่ค้นหา' : 'ไม่มีรายชื่อแนะนำ')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: displayedMembers.length,
                  itemBuilder: (context, index) {
                    final item = displayedMembers[index];
                    final member = item.member;
                    final email = (member.email ?? '').trim();
                    final isSelf = _isSelf(email);

                    return ListTile(
                      leading: _buildAvatar(member),
                      title: Text(
                        member.username ??
                            (email.isNotEmpty ? email : 'ไม่ระบุชื่อ'),
                      ),
                      subtitle: Text(
                        '${member.firstName ?? ''} ${member.lastName ?? ''}',
                      ),
                      trailing: isSelf
                          ? const SizedBox.shrink()
                          : (item.joined
                              ? const Text(
                                  'เชิญสำเร็จแล้ว',
                                  style: TextStyle(color: Colors.green),
                                )
                              : ElevatedButton(
                                  onPressed: () => _invite(email),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text('เชิญ'),
                                )),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
