// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Soccer Club Manager';

  @override
  String get startTagline => 'Take charge of a club and chase the title';

  @override
  String startSlotLabel(int number) {
    return 'Slot $number';
  }

  @override
  String get startEmptySlot => 'Empty slot';

  @override
  String startDeleteSlot(int number) {
    return 'Delete slot $number?';
  }

  @override
  String get startCreateClub => 'New club';

  @override
  String startNewClubIn(int number) {
    return 'Create a new club in slot $number';
  }

  @override
  String get startClubNameLabel => 'Club name';

  @override
  String get startLeagueLabel => 'League';

  @override
  String get startDifficultyLabel => 'Difficulty';

  @override
  String get startCreate => 'Found the club';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Start';

  @override
  String get navHome => 'Home';

  @override
  String get navSquad => 'Squad';

  @override
  String get navTactics => 'Tactics';

  @override
  String get navStandings => 'Table';

  @override
  String get firstRunTitle => 'First steps';

  @override
  String firstRunProgress(int done, int total) {
    return 'First steps ($done/$total)';
  }

  @override
  String get firstRunClose => 'Dismiss guide';

  @override
  String firstRunSemantics(int done, int total) {
    return 'First-run guide progress: $done of $total steps done';
  }

  @override
  String get firstRunMatchHint => 'Start from the next fixture just below';

  @override
  String get firstRunLineupLabel => 'Check your starting XI';

  @override
  String get firstRunLineupDesc =>
      'See who takes the pitch. You can change the line-up at any time.';

  @override
  String get firstRunLineupAction => 'Line-up';

  @override
  String get firstRunTrainingLabel => 'Set this week\'s training';

  @override
  String get firstRunTrainingDesc =>
      'Training changes how players develop. General training is a fine default.';

  @override
  String get firstRunTrainingAction => 'Training';

  @override
  String get firstRunMatchLabel => 'Play your first match';

  @override
  String get firstRunMatchDesc =>
      'Choose Play live and you decide what happens at every clear chance.';

  @override
  String get firstRunMatchAction => 'Match';

  @override
  String get firstRunGrowthLabel => 'See a player improve';

  @override
  String get firstRunGrowthDesc =>
      'Open a player from the squad to see their attribute trend over time.';

  @override
  String get firstRunGrowthAction => 'Squad';
}
