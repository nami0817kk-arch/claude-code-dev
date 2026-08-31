# 同梱フォントについて

しっぽり明朝 (Shippori Mincho) — SIL Open Font License 1.1 (`OFL.txt` 参照)
https://github.com/fontdasu/ShipporiMincho

## なぜ同梱しているか

以前は `google_fonts` パッケージ経由で読み込んでいたが、この方式は初回起動時に
`fonts.gstatic.com` へ取得しに行くため、利用者のIPアドレスが Google に渡る。
これはプライバシーポリシーの「外部サーバーへの通信機能を持たず、第三者への
情報提供は発生しません」という記載と矛盾する。

さらに Android のリリースビルドには INTERNET 権限がない (debug/profile の
マニフェストにしかない) ため取得に失敗し、Android 版だけ明朝体が当たらない
という不具合にもなっていた。

同梱に切り替えたことで、通信はゼロになり、全プラットフォームで表示が揃う。

## サブセットについて

配布元の TTF は 1 ファイル 8.0MB (15,363 コードポイント) あり、見出しにしか
使わないフォントとしては大きすぎるため、次の範囲に絞ってある (3.7MB)。

- cp932 (Windows 日本語) でエンコードできる文字。JIS X 0208 と NEC/IBM 拡張を
  含み、利用者が入力するクラブ名は通常この範囲に収まる
- 上記に加えて、`lib/` 内のソースに実際に登場する文字 (— や • など cp932 に
  ない記号を拾うため)

この範囲外の文字は端末の標準フォントにフォールバックして表示される
(絵文字は元の配布フォントにも収録されていないため、従来から同じ挙動)。

再生成するには:

    pip install fonttools
    pyftsubset ShipporiMincho-<Weight>.ttf --text-file=subset.txt \
      --output-file=ShipporiMincho-<Weight>.ttf \
      --layout-features='*' --notdef-outline --recommended-glyphs
