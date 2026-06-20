import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;
  final IconData icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor.withValues(alpha: 0.8), size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: AppColors.textGrey.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
