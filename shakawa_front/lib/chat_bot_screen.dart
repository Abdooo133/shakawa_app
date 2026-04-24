import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🛑 ضفت دي عشان نجيب الـ ID الصح
import 'tracking_screen.dart';
import 'company_screen.dart';
import 'constants.dart';

// متغير جلوبال عشان يحفظ المحادثة طول ما التطبيق شغال
List<Map<String, dynamic>> globalChatMessages = [];

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  bool isLoading = false;
  String userName = "";

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    userName = user?.displayName?.split(' ')[0] ?? "يا غالي".tr();

    if (globalChatMessages.isEmpty) {
      // 🛠️ التعديل الأول: استخدام دمج النصوص الاحترافي بدل الـ +
      String welcomeText =
          '${"أهلاً بك يا".tr()} $userName! ${"إزاي أقدر أساعدك النهاردة؟".tr()}';

      globalChatMessages.add({
        "sender": "bot",
        "text": welcomeText,
        "type": "text",
      });
    }
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      globalChatMessages.add({
        "sender": "user",
        "text": text.trim(),
        "type": "text",
      });
      isLoading = true;
    });
    _controller.clear();

    try {
      var response = await http.post(
        Uri.parse("http://${AppConfig.serverIp}:8000/chatbot"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "text": text.trim(),
          "customer_name": userName,
          "lang": context.locale.languageCode,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          globalChatMessages.add({
            "sender": "bot",
            "text": data['reply'],
            "type": data['type'],
            "category": data['category'] ?? "",
            "description": data['description'] ?? "",
          });
        });

        if (data['type'] == 'track') {
          trackComplaint(data['id']);
        } else if (data['type'] == 'go_to_form') {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return; // 🛡️ حماية الـ Async
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompanyScreen(
                  initialDescription: data['description'] ?? "",
                ),
              ),
            );
          });
        } else if (data['type'] == 'go_to_track') {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return; // 🛡️ حماية الـ Async
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TrackingScreen(initialId: data['id'] ?? ""),
              ),
            );
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => globalChatMessages.add({
          "sender": "bot",
          "text": "عذراً، في مشكلة في الاتصال بالسيرفر 🔌".tr(),
          "type": "text",
        }),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void trackComplaint(String id) async {
    try {
      var response = await http.post(
        Uri.parse(
          "http://${AppConfig.serverIp}/shakawa_api/bot_actions.php?action=track",
        ),
        body: {"complaint_id": id},
      );

      if (!mounted) return;

      var resData = jsonDecode(response.body);
      String replyText = resData['status'] == 'success'
          ? '${"لقيتها! شكوتك رقم".tr()} #$id ${"حالتها دلوقتي:".tr()} ${resData['state']} ⏱️'
          : "للأسف مفيش شكوى متسجلة بالرقم ده .".tr();

      setState(
        () => globalChatMessages.add({
          "sender": "bot",
          "text": replyText,
          "type": "text",
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => globalChatMessages.add({
          "sender": "bot",
          "text": "مش قادر أوصل لقاعدة البيانات دلوقتي.".tr(),
          "type": "text",
        }),
      );
    }
  }

  void confirmSave(String cat, String desc) async {
    setState(
      () => globalChatMessages.add({
        "sender": "bot",
        "text": "ثواني، بسجلها في السيستم...".tr(),
        "type": "text",
      }),
    );

    try {
      // 🛠️ التعديل الأهم (إصلاح الكارثة): هنجيب الـ ID بتاع العميل الفعلي مش رقم 1
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int customerId = prefs.getInt('customer_id') ?? 0;

      if (customerId == 0) {
        if (!mounted) return;
        setState(
          () => globalChatMessages.add({
            "sender": "bot",
            "text": "برجاء تسجيل الدخول أولاً لتتمكن من حفظ الشكوى.".tr(),
            "type": "text",
          }),
        );
        return;
      }

      var response = await http.post(
        Uri.parse(
          "http://${AppConfig.serverIp}/shakawa_api/bot_actions.php?action=save",
        ),
        body: {
          "customer_id": customerId.toString(), // 👈 دلوقتي بتتبعت صح
          "category": cat,
          "description": desc,
        },
      );

      if (!mounted) return;

      var resData = jsonDecode(response.body);
      setState(
        () => globalChatMessages.add({
          "sender": "bot",
          "text": resData['msg'],
          "type": "text",
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => globalChatMessages.add({
          "sender": "bot",
          "text": "حصلت مشكلة أثناء الحفظ.".tr(),
          "type": "text",
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA);
    Color botBubble = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color userBubble = isDark ? Colors.blue[700]! : Colors.blueAccent;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 2,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.blueAccent,
        ),
        title: Row(
          children: [
            const Icon(Icons.support_agent, color: Colors.blueAccent, size: 40),
            const SizedBox(width: 12),
            Text(
              "مساعدك الذكي".tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: globalChatMessages.length,
              itemBuilder: (context, index) {
                var msg = globalChatMessages[index];
                bool isUser = msg['sender'] == "user";

                return Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUser ? userBubble : botBubble,
                          boxShadow: [
                            BoxShadow(
                              // 🛠️ التعديل التالت: withValues
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: isUser
                                ? const Radius.circular(18)
                                : Radius.zero,
                            bottomRight: isUser
                                ? Radius.zero
                                : const Radius.circular(18),
                          ),
                        ),
                        child: Text(
                          msg['text']!,
                          style: TextStyle(
                            color: isUser ? Colors.white : textColor,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (msg['type'] == 'complaint' && !isUser)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          bottom: 10,
                          top: 4,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              confirmSave(msg['category'], msg['description']),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                          ),
                          label: Text("أيوة، سجل شكوى".tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "جيمي بيكتب...".tr(),
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "احكي مشكلتك هنا...".tr(),
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
