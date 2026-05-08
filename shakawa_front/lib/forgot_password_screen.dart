import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class ForgotPasswordScreen extends StatefulWidget {
  // 🛠️ التعديل الأول: الطريقة الحديثة للـ Key
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    // 🛡️ التعديل الثاني: Regex أكثر دقة ومعيارية
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );

    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      _showSnackBar(
        "يرجى إدخال بريد إلكتروني بصيغة صحيحة (مثال: name@mail.com)".tr(),
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 سطر الكود السحري من فايربيز
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return; // 🛡️ حماية الـ Async

      _showSnackBar(
        "تم إرسال رابط استعادة كلمة المرور للإيميل بتاعك 📩".tr(),
        Colors.green,
      );

      // نرجعه لشاشة اللوجين بعد ثانية عشان يلحق يقرأ السناك بار
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMsg = "حدث خطأ: {}".tr(args: [e.message.toString()]);
      if (e.code == 'user-not-found') {
        errorMsg = "عفواً، هذا البريد غير مسجل لدينا.".tr();
      }
      _showSnackBar(errorMsg, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🛠️ التعديل الثالث: استدعاء الثيم مرة واحدة للأداء
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          "استعادة كلمة المرور".tr(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_reset, size: 100, color: theme.primaryColor),
              const SizedBox(height: 20),
              Text(
                "نسيت كلمة المرور؟".tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "اكتب إيميلك اللي سجلت بيه، وهنبعتلك رابط تعمل منه باسورد جديد."
                    .tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "البريد الإلكتروني".tr(),
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "إرسال الرابط".tr(),
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
    );
  }
}
