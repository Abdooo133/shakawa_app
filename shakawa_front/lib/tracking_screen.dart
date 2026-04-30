import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'complaint_details_screen.dart';
import 'constants.dart';
import 'package:easy_localization/easy_localization.dart';

class TrackingScreen extends StatefulWidget {
  final String? initialId;
  const TrackingScreen({super.key, this.initialId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final TextEditingController searchController = TextEditingController();
  List complaints = [];
  bool isLoading = false;
  bool hasSearched = false;

  @override
  void initState() {
    super.initState();
    // 🚀 التعديل الأول والعبقري: تشغيل البحث التلقائي لو جينا من الشات بوت
    if (widget.initialId != null && widget.initialId!.isNotEmpty) {
      searchController.text = widget.initialId!;
      // ننتظر ثانية لحد ما الشاشة تتبني وبعدين نضرب الريكويست للسيرفر
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchComplaint();
      });
    }
  }

  Future<void> searchComplaint() async {
    String searchValue = searchController.text.trim();
    if (searchValue.isEmpty) return;

    setState(() {
      isLoading = true;
      complaints = [];
      hasSearched = true;
    });

    var url = Uri.parse(
      'https://${AppConfig.apiUrl}/shakawa_api/search_complaint.php',
    );

    try {
      var response = await http
          .post(url, body: {'search_value': searchValue})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              complaints = data['data'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🛠️ التعديل التاني: فصلنا اللوجيك عن الترجمة عشان الألوان تشتغل صح في كل اللغات
  Color _getStatusColor(String status) {
    String s = status.toLowerCase();
    if (s.contains('حل') && !s.contains('بانتظار')) return Colors.green;
    if (s.contains('معالجة') || s.contains('جاري') || s.contains('processing')) {
      return Colors.orange;
    }
    if (s.contains('معلق') || s.contains('بانتظار') || s.contains('pending')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  IconData _getStatusIcon(String status) {
    String s = status.toLowerCase();
    if (s.contains('حل') && !s.contains('بانتظار')) {
      return Icons.check_circle_outline;
    }
    if (s.contains('معالجة') || s.contains('جاري') || s.contains('processing')) {
      return Icons.engineering_outlined;
    }
    if (s.contains('معلق') || s.contains('بانتظار') || s.contains('pending')) {
      return Icons.pause_circle_outline;
    }
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text('متابعة الشكاوى'.tr()), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'استعلم عن شكواك:'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: searchController,
              keyboardType: TextInputType.text,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'أدخل رقم الهاتف أو رقم الشكوى'.tr(),
                filled: true,
                fillColor: theme.cardColor,
                prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onFieldSubmitted: (_) => searchComplaint(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: isLoading ? null : searchComplaint,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'بـحـث'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),

            if (hasSearched && !isLoading)
              complaints.isEmpty
                  ? Center(child: Text("عفواً، لا توجد شكاوى بهذا الرقم".tr()))
                  : Column(
                      children: complaints
                          .map(
                            (complaint) => _buildResultCard(complaint, theme),
                          )
                          .toList(),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map complaint, ThemeData theme) {
    Color statusColor = _getStatusColor(complaint['status']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ComplaintDetailsScreen(complaintId: complaint['id'].toString()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // 🛠️ التعديل التالت: withValues
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
          // 🛠️ التعديل الرابع: BorderDirectional عشان الخط يقلب مع اللغة أوتوماتيك
          border: BorderDirectional(
            start: BorderSide(color: statusColor, width: 6),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  _getStatusIcon(complaint['status']),
                  color: statusColor,
                  size: 30,
                ),
                Text(
                  '#${complaint['id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            _buildInfoRow(
              Icons.person,
              'الاسم'.tr(),
              complaint['full_name'],
              theme,
            ),
            _buildInfoRow(
              Icons.category,
              'الخدمة'.tr(),
              complaint['service_type'] ?? 'غير محدد'.tr(),
              theme,
            ),
            const SizedBox(height: 15),
            Text(
              // نترجم الحالة للـ UI فقط
              complaint['status'].toString().tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "اضغط لعرض كامل التفاصيل والردود".tr(),
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 🛠️ التعديل الخامس: withValues
          Icon(
            icon,
            size: 16,
            color: theme.primaryColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
