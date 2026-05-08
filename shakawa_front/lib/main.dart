import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main_menu_screen.dart';
import 'complaint_details_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

// سايبين المفتاح ده زي ما طلبت عشان متمسحش حاجة، بس هنعتمد على globalNavigatorKey تحت
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<bool> hasNewNotification = ValueNotifier(false);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

 AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'إشعارات هامة'.tr(),
  description: 'هذه القناة تستخدم لإشعارات الشكاوى الهامة.'.tr(),
  importance: Importance.max,
  playSound: true,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/lanucher_icon');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // ✅ التعديل هنا: استخدمنا المفتاح الماستر globalNavigatorKey في النقل
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      if (details.payload != null) {
        globalNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                ComplaintDetailsScreen(complaintId: details.payload!),
          ),
        );
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // 🚀 التعديل الجذري: دمج الإشعارين مع بعض (إشعار النظام + اليافطة الخضراء)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // جلب الـ ID من الـ Data
    String? complaintIdFromData =
        message.data['complaint_id']?.toString() ??
        message.data['ticket_id']?.toString();

    if (notification != null && android != null) {
      // ١. نور لمبة الجرس الحمراء فوراً
      hasNewNotification.value = true;

      // ٢. إظهار الإشعار بره في الستارة (System Notification)
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: android.smallIcon ?? '@mipmap/lanucher_icon',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        payload: complaintIdFromData,
      );
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    String? token = await messaging.getToken();
    debugPrint("FCM TOKEN: $token");
  } catch (e) {
    debugPrint("Error Token: $e");
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/lang',
      fallbackLocale: const Locale('ar'),
      child: ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: const ShakawaaApp(),
      ),
    ),
  );
}

class ShakawaaApp extends StatelessWidget {
  const ShakawaaApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    const primaryColor = Color(0xFF1E429B); // اللون الأساسي للتطبيق (أزرق غامق)
    return MaterialApp(
      scaffoldMessengerKey: globalMessengerKey,
      navigatorKey: globalNavigatorKey,
      title: 'shakawa',
      debugShowCheckedModeBanner: false,
      // 👇 تخصيص اللايت مود
      theme: ThemeData.light().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor, // لون الزرار دايما أزرق
            foregroundColor: Colors.white,
          ),
        ),
      ),

      // 👇 تخصيص الدارك مود (عشان الأزرار متبقاش سوداء)
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xFF121212), // أسود هادي
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor, // الهيدر يفضل أزرق
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor, // الزرار يفضل أزرق وباين
            foregroundColor: Colors.white,
          ),
        ),
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: Colors.blueAccent,
        ),
      ),

      themeMode: settings.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // متغيرات الأنيميشن (هيبدأوا مختفيين وصغيرين جداً)
  double _opacity = 0.0;
  double _scale = 0.5;

  @override
  void initState() {
    super.initState();

    // 1. تشغيل الأنيميشن: بعد ما الشاشة تفتح بجزء من الثانية، هنغير القيم عشان تظهر وتكبر
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0; // الشفافية تبقى 100%
          _scale = 1.0; // الحجم يرجع طبيعي
        });
      }
    });

    // 2. الكود بتاعك الأصلي بتاع فايربيز (النقل بعد 3 ثواني)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        User? currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainMenuScreen()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF1E429B,
      ), // لون اللوجو بتاعك عشان يبقى متناسق
      body: Center(
        // أداة الشفافية التدريجية
        child: AnimatedOpacity(
          duration: const Duration(seconds: 2), // الأنيميشن هياخد ثانيتين
          curve: Curves.easeIn, // حركة ناعمة في الدخول
          opacity: _opacity,
          // أداة التكبير التدريجي
          child: AnimatedScale(
            duration: const Duration(seconds: 2),
            curve: Curves
                .easeOutBack, // 👈 دي اللي بتعمل تأثير السوستة الشيك (بتكبر وتريح)
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // اللوجو
                Image.asset('assets/main_icon.png', width: 200, height: 150),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
