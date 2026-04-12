import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/translator.dart';


class SuccessOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const SuccessOverlay({super.key, required this.message, required this.onDismissed});

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();

  static void show(BuildContext context, String message, {VoidCallback? onComplete}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return _SuccessOverlayDialog(
          message: message,
          animation: anim1,
          onComplete: () {
            Navigator.of(context).pop();
            if (onComplete != null) onComplete();
          },
        );
      },
    );
  }
}

class _SuccessOverlayState extends State<SuccessOverlay> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // This is just a shell for the static method.
  }
}

class _SuccessOverlayDialog extends StatefulWidget {
  final String message;
  final Animation<double> animation;
  final VoidCallback onComplete;

  const _SuccessOverlayDialog({
    required this.message,
    required this.animation,
    required this.onComplete,
  });

  @override
  State<_SuccessOverlayDialog> createState() => _SuccessOverlayDialogState();
}

class _SuccessOverlayDialogState extends State<_SuccessOverlayDialog> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: widget.animation, curve: Curves.elasticOut),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981), // SahayaColors.emerald
                  size: 80,
                ),
                const SizedBox(height: 24),
                T(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
