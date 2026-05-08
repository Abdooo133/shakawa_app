import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_menu_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class SignUpScreen extends StatefulWidget {
  final String initialEmail;
  // 🛠️ التعديل الأول: الطريقة الحديثة للـ Key
  const SignUpScreen({super.key, this.initialEmail = ""});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  // 🚀 دالة إنشاء الحساب
  Future<void> _registerUser() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty) {
      _showSnackBar("يرجى استكمال كل البيانات".tr(), Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. إنشاء الحساب في فايربيز
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 🛡️ حماية الـ Async: نأكد إن الشاشة لسه موجودة قبل ما نحدث الاسم
      if (!mounted) return;

      // 2. تحديث اسم المستخدم
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;

      // 3. التوجيه النهائي
      _showSnackBar("تم إنشاء الحساب بنجاح! 🎉".tr(), Colors.green);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainMenuScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = "حدث خطأ أثناء إنشاء الحساب".tr();
      if (e.code == 'weak-password') {
        errorMessage = "كلمة المرور ضعيفة جداً، لازم 6 حروف أو أرقام على الأقل."
            .tr();
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "البريد الإلكتروني ده متسجل بيه حساب قبل كده.".tr();
      }
      _showSnackBar(errorMessage, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // 🛠️ التعديل الثاني: القراءة من الثيم أوتوماتيك
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "إنشاء حساب جديد".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "سجل بياناتك وانضم لينا عشان نتابع شكوتك".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                _buildTextField(
                  _nameController,
                  "الاسم بالكامل".tr(),
                  Icons.person,
                  theme,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _phoneController,
                  "رقم الهاتف".tr(),
                  Icons.phone,
                  theme,
                  isPhone: true,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _emailController,
                  "البريد الإلكتروني".tr(),
                  Icons.email_outlined,
                  theme,
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: "كلمة المرور (6 أحرف/أرقام على الأقل)".tr(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "إنشاء الحساب".tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    ThemeData theme, {
    bool isPhone = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.emailAddress,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
