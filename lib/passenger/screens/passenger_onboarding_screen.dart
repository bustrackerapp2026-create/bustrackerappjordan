import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/analytics_service.dart';
import '../../services/route_prefs_service.dart';

/// شاشة أول مرة: اختيار الخط المعتاد للراكب.
class PassengerOnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const PassengerOnboardingScreen({super.key, required this.onFinished});

  @override
  State<PassengerOnboardingScreen> createState() =>
      _PassengerOnboardingScreenState();
}

class _PassengerOnboardingScreenState extends State<PassengerOnboardingScreen> {
  final _searchCtrl = TextEditingController();
  String? _selected;
  String _query = '';
  bool _saving = false;

  List<String> get _filtered {
    final q = _query.trim();
    if (q.isEmpty) return AppConstants.jordanRoutes;
    return AppConstants.jordanRoutes
        .where((r) => r.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final route = _selected;
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر خطاً أولاً')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await RoutePrefsService().savePreferredRoute(route);
      AnalyticsService().routeFilterChanged(route);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      widget.onFinished();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    try {
      await RoutePrefsService().skipOnboarding();
      if (!mounted) return;
      widget.onFinished();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    size: 36,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'مرحباً بك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر خطك المعتاد لنعرض باصاته مباشرة\nكل ما تفتح التطبيق',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الخط أو اسمه',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الخطوط',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: routes.isEmpty
                    ? Center(
                        child: Text(
                          'لا نتائج',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: routes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final route = routes[i];
                          final selected = _selected == route;
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selected = route);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.primaryColor
                                        : Colors.grey.shade200,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.route_rounded,
                                      color: selected
                                          ? AppTheme.primaryColor
                                          : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        route,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: selected
                                              ? AppTheme.primaryColor
                                              : AppTheme.textColor,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.primaryColor,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'حفظ والمتابعة',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _skip,
                child: Text(
                  'تخطي الآن',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
