import 'package:flutter/material.dart';
import '../models/player.dart';

/// ポジション大分類(GK/DEF/MID/ATT)で一覧を絞り込むためのチップ列。
/// 移籍市場・スカウト画面など、選手リストを扱う画面で共通して使う。
class PositionFilterBar extends StatelessWidget {
  final PositionGroup? value;
  final ValueChanged<PositionGroup?> onChanged;

  const PositionFilterBar(
      {super.key, required this.value, required this.onChanged});

  static String labelFor(PositionGroup? g) => switch (g) {
        null => 'すべて',
        PositionGroup.gk => 'GK',
        PositionGroup.def => 'DF',
        PositionGroup.mid => 'MF',
        PositionGroup.att => 'FW',
      };

  @override
  Widget build(BuildContext context) {
    final options = <PositionGroup?>[null, ...PositionGroup.values];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final g in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labelFor(g)),
                selected: value == g,
                onSelected: (_) => onChanged(g),
              ),
            ),
        ],
      ),
    );
  }
}
