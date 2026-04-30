import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'constants.dart';
import 'package:easy_localization/easy_localization.dart';

class EditComplaintScreen extends StatefulWidget {
  final Map<String, dynamic> complaintData;
  // 🛠️ التعديل الأول: الطريقة الحديثة للـ Key
  const EditComplaintScreen({super.key, required this.complaintData});

  @override
  State<EditComplaintScreen> createState() => _EditComplaintScreenState();
}

class _EditComplaintScreenState extends State<EditComplaintScreen> {
  late TextEditingController descController;
  late TextEditingController locationController;
  late TextEditingController govController;
  late TextEditingController serviceController;
  late TextEditingController phoneComplaintController;
  late TextEditingController landlineController;

  File? _newImage;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    // ملء الخانات بالبيانات القديمة
    descController = TextEditingController(
      text: widget.complaintData['description'],
    );
    phoneComplaintController = TextEditingController(
      text: widget.complaintData['complaint_phone'].toString(),
    );
    landlineController = TextEditingController(
      text: widget.complaintData['landline'].toString(),
    );
    locationController = TextEditingController(
      text: widget.complaintData['location'],
    );
    govController = TextEditingController(
      text: widget.complaintData['governorate'],
    );
    serviceController = TextEditingController(
      text: widget.complaintData['service_type'],
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() => _newImage = File(pickedFile.path));
    }
  }

  Future<void> _updateComplaint() async {
    // 🛡️ حماية بسيطة: التأكد إن الوصف مش فاضي
    if (descController.text.trim().isEmpty) {
      _showSnackBar("برجاء كتابة وصف للمشكلة".tr(), Colors.red);
      return;
    }

    setState(() => isUpdating = true);

    var url = Uri.parse(
      "https://${AppConfig.apiUrl}/shakawa_api/update_complaint.php",
    );
    var request = http.MultipartRequest("POST", url);

    request.fields['complaint_id'] = widget.complaintData['id'].toString();
    request.fields['description'] = descController.text.trim();
    request.fields['location'] = locationController.text.trim();
    request.fields['governorate'] = govController.text.trim();
    request.fields['service_type'] = serviceController.text.trim();
    request.fields['complaint_phone'] = phoneComplaintController.text.trim();
    request.fields['landline'] = landlineController.text.trim();

    if (_newImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', _newImage!.path),
      );
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint("رد سيرفر التعديل: ${response.body}");

      // 🛡️ حماية الـ Async Gap
      if (!mounted) return;

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success') {
          _showSnackBar(
            decoded['message'] ?? 'تم التعديل بنجاح'.tr(),
            Colors.green,
          );
          // بنرجع true عشان الشاشة اللي فاتت تعرف إن فيه تعديل حصل وتعمل ريفريش
          Navigator.pop(context, true);
        } else {
          _showSnackBar(decoded['message'] ?? 'فشل التعديل'.tr(), Colors.red);
        }
      } else {
        _showSnackBar(
          'خطأ في الاتصال: ${response.statusCode}'.tr(),
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint("خطأ في التعديل: $e");
      if (mounted) {
        _showSnackBar(
          'حدث خطأ غير متوقع، تأكد من اتصالك بالإنترنت'.tr(),
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('تعديل بيانات الشكوى'.tr()),
        // 🛠️ التعديل التاني: الألوان تقرأ من الثيم أوتوماتيك
        backgroundColor: isDark ? Colors.black87 : theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isUpdating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildField(
                    descController,
                    "وصف المشكلة".tr(),
                    Icons.description,
                    theme,
                    maxLines: 3,
                  ),
                  _buildField(govController, "المحافظة".tr(), Icons.map, theme),
                  _buildField(
                    locationController,
                    "العنوان بالتفصيل".tr(),
                    Icons.location_on,
                    theme,
                  ),
                  _buildField(
                    serviceController,
                    "نوع الخدمة".tr(),
                    Icons.settings,
                    theme,
                  ),
                  _buildField(
                    phoneComplaintController,
                    "رقم الهاتف الخاص بالشكوى".tr(),
                    Icons.phone,
                    theme,
                  ),
                  _buildField(
                    landlineController,
                    "رقم الهاتف الارضي".tr(),
                    Icons.phone,
                    theme,
                  ),

                  const SizedBox(height: 20),

                  Column(
                    children: [
                      if (_newImage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _newImage!,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_a_photo),
                        label: Text(
                          _newImage == null
                              ? "تغيير الصورة المرفقة".tr()
                              : "تم اختيار صورة جديدة (اضغط للتغيير)".tr(),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: _updateComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? theme.primaryColor
                          : Colors.blue[900],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "حفظ التعديلات النهائية".tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon,
    ThemeData theme, {
    int maxLines = 1,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
          prefixIcon: Icon(icon, color: theme.primaryColor),
          filled: true,
          fillColor: isDark ? Colors.grey[900] : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
