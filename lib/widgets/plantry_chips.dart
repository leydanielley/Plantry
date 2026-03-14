import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

/// Ein einheitlicher Filter-Chip für das Plantry Design System.
class PlantryFilterChips extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const PlantryFilterChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? DT.accent : DT.surface,
                borderRadius: BorderRadius.circular(DT.radiusChip),
                border: Border.all(
                  color: isSelected
                      ? DT.accent
                      : DT.border,
                ),
                boxShadow: isSelected 
                    ? [BoxShadow(color: DT.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Center(
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: isSelected ? DT.onAccent : DT.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
