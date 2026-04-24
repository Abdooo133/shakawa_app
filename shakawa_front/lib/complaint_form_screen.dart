import 'dart:io';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'success_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ComplaintForm extends StatefulWidget {
  final String? initialDescription;
  final String? initialCategory;
  final String companyName;
  final String? imagePath;
  final Color brandColor;

  const ComplaintForm({
    super.key,
    this.initialDescription,
    this.initialCategory,
    required this.companyName,
    this.imagePath,
    this.brandColor = Colors.blue,
  });

  @override
  State<ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<ComplaintForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController phoneComplaintController =
      TextEditingController();
  final TextEditingController landlineController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String selectedGovernorate = 'القاهرة';
  String selectedService = 'إنترنت منزلي';
  String? selectedGender;
  bool isLoading = false;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();
  String _locationName = "تحديد الموقع";
  int customerId = 0;

  bool validatePhoneNumbers(
    String companyName,
    String complaintPhone,
    String landline,
  ) {
    if (complaintPhone.isNotEmpty) {
      if (complaintPhone.length != 11) {
        _showSnackBar(
          "رقم الشكوى الخاص يجب أن يتكون من 11 رقم".tr(),
          Colors.red,
        );
        return false;
      }
      if (companyName == 'فودافون' && !complaintPhone.startsWith('010')) {
        _showSnackBar("رقم فودافون يجب أن يبدأ بـ 010".tr(), Colors.red);
        return false;
      } else if (companyName == 'أورانج' && !complaintPhone.startsWith('012')) {
        _showSnackBar("رقم أورانج يجب أن يبدأ بـ 012".tr(), Colors.red);
        return false;
      } else if (companyName == 'اتصالات' &&
          !complaintPhone.startsWith('011')) {
        _showSnackBar("رقم اتصالات يجب أن يبدأ بـ 011".tr(), Colors.red);
        return false;
      } else if (companyName == 'وي' && !complaintPhone.startsWith('015')) {
        _showSnackBar("رقم وي (WE) يجب أن يبدأ بـ 015".tr(), Colors.red);
        return false;
      }
    }

    if (landline.isNotEmpty) {
      RegExp landlineRegex = RegExp(r'^0[2-9][0-9]{7,8}$');
      if (!landlineRegex.hasMatch(landline)) {
        _showSnackBar(
          "صيغة الرقم الأرضي غير صحيحة (مثال: 022xxxxxxx)".tr(),
          Colors.red,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> submitComplaintToBackend() async {
    if (!_formKey.currentState!.validate()) return;

    if (_locationName == "تحديد الموقع" ||
        _locationName == "فشل التحديد" ||
        _locationName.contains("عطل") ||
        _locationName.contains("جاري")) {
      _showSnackBar(
        "برجاء الانتظار حتى يتم تحديد موقعك بدقة! 📍".tr(),
        Colors.red,
      );
      return;
    }

    if (!validatePhoneNumbers(
      widget.companyName,
      phoneComplaintController.text,
      landlineController.text,
    )) {
      return;
    }

    setState(() => isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int customerId = prefs.getInt('customer_id') ?? 0;
      String? token = await FirebaseMessaging.instance.getToken();

      var uri = Uri.parse(
        'http://${AppConfig.serverIp}/shakawa_api/add_complaint.php',
      );
      var request = http.MultipartRequest("POST", uri);

      request.fields['customer_id'] = customerId.toString();
      request.fields['full_name'] = nameController.text;
      request.fields['phone'] = phoneController.text;
      request.fields['complaint_phone'] = phoneComplaintController.text;
      request.fields['landline'] = landlineController.text;
      request.fields['email'] = emailController.text;
      request.fields['gender'] = selectedGender ?? 'ذكر';
      request.fields['governorate'] = selectedGovernorate;
      request.fields['service_type'] = selectedService;
      request.fields['description'] = detailsController.text;
      request.fields['location'] = _locationName;
      request.fields['device_id'] = token ?? "";
      request.fields['company_name'] = widget.companyName == 'جهة عامة'
          ? 'شكوى عامة'
          : widget.companyName;

      if (selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', selectedImage!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      debugPrint("رد السيرفر هو:${response.body}");

      // 🛡️ حماية الـ Async
      if (!mounted) return;

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          String ticketNum = jsonResponse['complaint_id'].toString();

          if (jsonResponse.containsKey('customer_id')) {
            int newId = jsonResponse['customer_id'];
            await prefs.setInt('customer_id', newId);
          }
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(ticketNumber: ticketNum),
            ),
          );
        } else {
          _showSnackBar(
            'فشل الإرسال: {}'.tr(args: [jsonResponse['message']]),
            Colors.red,
          );
        }
      } else {
        _showSnackBar(
          'مشكلة في السيرفر ({})'.tr(args: [response.statusCode.toString()]),
          Colors.red,
        );
      }
    } catch (e) {
      debugPrint("خطأ الإرسال: $e");
      if (!mounted) return;
      _showSnackBar('حدث خطأ في الاتصال بالسيرفر ❌'.tr(), Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.imagePath != null)
              Image.asset(
                widget.imagePath!,
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.companyName == 'جهة عامة'
                    ? 'تقديم شكوى عامة'.tr()
                    : widget.companyName.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: widget.brandColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "بيانات الشكوى:".tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                nameController,
                'الاسم ثلاثي'.tr(),
                Icons.person,
                theme,
                customValidator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'برجاء إدخال الاسم'.tr();
                  }
                  if (!RegExp(r'^[\a-zA-Z\u0600-\u06FF\s]+$').hasMatch(value)) {
                    return 'عفواً، الاسم يجب أن يحتوي على حروف فقط'.tr();
                  }
                  if (value.trim().length < 3) {
                    return 'الاسم قصير جداً، يرجى كتابة اسم حقيقي'.tr();
                  }
                  return null;
                },
              ),
              _buildTextField(
                phoneController,
                'رقم الهاتف للتواصل'.tr(),
                Icons.contact_phone_rounded,
                theme,
                isPhone: true,
              ),
              _buildTextField(
                phoneComplaintController,
                'رقم الهاتف الخاص بالشكوى'.tr(),
                Icons.settings_phone_rounded,
                theme,
                isPhone: true,
                isRequired:
                    selectedService ==
                    'موبايل إنترنت', // فحص القيمة الأصلية مش المترجمة
              ),
              _buildTextField(
                landlineController,
                'رقم الهاتف الارضي'.tr(),
                Icons.local_phone_outlined,
                theme,
                isPhone: true,
                isRequired: selectedService == 'إنترنت منزلي',
              ),
              _buildTextField(
                emailController,
                'البريد الإلكتروني'.tr(),
                Icons.email,
                theme,
                customValidator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'برجاء إدخال البريد الإلكتروني'.tr();
                  }
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'صيغة البريد الإلكتروني غير صحيحة (مثال: user@mail.com)'
                        .tr();
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'النوع'.tr(),
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                initialValue: selectedGender,
                hint: Text("حدد جنسك".tr()),
                items: ['ذكر', 'انثى'].map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item.tr()),
                  );
                }).toList(),
                onChanged: (newValue) =>
                    setState(() => selectedGender = newValue),
                validator: (value) =>
                    value == null ? 'يرجى اختيار الجنس'.tr() : null,
              ),
              const SizedBox(height: 15),

              _buildDropdown(
                "المحافظة".tr(),
                selectedGovernorate,
                [
                  'القاهرة',
                  'كفر الشيخ',
                  'الإسكندرية',
                  'الجيزة',
                  'الدقهلية',
                  'المنيا',
                  'القليوبية',
                  'الغربية',
                  'الشرقية',
                  'السويس',
                  'بورسعيد',
                  'الإسماعيلية',
                  'أسوان',
                  'أسيوط',
                  'الفيوم',
                  'المنوفية',
                  'الوادي الجديد',
                  'البحر الأحمر',
                  'جنوب سيناء',
                  'شمال سيناء',
                  'الأقصر',
                  'البحيرة',
                  'بني سويف',
                  'مطروح',
                  'قنا',
                  'سوهاج',
                  'دمياط',
                ],
                (val) => setState(() => selectedGovernorate = val!),
                theme,
              ),
              const SizedBox(height: 15),

              _buildDropdown(
                "نوع الخدمة".tr(),
                selectedService,
                [
                  'إنترنت منزلي',
                  'موبايل إنترنت',
                  'خدمة عملاء',
                  'فواتير',
                  'أخرى',
                ],
                (val) => setState(() => selectedService = val!),
                theme,
              ),
              const SizedBox(height: 15),

              _buildTextField(
                detailsController,
                'وصف المشكلة بالتفصيل'.tr(),
                Icons.description,
                theme,
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      selectedImage == null
                          ? 'إرفاق صورة'.tr()
                          : 'تم اختيار صورة'.tr(),
                      selectedImage == null ? Colors.blueGrey : Colors.green,
                      Icons.image,
                      () => _showPicker(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      'تحديد الموقع'.tr(),
                      Colors.green[700]!,
                      Icons.location_on,
                      _determinePosition,
                    ),
                  ),
                ],
              ),

              if (_locationName != "تحديد الموقع".tr() &&
                  _locationName != "تحديد الموقع")
                Container(
                  margin: const EdgeInsets.only(top: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      // 🛠️ التعديل هنا لـ withValues
                      color: theme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.brandColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: isLoading ? null : submitComplaintToBackend,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'إرسال الشكوى'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    ThemeData theme, {
    bool isPhone = false,
    int maxLines = 1,
    bool isRequired = true,
    String? Function(String?)? customValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          // 🛠️ ظبطنا رسالة الاختياري عشان الترجمة
          labelText: isRequired ? label : "$label (${'اختياري'.tr()})",
          prefixIcon: Icon(icon, color: theme.primaryColor),
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator:
            customValidator ??
            (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) {
                return 'هذا الحقل مطلوب'.tr();
              }
              return null;
            },
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
    ThemeData theme,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item.tr()),
        ); // عرض مترجم فقط
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
    );
    if (image != null) setState(() => selectedImage = File(image.path));
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (bc) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('المعرض'.tr()),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text('الكاميرا'.tr()),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _determinePosition() async {
    setState(() => _locationName = "جاري التحديد...".tr());

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(
          () => _locationName = "فشل التحديد: برجاء تشغيل الـ GPS أولاً".tr(),
        );
        _showSnackBar(
          "برجاء تشغيل الـ GPS (الموقع) من إعدادات الهاتف".tr(),
          Colors.orange,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationName = "فشل التحديد: تم رفض الصلاحية".tr());
          _showSnackBar(
            "يجب الموافقة على صلاحية الموقع لتحديد مكانك".tr(),
            Colors.red,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(
          () => _locationName = "فشل التحديد: الصلاحية مرفوضة نهائياً".tr(),
        );
        _showSnackBar(
          "صلاحية الموقع مرفوضة. يرجى تفعيلها من إعدادات التطبيق".tr(),
          Colors.red,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(),
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(
          () => _locationName =
              "${placemarks[0].locality}, ${placemarks[0].administrativeArea}",
        );
      }
    } catch (e) {
      debugPrint("خطأ في اللوكيشن: $e");
      setState(() => _locationName = "فشل التحديد".tr());
    }
  }
}
