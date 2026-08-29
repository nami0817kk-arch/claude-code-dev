import 'package:flutter/services.dart';
import '../state/settings_controller.dart';

/// サウンド・触覚フィードバックをアプリ全体から呼び出すための小さなサービス。
/// SettingsControllerのON/OFF設定を尊重する。BuildContextを持たないロジック層
/// (試合画面のコールバックなど)からも呼べるよう、起動時に一度だけ設定を紐付ける。
class FeedbackService {
  static SettingsController? _settings;

  static void attach(SettingsController settings) {
    _settings = settings;
  }

  static bool get _hapticsOn => _settings?.hapticsEnabled ?? true;
  static bool get _soundOn => _settings?.soundEnabled ?? true;

  /// ボタンタップなど、軽い操作フィードバック。
  static void tap() {
    if (_hapticsOn) HapticFeedback.selectionClick();
  }

  /// 得点シーン。自クラブの得点かどうかで強さを変える。
  static void goal({required bool isUserGoal}) {
    if (_hapticsOn) {
      isUserGoal ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    }
    if (_soundOn) SystemSound.play(SystemSoundType.click);
  }

  /// 試合終了時の勝敗結果。
  static void matchResult({required bool won, required bool drew}) {
    if (_hapticsOn) {
      if (won) {
        HapticFeedback.heavyImpact();
      } else if (!drew) {
        HapticFeedback.vibrate();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
    if (_soundOn) SystemSound.play(SystemSoundType.click);
  }

  /// 契約更新・移籍成立など、達成感のある操作の完了通知。
  static void success() {
    if (_hapticsOn) HapticFeedback.mediumImpact();
    if (_soundOn) SystemSound.play(SystemSoundType.click);
  }

  /// 資金不足など、操作が失敗したことの通知。
  static void error() {
    if (_hapticsOn) HapticFeedback.heavyImpact();
  }
}
