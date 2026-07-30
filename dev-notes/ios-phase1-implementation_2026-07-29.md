# Sky Grid iOS Phase 1 実装ログ (2026-07-29)

## 状態

`~/Desktop/SkyGrid/ios/` にXcodeGenベースのプロジェクトを新規作成し、code-architect(Opus)のブループリント(タスク#1〜#11)を全て実装。`build_sim`/`test_sim`で継続的に検証しながら進めた。**Firebase/Firestore/Auth(Phase 2)は未実装** — `Data/Local/`のモックバックエンドのみで、オンボーディング→ハンドル設定→今日画面→撮影→投稿作成→アップロードキュー登録、通知タップ→カメラ直行、までシミュレータ上で一気通貫に動く状態。全45件程度のユニットテストが緑。同日、実機(iPhone 15 Pro「俺のGALAXY Pro Max」)へのワイヤレスデバッグ実機デプロイにも成功(下記「実機デプロイ手順」参照)。

## 実機デプロイ手順(2026-07-29、iPhone 15 Proで確認済み)

XcodeBuildMCPの実機向けツール(build_device/install_app_device等)は本セッションでは未有効化(シミュレータ向けのみ有効)。代わりに`xcodebuild`+`xcrun devicectl`を直接使用した。手順:

1. **接続確認(必須、`list devices`だけでは不十分):**
   ```
   xcrun devicectl list devices                              # "available (paired)" は接続中の意味ではない
   xcrun devicectl device info details --device <identifier> # これを実行した時点で実トンネルが確立される
   ```
   1回目は`tunnelState: unavailable`(未接続)、同じコマンドを再実行したら`tunnelState: connected`になった([[devicectl-wireless-reconnect-gotcha]]通りの挙動を実際に再現)。
2. **destinationのUDID確認:** `devicectl`の`identifier`(例`FF649B7E-...`)と`xcodebuild -destination`が使う`udid`(例`00008130-...`、`hardwareProperties.udid`)は別物。`xcodebuild -showdestinations`で実際に認識されているIDを確認してから使うこと。
3. **ビルド:**
   ```
   xcodebuild -project SkyGrid.xcodeproj -scheme SkyGrid -configuration Debug \
     -destination 'id=<xcodebuildのudid>' -allowProvisioningUpdates build
   ```
   `project.yml`の`CODE_SIGN_STYLE: Automatic`のおかげで、Apple Developer Portal側でBundle ID `com.takmin.skygrid`やSign in with Apple/Push capabilityを事前登録していなくても、`-allowProvisioningUpdates`が自動でApp ID登録・プロビジョニングプロファイル発行まで行った(署名エラーは一切発生せず)。**VISION.md §7の「Bundle ID登録」チェック項目は、実質この一回のビルドで自動的に満たされた形になっている。**
4. **インストール・起動:**
   ```
   xcrun devicectl device install app --device <identifier> <path-to-.app>
   xcrun devicectl device process launch --device <identifier> <bundle-id>
   ```
   `.app`のパスは`~/Library/Developer/Xcode/DerivedData/SkyGrid-*/Build/Products/Debug-iphoneos/SkyGrid.app`。

## エージェント委譲の失敗(重要 — 次回同じ轍を踏まないこと)

**症状:** `Agent`ツールに`subagent_type: "fork"`で実装作業(Xcodeプロジェクト雛形〜Task#6相当)を2回委譲したが、両方とも`tool_uses: 0`で数秒〜数十秒後に完了扱いで返ってきた。`result`欄には実際の作業内容ではなく、委譲時に自分が書いた指示文の要約のような文言が返っていた。
**確認方法:** `find ~/Desktop/SkyGrid -type f`で実際のファイル生成状況を都度確認したところ、1回目・2回目とも一切ファイルが作成されていなかった(`ios/`ディレクトリすら存在せず)。
**原因(未特定):** 直前に受け取ったcode-architectの巨大なブループリント(85K トークン相当)を会話コンテキストとして継承した状態でforkしたことが関係している可能性があるが未確認。
**対処:** forkでの委譲を諦め、メインループ(自分自身)が直接`Write`/`Bash`/`xcodebuild` MCPツールを使って実装。以降は問題なく進行した。
**次回への申し送り:** 大規模実装をforkに投げる前に、まず小さなタスク(1ファイル作成など)で試験的にforkが機能するか確認してから本委譲すること。`tool_uses: 0`で即完了する場合はforkが機能していない兆候として扱い、即座にファイルシステムで実際の成果物を確認する。

## SourceKitの事前診断は今回のセッションでも一貫して信頼できなかった

**症状:** ファイルを書くたびに`No such module 'UIKit'`「`Cannot find type 'LocalDate' in scope`」等、100件以上の偽陽性が出た。特に他ファイルで定義した型への参照は、Xcodeプロジェクトが最新化されるまで(=`xcodegen generate`→`build_sim`が通るまで)ほぼ確実に赤く表示された。
**確認:** 実際の`xcodebuild`結果とは終始無相関。SourceKit上でエラーだらけに見えたファイルが実ビルドでは何の問題もなく通った例が多数。
**教訓(既存メモリ`sourcekit-diagnostics-not-authoritative`を再確認):** 判断は必ず`build_sim`/`test_sim`の実行結果で行うこと。今回のボリューム感(100件超)を踏まえ、このメモリの重要度を再確認した。

## Xcodeプロジェクト設定

**症状:** 初回`build_sim`が `None of the input catalogs contained a matching ... icon set ... named "AppIcon"` で失敗。
**原因:** `Assets.xcassets`に`AppIcon.appiconset`が存在しない状態で`ASSETCATALOG_COMPILER_APPICON_NAME`関連のデフォルト検証に引っかかった(シミュレータ向けDebugビルドでも必須)。
**対処:** Python標準ライブラリ(`zlib`+`struct`)で1024×1024の単色PNGを直接生成(Pillow等の外部依存なし)→`AppIcon.appiconset/Contents.json`(universal/ios/1024x1024の1エントリ)を用意→`project.yml`に`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`を追加。**このアイコンは単色プレースホルダーであり、実際のデザイン(Canva等)には未着手。**

## Swift正規表現リテラルの罠

**症状:** `HandleValidator`で`/^[a-z0-9_]{3,20}$/`という正規表現リテラルを使ったところ、SourceKitが「`/^`」をoperatorとして誤認し、無関係な構文エラーが10件近くカスケードした。
**対処:** 正規表現リテラルを使わず、`CharacterSet`+`count`チェックの手書きバリデーションに置き換え。今回程度の単純な文字種チェックには正規表現リテラルのリスクを取る価値がないと判断。

## Swift並行性(Strict Concurrency, targeted)の3つの実戦的な罠

1. **`@MainActor final class`が`AVCaptureSession`等(非Sendable)をGCDキュー経由で操作する場合:** `session`/`photoOutput`/`videoOutput`を`nonisolated(unsafe)`にし、設定処理を`nonisolated static func`に切り出し、`@preconcurrency import AVFoundation`を追加して解消。素朴に`@MainActor`クラスの中でGCD `.async`ブロックからセッション操作を書くと"crosses main actor-isolated code"警告が出る。
2. **`@MainActor final class`が(`@MainActor`を付けていない)`Sendable`プロトコルに準拠する場合:** 同様に"conformance crosses main actor-isolated code"警告。`PostRepository`/`UserRepository`/`FriendRepository`プロトコル自体に`@MainActor`を付けることで解消(`CameraSource`は最初から`@MainActor`だった)。
3. **SwiftDataの`#Predicate`マクロが生成する`KeyPath`が`Sendable`に準拠しない:** actor(`UploadQueue`)内で`#Predicate`を使うと"type 'KeyPath<...>' does not conform to the 'Sendable' protocol; this is an error in the Swift 6 language mode"という警告が出る。**現状(`SWIFT_STRICT_CONCURRENCY: targeted`)では警告止まりでビルドは通る。** 今回のセッション中、一度他の修正のついでに消えたように見えたが、その後の変更で再度出現しており、確実な直し方は未発見。Swift 6完全準拠モードへの移行時に要再検証。

## `@ModelActor`マクロは追加の初期化引数を受け付けない

**症状:** `UploadQueue`に`ImageUploading`を注入したかったが、`@ModelActor`マクロが自動生成する`init(modelContainer:)`はカスタム引数を想定していない。
**対処:** マクロを使わず、`actor UploadQueue`を手書きし、`init(modelContainer:uploader:)`内で`ModelContext(modelContainer)`を自前生成。`ModelContext`はSendableではないが、actorの分離境界内に閉じ込める限り安全(マクロの主な価値はSendable保証そのものではなく利便性)。

## 二重オプショナルの実バグ(SourceKitノイズではなく実際のコンパイルエラー)

**症状:** `firstValue<T>(from: AsyncStream<T>) -> T?`という汎用ヘルパーに`AsyncStream<UserProfile?>`を渡すと戻り値が`UserProfile??`になり、`profile.displayName`のようなアクセスが実ビルドで型エラーになった(SourceKitではなく`xcodebuild`が検出)。
**対処:** `.flatMap { $0 }`で二重オプショナルを平坦化してから使用(`TodayViewModel.refreshBuddies`)。

## EnvironmentKeyのdefaultValueと`@MainActor`の衝突

**症状:** `AppServices`(`@MainActor` struct)を`EnvironmentKey.defaultValue`(nonisolatedな静的コンテキスト)で直接構築しようとすると分離境界エラーになる。
**対処:** `appServices`環境値を`AppServices?`にして`defaultValue = nil`とし、`SkyGridApp`のルートで`.environment(\.appServices, services)`により明示的に一度だけ注入する設計に変更。`RootView`側は`nil`の間は`ProgressView()`を表示。

## CIAreaAverageによる空色抽出の実装ポイント

- フレーム全体ではなく**上部55%の帯**のみを平均する(地面・建物の混入を防ぐ)。`CIImage`の座標系は左下原点なので、「上部」は`maxY`側の帯になる点に注意。
- `CIContext`の`workingColorSpace`/`outputColorSpace`を明示的に`sRGB`に設定しないと、ガンマがずれて不自然に暗い/濁った色が出る(既定値任せは罠)。
- 検証用に、Python標準ライブラリで「上60%=空色・下40%=地面色」の合成PNG(`clear_sky.png`/`golden_hour.png`)を生成し、`SkyColorExtractorTests`で「抽出色が地面色に引っ張られていないこと」を回帰テスト。実際の空写真フィクスチャへの差し替えは未着手(次回課題)。

## シミュレータにはカメラが存在しない

`CameraSessionController`(実機用AVFoundation実装)はシミュレータ上で一切検証できない。`SimulatorCameraSource`(`Resources/Fixtures/`の画像を巡回表示)を`ServiceFactory`が`#if targetEnvironment(simulator)`で切り替えて注入することで、Phase 1の開発・テストがシミュレータのみで完結する。

## `xcodebuild test_sim`の一過性インフラ障害

一度「Mach error -308 (ipc/mig) server died」でテストランナーの起動自体が失敗した。CoreSimulatorデーモンの一時的なクラッシュと判断し、単純に再実行して解消(コード側の問題ではなかった)。

## 次回セッションへの申し送り(未着手・既知の残課題)

- **Firebase/Firestore/Auth(Phase 2)は全くのコード未着手。** `Data/Firestore/`ディレクトリ自体が存在しない。実装前に依頼者のFirebaseプロジェクト作成・`GoogleService-Info.plist`配置が必要(VISION.md §7)。
- **BGProcessingTaskの登録・ハンドラ実装は未着手。** `UploadTriggers`はフォアグラウンド復帰+`NWPathMonitor`の2トリガーのみ実装済み。実機での検証が必要なため意図的に後回し。
- **アプリアイコンは単色プレースホルダー。** 実際のデザイン制作(Canva等)は依頼者の指示で今回のセッション中に中断・後回しにされた。
- **`SkyColorExtractorTests`のフィクスチャは合成画像。** 実際の空の写真での回帰確認は未実施。
- **ペイウォールの価格・商品構成はVISION.md §2のドラフト値をそのまま`PreviewPurchasesService`に転記しただけ。** 依頼者との協議で確定させる必要がある。
- **gitリポジトリは未初期化。** `~/Desktop/SkyGrid/`はまだ`git init`されていない(次回、必要か確認してから初期化すること)。
- **`#Predicate`のKeyPath Sendable警告は未解決の技術的負債。** 現状は警告のみでビルドを妨げないため放置しているが、Swift 6完全準拠モードへの移行時には要対応。
