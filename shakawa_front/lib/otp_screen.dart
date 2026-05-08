import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_menu_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'constants.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  // 🛠️ التعديل الأول: الطريقة الحديثة للـ Key
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String _verificationId = "";

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  // 🚀 دالة إرسال الـ SMS
  Future<void> _sendOtp() async {
    String phone = widget.phoneNumber.trim();
    if (phone.startsWith('0')) {
      phone = '+20${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      phone = '+20$phone';
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          _goToMainScreen();
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          _showSnackBar(
            "فشل إرسال الكود: {}".tr(args: [e.message.toString()]),
            Colors.red,
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
          _showSnackBar("تم إرسال كود التفعيل بنجاح 📩".tr(), Colors.green);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint("Error sending OTP: $e");
    }
  }

  // 🚀 دالة التحقق من الكود
  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      _showSnackBar("الكود لازم يكون 6 أرقام".tr(), Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return; // 🛡️ حماية الـ Async

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        _showNameDialog(user);
      } else {
        _goToMainScreen();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("OTP Verification Error: ${e.message}");
       if (!mounted) return;
      _showSnackBar("الكود غير صحيح، راجع الرسالة تاني".tr(), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNameDialog(User user) {
    final nameController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          "أهلاً بك! ما هو اسمك؟".tr(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "اكتب اسمك هنا".tr(),
            hintStyle: const TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await user.updateDisplayName(nameController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  _goToMainScreen();
                }
              }
            },
            child: Text(
              "حفظ ودخول".tr(),
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

void _goToMainScreen() async {
    // ✅ أضف الـ sync قبل الانتقال
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
        try {
            final prefs = await SharedPreferences.getInstance();
            var response = await http.post(
                Uri.parse("${AppConfig.apiUrl}/shakawa_api/sync_user.php"),
                headers: {"ngrok-skip-browser-warning": "true"},
                body: {
                    "firebase_uid": user.uid,
                    "email": user.email ?? "",
                    "full_name": user.displayName ?? "مستخدم جديد",
                    "phone": user.phoneNumber ?? "",
                },
            );
            var data = jsonDecode(response.body);
            if (data['customer_id'] != null && data['customer_id'] != 0) {
                await prefs.setInt('customer_id', data['customer_id']);
            }
        } catch (e) {
            debugPrint("Sync error: $e");
        }
    }
    if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainMenuScreen()),
            (route) => false,
        );
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          "تأكيد رقم الهاتف".tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.message_outlined, size: 80, color: theme.primaryColor),
              const SizedBox(height: 20),
              Text(
                "أدخل كود التفعيل".tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "بعتنالك رسالة فيها 6 أرقام على الرقم: {}".tr(
                  args: [widget.phoneNumber],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: TextStyle(
                  fontSize: 24,
                  letterSpacing: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "تأكيد الدخول".tr(),
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
