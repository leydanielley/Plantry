// =============================================
// GROWLOG - Dashboard with Custom Icons
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/screens/plants_screen.dart';
import 'package:growlog_app/screens/grow_list_screen.dart';
import 'package:growlog_app/screens/room_list_screen.dart';
import 'package:growlog_app/screens/fertilizer_list_screen.dart';
import 'package:growlog_app/screens/harvest_list_screen.dart';
import 'package:growlog_app/screens/settings_screen.dart';
import 'package:growlog_app/screens/rdwc_systems_screen.dart';
import 'package:growlog_app/screens/nutrient_calculator_screen.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/app_state_recovery.dart';
import 'package:growlog_app/widgets/battery_optimization_dialog.dart';
import 'package:growlog_app/main.dart';
import 'package:growlog_app/di/service_locator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  AppTranslations _t = AppTranslations('de');
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
        _isLoading = false;
      });
      _fadeController.forward();

      // ✅ P0 FIX: Check for battery optimization issues
      final crashCount = await AppStateRecovery.getCrashCount();
      if (mounted) {
        await BatteryOptimizationDialog.showIfNeeded(context, crashCount);
      }
    }
  }

  void _onSettingsChanged(AppSettings newSettings) {
    setState(() {
      _t = AppTranslations(newSettings.language);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.grey)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(onSettingsChanged: _onSettingsChanged),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildCleanDashboard(),
    );
  }

  Widget _buildCleanDashboard() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: bottomPadding > 0 ? bottomPadding + 16 : 32,
        ),
        child: Column(
          children: [
            // Action Cards with Custom Icons
            _buildActionCard(
              'assets/icons/plant_icon.png',
              _t['plants'],
              _t['dashboard_plants_subtitle'], // ✅ i18n
              isDark,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PlantsScreen()),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              'assets/icons/grows_icon.png',
              _t['grows'],
              _t['dashboard_grows_subtitle'], // ✅ i18n
              isDark,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GrowListScreen()),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              'assets/icons/room_icon.png',
              _t['rooms'],
              _t['dashboard_rooms_subtitle'], // ✅ i18n
              isDark,
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RoomListScreen()),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              'assets/icons/fertilizer_icon.png',
              _t['fertilizers'],
              _t['dashboard_fertilizers_subtitle'], // ✅ i18n
              isDark,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FertilizerListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              'assets/icons/harvest_icon.png',
              _t['dashboard_harvests_title'], // ✅ i18n
              _t['dashboard_harvests_subtitle'], // ✅ i18n
              isDark,
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HarvestListScreen(),
                ),
              ),
            ),

            // RDWC Systems (Expert Mode Only)
            if (GrowLogApp.of(context)?.settings.isExpertMode ?? false) ...[
              const SizedBox(height: 12),
              _buildActionCard(
                'assets/icons/fertilizer_icon.png', // Reusing icon for now
                _t['rdwc_systems'],
                _t['dashboard_rdwc_subtitle'], // ✅ i18n
                isDark,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RdwcSystemsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                'assets/icons/fertilizer_icon.png', // Reusing icon for now
                _t['dashboard_nutrient_calculator'], // ✅ i18n
                _t['dashboard_nutrient_calculator_subtitle'], // ✅ i18n
                isDark,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NutrientCalculatorScreen(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌿', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  _t['dashboard_app_version'], // ✅ i18n
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String iconPath,
    String title,
    String subtitle,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFD0D0D0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    iconPath,
                    width: 54,
                    height: 54,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFD0D0D0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
