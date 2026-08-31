import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// `AppLocalizations.of(context)!` を毎回書かずに済むようにする。
///
/// MaterialApp に delegate を登録してあるので、アプリのウィジェットツリー内で
/// null になることはない。ツリー外から呼べば例外になるが、それは呼び出し側の
/// 誤りなので握りつぶさずに落とす。
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
