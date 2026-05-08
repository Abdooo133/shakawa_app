import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class AppDrawer extends StatelessWidget {
  // 🛠️ التعديل الأول: استخدام Super Parameters بدل الطريقة القديمة
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: theme.primaryColor),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.transparent,
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 50,
                        height: 50,
                      ),
                    ),
                    const Text(
                      'shakawa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            _buildDrawerItem(Icons.settings_outlined, 'الإعدادات'.tr(), () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }),

            _buildDrawerItem(Icons.mail_outline, 'تواصل معنا'.tr(), () async {
              Navigator.pop(context);
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'abdoeslah67@gmail.com',
                queryParameters: {'subject': 'تواصل من داخل التطبيق '.tr()},
              );

              try {
                await launchUrl(
                  emailLaunchUri,
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "يرجى التأكد من وجود تطبيق Gmail على هاتفك".tr(),
                      ),
                    ),
                  );
                }
              }
            }),

            _buildDrawerItem(Icons.info_outline_rounded, 'عن التطبيق'.tr(), () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'shakawa',
                applicationVersion: '1.0.2',
                applicationIcon: Image.asset(
                  'assets/app_icon.png',
                  width: 60,
                  height: 60,
                ),
                children: [
                  Text("تطبيق شكاوى الاتصالات - مشروع تخرج 2026".tr()),
                ],
              );
            }),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.grey),
            ),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                'تسجيل الخروج'.tr(),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();

                // 🛡️ حماية الـ Async
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),

            const Spacer(),

            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'v 1.0.2 - Beta',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
