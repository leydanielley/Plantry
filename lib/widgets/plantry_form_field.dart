import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

/// Ein einheitliches Form-Feld für das Plantry Design System.
/// Nutzt DT.elevated als Hintergrund und bietet konsistente Radien und Textfarben.
class PlantryFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool autofocus;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final VoidCallback? onTap;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const PlantryFormField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.autofocus = false,
    this.suffixIcon,
    this.prefixIcon,
    this.onTap,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: DT.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          autofocus: autofocus,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          style: const TextStyle(color: DT.textPrimary, fontSize: 16),
          cursorColor: DT.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: DT.textTertiary, fontSize: 14),
            filled: true,
            fillColor: DT.elevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DT.radiusInput),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DT.radiusInput),
              borderSide: const BorderSide(color: DT.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DT.radiusInput),
              borderSide: const BorderSide(color: DT.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DT.radiusInput),
              borderSide: const BorderSide(color: DT.error, width: 1),
            ),
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}
