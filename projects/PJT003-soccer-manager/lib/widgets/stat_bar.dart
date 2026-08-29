import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/settings_controller.dart';

class StatBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color? color;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 99,
    this.color,
  });

  static Color _autoColor(double ratio, bool colorblind) {
    if (colorblind) {
      if (ratio >= 0.75) return Colors.blue.shade700;
      if (ratio >= 0.5) return Colors.blue.shade300;
      if (ratio >= 0.3) return Colors.orange.shade400;
      return Colors.orange.shade900;
    }
    if (ratio >= 0.75) return Colors.green.shade600;
    if (ratio >= 0.5) return Colors.lightGreen.shade700;
    if (ratio >= 0.3) return Colors.orange.shade700;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (value / max).clamp(0, 1).toDouble();
    final colorblind = context.watch<SettingsController>().colorblindMode;
    final barColor = color ?? _autoColor(ratio, colorblind);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('$value',
                  style:
                      TextStyle(color: barColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}
