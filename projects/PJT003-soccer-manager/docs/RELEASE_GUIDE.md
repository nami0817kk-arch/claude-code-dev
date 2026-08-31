# リリース手順書（Google Play / App Store）

Mac を持っていない前提で、両ストアに提出できる状態まで持っていくための手順書。
署名済みの成果物は GitHub Actions（macOS ランナーを含む）で生成するので、
手元に必要なのは Web ブラウザと、OpenSSL が動く環境（この Linux 環境で可）だけ。

**このリポジトリは公開リポジトリなので、macOS ランナーを含め Actions は無料枠で使える。**

---

## 0. 全体像

| 工程 | やる人 | 所要 |
|---|---|---|
| 1. Android の署名鍵（keystore）を作る | あなた | 5分 |
| 2. Google Play デベロッパー登録（$25・買い切り） | あなた | 30分〜数日（本人確認） |
| 3. Apple Developer Program 登録（$99/年） | あなた | 1〜2日（審査） |
| 4. Apple の証明書・プロファイルを作る（Mac 不要） | あなた | 30分 |
| 5. GitHub Secrets に登録 | あなた | 10分 |
| 6. ワークフローを実行して AAB / IPA を生成 | CI | 15分 |
| 7. ストアに提出 | あなた | 1〜2時間 |

**鍵とアカウントの作成は、代わりにやってはいけない類のものです。**
署名鍵はアプリの同一性そのもので、失うとそのアプリを二度と更新できません。
Apple / Google のアカウントもあなた個人（または法人）に紐づく資産です。
このガイドはその作り方を示すもので、作業自体はあなたの手で行ってください。

---

## 1. Android の署名鍵（keystore）を作る

`keytool` は JDK に付属しています（`java -version` が通れば入っています）。

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

対話で以下を聞かれます。

- **キーストアのパスワード** … 任意。控えておく（= `ANDROID_KEYSTORE_PASSWORD`）
- **姓名／組織／都市／国コード** … 実在の情報でなくても通る。国コードは `JP`
- **鍵のパスワード** … 空 Enter でキーストアと同じにできる（= `ANDROID_KEY_PASSWORD`）

`-alias upload` の `upload` が `ANDROID_KEY_ALIAS` になります。

> ⚠️ **`upload-keystore.jks` は絶対に失わないでください。**
> この鍵をなくすと、同じアプリとしてのアップデートを配信できなくなります。
> Git には入りません（`.gitignore` 済み）。パスワードマネージャや
> オフラインのバックアップなど、リポジトリの外に安全に保管してください。
>
> なお Google Play の「アプリ署名」を有効にすると、配信用の鍵は Google 側が
> 管理し、あなたが持つのはアップロード用の鍵だけになります。この場合、
> アップロード鍵を紛失しても Google に再登録を申請できます。
> 新規アプリでは既定で有効なので、そのまま進めて構いません。

CI に渡すため Base64 の 1 行に変換します。

```bash
base64 -w 0 upload-keystore.jks > keystore.base64.txt
```

### ローカルでリリースビルドを試したい場合

`android/key.properties` を作ります（このファイルは `.gitignore` 済み）。

```properties
storeFile=/絶対パス/upload-keystore.jks
storePassword=<キーストアのパスワード>
keyAlias=upload
keyPassword=<鍵のパスワード>
```

`storeFile` は**絶対パス**で書いてください。
`key.properties` は `android/` から読まれますが、`file()` の解決は
`android/app/` 基準になるため、相対パスだと取り違えます。

このファイルがない環境ではデバッグ鍵にフォールバックするので、
鍵を持たない開発機でも `flutter run --release` はそのまま動きます。

---

## 2. Google Play デベロッパー登録

