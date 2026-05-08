import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class SettingsScreen extends StatefulWidget {
  // 🛠️ التعديل الأول: الطريقة الحديثة للـ Key
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? "";
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      if (_nameController.text.trim() != user?.displayName) {
        await user?.updateDisplayName(_nameController.text.trim());

        // 🛡️ حماية الـ Async
        if (!mounted) return;

        setState(() {
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // 🛠️ التعديل التاني: ترجمة النص نفسه
            content: Text("تم تحديث الاسم بنجاح ✅".tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ: {}".tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    // 🛠️ التعديل التالت: استدعاء الثيم مرة واحدة عشان سرعة الأداء
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey : Colors.black54;
    final borderColor = isDark ? Colors.white24 : Colors.black26;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        title: Text(
          "الإعدادات".tr(),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "معلومات الحساب".tr(),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            TextFormField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              onChanged: (value) {
                setState(() {
                  _hasChanges = value.trim() != (user?.displayName ?? "");
                });
              },
              decoration: InputDecoration(
                labelText: "الاسم".tr(),
                labelStyle: TextStyle(color: hintColor),
                prefixIcon: Icon(Icons.person, color: hintColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.primaryColor),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),

            TextFormField(
              initialValue: user?.email ?? "لا يوجد بريد مرتبط".tr(),
              enabled: false,
              style: TextStyle(color: hintColor),
              decoration: InputDecoration(
                labelText: "البريد الإلكتروني".tr(),
                labelStyle: TextStyle(color: hintColor),
                prefixIcon: Icon(Icons.email, color: hintColor),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),

            if (_hasChanges)
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "حفظ التعديلات".tr(),
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ),

            const SizedBox(height: 30),
            Divider(color: borderColor),
            const SizedBox(height: 10),

            Text(
              "تخصيص التطبيق".tr(),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.dark_mode_outlined, color: textColor),
              title: Text(
                "مظهر التطبيق".tr(),
                style: TextStyle(color: textColor),
              ),
              trailing: DropdownButton<ThemeMode>(
                value: settings.themeMode,
                dropdownColor: theme.scaffoldBackgroundColor,
                style: TextStyle(color: textColor),
                underline: const SizedBox(),
                onChanged: (mode) => settings.setTheme(mode!),
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text("تلقائي (النظام)".tr()),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text("فاتح".tr()),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text("داكن".tr()),
                  ),
                ],
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.language, color: textColor),
              title: Text(
                "لغة التطبيق".tr(),
                style: TextStyle(color: textColor),
              ),
              trailing: DropdownButton<String>(
                value: context.locale.languageCode,
                dropdownColor: theme.scaffoldBackgroundColor,
                style: TextStyle(color: textColor),
                underline: const SizedBox(),
                onChanged: (lang) async {
                  if (lang != null) {
                    await context.setLocale(Locale(lang));
                  }
                },
                items: [
                  DropdownMenuItem(value: 'ar', child: Text("العربية".tr())),
                  DropdownMenuItem(value: 'en', child: Text("English".tr())),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(color: borderColor),
            const SizedBox(height: 10),

            Text(
              "حول التطبيق".tr(),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline, color: hintColor),
              title: Text(
                "إصدار التطبيق".tr(),
                style: TextStyle(color: textColor),
              ),
              trailing: Text("1.0.0", style: TextStyle(color: hintColor)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_user_outlined, color: hintColor),
              title: Text(
                "حقوق النشر".tr(),
                style: TextStyle(color: textColor),
              ),
              trailing: Text(
                "shakawa 2026 ©",
                style: TextStyle(color: hintColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
