import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfileScreen extends StatefulWidget {
  // 🛠️ التعديل الأول: Super parameter
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? "";
    _phoneController.text = user?.phoneNumber ?? "";
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      if (_nameController.text.trim() != user?.displayName) {
        await user?.updateDisplayName(_nameController.text.trim());
      }

      // 🛡️ حماية الـ Async Gap
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // 🛠️ التعديل التاني: ترجمة النص نفسه قبل ما يدخل الـ Text
          content: Text("تم تحديث البيانات بنجاح ✅".tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return; // 🛡️ حماية هنا كمان
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("حدث خطأ أثناء التحديث: {}".tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛠️ التعديل التالت: سحب الثيم عشان نظبط الألوان للدارك واللايت مود
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey : Colors.black54;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "حسابي".tr(),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  // 🛠️ التعديل الرابع: withValues
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.blueAccent,
                        )
                      : null,
                ),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 30),

            TextFormField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "الاسم بالكامل".tr(),
                labelStyle: TextStyle(color: hintColor),
                prefixIcon: Icon(Icons.person_outline, color: hintColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              initialValue: user?.email ?? "لا يوجد بريد إلكتروني".tr(),
              enabled: false,
              style: TextStyle(color: hintColor),
              decoration: InputDecoration(
                labelText: "البريد الإلكتروني".tr(),
                labelStyle: TextStyle(color: hintColor),
                prefixIcon: Icon(Icons.email_outlined, color: hintColor),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🛠️ التعديل الخامس: قفلنا حقل التليفون عشان ميديوش إيحاء كاذب إنه هيتغير
            TextFormField(
              controller: _phoneController,
              enabled: false,
              style: TextStyle(color: hintColor),
              decoration: InputDecoration(
                labelText: "رقم الهاتف".tr(),
                labelStyle: TextStyle(color: hintColor),
                prefixIcon: Icon(Icons.phone_android, color: hintColor),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "حفظ التعديلات".tr(),
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
    );
  }
}