1. https://play.google.com/console にアクセスし、Google アカウントで登録
2. 登録料 **$25（買い切り・1回だけ）** を支払う
3. 本人確認（住所確認・身分証）を済ませる — 数日かかることがある
4. 個人開発者の場合、**新規アカウントは 20 人以上のテスターによる
   14 日間のクローズドテストを経ないと製品版に公開できません。**
   審査より先にここで時間がかかるので、早めに着手してください。

---

## 3. Apple Developer Program 登録

1. https://developer.apple.com/programs/ から登録
2. 年額 **$99（毎年更新）**
3. 審査に 1〜2 日かかる
4. 支払いは iPhone / iPad の Developer アプリからでも、Web からでも可

**これは避けられません。** Apple の署名証明書は Apple Developer Program の
会員にしか発行されず、証明書なしに App Store へは提出できません。
（Mac は不要ですが、Program 登録は必須です。）

---

## 4. Apple の証明書・プロファイルを Mac なしで作る

通常は Mac の Keychain Access で CSR（証明書署名要求）を作りますが、
同じものは OpenSSL で作れます。以下はこの Linux 環境でそのまま実行できます。

### 4-1. 秘密鍵と CSR を作る

```bash
# 秘密鍵（これも絶対に失わないこと）
openssl genrsa -out ios_distribution.key 2048

# CSR。email とサブジェクトは Apple ID のものに合わせておくと分かりやすい
openssl req -new -key ios_distribution.key -out ios_distribution.csr \
  -subj "/emailAddress=あなたのAppleID@example.com/CN=Soccer Manager Distribution/C=JP"
```

### 4-2. Apple に CSR を渡して証明書をもらう

1. https://developer.apple.com/account/resources/certificates/list を開く
2. **＋** → **Apple Distribution** を選ぶ
3. 先ほどの `ios_distribution.csr` をアップロード
4. 発行された `distribution.cer` をダウンロード

### 4-3. .cer と秘密鍵を .p12 にまとめる

CI に渡すのは「証明書＋秘密鍵」のペア（.p12）です。

```bash
# Apple が返す .cer は DER 形式なので PEM に変換
openssl x509 -inform DER -in distribution.cer -out distribution.pem

# 秘密鍵と結合して .p12 に。ここで設定するパスワードが
# IOS_DIST_CERT_PASSWORD になる
openssl pkcs12 -export \
  -inkey ios_distribution.key \
  -in distribution.pem \
  -out ios_distribution.p12 \
  -name "Apple Distribution" \
  -legacy

# CI へ渡すため Base64 化
base64 -w 0 ios_distribution.p12 > ios_cert.base64.txt
```

> `-legacy` は OpenSSL 3.x で必要です。これを付けないと、macOS の
> `security import` が読めない暗号化方式（AES-256-CBC）で書き出され、
> CI の証明書インポートが失敗します。

### 4-4. App ID を登録する

1. https://developer.apple.com/account/resources/identifiers/list
2. **＋** → **App IDs** → **App**
3. Bundle ID に **`com.kabuagari.soccerManager`** を入力（Explicit）
   - このアプリの iOS 側バンドル ID です。
   - Android 側の applicationId は `com.kabuagari.soccer_manager` で、
     わざと違います。iOS のバンドル ID はアンダースコアを使えないためです。
     両者が一致している必要はありません。
4. Capabilities は何も追加しなくて構いません（このアプリは
   ネットワーク通信も通知も課金も使いません）

### 4-5. プロビジョニングプロファイルを作る

1. https://developer.apple.com/account/resources/profiles/list
2. **＋** → Distribution の **App Store Connect** を選ぶ
3. App ID に `com.kabuagari.soccerManager` を選択
4. 証明書に 4-2 で作った Apple Distribution 証明書を選択
5. プロファイル名を付けて生成し、`.mobileprovision` をダウンロード

```bash
base64 -w 0 SoccerManager_AppStore.mobileprovision > ios_profile.base64.txt
```

### 4-6. Team ID を控える

https://developer.apple.com/account の Membership details にある
10 文字の英数字が `IOS_TEAM_ID` です。

