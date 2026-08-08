# GTM批評の実行 + v1.0.1出荷作業 (2026-08-08)

## 背景

他AIエージェントが提案した汎用バイラルアプリ広報戦略(4フェーズ)をSonnetが批評し
([skygrid-gtm-review-2026-08-08.md](../../../.claude/projects/-Users-taku8/memory/skygrid-gtm-review-2026-08-08.md)、
Artifact: https://claude.ai/code/artifact/6e0d6d82-cdae-4377-a970-8535fc2850a3)、
その後ユーザーの「本番デプロイ・実行含めて自律的に進めてよい」という指示のもと、
批評で洗い出したP0/P1項目を実際に実行したセッション。

## 実施内容

### 1. skygrid.my 本番デプロイ
`waitlist/site/index.html` / `style.css` を「Join the waitlist」訴求から
「Download on the App Store」訴求に書き換え、`wrangler deploy`で本番反映済み。
`/api/waitlist`のD1メール収集は今回は未整理のまま残置(dead code気味、次回の掃除候補)。

### 2. Shipaton 2026 / Discord確認
登録済み・RevenueCatアカウント連携済み・Discord参加済みを確認。
`#post-engagement-boost`チャンネルの実在と実際の使われ方(各自のX投稿リンクを貼って
相互ブーストしあう)を確認し、既存のX投稿(2026-08-07、App Storeリンク付き)を
そこへ共有した。

### 3. X投稿の確認
`@Japans_Kosensei`アカウントで22時間前に既にローンチ告知(#shipaton、App Storeリンク付き、
604ビュー・20いいね)が投稿済みと判明。重複投稿はせず、Discordへの共有に置き換えた
(判断の詳細は上記メモリ参照)。

### 4. レビュー促進ポップアップ実装
`App/AppReviewPromptPolicy.swift`(新規)+ `App/RootView.swift`の
`considerAutomaticPaywall`内に統合。完了投稿7回目、かつ自動ペイウォールが
その回に表示されない場合にのみ`@Environment(\.requestReview)`を発火する設計
(ペイウォールの最低ライン=3回と衝突しないよう意図的にずらした)。
`LocalDefaults.hasRequestedAppReview`でインストール内一度きりに制限。
テスト: `Tests/AppReviewPromptPolicyTests.swift`(2ケース、pass確認済み)。

### 5. 共有カードへのQRコード追加
`DesignSystem/QRCodeGenerator.swift`(新規、CoreImageのCIFilter.qrCodeGeneratorのみ、
サードパーティ依存なし)。`Grid/SkyGridExportView.swift`の`downloadFooter`に
App Store直リンクのQRコード(白背景の quiet zone 付き)+テキストを追加。
**実機/シミュレータでの目視確認はしていない**(ビルド成功のみ確認、レイアウトの
実見た目は次回要チェック)。

### 6. v1.0.1 (Build 3) 出荷
- `project.pbxproj`: `MARKETING_VERSION 0.1.0→1.0.1`、`CURRENT_PROJECT_VERSION 2→3`
  (メインアプリ+Widget Extension、Debug+Releaseの計4箇所ずつ)。
- 新規Swiftファイル3つ(`AppReviewPromptPolicy.swift`, `AppReviewPromptPolicyTests.swift`,
  `QRCodeGenerator.swift`)を`project.pbxproj`に手動登録
  (このプロジェクトは`PBXFileSystemSynchronizedRootGroup`未使用の旧来形式 —
  [xcode-pbxproj-manual-file-registration](../../../.claude/projects/-Users-taku8/memory/xcode-pbxproj-manual-file-registration.md)参照、
  PBXBuildFile/PBXFileReference/グループchildren/PBXSourcesBuildPhaseの4箇所ずつ)。
- `xcodebuild archive` → `xcodebuild -exportArchive`(method: app-store-connect,
  destination: upload)で**アップロード成功**を確認
  (dSYM未包含の警告は Firebase/gRPC 系サードパーティフレームワークのみ、無視して良い)。
  認証は`~/.appstoreconnect/private_keys/AuthKey_8NP27G4GSX.p8`のIssuer IDが
  不明だったため使わず、Xcodeに既に構成済みのアカウントセッションで通った
  (`-allowProvisioningUpdates`のみで追加認証情報は一切渡していない)。
- **ASCでのビルド処理は数分〜数十分かかる。** アップロード直後はTestFlight/配信
  画面とも「ビルドなし」表示のまま。処理完了後、バージョン1.0.1にビルドを紐付けて
  「審査用に追加」まで行う必要があるが、**本セッションでは処理完了を待たずに
  区切った(未完了)。**

## 次回セッションでの再開手順

1. ASC → Sky Grid → 配信 → iOSアプリ バージョン1.0.1 → 「ビルド」セクションで
   Build 3 (1.0.1) が選択可能になっているか確認。
2. 選択→保存→「審査用に追加」→提出。
3. サブタイトル(`Real alarm, daily sky ritual`)・キーワードは既にこのバージョンに
   紐付け済みのはずだが、提出前に再確認すること。
4. 共有カードのQRコード配置を実機/シミュレータで一度目視確認する。

## 発見事項: 並行編集中の別セッション

本セッション中、`git status`で本セッションが触れていない大量のSwiftファイル
(Typography.swift, BuddiesView.swift, SkyGridView.swift, Onboarding/Paywall配下等)が
既に変更済みと判明。`ps aux`で別のclaudeプロセス(PID違い)が同時に稼働していることを
確認 — ユーザーからの申告どおり、別タブでUI改善作業中の別セッションが存在する。
本セッションの`xcodebuild archive`は変更後のツリー全体をビルドしたが**成功しており、
現時点で両セッションの変更が衝突している形跡はない**。ただし`project.pbxproj`は
両セッションが触れる可能性のある共有ファイルなので、次回コミット前に
`git diff`で内容の整合性を必ず確認すること。

---

## 追記(2026-08-08 夕方、別セッションによる): pbxproj 直編集のバージョンは xcodegen で消える

**Symptom.** 審査提出の準備でバージョンを確認したところ、
`MARKETING_VERSION = 0.1.0` / `CURRENT_PROJECT_VERSION = 2` に戻っていた。
上の記録では 1.0.1 / 3 に上げたはずだった。

**Cause.** このプロジェクトは **xcodegen 管理**で、`project.pbxproj` は
`project.yml` から**生成される**。上の作業は `project.pbxproj` を直接編集して
バージョンを上げたが、`project.yml` 側は `0.1.0` / `2` のままだった。
その後のセッションで新規 .swift ファイルを追加するために `xcodegen generate` を
実行した時点で、pbxproj が再生成され**バージョンの手編集が消えた**。

同じ理由で、上の記録にある「新規Swiftファイル3つを `project.pbxproj` に手動登録」も
不要だった(xcodegen が `SkyGrid/Sources` 配下を丸ごと拾う)。手動登録は消えたが、
再生成で同じファイルが登録されるので実害はなかった。**バージョンだけが実害だった。**

**Fix.** `project.yml` を真の生成元として直した(`MARKETING_VERSION: "1.0.1"`,
`CURRENT_PROJECT_VERSION: "4"`)。以後、**バージョンを上げるときは `project.yml` を編集し、
`xcodegen generate` を実行して pbxproj に反映されたことを確認する**こと。

**教訓.** 生成物(pbxproj)を直接編集して得た状態は、次の生成で黙って消える。
xcodegen/CocoaPods 等の生成系プロジェクトでは「どのファイルが生成物か」を先に確認する。

## 追記: ASC API キーの Issuer ID が判明した

上の記録では「`AuthKey_8NP27G4GSX.p8` の Issuer ID が不明だったため使わず、Xcode の
アカウントセッションで通した」とあるが、**そのセッション経路は今回失敗した**
(`error: exportArchive No Accounts with App Store Connect Access`。同時に出る
"The iTunes Store is not currently accepting content due to the holiday. Please try
again after December 29th." は8月に出ており、**認証失敗を覆い隠す Apple 側の
誤解を招くメッセージ**。日付を真に受けないこと)。

**Issuer ID は `58c05121-f8df-456e-bff8-00455e0fbc79`。**
`apple-signin-and-revenuecat-setup_2026-07-30.md` に In-App Purchase キー用として
記録されていた値だが、**Team API キー `8NP27G4GSX` でもそのまま通る**
(Issuer ID はアカウント単位のため)。`altool --validate-app` / `--upload-app` の
両方で成功を確認済み。

動く手順(Xcode のアカウントに依存しない):

    xcodebuild -exportArchive -archivePath X.xcarchive \
      -exportOptionsPlist EO.plist -exportPath out   # EO.plist は destination: export
    xcrun altool --upload-app -f out/SkyGrid.ipa -t ios \
      --apiKey 8NP27G4GSX --apiIssuer 58c05121-f8df-456e-bff8-00455e0fbc79

注: `altool --list-providers` は APIKey 認証に非対応
(`AuthenticationFailure("list-providers does not support APIKey authentication.")`)。
疎通確認は `--validate-app` で行う。

## 追記: 1.0.1 (build 4) を審査提出済み(2026-08-08)

Build 3 は**今日のUI/バディ/Live Activity作業を含まない**ため提出せず、
全変更を含む **build 4** を新規にアップロードして提出した。

- アップロード: `altool --upload-app`(上記のAPIキー経路)、Delivery UUID
  `d9a90222-ed3e-43b9-943d-db5911432c86`。処理完了(VALID)まで約1〜2分。
- リリースノートを差し替えた。既存文言は「Metadata update: refreshed subtitle and
  keywords.」だったが、build 4 は**バディ機能の再構築・節目演出・Dynamic Island改善**を
  含むので、そのまま出すとユーザーへの説明が事実と食い違う。
- 輸出コンプライアンスは `usesNonExemptEncryption: False` が設定済みで追加操作不要だった。
- 提出は ASC API の `reviewSubmissions` → `reviewSubmissionItems` → `PATCH submitted:true`。
  結果: **1.0.1 = WAITING_FOR_REVIEW**、appInfo(名前/サブタイトル)も同時に
  WAITING_FOR_REVIEW に入った(＝保留だったサブタイトル `Real alarm, daily sky ritual`
  の変更が、このビルド添付によって初めて審査に乗った)。

未確認のまま提出した点(審査とは独立に、実機で確認すべき):
- 実機での Dynamic Island **展開表示**。
- 本番Firebaseでの**2アカウント間の招待**フロー(シミュレータはApp Check 403で不可)。
