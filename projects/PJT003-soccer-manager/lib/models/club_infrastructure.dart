import '../l10n/tr.dart';

/// チケット価格戦略。値上げは1人あたり収入を増やす一方で観客動員率を下げ、
/// 値下げはその逆になる(合計の増収効果は保証されない)。
enum TicketPricing { budget, standard, premium }

extension TicketPricingInfo on TicketPricing {
  String get label => switch (this) {
        TicketPricing.budget => Tr.pick('低価格', 'Cheap'),
        TicketPricing.standard => Tr.pick('標準', 'Standard'),
        TicketPricing.premium => Tr.pick('高価格', 'Expensive'),
      };

  String get description => switch (this) {
        TicketPricing.budget => Tr.pick('観客動員率+15%だが、1人あたり収入-25%',
            'Attendance +15%, but revenue per head -25%'),
        TicketPricing.standard => Tr.pick('標準の価格設定', 'The standard pricing'),
        TicketPricing.premium => Tr.pick('1人あたり収入+30%だが、観客動員率-20%',
            'Revenue per head +30%, but attendance -20%'),
      };

  /// 観客動員率に対する倍率。
  double get attendanceMultiplier => switch (this) {
        TicketPricing.budget => 1.15,
        TicketPricing.standard => 1.0,
        TicketPricing.premium => 0.8,
      };

  /// 試合収入(観客動員数に依存する部分)に対する倍率。
  double get revenueMultiplier => switch (this) {
        TicketPricing.budget => 0.75,
        TicketPricing.standard => 1.0,
        TicketPricing.premium => 1.3,
      };
}

enum StaffRole { headCoach, scout, physio, youthCoach, fitnessCoach }

extension StaffRoleInfo on StaffRole {
  String get label => switch (this) {
        StaffRole.headCoach => Tr.pick('ヘッドコーチ', 'Head Coach'),
        StaffRole.scout => Tr.pick('スカウト', 'Scout'),
        StaffRole.physio => Tr.pick('フィジオ', 'Physio'),
        StaffRole.youthCoach => Tr.pick('ユースコーチ', 'Youth Coach'),
        StaffRole.fitnessCoach => Tr.pick('フィットネスコーチ', 'Fitness Coach'),
      };

  String get description => switch (this) {
        StaffRole.headCoach => Tr.pick(
            'トレーニングの成長効率を高める', 'Raises how much players gain from training'),
        StaffRole.scout => Tr.pick('スカウト選手の質を高め、費用を抑える',
            'Raises the quality of scouted players and lowers the cost'),
        StaffRole.physio => Tr.pick('負傷の発生率と療養期間を減らす',
            'Cuts how often injuries happen and how long they last'),
        StaffRole.youthCoach =>
          Tr.pick('アカデミー昇格候補の質を高める', 'Raises the quality of academy graduates'),
        StaffRole.fitnessCoach => Tr.pick('週次トレーニングでの疲労回復量をさらに高める',
            'Further increases how much fatigue the weekly training recovers'),
      };
}

enum FacilityType {
  trainingGround,
  stadium,
  youthFacility,
  commercialFacility,
  medicalCenter,
}

extension FacilityTypeInfo on FacilityType {
  String get label => switch (this) {
        FacilityType.trainingGround =>
          Tr.pick('トレーニング施設', 'Training Facilities'),
        FacilityType.stadium => Tr.pick('スタジアム', 'Stadium'),
        FacilityType.youthFacility => Tr.pick('ユース施設', 'Youth Facilities'),
        FacilityType.commercialFacility =>
          Tr.pick('商業施設', 'Commercial Facilities'),
        FacilityType.medicalCenter => Tr.pick('メディカルセンター', 'Medical Centre'),
      };

  String get description => switch (this) {
        FacilityType.trainingGround => Tr.pick(
            '選手の成長速度と疲労回復を高める', 'Speeds up player growth and fatigue recovery'),
        FacilityType.stadium =>
          Tr.pick('試合ごとの観客収入を増やす', 'Increases gate receipts from each match'),
        FacilityType.youthFacility => Tr.pick('ユース昇格候補の受け入れ枠を増やす',
            'Increases how many academy graduates you can take on'),
        FacilityType.commercialFacility => Tr.pick('観客収入とスポンサー収入をまとめて底上げする',
            'Lifts both gate receipts and sponsorship income'),
        FacilityType.medicalCenter => Tr.pick('フィジオの効果と合わせて負傷リスク・療養期間をさらに減らす',
            'Works with your physio to cut injury risk and recovery time further'),
      };
}

