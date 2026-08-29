import '../models/team.dart';
import '../models/league.dart';

class FixtureGenerator {
  static List<Fixture> generateDoubleRoundRobin(List<Team> teams) {
    final ids = teams.map((t) => t.id).toList();
    final hasBye = ids.length.isOdd;
    if (hasBye) ids.add('__BYE__');

    final n = ids.length;
    final rounds = n - 1;
    final half = n ~/ 2;
    final arr = List<String>.from(ids);
    final firstLeg = <List<Fixture>>[];

    for (int r = 0; r < rounds; r++) {
      final roundFixtures = <Fixture>[];
      for (int i = 0; i < half; i++) {
        final home = arr[i];
        final away = arr[n - 1 - i];
        if (home != '__BYE__' && away != '__BYE__') {
          roundFixtures.add(
              Fixture(matchday: r + 1, homeTeamId: home, awayTeamId: away));
        }
      }
      firstLeg.add(roundFixtures);
      final last = arr.removeLast();
      arr.insert(1, last);
    }

    final all = <Fixture>[];
    for (final round in firstLeg) {
      all.addAll(round);
    }
    for (final round in firstLeg) {
      for (final f in round) {
        all.add(Fixture(
          matchday: f.matchday + rounds,
          homeTeamId: f.awayTeamId,
          awayTeamId: f.homeTeamId,
        ));
      }
    }
    return all;
  }
}
