import '../models/player.dart';

enum Formation {
  f442,
  f433,
  f4231,
  f352,
  f4141,
  f343,
  f4411,
  f4321,
  f541,
  f424
}

extension FormationInfo on Formation {
  String get label {
    switch (this) {
      case Formation.f442:
        return '4-4-2';
      case Formation.f433:
        return '4-3-3';
      case Formation.f4231:
        return '4-2-3-1';
      case Formation.f352:
        return '3-5-2';
      case Formation.f4141:
        return '4-1-4-1';
      case Formation.f343:
        return '3-4-3';
      case Formation.f4411:
        return '4-4-1-1';
      case Formation.f4321:
        return '4-3-2-1';
      case Formation.f541:
        return '5-4-1';
      case Formation.f424:
        return '4-2-4';
    }
  }

  /// フォーメーションを構成する具体的な11ポジション。
  List<Position> get slots {
    switch (this) {
      case Formation.f442:
        return const [
          Position.gk,
          Position.dr,
          Position.dc,
          Position.dc,
          Position.dl,
          Position.mr,
          Position.mc,
          Position.mc,
          Position.ml,
          Position.st,
          Position.st,
        ];
      case Formation.f433:
        return const [
          Position.gk,
          Position.dr,
          Position.dc,
          Position.dc,
          Position.dl,
          Position.mc,
          Position.mc,
          Position.mc,
          Position.amr,
          Position.aml,
          Position.st,
        ];
      case Formation.f4231:
        return const [
          Position.gk,
          Position.dr,
          Position.dc,
          Position.dc,
          Position.dl,
          Position.dm,
          Position.dm,
          Position.amr,
          Position.amc,
          Position.aml,
          Position.st,
        ];
      case Formation.f352:
        return const [
          Position.gk,
          Position.dc,
          Position.dc,
          Position.dc,
          Position.wbr,
          Position.mc,
          Position.mc,
          Position.mc,
          Position.wbl,
          Position.st,
          Position.st,
        ];
      case Formation.f4141:
        return const [
          Position.gk,
          Position.dr,
          Position.dc,
          Position.dc,
          Position.dl,
          Position.dm,
          Position.mr,
          Position.mc,
          Position.mc,
          Position.ml,
          Position.st,
        ];
      case Formation.f343:
        return const [
          Position.gk,
          Position.dc,
          Position.dc,
          Position.dc,
          Position.wbr,
          Position.mc,
          Position.mc,
          Position.wbl,
          Position.amr,
          Position.aml,
          Position.st,
        ];
      case Formation.f4411:
        return const [
          Position.gk,
          Position.dr,
          Position.dc,
          Position.dc,
          Position.dl,
          Position.mr,
          Position.mc,
          Position.mc,
          Position.ml,
          Position.amc,
          Position.st,
        ];
      case Formation.f4321:
        return const [
          Position.gk,
          Position.dr,
          Position.dc,
          Position.dc,
          Position.dl,
          Position.dm,
          Position.mc,
          Position.mc,
          Position.amr,
          Position.aml,
          Position.st,
        ];
      case Formation.f541:
        return const [
          Position.gk,
          Position.wbr,
          Position.dc,
          Position.dc,
          Position.dc,
          Position.wbl,
          Position.mr,
          Position.mc,
          Position.mc,
          Position.ml,
          Position.st,
        ];
      case Formation.f424:
        return const [
          Position.gk,
          Position.dr,
          Position.dc,
          Position.dc,
          Position.dl,
          Position.dm,
          Position.dm,
          Position.amr,
          Position.aml,
          Position.st,
          Position.st,
        ];
    }
  }

  /// このフォーメーションで特定ポジションが必要な人数。
  int quotaFor(Position position) => slots.where((p) => p == position).length;

  double get attackBias {
    switch (this) {
      case Formation.f442:
        return 1.0;
      case Formation.f433:
        return 1.08;
      case Formation.f4231:
        return 0.98;
      case Formation.f352:
        return 1.05;
      case Formation.f4141:
        return 0.95;
      case Formation.f343:
        return 1.12;
      case Formation.f4411:
        return 0.97;
      case Formation.f4321:
        return 1.06;
      case Formation.f541:
        return 0.85;
      case Formation.f424:
        return 1.2;
    }
  }

  double get defenseBias {
    switch (this) {
      case Formation.f442:
        return 1.0;
      case Formation.f433:
        return 0.94;
      case Formation.f4231:
        return 1.08;
      case Formation.f352:
        return 0.97;
      case Formation.f4141:
        return 1.1;
      case Formation.f343:
        return 0.9;
      case Formation.f4411:
        return 1.05;
      case Formation.f4321:
        return 0.96;
      case Formation.f541:
        return 1.18;
      case Formation.f424:
        return 0.8;
    }
  }
}
