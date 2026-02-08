// =============================================
// EXAMPLE: Using PhasePlantIcon in Plant Cards
// =============================================

/*
 * Beispiel-Verwendung des neuen PlantPotIcon in den Plant Cards
 * 
 * VORHER (mit Emoji in Container):
 * 
 * Container(
 *   padding: const EdgeInsets.all(14),
 *   decoration: BoxDecoration(
 *     color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD0D0D0),
 *     borderRadius: BorderRadius.circular(12),
 *   ),
 *   child: Text(
 *     _getPhaseEmoji(plant.phase),  // 🌱, 🌿, 🌸, ✂️, 📦
 *     style: const TextStyle(fontSize: 28),
 *   ),
 * ),
 * 
 * 
 * NACHHER (mit PlantPotIcon):
 * 
 * Container(
 *   padding: const EdgeInsets.all(8),
 *   decoration: BoxDecoration(
 *     color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD0D0D0),
 *     borderRadius: BorderRadius.circular(12),
 *   ),
 *   child: PhasePlantIcon(
 *     phase: plant.phase,
 *     size: 40,
 *   ),
 * ),
 * 
 * 
 * ALTERNATIV (wenn du mehr Kontrolle willst):
 * 
 * PlantPotIcon(
 *   size: 40,
 *   leavesColor: _getPhaseColor(plant.phase),
 *   stemColor: _getPhaseColor(plant.phase).darken(0.3),
 *   potColor: isDark ? const Color(0xFF78909C) : const Color(0xFF90A4AE),
 * )
 */

// =============================================
// INTEGRATION IN plants_screen.dart
// =============================================

/*
 * Ersetze in _buildPlantCard():
 * 
 * VON:
 * 
 * Container(
 *   padding: const EdgeInsets.all(14),
 *   decoration: BoxDecoration(
 *     color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD0D0D0),
 *     borderRadius: BorderRadius.circular(12),
 *   ),
 *   child: Text(
 *     _getPhaseEmoji(plant.phase),
 *     style: const TextStyle(fontSize: 28),
 *   ),
 * ),
 * 
 * 
 * ZU:
 * 
 * Container(
 *   padding: const EdgeInsets.all(8),
 *   decoration: BoxDecoration(
 *     color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD0D0D0),
 *     borderRadius: BorderRadius.circular(12),
 *   ),
 *   child: PhasePlantIcon(
 *     phase: plant.phase,
 *     size: 44,
 *   ),
 * ),
 */

// =============================================
// FARB-SCHEMA nach Phase
// =============================================

/*
 * SEEDLING (Keimling) 🌱
 * - Leaves: Light Green (#81C784)
 * - Stem: Light Brown (#8D6E63)
 * - Pot: Light Blue Grey (#90A4AE)
 * 
 * VEG (Wachstum) 🌿
 * - Leaves: Strong Green (#4CAF50)
 * - Stem: Brown (#6D4C41)
 * - Pot: Blue Grey (#78909C)
 * 
 * BLOOM (Blüte) 🌸
 * - Leaves: Purple (#9C27B0)
 * - Stem: Dark Purple (#4A148C)
 * - Pot: Light Purple (#7E57C2)
 * 
 * HARVEST (Ernte) ✂️
 * - Leaves: Orange (#FF9800)
 * - Stem: Dark Orange (#E65100)
 * - Pot: Light Orange (#FFB74D)
 * 
 * ARCHIVED (Archiviert) 📦
 * - Leaves: Grey (#9E9E9E)
 * - Stem: Dark Grey (#616161)
 * - Pot: Grey (#757575)
 */

// =============================================
// WEITERE VERWENDUNGEN
// =============================================

/*
 * 1. IN GROW HEADERS (statt 🌱 Emoji):
 * 
 * Text(
 *   growId == null ? '🌿' : '🌱',
 *   style: const TextStyle(fontSize: 32),
 * ),
 * 
 * WIRD ZU:
 * 
 * PlantPotIcon(
 *   size: 32,
 *   leavesColor: growId == null 
 *       ? const Color(0xFF4CAF50)  // 🌿 Veg-Farben
 *       : const Color(0xFF81C784), // 🌱 Seedling-Farben
 * )
 * 
 * 
 * 2. IN FLOATING ACTION BUTTONS:
 * 
 * FloatingActionButton(
 *   onPressed: () => _addPlant(),
 *   child: PlantPotIcon(
 *     size: 28,
 *     leavesColor: Colors.white,
 *     stemColor: Colors.white70,
 *     potColor: Colors.white60,
 *   ),
 * )
 * 
 * 
 * 3. IN APP BAR:
 * 
 * AppBar(
 *   title: Row(
 *     children: [
 *       PlantPotIcon(size: 24),
 *       const SizedBox(width: 8),
 *       const Text('Growlogger9000'),
 *     ],
 *   ),
 * )
 * 
 * 
 * 4. IN BOTTOM NAVIGATION:
 * 
 * BottomNavigationBarItem(
 *   icon: PlantPotIcon(
 *     size: 24,
 *     leavesColor: Colors.grey,
 *   ),
 *   activeIcon: PlantPotIcon(
 *     size: 24,
 *     leavesColor: Colors.green,
 *   ),
 *   label: 'Pflanzen',
 * )
 */
