import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'analytics_screen.dart';
import 'company_screen.dart';
import 'tracking_screen.dart';
import 'notification_bell.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'chat_bot_screen.dart';
import 'constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'drawer.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:connectivity_plus/connectivity_plus.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Map<String, dynamic> summary = {};
  bool isSyncing = true;
  int customerId = 0;

  @override
  void initState() {
    super.initState();
    checkInternetConnection(context);
    requestNotificationPermission();
    _loadCustomerId();
    fetchQuickSummary();
  }

  void requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('المستخدم وافق على الإشعارات ✅');
    }
  }

  // دالة فحص الإنترنت
  Future<void> checkInternetConnection(BuildContext context) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      if (!context.mounted) return;
      // لو مفيش نت، نعرض تنبيه للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 10),
              Text("عفواً، لا يوجد اتصال بالإنترنت!".tr()),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(days: 365), // يفضل ثابت لحد ما النت ييجي
        ),
      );
    }
  }


  Future<void> _loadCustomerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int id = prefs.getInt('customer_id') ?? 0;

    if (mounted) {
      setState(() {
        customerId = id;
      });
    }
  }

  Future<void> fetchQuickSummary() async {
    if (!mounted) return;
    setState(() => isSyncing = true);
    try {
      var response = await http
          .get(
            Uri.parse(
              'http://${AppConfig.serverIp}/shakawa_api/get_summary.php',
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (mounted && data['status'] == 'success') {
          setState(() {
            summary = data;
            isSyncing = false;
          });
        }
      } else {
        if (mounted) setState(() => isSyncing = false);
      }
    } catch (e) {
      debugPrint("❌ خطأ الماركي: $e");
      if (mounted) setState(() => isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data;
            return Text(
              "مرحباً {}".tr(args: [user?.displayName ?? ""]),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            );
          },
        ),
        centerTitle: false,
        actions: [NotificationBell(customerId: customerId)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadCustomerId();
          await fetchQuickSummary();
          await FirebaseAuth.instance.currentUser?.reload();
          if (mounted) {
            setState(() {});
          }
        },
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                );
              },
              child: _buildMarquee(theme),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Image.asset(
                      'assets/main_icon.png',
                      width: 400,
                      height: 100,
                    ),
                    const SizedBox(height: 100),

                    BreathingButton(
                      title: 'تقديم شكوى جديدة'.tr(),
                      icon: Icons.add_circle_outline,
                      color: theme.primaryColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompanyScreen(),
                        ),
                      ),
                      delay: 0,
                    ),

                    BreathingButton(
                      title: 'متابعة شكوى سابقة'.tr(),
                      icon: Icons.search_rounded,
                      color: Colors.blueGrey[700]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrackingScreen(),
                        ),
                      ),
                      delay: 300,
                    ),

                    BreathingButton(
                      title: 'عرض لوحة التحليلات'.tr(),
                      icon: Icons.bar_chart_rounded,
                      color: Colors.teal[700]!,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsScreen(),
                        ),
                      ),
                      delay: 600,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const AnimatedChatbotButton(),
    );
  }

  Widget _buildMarquee(ThemeData theme) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        // 🛠️ التعديل الأول: withValues بدلاً من withOpacity
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        // 🛠️ التعديل التاني: Directionality عشان تتشقلب مع الإنجليزي
        textDirection: Directionality.of(context),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            color: theme.primaryColor,
            child: const Icon(Icons.insights, color: Colors.white, size: 22),
          ),
          Expanded(
            child: isSyncing
                ? const Center(child: LinearProgressIndicator())
                : Marquee(
                    text:
                        "إجمالي الشكاوى: {total} | تم حل: {solved} | المعلقة: {pending} "
                            .tr(
                              namedArgs: {
                                "total": summary['total']?.toString() ?? '0',
                                "solved": summary['solved']?.toString() ?? '0',
                                "pending":
                                    summary['pending']?.toString() ?? '0',
                              },
                            ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                    velocity: 35.0,
                    blankSpace: 40.0,
                    // 🛠️ التعديل التالت: القراءة من الثيم عشان الشريط يمشي صح في اللغتين
                    textDirection: Directionality.of(context),
                  ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// 👇 كلاس الشات بوت المتحرك ورسالة الترحيب
// =================================================================
class AnimatedChatbotButton extends StatefulWidget {
  const AnimatedChatbotButton({super.key});

  @override
  State<AnimatedChatbotButton> createState() => _AnimatedChatbotButtonState();
}

class _AnimatedChatbotButtonState extends State<AnimatedChatbotButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showMessage = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showMessage = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: _showMessage ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: _showMessage
              ? Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        // 🛠️ التعديل الرابع: withValues
                        color: Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    "مرحباً، كيف يمكنني مساعدتك؟".tr(),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        ScaleTransition(
          scale: _animation,
          child: FloatingActionButton(
            heroTag: "chatbot_animated_btn",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatBotScreen()),
              );
            },
            backgroundColor: Colors.white,
            elevation: 8,
            child: ClipOval(
              child: Icon(
                Icons.support_agent,
                size: 40,
                color: theme.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =================================================================
// 👇 كلاس الزرار اللي بيتنفس (Breathing Button)
// =================================================================
class BreathingButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int delay;

  const BreathingButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.delay = 0,
  });

  @override
  State<BreathingButton> createState() => _BreathingButtonState();
}

class _BreathingButtonState extends State<BreathingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: double.infinity,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 4,
          ),
          onPressed: widget.onTap,
          icon: Icon(widget.icon),
          label: Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
