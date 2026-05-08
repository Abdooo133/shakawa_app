import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🛠️ التعديل الأول: القيم دي للسيرفر (لازم تفضل عربي)، الترجمة هتتم في الـ UI بس
  String selectedCompany = "فودافون";
  String selectedTrend = 'أسبوع';

  Map<String, dynamic> stats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchAnalytics();
  }

  Color _getActiveColor() {
    switch (selectedCompany) {
      case 'فودافون':
        return Colors.red;
      case 'أورانج':
        return Colors.orange;
      case 'اتصالات':
        return Colors.green;
      case 'وي':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  Future<void> fetchAnalytics() async {
    if (mounted) setState(() => isLoading = true);
    try {
      var response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/shakawa_api/analytics.php'),
        headers: {"ngrok-skip-browser-warning": "true"},
        body: {
          'company': selectedCompany,
          'trend': selectedTrend,
        }, // بيبعت دايما عربي للسيرفر
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            stats = jsonDecode(response.body);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'لوحة التحليلات'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDarkMode ? Colors.black87 : theme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 15,
          ),
          tabs: [
            Tab(text: 'نظرة عامة'.tr()),
            Tab(text: 'تحليل الشركات'.tr()),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralOverview(theme, isDarkMode),
                _buildCompanyDeepDive(theme, isDarkMode),
              ],
            ),
    );
  }

  Widget _buildGeneralOverview(ThemeData theme, bool isDarkMode) {
    var summary = stats['summary'] ?? {};
    return RefreshIndicator(
      onRefresh: fetchAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildHeaderSummary(
                  'الإجمالي'.tr(),
                  summary['total']?.toString() ?? '0',
                  Colors.blue,
                  Icons.analytics,
                  theme,
                ),
                _buildHeaderSummary(
                  'المحلولة'.tr(),
                  summary['solved']?.toString() ?? '0',
                  Colors.green,
                  Icons.check_circle,
                  theme,
                ),
              ],
            ),
            Row(
              children: [
                _buildHeaderSummary(
                  'المعلقة'.tr(),
                  summary['pending']?.toString() ?? '0',
                  Colors.orange,
                  Icons.pending_actions,
                  theme,
                ),
                _buildHeaderSummary(
                  'الجديدة'.tr(),
                  summary['new_count']?.toString() ?? '0',
                  Colors.red,
                  Icons.new_releases,
                  theme,
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildSectionCard(
              title: 'توزيع الشكاوى حسب الجنس'.tr(),
              icon: Icons.pie_chart_outline,
              theme: theme,
              child: SizedBox(height: 200, child: PieChart(_getPieData())),
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              // تم ضبط الترجمة هنا عشان تشتغل صح مع المتغيرات
              title: "إحصائيات دورية ({})".tr(args: [selectedTrend.tr()]),
              icon: Icons.show_chart,
              theme: theme,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      'أسبوع',
                      'شهر',
                      'سنة',
                    ].map((t) => _buildTrendFilter(t, theme)).toList(),
                  ),
                  const SizedBox(height: 30),
                  // 🛠️ التعديل التاني: Directional للحفاظ على الرسم البياني في أي لغة
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: 20,
                      start: 10,
                    ),
                    child: SizedBox(
                      height: 220,
                      child: LineChart(_getLineChartData(theme, isDarkMode)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDeepDive(ThemeData theme, bool isDarkMode) {
    var cStats = stats['company_stats'] ?? {};
    int total = int.tryParse(cStats['total']?.toString() ?? '0') ?? 0;

    return RefreshIndicator(
      onRefresh: fetchAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'اختر الشركة للتحليل:'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCompanyChip("فودافون", Colors.red, theme),
                  _buildCompanyChip("أورانج", Colors.orange, theme),
                  _buildCompanyChip("اتصالات", Colors.green, theme),
                  _buildCompanyChip("وي", Colors.purple, theme),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'تحليل أداء {}'.tr(args: [selectedCompany.tr()]),
              icon: Icons.insights,
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMiniStat(
                        'الإجمالي'.tr(),
                        total.toString(),
                        Colors.blue,
                        theme,
                      ),
                      _buildMiniStat(
                        'محلولة'.tr(),
                        cStats['solved']?.toString() ?? '0',
                        Colors.green,
                        theme,
                      ),
                      _buildMiniStat(
                        'معلقة'.tr(),
                        cStats['pending']?.toString() ?? '0',
                        Colors.orange,
                        theme,
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  Text(
                    "توزيع المحافظات:".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...(stats['company_govs'] as List? ?? []).map((gov) {
                    double pct = total == 0
                        ? 0
                        : (int.parse(gov['count'].toString()) / total);
                    return _buildProgressItem(
                      gov['governorate'],
                      gov['count'].toString(),
                      pct,
                      _getActiveColor(),
                      theme,
                    );
                  }),
                  const Divider(height: 40),
                  Text(
                    "تحليل أنواع الخدمات:".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...(stats['company_services'] as List? ?? []).map((service) {
                    double pct = total == 0
                        ? 0
                        : (int.parse(service['count'].toString()) / total);
                    return _buildProgressItem(
                      service['service_type'],
                      service['count'].toString(),
                      pct,
                      _getActiveColor(),
                      theme,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _getLineChartData(ThemeData theme, bool isDarkMode) {
    List<dynamic> trendData = stats['trend_data'] ?? [];
    if (trendData.isEmpty) return LineChartData();

    List<FlSpot> spots = trendData
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            double.parse(e.value['count'].toString()),
          ),
        )
        .toList();

    return LineChartData(
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.5),
          top: BorderSide.none,
          left: BorderSide.none,
          right: BorderSide.none,
        ),
      ),
      minX: 0,
      maxX: (trendData.length - 1).toDouble(),
      minY: 0,
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: selectedTrend == 'شهر' ? 45 : 30, // بدون ترجمة للوجيك
            interval: 1,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index >= 0 && index < trendData.length) {
                return SideTitleWidget(
                  meta: meta,
                  space: 12,
                  angle: selectedTrend == 'شهر' ? -0.8 : 0.0,
                  child: Text(
                    trendData[index]['date'].toString(),
                    style: TextStyle(
                      fontSize: selectedTrend == 'شهر' ? 9 : 10,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.blue[200] : theme.primaryColor,
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          preventCurveOverShooting: true,
          spots: spots,
          isCurved: true,
          color: _getActiveColor(),
          barWidth: 4,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                // 🛠️ التعديل التالت: withValues بدل withOpacity
                _getActiveColor().withValues(alpha: 0.3),
                _getActiveColor().withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  PieChartData _getPieData() {
    List<dynamic> genderList = stats['gender_dist'] ?? [];
    if (genderList.isEmpty) return PieChartData();
    return PieChartData(
      sections: genderList.map((g) {
        // فحص الكلمة الأصلية من الداتا بيز
        bool isMale = g['gender'] == 'ذكر';
        return PieChartSectionData(
          value: double.parse(g['count'].toString()),
          // الترجمة للـ UI بس
          title: '${g['gender'].toString().tr()}\n${g['count']}',
          color: isMale ? Colors.blue : Colors.pink,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeaderSummary(
    String title,
    String count,
    Color color,
    IconData icon,
    ThemeData theme,
  ) {
    bool isDarkMode = theme.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(15),
          // 🛠️ التعديل الرابع: BorderDirectional عشان الخط الملون يقلب يمين وشمال مع اللغة
          border: BorderDirectional(end: BorderSide(color: color, width: 5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.grey, size: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    required ThemeData theme,
  }) {
    bool isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    String label,
    String count,
    double pct,
    Color col,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.tr()), // لو المحافظة أو الخدمة ليها ترجمة هتشتغل
              Text(
                count,
                style: TextStyle(fontWeight: FontWeight.bold, color: col),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            color: col,
            backgroundColor: theme.dividerColor,
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendFilter(String titleRaw, ThemeData theme) {
    bool isSelected = selectedTrend == titleRaw;
    Color chipColor = theme.primaryColor;

    return GestureDetector(
      onTap: () {
        setState(() => selectedTrend = titleRaw);
        fetchAnalytics();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipColor),
        ),
        child: Text(
          titleRaw.tr(), // بنترجم هنا وقت العرض بس
          style: TextStyle(
            color: isSelected ? Colors.white : chipColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyChip(String nameRaw, Color color, ThemeData theme) {
    bool isSelected = selectedCompany == nameRaw;
    return GestureDetector(
      onTap: () {
        setState(() => selectedCompany = nameRaw);
        fetchAnalytics();
      },
      child: Container(
        // استخدمنا Directional عشان المسافات تتظبط في اللغتين
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          nameRaw.tr(), // بنترجم هنا وقت العرض بس
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String val, Color col, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          val,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: col,
          ),
        ),
      ],
    );
  }
}
