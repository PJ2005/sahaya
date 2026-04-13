import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SahayaColors.coral.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: SahayaColors.coral,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          T(
            'See you soon!',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : SahayaColors.darkSurface,
            ),
          ),
          const SizedBox(height: 12),
          T(
            'Are you sure you want to log out from Sahaya? You can always come back and help more.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: T(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : SahayaColors.lightMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SahayaColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: T(
                    'Logout',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => const LogoutDialog(),
        ) ??
        false;
  }
}
