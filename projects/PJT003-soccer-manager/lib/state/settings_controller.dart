import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';

/// アプリ全体の表示・操作設定(テーマ/文字サイズ/サウンド/触覚/オンボーディング済みフラグ)。
/// セーブデータとは独立してSharedPreferencesに永続化する。
class SettingsController extends ChangeNotifier {
  static const _themeModeKey = 'settings_theme_mode';
  static const _textScaleKey = 'settings_text_scale';
  static const _soundEnabledKey = 'settings_sound_enabled';
  static const _hapticsEnabledKey = 'settings_haptics_enabled';
  static const _onboardingSeenKey = 'settings_onboarding_seen';
  static const _colorblindModeKey = 'settings_colorblind_mode';
  static const _boldTextModeKey = 'settings_bold_text_mode';
  static const _languageKey = 'settings_language';

  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.3;

  bool initialized = false;
  ThemeMode themeMode = ThemeMode.system;
  double textScale = 1.0;
  bool soundEnabled = true;
  bool hapticsEnabled = true;
  bool hasSeenOnboarding = false;

  /// 色覚サポートモード。勝敗などの色分け表現を、赤緑ではなく青とオレンジに置き換える。
  bool colorblindMode = false;

  /// 太字強調モード。文字を全体的に太くして視認性を高める。
  bool boldTextMode = false;

  /// 表示言語。既定は端末の設定に従う。
  ///
  /// この値は `Tr.language` にも書き戻す。ウィジェットの外(モデルやニュース文)は
  /// BuildContextを取れず `Tr` を直接読むため、両者がずれないようにする。
  AppLanguage language = AppLanguage.system;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_themeModeKey);
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => ThemeMode.system,
    );
    textScale = prefs.getDouble(_textScaleKey) ?? 1.0;
    soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    hapticsEnabled = prefs.getBool(_hapticsEnabledKey) ?? true;
    hasSeenOnboarding = prefs.getBool(_onboardingSeenKey) ?? false;
    colorblindMode = prefs.getBool(_colorblindModeKey) ?? false;
    boldTextMode = prefs.getBool(_boldTextModeKey) ?? false;
    final languageName = prefs.getString(_languageKey);
    language = AppLanguage.values.firstWhere(
      (l) => l.name == languageName,
      orElse: () => AppLanguage.system,
    );
    Tr.language = language;
    initialized = true;
    notifyListeners();
  }

  /// MaterialApp に渡す言語コード。端末準拠のときはnull。
  String? get localeCode => Tr.localeCode;

  Future<void> setLanguage(AppLanguage value) async {
    language = value;
    Tr.language = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> setTextScale(double scale) async {
    textScale = scale.clamp(minTextScale, maxTextScale);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, textScale);
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    hapticsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsEnabledKey, value);
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    hasSeenOnboarding = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, value);
  }

  Future<void> setColorblindMode(bool value) async {
    colorblindMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_colorblindModeKey, value);
  }

  Future<void> setBoldTextMode(bool value) async {
    boldTextMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_boldTextModeKey, value);
  }
}
