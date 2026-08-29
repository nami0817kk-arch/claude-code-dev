import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/feedback_service.dart';
import 'state/game_state.dart';
import 'state/settings_controller.dart';
import 'screens/onboarding_screen.dart';
import 'screens/start_screen.dart';

void main() {
  runApp(const SoccerManagerApp());
}

/// クラブの重役室を思わせる、紺(ネイビー)と金(ゴールド)を基調にした配色。
const _navy = Color(0xFF14213D);
const _navyDeep = Color(0xFF0B1526);
const _gold = Color(0xFFC9A24B);

class SoccerManagerApp extends StatelessWidget {
  const SoccerManagerApp({super.key});

  TextTheme _bolden(TextTheme t) {
    TextStyle? bump(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w700);
    return t.copyWith(
      displayLarge: bump(t.displayLarge),
      displayMedium: bump(t.displayMedium),
      displaySmall: bump(t.displaySmall),
      headlineLarge: bump(t.headlineLarge),
      headlineMedium: bump(t.headlineMedium),
      headlineSmall: bump(t.headlineSmall),
      titleLarge: bump(t.titleLarge),
      titleMedium: bump(t.titleMedium),
      titleSmall: bump(t.titleSmall),
      bodyLarge: bump(t.bodyLarge),
      bodyMedium: bump(t.bodyMedium),
      bodySmall: bump(t.bodySmall),
      labelLarge: bump(t.labelLarge),
      labelMedium: bump(t.labelMedium),
      labelSmall: bump(t.labelSmall),
    );
  }

  /// 大見出しなど「たまにしか出てこない大きな文字」だけ明朝体にする。
  /// titleMedium/titleSmallはListTileの標準スタイルとして選手名などの
  /// 一覧行にも使われるため対象外(可読性優先で本文用ゴシック体のまま)。
  /// headlineMediumは試合スコアの数字表示に使われるため同様に対象外。
  TextTheme _withSerifHeadlines(TextTheme t) {
    TextStyle? serif(TextStyle? s) =>
        s == null ? null : GoogleFonts.shipporiMincho(textStyle: s);
    return t.copyWith(
      displayLarge: serif(t.displayLarge),
      displayMedium: serif(t.displayMedium),
      displaySmall: serif(t.displaySmall),
      headlineLarge: serif(t.headlineLarge),
      headlineSmall: serif(t.headlineSmall),
      titleLarge: serif(t.titleLarge),
    );
  }

  ThemeData _buildTheme(Brightness brightness, {required bool boldText}) {
    final isDark = brightness == Brightness.dark;
    // primary/secondary/tertiaryを紺・金に固定するため、それぞれの
    // on〇〇色も明暗どちらでも十分なコントラストが出るよう明示的に固定する
    // (自動導出に任せると、ダークモードでprimaryとonPrimaryがどちらも
    // 暗色になり読めなくなる不具合があったため)。
    final scheme = ColorScheme.fromSeed(
      seedColor: _navy,
      brightness: brightness,
      primary: _navy,
      onPrimary: Colors.white,
      secondary: _gold,
      onSecondary: _navyDeep,
      tertiary: _gold,
      onTertiary: _navyDeep,
      surface: isDark ? _navyDeep : const Color(0xFFFBFAF6),
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
    );
    var textTheme = _withSerifHeadlines(base.textTheme);
    if (boldText) textTheme = _bolden(textTheme);
    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        shadowColor: _gold.withValues(alpha: 0.18),
        color: base.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _gold.withValues(alpha: 0.18)),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
        titleTextStyle: GoogleFonts.shipporiMincho(
          textStyle: base.textTheme.titleLarge,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        surfaceTintColor: _gold,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: base.colorScheme.surfaceContainer,
        indicatorColor: _gold.withValues(alpha: 0.24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor:
            base.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()..init()),
        ChangeNotifierProvider(create: (_) => SettingsController()..init()),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          FeedbackService.attach(settings);
          return MaterialApp(
            title: 'サッカー経営マネージャー',
            theme:
                _buildTheme(Brightness.light, boldText: settings.boldTextMode),
            darkTheme:
                _buildTheme(Brightness.dark, boldText: settings.boldTextMode),
            themeMode: settings.themeMode,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(settings.textScale),
                ),
                child: child!,
              );
            },
            home: const _RootScreen(),
          );
        },
      ),
    );
  }
}

/// 設定・セーブデータの初期化が終わるまで待ち、初回起動ならチュートリアルを挟んでから
/// 通常のスタート画面へ進む。
class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final gameState = context.watch<GameState>();

    if (!settings.initialized || !gameState.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!settings.hasSeenOnboarding) {
      return OnboardingScreen(
          onDone: () => settings.setHasSeenOnboarding(true));
    }
    return const StartScreen();
  }
}
