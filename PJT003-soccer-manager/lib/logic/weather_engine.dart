import 'dart:math';
import '../models/weather.dart';

class WeatherEngine {
  static final Random _rng = Random();

  /// 試合ごとの天候をランダムに決定する。晴れが最も多く、荒天ほど稀になる。
  static Weather roll() {
    final r = _rng.nextDouble();
    if (r < 0.55) return Weather.clear;
    if (r < 0.75) return Weather.rain;
    if (r < 0.87) return Weather.wind;
    if (r < 0.96) return Weather.heatwave;
    return Weather.snow;
  }
}
