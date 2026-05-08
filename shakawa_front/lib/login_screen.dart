import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import 'main_menu_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


class LoginScreen extends StatefulWidget {
  // 🛠️ التعديل الأول: الطريقة الحديثة للـ Key
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // 🛡️ دالة مزامنة المستخدم مع MySQL (Backend Integration)
  Future<void> syncUserToMysql(User user) async {
    try {
      var response = await http
          .post(
            Uri.parse("${AppConfig.apiUrl}/shakawa_api/sync_user.php"),
                        headers: {"ngrok-skip-browser-warning":"true"},

            body: {
              "firebase_uid": user.uid,
              "email": user.email ?? "",
              "full_name": user.displayName ?? "مستخدم جديد".tr(),
              "phone": user.phoneNumber ?? "",
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['customer_id'] != null && data['customer_id'] != 0) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setInt('customer_id', data['customer_id']);
          } 
        debugPrint("✅ تم ربط الحساب بقاعدة البيانات بنجاح");
      }
    } catch (e) {
      debugPrint("❌ فشل الربط بالسيرفر: $e");
    }
  }

  // 🔵 تسجيل الدخول بجوجل
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final google_auth.GoogleSignInAccount? googleUser =
          await google_auth.GoogleSignIn().signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final google_auth.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (mounted && userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainMenuScreen()),
        );
        await syncUserToMysql(userCredential.user!);
      }
    } catch (e) {
      debugPrint("فشل التسجيل بجوجل ❌: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("فشل تسجيل الدخول بجوجل: ${e.toString()}".tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟠 تسجيل الدخول بمايكروسوفت
  Future<void> _signInWithMicrosoft() async {
    setState(() => _isLoading = true);
    try {
      final provider = OAuthProvider('microsoft.com');
      final userCredential = await FirebaseAuth.instance.signInWithProvider(
        provider,
      );

      if (mounted && userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainMenuScreen()),
        );
        await syncUserToMysql(userCredential.user!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "فشل تسجيل الدخول بمايكروسوفت: {}".tr(args: [e.toString()]),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 دالة تسجيل الدخول اليدوي (إيميل أو هاتف)
  Future<void> _loginUser() async {
    String input = _emailOrPhoneController.text.trim();
    String password = _passwordController.text.trim();

    if (input.isEmpty || (input.contains('@') && password.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("يرجى إدخال البيانات المطلوبة".tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (input.contains('@')) {
        // تسجيل دخول بالإيميل
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainMenuScreen()),
          );
          await syncUserToMysql(FirebaseAuth.instance.currentUser!);
        }
      } else {
        // تحويل لرقم الهاتف والـ OTP
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(phoneNumber: input),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("الحساب غير مسجل.. جاري تحويلك لإنشاء حساب".tr()),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignUpScreen(initialEmail: input),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("حدث خطأ: ${e.message}".tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 100,
                  backgroundColor: Colors.transparent,
                  child: Image.asset(
                    'assets/main_icon.png',
                    width: 400,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "سجل دخولك لمتابعة شكاويك وحلها أسرع".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _emailOrPhoneController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: "البريد الإلكتروني أو رقم الهاتف".tr(),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: "كلمة المرور".tr(),
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

                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: Text("نسيت كلمة المرور؟".tr()),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "تسجيل الدخول".tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  children: [
                    const Expanded(child: Divider(thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "أو".tr(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(thickness: 1)),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBrandButton(
                      url:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                      onTap: () => _isLoading ? null : _signInWithGoogle(),
                    ),
                    const SizedBox(width: 20),
                    _buildBrandButton(
                      url:
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Microsoft_logo.svg/120px-Microsoft_logo.svg.png',
                      onTap: () => _isLoading ? null : _signInWithMicrosoft(),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "ليس لديك حساب؟".tr(),
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SignUpScreen(initialEmail: ""),
                        ),
                      ),
                      child: Text(
                        "إنشاء حساب جديد".tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandButton({required String url, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Image.network(
          url,
          width: 35,
          height: 35,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
        ),
      ),
    );
  }
}