### 4-7.（任意）App Store Connect API キー

CI から TestFlight へ自動アップロードしたい場合のみ必要です。
手動でアップロードするなら飛ばして構いません。

1. https://appstoreconnect.apple.com/access/integrations/api
2. **App Manager** 権限でキーを生成
3. `AuthKey_XXXXXXXX.p8` をダウンロード（**再ダウンロードできません**）
4. Key ID と Issuer ID を控える

```bash
base64 -w 0 AuthKey_XXXXXXXX.p8 > appstore_key.base64.txt
```

---

## 5. GitHub Secrets の登録

リポジトリの **Settings → Secrets and variables → Actions → New repository secret**
で、以下を登録します。Base64 のものは `.txt` の中身をそのまま貼り付けてください。

### Android（必須）

| Secret 名 | 中身 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `keystore.base64.txt` の中身 |
| `ANDROID_KEYSTORE_PASSWORD` | キーストアのパスワード |
| `ANDROID_KEY_PASSWORD` | 鍵のパスワード |
| `ANDROID_KEY_ALIAS` | `upload` |

### iOS（必須）

| Secret 名 | 中身 |
|---|---|
| `IOS_DIST_CERT_BASE64` | `ios_cert.base64.txt` の中身 |
| `IOS_DIST_CERT_PASSWORD` | .p12 のパスワード |
| `IOS_PROVISIONING_PROFILE_BASE64` | `ios_profile.base64.txt` の中身 |
| `IOS_TEAM_ID` | 10 文字の Team ID |

### iOS TestFlight 自動アップロード（任意）

| Secret 名 | 中身 |
|---|---|
| `APPSTORE_API_KEY_ID` | Key ID |
| `APPSTORE_API_ISSUER_ID` | Issuer ID |
| `APPSTORE_API_KEY_BASE64` | `appstore_key.base64.txt` の中身 |

> Secrets はワークフローのログに出ません（GitHub が自動でマスクします）。
> ワークフロー側でも、ジョブの最後に `if: always()` で鍵をランナーから
> 削除しています。

登録が済んだら、**手元の `.jks` / `.p12` / `.p8` / `.base64.txt` を
リポジトリの作業ディレクトリの外へ移してください。**
`.gitignore` で保護してはいますが、置かないのが一番確実です。

---

## 6. ビルドする

### Android

GitHub の **Actions → Build Soccer Manager (Android Release) → Run workflow**

- 成果物は `soccer-manager-android` という artifact に入ります
  - `app-release.aab` … Google Play に提出するもの
  - `app-release.apk` … 手持ちの Android 実機で動作確認するもの
- 再提出時は `build_number` に前回より大きい数を入れてください。
  Play は同じ versionCode を二度受け付けません。

### iOS

GitHub の **Actions → Build Soccer Manager (iOS Release) → Run workflow**

- 成果物は `soccer-manager-ios` artifact の `.ipa`
- `upload_to_testflight` を on にすると TestFlight まで自動で上がります
  （5. の任意 Secrets が必要）
