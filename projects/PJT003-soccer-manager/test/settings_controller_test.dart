import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/state/settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SettingsController.init loads sensible defaults on first launch',
      () async {
    final settings = SettingsController();
    await settings.init();

    expect(settings.initialized, isTrue);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.textScale, 1.0);
    expect(settings.soundEnabled, isTrue);
    expect(settings.hapticsEnabled, isTrue);
    expect(settings.hasSeenOnboarding, isFalse);
    expect(settings.colorblindMode, isFalse);
    expect(settings.boldTextMode, isFalse);
  });

  test('SettingsController persists changes across a fresh instance', () async {
    final settings = SettingsController();
    await settings.init();
    await settings.setThemeMode(ThemeMode.dark);
    await settings.setTextScale(1.5);
    await settings.setSoundEnabled(false);
    await settings.setHapticsEnabled(false);
    await settings.setHasSeenOnboarding(true);
    await settings.setColorblindMode(true);
    await settings.setBoldTextMode(true);

    final reloaded = SettingsController();
    await reloaded.init();

    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.textScale, SettingsController.maxTextScale);
    expect(reloaded.soundEnabled, isFalse);
    expect(reloaded.hapticsEnabled, isFalse);
    expect(reloaded.hasSeenOnboarding, isTrue);
    expect(reloaded.colorblindMode, isTrue);
    expect(reloaded.boldTextMode, isTrue);
  });

  test('SettingsController.setTextScale clamps to the allowed range', () async {
    final settings = SettingsController();
    await settings.init();

    await settings.setTextScale(10.0);
    expect(settings.textScale, SettingsController.maxTextScale);

    await settings.setTextScale(0.1);
    expect(settings.textScale, SettingsController.minTextScale);
  });
}
