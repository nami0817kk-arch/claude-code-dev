// Flutter の既定のブートストラップを上書きしている。
//
// 既定では CanvasKit (レンダラ本体、約 1.5MB の .js と .wasm) を
// https://www.gstatic.com/flutter-canvaskit/... から読み込むため、
// ページを開いただけで利用者のIPアドレスが Google に渡る。
// これはプライバシーポリシーの「外部サーバーへの通信機能を持たず」という
// 記載と矛盾するので、ビルド時に build/web/canvaskit/ へ出力される
// ローカルのコピーを使うように canvasKitBaseUrl を明示する。
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
