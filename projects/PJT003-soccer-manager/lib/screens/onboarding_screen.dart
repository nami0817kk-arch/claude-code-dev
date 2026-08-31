import 'package:flutter/material.dart';
import '../l10n/l10n_ext.dart';
import '../l10n/tr.dart';

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });
}

// const にできないのは、各スライドの文言が表示時の言語で決まるため。
// final にすると最初のアクセスで言語が固定され、設定で切り替えても
// 反映されなくなるので、参照のたびに組み立てるゲッターにしている。
List<_OnboardingSlide> get _slides => [
      _OnboardingSlide(
        icon: Icons.sports_soccer,
        title: Tr.pick('クラブを率いて頂点へ', 'Take a club to the top'),
        description: Tr.pick('クラブを創設し、監督としてリーグ優勝・カップ制覇・昇格を目指しましょう。',
            'Found a club and manage it towards the title, the cup and promotion.'),
      ),
      _OnboardingSlide(
        icon: Icons.groups,
        title: Tr.pick('スカッドと戦術を作り込む', 'Build your squad and your tactics'),
        description: Tr.pick('選手の役割・デューティ、フォーメーション、幅とテンポを調整して自分だけの戦術を組み立てられます。',
            "Set each player's role and duty, choose a formation, and tune width and tempo into a shape of your own."),
      ),
      _OnboardingSlide(
        icon: Icons.swap_horiz,
        title:
            Tr.pick('移籍市場とクラブ経営', 'The transfer market and the balance sheet'),
        description: Tr.pick('選手の獲得・放出、契約交渉、スタッフ・施設への投資でクラブを長期的に強化していきます。',
            'Sign and sell, negotiate contracts, and invest in staff and facilities to build the club for the long run.'),
      ),
      _OnboardingSlide(
        icon: Icons.live_tv,
        title: Tr.pick('試合をライブで観戦・采配', 'Watch matches live and manage them'),
        description: Tr.pick(
            'ライブ観戦では決定機の判断・交代・試合中の指示を自分で下せます。カップ戦のPK戦も1本ずつ見届けられます。おまかせのクイック消化も選べます。',
            'Watching live, you decide what happens at each big chance, make the changes and give the instructions. You can follow a cup shootout kick by kick, or just let the game settle the result for you.'),
      ),
      _OnboardingSlide(
        icon: Icons.emoji_events,
        title: Tr.pick('通算成績を積み重ねよう', 'Build a career record'),
        description: Tr.pick(
            '監督キャリア画面で通算成績やトロフィーを確認できます。この設定はいつでも「設定」からもう一度見返せます。',
            'Your career page keeps your record and your trophies. You can watch this again any time from Settings.'),
      ),
    ];

/// 初回起動時に表示するシンプルなチュートリアル。設定画面からも再表示できる。
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(context.l10n.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          slide.icon,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLast) {
                      widget.onDone();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(isLast
                      ? context.l10n.onboardingStart
                      : context.l10n.onboardingNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
