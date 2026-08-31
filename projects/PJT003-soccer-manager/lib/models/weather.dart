import 'package:flutter/material.dart';
import '../l10n/tr.dart';

/// 試合当日の天候。攻守のパフォーマンスやチャンスの数、疲労蓄積に影響する。
enum Weather { clear, rain, wind, heatwave, snow }

extension WeatherEffects on Weather {
  String get label => switch (this) {
        Weather.clear => Tr.pick('晴れ', 'Clear'),
        Weather.rain => Tr.pick('雨', 'Rain'),
        Weather.wind => Tr.pick('強風', 'Windy'),
        Weather.heatwave => Tr.pick('猛暑', 'Heatwave'),
        Weather.snow => Tr.pick('雪', 'Snow'),
      };

  /// 天候アイコン。絵文字ではなく Material アイコンを使う。
  /// 絵文字はアプリが同梱しているフォントに収録が無く、Web版では
  /// 端末に頼れないため豆腐(□)になってしまう。
  IconData get icon => switch (this) {
        Weather.clear => Icons.wb_sunny,
        Weather.rain => Icons.umbrella,
        Weather.wind => Icons.air,
        Weather.heatwave => Icons.thermostat,
        Weather.snow => Icons.ac_unit,
      };

  /// 攻撃力への倍率。悪天候ほどボールコントロール・シュート精度が落ちる。
  double get attackMultiplier => switch (this) {
        Weather.clear => 1.0,
        Weather.rain => 0.93,
        Weather.wind => 0.95,
        Weather.heatwave => 0.97,
        Weather.snow => 0.90,
      };

  /// 守備力への倍率。雨は攻め手が単調になる分、守備側がやや優位になる。
  double get defenseMultiplier => switch (this) {
        Weather.clear => 1.0,
        Weather.rain => 1.03,
        Weather.wind => 1.0,
        Weather.heatwave => 0.97,
        Weather.snow => 0.95,
      };

  /// 試合内で生まれるチャンスの総数への倍率。荒天は展開が単調になり
  /// チャンスの絶対数が減る。
  double get chanceCountMultiplier => switch (this) {
        Weather.clear => 1.0,
        Weather.rain => 0.9,
        Weather.wind => 0.95,
        Weather.heatwave => 1.0,
        Weather.snow => 0.8,
      };

  /// 疲労蓄積への倍率。猛暑は消耗が激しい。
  double get fatigueMultiplier => switch (this) {
        Weather.clear => 1.0,
        Weather.rain => 1.0,
        Weather.wind => 1.0,
        Weather.heatwave => 1.3,
        Weather.snow => 1.05,
      };
}
