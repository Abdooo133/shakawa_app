import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen ({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("معلومات الحساب").tr()),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 30),
            _buildInfoCard(
              "الاسم".tr(),
              user?.displayName ?? "غير محدد".tr(),
              Icons.person_outline,
            ),
            _buildInfoCard(
              "البريد الإلكتروني".tr(),
              user?.email ?? "غير محدد".tr(),
              Icons.email_outlined,
            ),

            // لو مسجل برقم تليفون هيظهر هنا
            if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty)
              _buildInfoCard(
                "رقم الهاتف".tr(),
                user.phoneNumber!,
                Icons.phone,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
