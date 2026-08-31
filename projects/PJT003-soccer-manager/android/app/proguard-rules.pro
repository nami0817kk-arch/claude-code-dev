# Flutter アプリ向け R8 設定。
#
# Flutter エンジンは JNI からこれらのクラスを名前で参照するため、
# 縮小・難読化の対象から外す必要がある。除外しないとリリースビルドが
# 起動直後に ClassNotFoundException で落ちる。
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (deferred components) は本アプリでは未使用だが、
# Flutter の生成コードが参照するため警告のみ抑制する。
-dontwarn com.google.android.play.core.**