- off の場合は、artifact の IPA を
  [Transporter](https://apps.apple.com/app/transporter/id1450874784)（Mac 用）か
  App Store Connect の Web UI から手動でアップロードします。
  **Mac がない場合は `upload_to_testflight` を使うのが実質唯一の道です。**

### タグで両方まとめて走らせる

```bash
git tag soccer-manager-v1.0.0
git push origin soccer-manager-v1.0.0
```

Android / iOS 両方のワークフローが起動します。

---

## 6-2. 収益化の設定（AdMob とアプリ内課金）

**既定値のままでは収益は発生しません。** 広告IDは Google のテスト用IDにしてあり、
テスト広告しか出ないためです。差し替え忘れても規約違反にならないよう、
わざとこの既定にしています。

### AdMob

1. https://apps.admob.com でアカウントを作り、アプリを登録する
   （Android と iOS は別々のアプリとして登録する）
2. アプリごとに「リワード」広告ユニットを1つ作る
3. 控えるもの: **アプリID**（`ca-app-pub-xxx~yyy`、`~` 区切り）と
   **広告ユニットID**（`ca-app-pub-xxx/zzz`、`/` 区切り）

**Android** — アプリIDは Gradle 経由でマニフェストに入る。

```bash
flutter build appbundle --release \
  -PADMOB_APP_ID=ca-app-pub-xxxx~yyyy \
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxxx/zzzz
```

**iOS** — アプリIDは `ios/Runner/Info.plist` の `GADApplicationIdentifier` を
自分のIDに書き換える。広告ユニットIDはビルド時に渡す。

```bash
flutter build ipa --release \
  --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-xxxx/zzzz \
  --export-options-plist=ios/ExportOptions.plist
```

> iOS では AdMob が SKAdNetwork の識別子一覧を `Info.plist` に載せることを
> 求めています。広告の計測精度に関わる項目で、未設定でも広告は表示されますが、
> 収益に影響します。最新の一覧は AdMob の公式ドキュメントから取得して
> `SKAdNetworkItems` として追記してください。

### アプリ内課金（サポーター）

商品IDは実装側で `soccer_manager_supporter` に固定してあります。
ストア側でこのIDの商品を作ってください。

- **Google Play Console** → 収益化 → アプリ内アイテム →
  商品ID `soccer_manager_supporter`、タイプは「1回限りの購入」
- **App Store Connect** → App内課金 → 非消耗型 →
  製品ID `soccer_manager_supporter`

どちらも審査があり、アプリ本体とは別に承認が必要です。
価格は各ストアの管理画面で設定します（アプリ側には持たせていません）。

### 動作確認

**この環境では広告も課金も実機確認ができていません。** どちらも
ストアとネットワークが要るためです。実機で次を確認してください。

- ファイナンス画面に「スポンサーの特別協賛金」カードが出る
- ボタンを押すとテスト広告が再生され、見終わると資金が増える
- 途中で閉じると資金が増えず、回数も減らない
- 上限（無料3回）に達するとボタンが押せなくなる
- 設定画面からサポーター購入ができ、購入後は広告なしで受け取れる
- 「購入を復元」が動く（iOS の審査要件）

---

## 7. バージョンの上げ方

`pubspec.yaml` の 1 行だけを変えます。

```yaml
version: 1.0.0+1
#        ^^^^^ ^
#        |     └─ ビルド番号（versionCode / CFBundleVersion）。提出のたびに +1
#        └─ ユーザーに見えるバージョン（versionName / CFBundleShortVersionString）
```

Android の `versionCode` も iOS の `CFBundleVersion` も、
どちらもここから自動で流し込まれます。個別に触る必要はありません。

---

## 8. よくある詰まりどころ

| 症状 | 原因と対処 |
|---|---|
| Android ビルドが「Secrets が未設定です」で落ちる | 5. の 4 つの Secret 名を確認。名前の綴りが 1 文字でも違うと空になる |
| 「AAB がデバッグ鍵で署名されています」で落ちる | `ANDROID_KEYSTORE_BASE64` の中身が壊れている。`base64 -w 0`（改行なし）で作り直す |
| iOS の `security import` が失敗する | .p12 を `-legacy` なしで作った可能性。4-3 をやり直す |
| iOS ビルドが provisioning profile で落ちる | プロファイルの App ID と `com.kabuagari.soccerManager` が一致しているか確認 |
| Play に上げたら versionCode が既に使われていると言われる | `build_number` に前回より大きい数を指定して再実行 |
| App Store Connect で輸出コンプライアンスを聞かれる | `Info.plist` に `ITSAppUsesNonExemptEncryption=false` を入れてあるので通常は出ません。出た場合は「いいえ」を選択 |
