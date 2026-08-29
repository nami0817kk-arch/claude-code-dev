import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/settings_controller.dart';

/// 「良い/悪い」を色だけで伝える箇所向けの配色ヘルパー。
/// 色覚サポートモードが有効な場合、赤緑ではなく青とオレンジを使う。
class SemanticColors {
  static bool _colorblind(BuildContext context) =>
      context.watch<SettingsController>().colorblindMode;

  static Color positive(BuildContext context) =>
      _colorblind(context) ? Colors.blue.shade700 : Colors.green.shade600;

  static Color negative(BuildContext context) =>
      _colorblind(context) ? Colors.orange.shade800 : Colors.redAccent;

  static Color neutral(BuildContext context) => Colors.blueGrey;
}
