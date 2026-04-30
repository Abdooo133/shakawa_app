import 'package:flutter/material.dart';
import 'package:flutter_application_1/complaint_details_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 ضفنا دي عشان الشاشة تعتمد على نفسها
import 'main.dart';
import 'constants.dart';
import 'package:easy_localization/easy_localization.dart';

class NotificationsScreen extends StatefulWidget {
  final int customerId;
  const NotificationsScreen({super.key, required this.customerId});

  @override
  // 🛠️ التعديل الأول: صلحنا تحذير الـ Private Type
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    int currentId = widget.customerId;

    // 🚀 التعديل الجذري: لو الشاشة استلمت 0 بالخطأ، هتروح تجيب الـ ID من الذاكرة بنفسها!
    if (currentId == 0) {
      final prefs = await SharedPreferences.getInstance();
      currentId = prefs.getInt('customer_id') ?? 0;
    }

    if (currentId == 0) {
      debugPrint(
        "⚠️ تم إيقاف الطلب: الـ Customer ID ما زال 0 حتى بعد فحصه في الذاكرة",
      );
      if (mounted) setState(() => isLoading = false);
      return;
    }

    final url = Uri.parse(
      "https://${AppConfig.apiUrl}/shakawa_api/get_notifications.php?customer_id=$currentId",
    );
    try {
      final response = await http.get(url, headers: {"ngrok-skip-browser-warning": "true"}).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              // 🛡️ أمان إضافي: عشان يقرأ الـ array سواء السيرفر مسميه data أو notifications
              notifications = data['data'] ?? data['notifications'] ?? [];
              isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => isLoading = false);
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ خطأ في جلب الإشعارات: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> markAsRead(int notificationId, int index) async {
    final url = Uri.parse(
      "https://${AppConfig.apiUrl}/shakawa_api/mark_read.php",
    );
    try {
      await http.post(
        url,
        body: {'notification_id': notificationId.toString()},
      );
      if (mounted) {
        setState(() {
          notifications[index]['is_read'] = 1;
        });

        bool anyUnread = notifications.any(
          (n) => n['is_read'] == 0 || n['is_read'] == "0",
        );
        if (!anyUnread) hasNewNotification.value = false;
      }
    } catch (e) {
      debugPrint("خطأ قراءة الإشعار: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "الإشعارات".tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDarkMode ? Colors.black87 : Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: Colors.blue[900],
              onRefresh: fetchNotifications,
              child: notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 100,
                                color: isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "لا توجد إشعارات حالياً".tr(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final note = notifications[index];
                        bool isUnread =
                            note['is_read'] == 0 || note['is_read'] == "0";

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isUnread
                                ? (isDarkMode
                                      ? Colors.blueGrey[900]
                                      : Colors.blue[50])
                                : (isDarkMode
                                      ? Colors.grey[900]
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDarkMode ? 0.3 : 0.04,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: isUnread
                                ? Border.all(color: Colors.blue[200]!, width: 1)
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isUnread
                                  ? Colors.blue[100]
                                  : (isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[200]),
                              child: Icon(
                                isUnread
                                    ? Icons.notifications_active
                                    : Icons.notifications,
                                color: isUnread
                                    ? Colors.blue[900]
                                    : Colors.grey[600],
                              ),
                            ),
                            title: Text(
                              note['message'],
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 15,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                note['created_at'].toString().substring(0, 16),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () {
                              if (isUnread) {
                                markAsRead(
                                  int.parse(note['id'].toString()),
                                  index,
                                );
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ComplaintDetailsScreen(
                                    complaintId: note['complaint_id']
                                        .toString(),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