/// クラブのスタッフ・施設レベル（1-8）。ユーザークラブにのみ適用される。
class ClubInfrastructure {
  static const int maxLevel = 8;

  final Map<StaffRole, int> staffLevels;
  final Map<FacilityType, int> facilityLevels;

  ClubInfrastructure({
    Map<StaffRole, int>? staffLevels,
    Map<FacilityType, int>? facilityLevels,
  })  : staffLevels = staffLevels ?? {for (final r in StaffRole.values) r: 1},
        facilityLevels =
            facilityLevels ?? {for (final f in FacilityType.values) f: 1};

  int staffLevel(StaffRole role) => staffLevels[role] ?? 1;
  int facilityLevel(FacilityType type) => facilityLevels[type] ?? 1;

  static int staffUpgradeCost(int currentLevel) => 250 * currentLevel;
  static int staffWeeklyWage(int level) => level * 20;
  static int facilityUpgradeCost(int currentLevel) =>
      500 * currentLevel * currentLevel;

  /// スタジアムのレベルに応じた収容人数。
  static int stadiumCapacity(int level) => 12000 + (level - 1) * 6000;

  /// ヘッドコーチ・トレーニング施設のレベルに応じたトレーニング成長効率の倍率。
  static double trainingGrowthMultiplier(
    int headCoachLevel,
    int trainingGroundLevel,
  ) =>
      1 + (headCoachLevel - 1) * 0.15 + (trainingGroundLevel - 1) * 0.08;

  /// トレーニング施設のレベルに応じた、週次の追加疲労回復量。
  static int fatigueRecoveryBonus(int trainingGroundLevel) =>
      (trainingGroundLevel - 1) * 3;

  /// フィットネスコーチのレベルに応じた、週次トレーニングでの追加疲労回復量
  /// (トレーニング施設の回復ボーナスに上乗せされる)。
  static int fitnessCoachRecoveryBonus(int fitnessCoachLevel) =>
      (fitnessCoachLevel - 1) * 2;

  /// フィジオのレベルに応じた負傷の発生率・療養期間の軽減係数(1.0で軽減なし)。
  static double injuryFactor(int physioLevel) =>
      (1 - (physioLevel - 1) * 0.09).clamp(0.35, 1.0);

  /// メディカルセンターのレベルに応じた、フィジオの効果に重ねてかかる
  /// 追加の負傷リスク軽減係数(1.0で軽減なし)。フィジオ単独では届かない
  /// 領域まで負傷リスクを下げられる、上級者向けの投資先。
  static double medicalCenterInjuryFactor(int medicalCenterLevel) =>
      (1 - (medicalCenterLevel - 1) * 0.06).clamp(0.6, 1.0);

  /// 商業施設のレベルに応じた、観客収入・スポンサー収入への倍率。
  static double commercialRevenueMultiplier(int level) => 1 + (level - 1) * 0.1;

  int get totalStaffWeeklyWage =>
      staffLevels.values.fold<int>(0, (s, lvl) => s + staffWeeklyWage(lvl));

  bool upgradeStaff(StaffRole role) {
    final lvl = staffLevel(role);
    if (lvl >= maxLevel) return false;
    staffLevels[role] = lvl + 1;
    return true;
  }

  bool upgradeFacility(FacilityType type) {
    final lvl = facilityLevel(type);
    if (lvl >= maxLevel) return false;
    facilityLevels[type] = lvl + 1;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'staffLevels': staffLevels.map((k, v) => MapEntry(k.name, v)),
        'facilityLevels': facilityLevels.map((k, v) => MapEntry(k.name, v)),
      };

  factory ClubInfrastructure.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClubInfrastructure();
    final staffJson = json['staffLevels'] as Map<String, dynamic>?;
    final facilityJson = json['facilityLevels'] as Map<String, dynamic>?;
    return ClubInfrastructure(
      staffLevels: {
        for (final r in StaffRole.values) r: (staffJson?[r.name] as int?) ?? 1,
      },
      facilityLevels: {
        for (final f in FacilityType.values)
          f: (facilityJson?[f.name] as int?) ?? 1,
      },
    );
  }
}
