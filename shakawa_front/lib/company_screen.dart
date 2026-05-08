import 'package:flutter/material.dart';
import 'complaint_form_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class CompanyScreen extends StatefulWidget {
  final String? initialDescription;
  final String? initialCategory;
  const CompanyScreen({
    super.key,
    this.initialDescription,
    this.initialCategory,
  });

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  String? _selectedCompany; // متغير عشان يحفظ الشركة اللي اخترناها وتفضل ملونة

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'اختر جهة الشكوى'.tr(),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.black87 : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),

      // 🛠️ التعديل الأول: شيلنا الـ Directionality الإجبارية واعتمدنا على لغة التطبيق
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 🛠️ التعديل التاني: Directional Padding عشان المسافة تتظبط يمين وشمال حسب اللغة
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 20, end: 10),
            child: Text(
              "برجاء اختيار الشركة أو الجهة المشتكى إليها:".tr(),
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.blueGrey,
              ),
            ),
          ),

          // 🛠️ التعديل التالت: فصلنا اسم العرض عن اسم الـ Database (عشان الـ Backend)
          _buildInteractiveCard(
            context,
            'وي - We',
            'وي',
            Colors.purple,
            'assets/we.png',
          ),
          _buildInteractiveCard(
            context,
            'فودافون - Vodafone',
            'فودافون',
            Colors.red,
            'assets/vodafone.png',
          ),
          _buildInteractiveCard(
            context,
            'أورانج - Orange',
            'أورانج',
            Colors.orange,
            'assets/orange.png',
          ),
          _buildInteractiveCard(
            context,
            'اتصالات - Etisalat',
            'اتصالات',
            Colors.green,
            'assets/etisalat.png',
          ),

          const SizedBox(height: 25),
          _buildGeneralComplaintButton(context, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildInteractiveCard(
    BuildContext context,
    String displayName,
    String dbName,
    Color brandColor,
    String imagePath,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InteractiveCompanyCard(
        displayName: displayName,
        brandColor: brandColor,
        imagePath: imagePath,
        isSelected: _selectedCompany == dbName,
        onTap: () {
          setState(() => _selectedCompany = dbName);
          if (!mounted) return;

          Future.delayed(
            const Duration(milliseconds: 250),
            () => _goToForm( dbName, imagePath, brandColor),
          );
        },
      ),
    );
  }

  Widget _buildGeneralComplaintButton(BuildContext context, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: InteractiveCompanyCard(
        displayName: "تقديم شكوى عامة / جهة أخرى".tr(),
        brandColor: isDarkMode ? Colors.blueAccent : Colors.blueGrey[800]!,
        icon: Icons.assignment_late_outlined,
        // هنا الداتا بيز متوقعة "جهة عامة" بالعربي دايماً
        isSelected: _selectedCompany == "جهة عامة",
        onTap: () {
          setState(() => _selectedCompany = "جهة عامة");
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!mounted) return;
            _goToForm("جهة عامة", null, Colors.blueGrey[800]!);
          });
        },
      ),
    );
  }

  void _goToForm(
    String company,
    String? imagePath,
    Color brandColor
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintForm(
          companyName: company,
          imagePath: imagePath,
          brandColor: brandColor,
          initialDescription: widget.initialDescription,
          initialCategory: widget.initialCategory,
        ),
      ),
    ).then((_) {
      // 🛡️ حماية الـ Async
      if (mounted) {
        setState(() => _selectedCompany = null);
      }
    });
  }
}

class InteractiveCompanyCard extends StatelessWidget {
  final String displayName;
  final Color brandColor;
  final String? imagePath;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const InteractiveCompanyCard({
    super.key,
    required this.displayName,
    required this.brandColor,
    this.imagePath,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color bgColor = isSelected
        ? brandColor
        : (isDarkMode ? Colors.grey[900]! : Colors.white);
    Color textColor = isSelected
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black);
    Color arrowColor = isSelected
        ? Colors.white
        : (isDarkMode ? Colors.grey[500]! : Colors.blueGrey);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 95,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              // 🛠️ التعديل الرابع: استخدام withValues
              color: isDarkMode
                  ? Colors.black
                  : Colors.grey.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imagePath != null
                    ? Image.asset(
                        imagePath!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                      )
                    : Icon(icon, color: textColor, size: 40),
              ),
              const SizedBox(width: 25),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 🛠️ التعديل الخامس: أيقونة سهم ذكية (بتشاور شمال في العربي، ويمين في الإنجليزي أوتوماتيك)
              Icon(Icons.arrow_forward_ios, color: arrowColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
