import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finalproject/controller/membercontroller.dart';
import 'package:finalproject/screens/LoginScreen.dart';
import 'package:finalproject/styles/appcolors.dart';
import 'package:finalproject/styles/textstyle.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // รูปสำหรับพรีวิวทันที
  Uint8List? _avatarBytes;

  // ไฟล์หลังครอป (ไว้ส่ง backend)
  File? selectedImage;

  bool _imageError = false;
  String? _imageErrorText;

  final CropController _cropController = CropController();

  // ฟิลด์ฟอร์ม
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  final promptpayController = TextEditingController();

  String? _emailServerError;
  final FocusNode _emailFocus = FocusNode();
  String? _formError;

  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =============== Validators ===============
  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'กรุณากรอกอีเมล';
    if (v.contains(' ')) return 'ห้ามมีช่องว่าง';
    if (v.length < 5 || v.length > 50) return 'ความยาว 5–50 ตัวอักษร';
    final email = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    if (!email.hasMatch(v)) return 'กรุณากรอกอีเมลให้ถูกต้อง';
    if (_emailServerError != null) return _emailServerError;
    return null;
  }

  String? _validateUsername(String? v) {
    if (v == null || v.isEmpty) return 'กรุณากรอก username';
    if (v.contains(' ')) return 'ห้ามมีช่องว่าง';
    if (!RegExp(r'^[A-Za-z0-9]{4,8}$').hasMatch(v)) {
      return 'username ต้องเป็นอักษรภาษาอังกฤษหรือตัวเลข 4–8 ตัว';
    }
    return null;
  }

  String? _validateName(String? v, String label) {
    if (v == null || v.isEmpty) return 'กรุณากรอก$label';
    final re = RegExp(r'^[A-Za-z\u0E01-\u0E2E\u0E30-\u0E3A\u0E40-\u0E44\u0E47-\u0E4E\s]{2,50}$');
    if (!re.hasMatch(v)) return '$label ต้องเป็นไทย/อังกฤษ 2–50 ตัว';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (v.contains(' ')) return 'ห้ามมีช่องว่าง';
    if (!RegExp(r'^[A-Za-z0-9!#_.]{8,16}$').hasMatch(v)) {
      return 'ใช้ A–Z a–z 0–9 และ ! # _ . ความยาว 8–16 ตัว';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) return 'กรุณากรอกหมายเลขโทรศัพท์';
    if (!RegExp(r'^0[689]\d{8}$').hasMatch(v)) {
      return 'ต้องขึ้นต้น 06,08,09 และยาว 10 หลัก';
    }
    return null;
  }

  String? _validatePromptPay(String? v) {
    if (v == null || v.isEmpty) return 'กรุณากรอกหมายเลข promptpay';
    if (RegExp(r'^\d{10}$').hasMatch(v)) {
      if (!RegExp(r'^0[689]\d{8}$').hasMatch(v)) {
        return 'เบอร์ PromptPay ต้องขึ้นต้น 06, 08 หรือ 09';
      }
      return null;
    }
    if (RegExp(r'^\d{13}$').hasMatch(v)) return null;
    return 'ต้องเป็น 10 หลัก (มือถือ) หรือ 13 หลัก (บัตร ปชช.)';
  }

  // =============== Pick & Crop ===============
  Future<void> _chooseAndCrop() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final okExt = RegExp(r'\.(jpe?g|png)$', caseSensitive: false);
    if (!okExt.hasMatch(picked.name)) {
      setState(() {
        _imageError = true;
        _imageErrorText = 'กรุณาเลือกรูป .jpg .jpeg หรือ .png';
      });
      return;
    }

    final bytes = await picked.readAsBytes();
    _openCropper(bytes);
  }

  void _openCropper(Uint8List bytes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 480,
          height: 520,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text('ครอปรูปโปรไฟล์', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Crop(
                    controller: _cropController,
                    image: bytes,
                    aspectRatio: 1,       // ครอปจัตุรัส
                    withCircleUi: true,   // UI วงกลม (ผลลัพธ์ยัง 1:1)
                    onCropped: (CropResult res) async {
                      try {
                        if (res is CropSuccess) {
                          final Uint8List cropped = res.croppedImage;

                          // ปิด dialog ก่อน
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }

                          if (!mounted) return;
                          // อัปเดตพรีวิวจากหน่วยความจำ
                          setState(() {
                            _avatarBytes = cropped;
                            _imageError = false;
                            _imageErrorText = null;
                          });

                          // เขียนไฟล์ชั่วคราวไว้ส่ง backend
                          final file = await _writeTempFile(cropped, 'profile_cropped.jpg');
                          if (!mounted) return;
                          setState(() {
                            selectedImage = file; // <- สำคัญ
                          });
                        } else if (res is CropFailure) {
                          final cause = res.cause;
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ครอปล้มเหลว: $cause')),
                          );
                        }
                      } catch (e) {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ครอปล้มเหลว: $e')),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('ยกเลิก'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _cropController.crop(); // trigger
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('ตกลง'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // เขียนไฟล์ชั่วคราว (มี fallback กันพังถ้า path_provider ยังไม่พร้อม)
  Future<File> _writeTempFile(Uint8List bytes, String name) async {
    try {
      final dir = await getTemporaryDirectory(); // path_provider
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      // fallback: ไม่พึ่งปลั๊กอิน
      final file = File('${Directory.systemTemp.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    }
  }

  // =============== Submit ===============
  Future<void> _registerMember() async {
    setState(() => _formError = null);

    final formOK = _formKey.currentState?.validate() ?? false;
    if (selectedImage == null) {
      setState(() {
        _imageError = true;
        _imageErrorText = 'จำเป็นต้องอัปโหลดรูปโปรไฟล์';
      });
    }
    if (!formOK || selectedImage == null) {
      setState(() => _formError = 'กรุณากรอกข้อมูลสมัครสมาชิกให้ถูกต้อง');
      return;
    }
    

    try {
      final result = await MemberController().doRegister(
        usernameController.text.trim(),
        passwordController.text,
        firstNameController.text.trim(),
        lastNameController.text.trim(),
        emailController.text.trim(),
        selectedImage!, // ส่งไฟล์ที่ครอปแล้ว
        phoneController.text.trim(),
        promptpayController.text.trim(),
      );

      if (!mounted) return;
      if (result['status'] == 'ok') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen(flashMessage: 'สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบด้วยอีเมลและรหัสผ่านของคุณ')),
        );
      } else {
        final msg = (result['message'] ?? '').toString();
        final code = result['code'] ?? 0;

        if (code == 409 || msg.contains('อีเมลนี้มีอยู่แล้ว')) {
          setState(() => _emailServerError = 'อีเมลนี้มีอยู่แล้ว');
          _formKey.currentState?.validate();
          _emailFocus.requestFocus();
          return;
        }

        setState(() => _formError = msg.isEmpty ? 'สมัครไม่สำเร็จ' : msg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = 'เกิดข้อผิดพลาด: $e');
    }
  }

  // =============== UI ===============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/logo.png', height: 120),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color.fromARGB(255, 255, 255, 255))),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.tabSelected,
                labelColor: AppColors.tabSelected,
                unselectedLabelColor: AppColors.tabUnselected,
                tabs: const [Tab(text: 'เข้าสู่ระบบ'), Tab(text: 'สมัครสมาชิก')],
                onTap: (i) {
                  if (i == 0) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 20),
            _avatarPicker(),
            const SizedBox(height: 6),
            if (_imageError)
              Align(
                alignment: Alignment.center,
                child: Text(
                  _imageErrorText ?? 'จำเป็นต้องอัปโหลดรูปโปรไฟล์',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(
                    label: 'username',
                    hint: 'กรุณากรอก username',
                    controller: usernameController,
                    icon: Icons.person_outline,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    validator: _validateUsername,
                    onChanged: (_) => setState(() => _formError = null),
                  ),
                  _field(
                    label: 'อีเมล',
                    hint: 'กรุณากรอกอีเมล',
                    controller: emailController,
                    icon: Icons.alternate_email,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._%+\-]')),
                      LengthLimitingTextInputFormatter(50),
                    ],
                    validator: _validateEmail,
                    focusNode: _emailFocus,
                    onChanged: (_) {
                      if (_emailServerError != null) setState(() => _emailServerError = null);
                      setState(() => _formError = null);
                    },
                  ),
                  _field(
                    label: 'ชื่อ',
                    hint: 'กรุณากรอกชื่อจริง',
                    controller: firstNameController,
                    icon: Icons.badge_outlined,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\u0E01-\u0E2E\u0E30-\u0E3A\u0E40-\u0E44\u0E47-\u0E4E\s]')),
                      LengthLimitingTextInputFormatter(50),
                    ],
                    validator: (v) => _validateName(v, 'ชื่อ'),
                    onChanged: (_) => setState(() => _formError = null),
                  ),
                  _field(
                    label: 'นามสกุล',
                    hint: 'กรุณากรอกนามสกุล',
                    controller: lastNameController,
                    icon: Icons.badge,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\u0E01-\u0E2E\u0E30-\u0E3A\u0E40-\u0E44\u0E47-\u0E4E\s]')),
                      LengthLimitingTextInputFormatter(50),
                    ],
                    validator: (v) => _validateName(v, 'นามสกุล'),
                    onChanged: (_) => setState(() => _formError = null),
                  ),
                  _field(
                    label: 'รหัสผ่าน',
                    hint: 'กรุณากรอกรหัสผ่าน',
                    controller: passwordController,
                    icon: Icons.lock_outline,
                    obscure: _obscure1,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.hintText,
                      ),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9!#_.]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    validator: _validatePassword,
                    onChanged: (_) => setState(() => _formError = null),
                  ),
                  _field(
                    label: 'ยืนยันรหัสผ่าน',
                    hint: 'กรุณายืนยันรหัสผ่าน',
                    controller: confirmPasswordController,
                    icon: Icons.lock_person_outlined,
                    obscure: _obscure2,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.hintText,
                      ),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9!#_.]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    validator: (v) {
                      final base = _validatePassword(v);
                      if (base != null) return base;
                      if (v != passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
                      return null;
                    },
                    onChanged: (_) => setState(() => _formError = null),
                  ),
                  _field(
                    label: 'หมายเลขโทรศัพท์',
                    hint: 'กรุณากรอกหมายเลขโทรศัพท์',
                    controller: phoneController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: _validatePhone,
                    onChanged: (_) => setState(() => _formError = null),
                  ),
                  _field(
                    label: 'หมายเลข promptpay',
                    hint: 'กรุณากรอกหมายเลข promptpay',
                    controller: promptpayController,
                    icon: Icons.qr_code_2_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    validator: _validatePromptPay,
                    onChanged: (_) => setState(() => _formError = null),
                  ),
                  const SizedBox(height: 6),
                  if (_formError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formError!,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 255, 162, 1),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _registerMember,
                      child: const Text('สมัครสมาชิก', style: KTextStyle.button),
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

  // ===== Avatar picker (พรีวิววงกลม + ปุ่มเล็กตรงมุม) =====
  Widget _avatarPicker() {
    const double radius = 56;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.inputBackground,
              backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
              child: (_avatarBytes == null)
                  ? Icon(Icons.person_outline, size: radius, color: Colors.grey[500])
                  : null,
            ),
            SizedBox(
              width: 36,
              height: 36,
              child: FloatingActionButton(
                heroTag: 'pick-avatar',
                elevation: 0,
                backgroundColor: Colors.white,
                onPressed: _chooseAndCrop,
                child: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _avatarBytes == null ? 'แตะกล้องเพื่อเพิ่มรูป' : 'แตะกล้องเพื่อเปลี่ยนรูป',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              style: KTextStyle.label,
              children: [
                TextSpan(text: label),
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            obscureText: obscure,
            style: KTextStyle.input,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.hintText),
              suffixIcon: suffix,
              hintText: hint,
              hintStyle: KTextStyle.hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
