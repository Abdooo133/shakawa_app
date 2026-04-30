import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'edit_complaint_screen.dart';
import 'constants.dart';
import 'package:easy_localization/easy_localization.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final String complaintId;
  const ComplaintDetailsScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  Map<String, dynamic>? complaintData;
  bool isLoading = true;

  final String apiUrl = "https://${AppConfig.apiUrl}/shakawa_api/";

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    if (widget.complaintId == 'null' || widget.complaintId.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    final url = Uri.parse(
      "${apiUrl}get_complaint_details.php?id=${widget.complaintId}",
    );
    try {
      final response = await http.get(url, headers: {"ngrok-skip-browser-warning": "true"}).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') {
          if (mounted) {
            setState(() {
              complaintData = decoded['data'];
              isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _submitCustomerDecision(String decision) async {
    setState(() => isLoading = true);
    final url = Uri.parse("${apiUrl}confirm_resolution.php");

    try {
      final response = await http.post(
        url,
                    headers: {"ngrok-skip-browser-warning":"true"},

        body: {'complaint_id': widget.complaintId, 'decision': decision},
      );

      // 🛡️ حماية الـ Async: التأكد إن الصفحة لسه مفتوحة قبل عرض الرسالة
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إرسال ردك للإدارة بنجاح'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          fetchDetails();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في الاتصال بالسيرفر'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  // 🛠️ التعديل الأول: فصلنا المنطق.. بقينا نفحص الكلمة الأصلية اللي جاية من السيرفر (عربي) أو الإنجليزي
  Color _getStatusColor(String status) {
    String lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('حل') && !lowerStatus.contains('بانتظار')) {
      return Colors.green;
    }
    if (lowerStatus.contains('بانتظار') || lowerStatus.contains('pending')) {
      return Colors.purple;
    }
    if (lowerStatus.contains('جاري') ||
        lowerStatus.contains('معالجة') ||
        lowerStatus.contains('معلق') ||
        lowerStatus.contains('processing')) {
      return Colors.orange;
    }
    if (lowerStatus.contains('جديد') || lowerStatus.contains('new')) {
      return Colors.red;
    }
    if (lowerStatus.contains('مرفوض') || lowerStatus.contains('rejected')) {
      return Colors.black87;
    }
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 🛠️ التعديل التاني: فحصنا حالة الزرار بناءً على الداتا الأصلية للسيرفر مش الترجمة
    String currentStatus = (complaintData?['status'] ?? '')
        .toString()
        .toLowerCase();
    bool isEditable =
        currentStatus.contains('جديد') ||
        currentStatus.contains('new') ||
        currentStatus.contains('جاري') ||
        currentStatus.contains('processing');
    bool isWaitingCustomer =
        currentStatus.contains('بانتظار تأكيد العميل') ||
        currentStatus.contains('pending');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('تفاصيل الشكوى'.tr()),
        backgroundColor: isDarkMode ? Colors.black87 : Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (complaintData == null)
          ? Center(
              child: Text(
                "عذراً، تعذر تحميل البيانات".tr(),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoCard(
                      context,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'رقم الشكوى: #{}'.tr(args: [?complaintData?['id'].toString()]),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Chip(
                            label: Text(
                              // هنا بنعرض الحالة زي ما هي من السيرفر بس ممكن نترجمها للـ UI
                              (complaintData?['status'] ?? '').toString().tr(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: _getStatusColor(currentStatus),
                          ),
                        ],
                      ),
                    ),

                    _buildInfoCard(
                      context,
                      child: Column(
                        children: [
                          _buildDetailRow(
                            context,
                            Icons.business,
                            "الشركة".tr(),
                            complaintData?['company_name'] ?? '',
                          ),
                          const Divider(),
                          _buildDetailRow(
                            context,
                            Icons.settings_suggest,
                            "النوع".tr(),
                            complaintData?['service_type']??
                                'غير متوفر'.tr(),
                          ),
                          const Divider(),
                          _buildDetailRow(
                            context,
                            Icons.phone_android,
                            "الرقم الخاص بالشكوى".tr(),
                            complaintData?['complaint_phone']?.toString() ??
                                'غير متوفر'.tr(),
                          ),
                          const Divider(),
                          _buildDetailRow(
                            context,
                            Icons.call,
                            "الرقم الارضي".tr(),
                            complaintData?['landline']?.toString() ??
                                'غير متوفر'.tr(),
                          ),
                          const Divider(),
                          _buildDetailRow(
                            context,
                            Icons.location_on,
                            "الموقع".tr(),
                            "${complaintData?['governorate'] ?? 'غير متوفر'.tr()} - ${complaintData?['location'] ?? 'غير متوفر'.tr()}",
                          ),
                        ],
                      ),
                    ),

                    _buildInfoCard(
                      context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "وصف المشكلة:".tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            complaintData?['description'] ?? '',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if ((complaintData?['admin_reply'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      _buildInfoCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "رد الإدارة:".tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Divider(),
                            Text(
                              complaintData?['admin_reply'] ?? '',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (currentStatus.contains('مرفوض') &&
                        (complaintData?['rejection_reason'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                      _buildInfoCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "سبب الرفض (من الإدارة):".tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.redAccent),
                            Text(
                              complaintData?['rejection_reason'] ?? '',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    _buildInfoCard(
                      context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            " المرفقات:".tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          (complaintData?['image_base64'] == null ||
                                  complaintData!['image_base64']
                                      .toString()
                                      .isEmpty)
                              ? Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text("لا توجد مرفقات".tr()),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    base64Decode(
                                      complaintData!['image_base64'],
                                    ),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 150,
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: Text(
                                                  "فشل معالجة الصورة".tr(),
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                        ],
                      ),
                    ),

                    if (isWaitingCustomer)
                      _buildInfoCard(
                        context,
                        child: Column(
                          children: [
                            Text(
                              "الأدمن أفاد بأن المشكلة حُلت، هل تؤكد ذلك؟".tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      "تم الحل".tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _submitCustomerDecision('solved'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      "لم يتم الحل".tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _submitCustomerDecision('not_solved'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    if (isEditable)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditComplaintScreen(
                                  complaintData: complaintData!,
                                ),
                              ),
                            ).then((value) {
                              if (value == true) fetchDetails();
                            });
                          },
                          icon: const Icon(
                            Icons.edit_note,
                            color: Colors.white,
                          ),
                          label: Text(
                            "تعديل بيانات الشكوى".tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required Widget child}) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            // 🛠️ التعديل التالت: withValues بدلاً من withOpacity
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: Colors.blue[900], size: 20),
        const SizedBox(width: 12),
        Text("$label: ", style: const TextStyle(color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
