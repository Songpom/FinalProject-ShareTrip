import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finalproject/controller/membercontroller.dart';
import 'package:finalproject/screens/home.dart';
import 'package:finalproject/screens/RegisterScreen.dart';
import 'package:finalproject/styles/appcolors.dart';
import 'package:finalproject/styles/textstyle.dart';
import 'package:finalproject/boxs/userlog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.flashMessage}); // 👈 เพิ่ม flashMessage
  final String? flashMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  late TabController _tabController;
  bool _obscure = true;

  String? _formError;
  String? _flash; // เก็บข้อความจาก Register

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _flash = widget.flashMessage; // รับข้อความ flash
  }

  String? _validateLoginEmail(String? v) {
    if (v == null || v.isEmpty) return 'กรุณากรอกอีเมล';
    if (v.contains(' ')) return 'ห้ามมีช่องว่าง';
    if (v.length < 5 || v.length > 50) return 'ความยาว 5–50 ตัวอักษร';
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(v)) {
      return 'อีเมลต้องเป็นภาษาอังกฤษและตัวเลข 0–9 เท่านั้น';
    }
    final email = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    if (!email.hasMatch(v)) return 'กรุณากรอกอีเมลให้ถูกต้อง';
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

  Future<void> _handleLogin() async {
    setState(() => _formError = null);

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _formError = 'กรุณากรอกข้อมูลให้ถูกต้อง');
      return;
    }

    final result = await MemberController().doLogin(
      emailCtrl.text.trim(),
      passwordCtrl.text,
    );

    if (!mounted) return;
    if (result['status'] == 'ok') {
      UserLog().email = emailCtrl.text.trim();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      final msg = (result['message'] ?? '').toString();
      setState(() {
        _formError = msg.isEmpty ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.asset('assets/images/logo.png', height: 130),
              ),
              const SizedBox(height: 12),

              // ✅ Flash message
              if (_flash != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF6DD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _flash!,
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _flash = null),
                      ),
                    ],
                  ),
                ),

              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE6EAF0), width: 1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.tabSelected,
                  labelColor: AppColors.tabSelected,
                  unselectedLabelColor: AppColors.tabUnselected,
                  tabs: const [Tab(text: 'เข้าสู่ระบบ'), Tab(text: 'สมัครสมาชิก')],
                  onTap: (i) {
                    if (i == 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                      _tabController.index = 0;
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _input(
                      controller: emailCtrl,
                      hint: 'อีเมล',
                      icon: Icons.email_outlined,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9@._%+\-]')),
                        LengthLimitingTextInputFormatter(50),
                      ],
                      validator: _validateLoginEmail,
                      onChanged: (_) => setState(() => _formError = null),
                    ),
                    const SizedBox(height: 12),
                    _input(
                      controller: passwordCtrl,
                      hint: 'รหัสผ่าน',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.hintText,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9!#_.]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      validator: _validatePassword,
                      onChanged: (_) => setState(() => _formError = null),
                    ),
                    const SizedBox(height: 12),
                    if (_formError != null)
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          _formError!,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 255, 162, 1),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _handleLogin,
                        child: const Text('เข้าสู่ระบบ', style: KTextStyle.button),
                      ),
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

  // ===== UI helper =====
  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: KTextStyle.input,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.hintText),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: KTextStyle.hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
