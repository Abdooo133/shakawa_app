import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notifications_screen.dart';
import 'main.dart';
import 'constants.dart';

class NotificationBell extends StatefulWidget {
  final int customerId;
  const NotificationBell({super.key, required this.customerId});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  bool hasUnreadDatabase = false;

  @override
  void initState() {
    super.initState();
    checkUnreadNotifications();
  }

  @override
  void didUpdateWidget(NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId == 0 && widget.customerId > 0) {
      checkUnreadNotifications();
    }
  }

  Future<void> checkUnreadNotifications() async {
    // 🛡️ التعديل الأول: توفير استهلاك السيرفر لو الـ ID لسه مجهول
    if (widget.customerId == 0) return;

    final url = Uri.parse(
      "${AppConfig.apiUrl}/shakawa_api/get_notifications.php?customer_id=${widget.customerId}",
    );

    try {
      // 🛡️ التعديل التاني: إضافة Timeout
      final response = await http.get(url, headers: {"ngrok-skip-browser-warning": "true"}).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          List notes = data['data'];
          bool unread = notes.any(
            (note) => note['is_read'] == 0 || note['is_read'] == "0",
          );

          if (mounted) {
            setState(() {
              hasUnreadDatabase = unread;
            });
            if (unread) {
              hasNewNotification.value = true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("خطأ في جلب الإشعارات: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: hasNewNotification,
      builder: (context, hasNewPush, child) {
        bool showDot = hasUnreadDatabase || hasNewPush;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () async {
                // أول ما يدوس، نطفي اللمبات فوراً عشان الـ UX
                hasNewNotification.value = false;
                if (mounted) setState(() => hasUnreadDatabase = false);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NotificationsScreen(customerId: widget.customerId),
                  ),
                );
                // لما يرجع من شاشة الإشعارات نشيك تاني
                checkUnreadNotifications();
              },
            ),

            if (showDot)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      // 🛠️ التعديل التالت: لون ذكي يندمج مع أي ثيم
                      color: theme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 10,
                    minHeight: 10,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
