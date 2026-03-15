// =============================================
// GROWLOG - Dashboard v11 — Premium HUD Evolution
// =============================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:growlog_app/screens/plants_screen.dart';
import 'package:growlog_app/screens/grow_list_screen.dart';
import 'package:growlog_app/screens/room_list_screen.dart';
import 'package:growlog_app/screens/fertilizer_list_screen.dart';
import 'package:growlog_app/screens/harvest_list_screen.dart';
import 'package:growlog_app/screens/settings_screen.dart';
import 'package:growlog_app/screens/rdwc_systems_screen.dart';
import 'package:growlog_app/screens/nutrient_calculator_screen.dart';
import 'package:growlog_app/screens/add_log_screen.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/app_state_recovery.dart';
import 'package:growlog_app/utils/app_version.dart';
import 'package:growlog_app/widgets/battery_optimization_dialog.dart';
import 'package:growlog_app/main.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/widgets/common/premium_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final IPlantLogRepository _logRepo = getIt<IPlantLogRepository>();

  AppTranslations _t = AppTranslations('de');
  bool _isLoading = true;
  int _plantCount = 0;
  int _growCount = 0;
  int _roomCount = 0;
  int _fertilizerCount = 0;
  int _harvestCount = 0;
  int _rdwcCount = 0;
  
  Map<PlantPhase, int> _phaseDistribution = {};
  Map<PlantPhase, double> _phaseAvgDays = {};
  List<Plant> _inactivePlants = [];
  String _lastActionTime = '—';

  late AnimationController _stagger;
  final List<Animation<double>> _fades = [];
  final List<Animation<Offset>> _slides = [];

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadData();
  }

  void _initAnims(int n) {
    _fades.clear(); _slides.clear();
    for (int i = 0; i < n; i++) {
      final s = (i * 0.08).clamp(0.0, 0.6);
      _fades.add(Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _stagger, curve: Interval(s, (s + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut))));
      _slides.add(Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _stagger, curve: Interval(s, (s + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutCubic))));
    }
  }

  @override
  void dispose() { _stagger.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final settings = await _settingsRepo.getSettings();
    final plants = await _plantRepo.findAll();
    final recentLogs = await _logRepo.getRecentActivity(limit: 1);
    
    final res = await Future.wait([
      _plantRepo.count(), 
      _growRepo.getAll().then((l) => l.length), 
      _roomRepo.count(),
      _fertilizerRepo.count(),
      _harvestRepo.getHarvestCount(),
      _rdwcRepo.getAllSystems().then((l) => l.length),
    ]);

    final Map<PlantPhase, int> dist = {};
    for (final p in plants) { dist[p.phase] = (dist[p.phase] ?? 0) + 1; }

    // Feature 2: Phase average days
    final Map<PlantPhase, List<int>> phaseDaysMap = {};
    for (final p in plants) {
      DateTime? ref;
      switch (p.phase) {
        case PlantPhase.veg:
          ref = p.vegDate ?? p.phaseStartDate;
          break;
        case PlantPhase.bloom:
          ref = p.bloomDate ?? p.phaseStartDate;
          break;
        case PlantPhase.seedling:
        case PlantPhase.harvest:
        case PlantPhase.archived:
          ref = p.phaseStartDate;
          break;
      }
      if (ref != null) {
        final days = DateTime.now().difference(ref).inDays;
        phaseDaysMap.putIfAbsent(p.phase, () => []).add(days);
      }
    }
    final Map<PlantPhase, double> avgDays = {};
    phaseDaysMap.forEach((phase, daysList) {
      avgDays[phase] = daysList.reduce((a, b) => a + b) / daysList.length;
    });

    // Feature 5: 48h inactivity check (parallel)
    final List<Plant> inactivePlants = [];
    if (plants.isNotEmpty) {
      final lastLogs = await Future.wait(
        plants.map((p) => _logRepo.getLastLogForPlant(p.id!)),
      );
      for (int i = 0; i < plants.length; i++) {
        final log = lastLogs[i];
        if (log == null || DateTime.now().difference(log.logDate).inHours >= 48) {
          inactivePlants.add(plants[i]);
        }
      }
    }

    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
        _plantCount = res[0]; _growCount = res[1]; _roomCount = res[2];
        _fertilizerCount = res[3]; _harvestCount = res[4]; _rdwcCount = res[5];
        _phaseDistribution = dist;
        _phaseAvgDays = avgDays;
        _inactivePlants = inactivePlants;
        if (recentLogs.isNotEmpty) {
          final diff = DateTime.now().difference(recentLogs.first.logDate);
          if (diff.inHours < 1) {
            _lastActionTime = '${diff.inMinutes}M';
          } else if (diff.inDays < 1) {
            _lastActionTime = '${diff.inHours}H';
          } else {
            _lastActionTime = '${diff.inDays}D';
          }
        }
        _isLoading = false;
      });
      _initAnims(14); _stagger.forward();
      final cc = await AppStateRecovery.getCrashCount();
      if (mounted) await BatteryOptimizationDialog.showIfNeeded(context, cc);
    }
  }

  void _onSettingsChanged(AppSettings s) { setState(() { _t = AppTranslations(s.language); }); }

  Widget _anim(int i, Widget child) {
    if (i >= _fades.length) return child;
    return AnimatedBuilder(
      animation: _stagger,
      builder: (_, sw) => Opacity(opacity: _fades[i].value, child: SlideTransition(position: _slides[i], child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: DT.canvas, body: Center(child: CircularProgressIndicator(color: DT.accent)));

    final top = MediaQuery.of(context).padding.top;
    final expert = GrowLogApp.of(context)?.settings.isExpertMode ?? false;

    return Scaffold(
      backgroundColor: DT.canvas,
      body: Stack(
        children: [
          Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(color: DT.accent.withValues(alpha: 0.025), shape: BoxShape.circle), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)))),
          
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, top + 24, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _anim(0, _Header(t: _t)),
                const SizedBox(height: 12),
                
                _anim(1, SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    const PlantryHudItem(label: 'Status', value: 'SYSTEM OK', color: DT.accent),
                    const SizedBox(width: 8),
                    PlantryHudItem(label: 'Letzter Log', value: _lastActionTime, color: DT.secondary),
                    const SizedBox(width: 8),
                    PlantryHudItem(label: 'Grows', value: '$_growCount', color: DT.info),
                  ]),
                )),
                const SizedBox(height: 32),

                _anim(2, Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Row(
                    children: [
                      QuickActionBubble(icon: Icons.water_drop_outlined, color: Colors.blue, onTap: _quickWater),
                      const SizedBox(width: 12),
                      QuickActionBubble(icon: Icons.camera_alt_outlined, color: DT.accent, onTap: _quickPhoto),
                      const SizedBox(width: 12),
                      QuickActionBubble(icon: Icons.edit_note_outlined, color: DT.warning, onTap: _quickNote),
                    ],
                  ),
                )),

                if (_inactivePlants.isNotEmpty)
                  _anim(12, Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        if (_inactivePlants.length == 1) {
                          _startQuickLogForPlant(_inactivePlants.first);
                        } else {
                          _showInactivePlantsSheet();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: DT.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DT.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: DT.warning, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t['plants_without_log'].replaceAll('{count}', '${_inactivePlants.length}'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DT.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _inactivePlants.length == 1
                                        ? _inactivePlants.first.name
                                        : _t['inactive_plants_tap_to_log'],
                                    style: const TextStyle(fontSize: 11, color: DT.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: DT.warning, size: 18),
                          ],
                        ),
                      ),
                    ),
                  )),

                _anim(3, PlantryPremiumCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantsScreen())).then((_) => _loadData()),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          Container(width: 60, height: 60, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: DT.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Image.asset('assets/icons/plant_icon.png')),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_t['plants'].toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: DT.textSecondary, letterSpacing: 1)),
                            Text('$_plantCount ${_t['plants'].toUpperCase()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DT.textPrimary)),
                          ])),
                          const Icon(Icons.arrow_forward_ios, color: DT.textTertiary, size: 16),
                        ]),
                      ),
                      _buildPhaseStatusBar(),
                      _buildPhaseTimerRow(),
                    ],
                  ),
                )),
                const SizedBox(height: 16),

                _anim(4, Row(children: [
                  Expanded(child: _GridTile(icon: 'assets/icons/grows_icon.png', label: _t['grows'], stat: _growCount, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrowListScreen())).then((_) => _loadData()))),
                  const SizedBox(width: 12),
                  Expanded(child: _GridTile(icon: 'assets/icons/room_icon.png', label: _t['rooms'], stat: _roomCount, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomListScreen())).then((_) => _loadData()))),
                ])),
                const SizedBox(height: 12),

                _anim(5, Row(children: [
                  Expanded(child: _GridTile(icon: 'assets/icons/fertilizer_icon.png', label: _t['fertilizers'], stat: _fertilizerCount, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FertilizerListScreen())).then((_) => _loadData()))),
                  const SizedBox(width: 12),
                  Expanded(child: _GridTile(icon: 'assets/icons/harvest_icon.png', label: _t['harvests'], stat: _harvestCount, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HarvestListScreen())).then((_) => _loadData()))),
                ])),
                
                if (expert) ...[
                  const SizedBox(height: 32),
                  _anim(6, const Text('RDWC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: DT.textTertiary, letterSpacing: 2))),
                  const SizedBox(height: 16),
                  _anim(7, Row(children: [
                    Expanded(child: _GridTile(icon: 'assets/icons/rdwc_icon.png', label: 'RDWC', stat: _rdwcCount, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RdwcSystemsScreen())).then((_) => _loadData()))),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ])),
                  const SizedBox(height: 32),
                  _anim(8, Text(_t['system_tools'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: DT.textTertiary, letterSpacing: 2))),
                  const SizedBox(height: 16),
                  _anim(9, Row(children: [
                    Expanded(child: _GridTile(iconWidget: const Icon(Icons.calculate_outlined, color: DT.warning, size: 40), label: _t['calculator_action'], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NutrientCalculatorScreen())).then((_) => _loadData()))),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ])),
                ],

                const SizedBox(height: 48),
                _anim(8, PlantryPremiumCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onSettingsChanged: _onSettingsChanged))).then((_) => _loadData()),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(children: [
                    const Icon(Icons.tune_rounded, size: 20, color: DT.textSecondary),
                    const SizedBox(width: 16),
                    Text(_t['settings'].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DT.textSecondary, letterSpacing: 1)),
                    const Spacer(),
                    Text('v${AppVersion.versionWithoutBuild}', style: const TextStyle(fontSize: 10, color: DT.textTertiary)),
                  ]),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseStatusBar() {
    if (_plantCount == 0) return const SizedBox.shrink();
    return Container(
      height: 4, width: double.infinity,
      color: Colors.white.withValues(alpha: 0.05),
      child: Row(
        children: [
          _barPart(PlantPhase.seedling, Colors.lightGreen),
          _barPart(PlantPhase.veg, Colors.green),
          _barPart(PlantPhase.bloom, Colors.purple),
          _barPart(PlantPhase.harvest, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildPhaseTimerRow() {
    if (_plantCount == 0 || _phaseAvgDays.isEmpty) return const SizedBox.shrink();

    final phaseLabels = {
      PlantPhase.seedling: 'SEEDLING',
      PlantPhase.veg: 'VEG',
      PlantPhase.bloom: 'BLÜTE',
      PlantPhase.harvest: 'HARVEST',
    };
    final orderedPhases = [PlantPhase.seedling, PlantPhase.veg, PlantPhase.bloom, PlantPhase.harvest];

    final parts = <String>[];
    for (final phase in orderedPhases) {
      if (_phaseAvgDays.containsKey(phase)) {
        final avg = _phaseAvgDays[phase]!.round();
        parts.add('${phaseLabels[phase]} • ⌀ ${avg}T');
      }
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        parts.join('   '),
        style: const TextStyle(
          fontSize: 10,
          color: DT.textTertiary,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _barPart(PlantPhase phase, Color color) {
    final count = _phaseDistribution[phase] ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Expanded(flex: count, child: Container(color: color));
  }

  // --- Quick Actions Logic ---
  Future<void> _quickWater() async => _startQuickLog(ActionType.water);
  Future<void> _quickPhoto() async => _startQuickLog(ActionType.note);
  Future<void> _quickNote() async => _startQuickLog(ActionType.note);

  Future<void> _startQuickLog(ActionType type) async {
    final plants = await _plantRepo.findAll();
    if (plants.isEmpty) return;
    
    if (mounted) {
      final sel = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(_t['select_plant_title'], style: const TextStyle(color: DT.textPrimary)),
        content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: plants.length, itemBuilder: (ctx, i) => ListTile(title: Text(plants[i].name, style: const TextStyle(color: DT.textPrimary)), onTap: () => Navigator.pop(ctx, plants[i].id)))),
      ));
      
      if (sel != null && mounted) {
        final p = plants.firstWhere((p) => p.id == sel);
        Navigator.push(context, MaterialPageRoute(builder: (_) => AddLogScreen(plant: p))).then((_) => _loadData());
      }
    }
  }

  Future<void> _startQuickLogForPlant(Plant plant) async {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddLogScreen(plant: plant))).then((_) => _loadData());
  }

  Future<void> _showInactivePlantsSheet() async {
    if (!mounted) return;
    final Plant? selected = await showModalBottomSheet<Plant>(
      context: context,
      backgroundColor: DT.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.radiusCard)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DT.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _t['select_plant_title'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DT.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _inactivePlants.length,
                  itemBuilder: (ctx, i) {
                    final plant = _inactivePlants[i];
                    return ListTile(
                      leading: const Icon(Icons.local_florist_outlined, color: DT.warning, size: 20),
                      title: Text(
                        plant.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DT.textPrimary,
                        ),
                      ),
                      subtitle: plant.strain != null
                          ? Text(
                              plant.strain!,
                              style: const TextStyle(fontSize: 12, color: DT.textSecondary),
                            )
                          : null,
                      onTap: () => Navigator.pop(ctx, plant),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      _startQuickLogForPlant(selected);
    }
  }
}

class _Header extends StatelessWidget {
  final AppTranslations t;
  const _Header({required this.t});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('PLANTRY', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: DT.textPrimary, letterSpacing: -1)),
          const SizedBox(width: 6),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: DT.accent, shape: BoxShape.circle)),
        ]),
        const Text('PLANT HEALTH TRACKER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DT.accent, letterSpacing: 2)),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  final String? icon;
  final Widget? iconWidget;
  final String label;
  final int? stat;
  final VoidCallback onTap;
  const _GridTile({this.icon, this.iconWidget, required this.label, this.stat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PlantryPremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          if (stat != null)
            Positioned(
              top: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: DT.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('$stat', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: DT.accent)),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              if (icon != null) Image.asset(icon!, width: 44, height: 44, fit: BoxFit.contain)
              else if (iconWidget != null) iconWidget!,
              const SizedBox(height: 16),
              Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: DT.textPrimary, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}
