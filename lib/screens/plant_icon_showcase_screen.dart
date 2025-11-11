// =============================================
// GROWLOG - Plant Icon Showcase Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/icons/plant_pot_icon.dart';

class PlantIconShowcaseScreen extends StatelessWidget {
  const PlantIconShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Pot Icon Showcase'),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const PlantPotIcon(size: 200),
              ),
            ),

            const SizedBox(height: 32),

            // Size variations
            const Text(
              'Size Variations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildVariation('Small', const PlantPotIcon(size: 40)),
                _buildVariation('Medium', const PlantPotIcon(size: 80)),
                _buildVariation('Large', const PlantPotIcon(size: 120)),
              ],
            ),

            const SizedBox(height: 32),

            // Color variations
            const Text(
              'Color Variations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Default colors
            _buildColorVariation('Default', const PlantPotIcon(size: 100)),

            const SizedBox(height: 16),

            // Dark leaves
            _buildColorVariation(
              'Dark Green',
              const PlantPotIcon(
                size: 100,
                leavesColor: Color(0xFF2E7D32),
                potColor: Color(0xFF546E7A),
              ),
            ),

            const SizedBox(height: 16),

            // Light leaves
            _buildColorVariation(
              'Light Green',
              const PlantPotIcon(
                size: 100,
                leavesColor: Color(0xFF81C784),
                potColor: Color(0xFF90A4AE),
              ),
            ),

            const SizedBox(height: 16),

            // Purple variation
            _buildColorVariation(
              'Purple (Bloom)',
              const PlantPotIcon(
                size: 100,
                leavesColor: Color(0xFF9C27B0),
                stemColor: Color(0xFF4A148C),
                potColor: Color(0xFF7E57C2),
              ),
            ),

            const SizedBox(height: 16),

            // Orange variation
            _buildColorVariation(
              'Orange (Harvest)',
              const PlantPotIcon(
                size: 100,
                leavesColor: Color(0xFFFF9800),
                stemColor: Color(0xFFE65100),
                potColor: Color(0xFFFFB74D),
              ),
            ),

            const SizedBox(height: 32),

            // Usage examples
            const Text(
              'Usage in App',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Card with icon
            Card(
              child: ListTile(
                leading: const PlantPotIcon(size: 48),
                title: const Text('My Cannabis Plant'),
                subtitle: const Text('Day 45 • Vegetative'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {},
              ),
            ),

            const SizedBox(height: 12),

            // Empty state
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PlantPotIcon(size: 80),
                    SizedBox(height: 16),
                    Text(
                      'Keine Pflanzen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Erstelle deine erste Pflanze!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVariation(String label, Widget icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon,
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildColorVariation(String label, Widget icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
