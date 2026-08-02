# 写真キャッシュ・グリッド再設計・Community Safety・アカウント削除App Check問題(2026-07-31 午後セッション)

## 背景

依頼者から6件の不具合報告(カメラ→サーバー未反映は別セッションで解決済みのため対象外)と、
「毎回サーバーに写真をリクエストしている」「Sky Gridのグリッドの隙間・曜日基準配置」の改善要望。

## 1. 写真の毎回サーバー再リクエスト問題(修正済み・検証済み)

**根本原因**: `Sources/Persistence/ImageFileStore.swift` にはサムネイル用のディスクキャッシュ
(`cachedThumbnailData`/`cacheThumbnail`, 32MB上限)が既に存在し `GridArchiveViewModel.loadThumbnail`
で正しく使われていた。しかし **フル解像度画像**を表示する `Sources/Today/TodayPhotoCard.swift` の
`loadImage()` は、ローカルoutbox確認の次に**いきなりネットワークfetchへ飛んでいた**——ディスク
キャッシュの段を素通りしていた。この`TodayPhotoCard`はToday画面の「今朝の写真」と、Sky Grid
アーカイブの日別詳細シート(`ArchivePhotoDetail`)の両方で共用されているため、日別写真を開き直す
たびに毎回フル画像をStorageから再ダウンロードしていた。

**修正**: `ImageFileStore`のサムネイル用キャッシュ関数を汎用化(`cachedData`/`cache`/`trimCacheIfNeeded`
の共通プライベートヘルパーに切り出し)し、フル画像用に別ディレクトリ・別予算(64MB)の
`cachedImageData`/`cacheImage`を追加。`TodayPhotoCard.loadImage()`にpending→**ディスクキャッシュ→**
ネットワークの順で確認する段を追加、フェッチ成功時に`cacheImage`で書き込むようにした
(`GridArchiveViewModel.loadThumbnail`と同じ3段パターン)。リモートパスはdocID単位でcreate-only
不変のため、キャッシュキーをremotePathのみにする設計は無効化条件を考える必要がなく安全。

## 2. Sky Gridの隙間・曜日基準配置(修正済み・スクリーンショットで視覚確認済み)

**発見した構造**: このアプリには2つの異なるグリッド表現があった。
- `GridCanvas`(年間365マスのCanvas描画、"SKY GRID"見出し直下)は元々spacing:0・day基準で
  問題なかった。
- **`SkyGridView.swift`の`MonthlyPhotoGrid`("PHOTO ARCHIVE"セクション)** が実際の依頼対象で、
  `GridLayoutMath.calendarSlots(year:month:)`(日曜始まりの曜日オフセット付き、先頭に空白セル)
  を使い、`LazyVGrid(spacing: 3)`で隙間もあった。

**修正**: `GridLayoutMath.calendarSlots`を削除し、`sequentialDates(year:month:)`
(単に`1...daysInMonth`を返すだけ、空白オフセットなし)に置き換え。`MonthlyPhotoGrid`の
`LazyVGrid`列間隔・行間隔を0に、`ArchivePhotoTile`の角丸クリップとストロークも撤去
(`.clipped()`のみに変更)——spacing 0でも角丸+ストロークが残っていると隣接セルの継ぎ目に
背景色の隙間が見えてしまうため。UIAudit「grid」シナリオでスクリーンショット確認済み:
1日目が左上から連続配置、隙間なしのモザイクになっている。

`Tests/GridLayoutMathTests.swift`の`calendarSlotsPreserveMonthGeometry`を
`sequentialDatesPackFromDayOne`/`sequentialDatesMatchLeapFebruary`に置き換え。

## 3. Community & Safetyが「空っぽ」に見える問題(修正済み)

**発見**: `SettingsView.swift`内の`CommunitySafetyView`は静的な説明文2行だけで、画面の残り
75%が完全な空白だった——依頼者の「何も表示されていない」という報告は文字通りではないが、
実質的に正しい体験だった。

**根本原因の深掘り**: `FriendRepository.block(ownerUid:blockedUid:)`/`unblock(...)`は実装済み
だったが、`FirebaseFriendRepository.observeFriendships`が
`.filter { (($0.data()["blockedBy"] as? [String]) ?? []).isEmpty }` で
**ブロック済みの関係を無条件にストリームから除外**していた。つまりブロックした瞬間、
そのbuddyは画面上のどこからも二度と見えなくなり、**`unblock`を呼び出すUI経路がアプリ内に
一つも存在しない**——実装されているのに到達不能なコードだった。

**修正**: `Friendship`モデルに`blockedBy: [String]`を追加、`FirebaseDocumentCodec.friendship(from:)`
でデコード。`FriendRepository`に`observeBlockedFriendships(uid:)`を追加。実装は
`observeFriendships`と**同じ`members array-contains uid`クエリ**を使い、`blockedBy`のフィルタは
クライアント側で行う——Firestoreは1クエリにつき`array-contains`を2つ使えず(`blockedBy`単独では
Security Rulesが`members`条件しか見ていないため証明可能性の観点でも通らない)、既存クエリを
再利用するのが正解。`CommunitySafetyView`に「BLOCKED」セクションと`BlockedBuddyRow`
(表示名解決+Unblockボタン)を追加。`SettingsView`/`RootView`/`SkyGridApp.swift`(UIAudit)の
呼び出し元を`friendRepository`/`userRepository`を渡すよう更新。

## 4. Privacy Policy / Contact Us遷移(コード上は問題なし、実機ビルドが古い可能性)

`SettingsView`の`Link(destination:)`はInfo.plist経由でSecrets.xcconfigのURL
(`https://skygrid-legal.taku810616.workers.dev/`等、200 OK確認済み)を読む。UIAudit「settings」
シナリオ+実XCUITestで、Contact us/Privacy Policyの両方をタップ→Safariへの遷移(`safari.wait(for:
.runningForeground)`)→アプリへの復帰、まで確認できた。**現在のコードでは正常に動作する。**
依頼者の実機が2026-07-30より前のビルド(Secrets.xcconfigのURL設定前)のままだった可能性が高い
——再デプロイして確認を推奨。

※ XCUITestの罠: SwiftUIの`Link`は`app.links`ではなく`app.buttons`としてクエリしないと見つからない
(automation type mismatch: "computed Button from legacy attributes vs Link from modern attribute")。

## 5. BuddiesViewの浮動タブバーがリストの最終行を隠す(修正済み)

`TodayView`/`SkyGridView`は「浮動タブバーが最後の週/行を覆う」問題に対し`.padding(.bottom, 128)`
で対処済み(コードコメントに経緯あり)だったが、`BuddiesView`(List)には同じ対処がなく、
「YOUR BUDDIES」の最後の行がタブバーに隠れていた。`.safeAreaInset(edge: .bottom) { Color.clear
.frame(height: 128) }`をListに追加して解消。UITestでスクロール後スクリーンショット確認。

## 6. アカウント削除ができない問題 — 根本原因確定・修正・デプロイ済みだが、**別の新規外部障害で
   最終確認がブロック中**(重要、次回セッション必読)

### 6-1. 元々診断した根本原因(code-architect/Opusによる詳細調査で確定)

`AccountDeletionService.swift`は`HTTPSCallableOptions(requireLimitedUseAppCheckTokens: true)`で
呼び出し、対応する`functions/src/index.ts`の`deleteAccount`は`consumeAppCheckToken: true`だった
(「破壊的操作のリプレイ防止」という意図)。

- **F1(最重要)**: `consumeAppCheckToken: true`は`firebase-functions`のソース上、
  `alreadyConsumed`を記録するだけで**リクエストを拒否する処理が一切ない**。つまりこの
  「リプレイ防止」は最初から一度も機能していなかった。
- **F2**: limited-useトークンのミントに失敗すると、iOS SDK(`FunctionsContext.swift`)は
  **placeholderトークンをそのまま送信**し、サーバーは「Decoding App Check token failed」で
  拒否する——観測したサーバーログと完全一致。
- **F3**: App Check Debug Provider自体はlimited-use対応済み(SDK側の不備ではない)。
  backendが交換を拒否していた、という事実だけが分かっている(拒否理由は当時未確定)。

**採用した修正(Plan A)**: `requireLimitedUseAppCheckTokens`/`consumeAppCheckToken`を両方削除、
`enforceAppCheck: true`のみ維持。リプレイ耐性は「認証済み呼び出し元のuidのみに作用する」
「冪等」という構造的性質に置き換え。`admin.auth().deleteUser(uid)`の再試行時
`auth/user-not-found`を握りつぶして200を返すよう変更(部分失敗後のリトライが505にならないように)。
`FirebaseRepositoryError.swift`に`com.firebase.functions`ドメインの分岐を追加
(App Check拒否や未認証エラーが`.unknown`に丸められ、UIが常に同じ「もう一度試してください」を
出していた問題も併せて解消)。

`npm run build`(tsc)・`npm test`(3件)通過後、`firebase deploy --only functions:deleteAccount`で
本番デプロイ済み。

### 6-2. デプロイ後の再検証中に発見した、**全く別の新規External障害**(未解決)

修正後に実機能検証(XCUITest+実Firebase)を行ったところ、依然として「Could not delete account」
が発生。調査の結果、**limited-use云々とは無関係に、App Checkのデバッグトークン交換自体が
このセッションの途中から失敗するようになっていた**ことを突き止めた:

1. 同一セッション内、07:19 UTC時点では`exchangeDebugToken`は成功していた(Firestore/Storageも
   正常)。しかし07:39 UTC以降、**同じ値・同じ登録済みトークンで**client os_logに
   `[FirebaseAppCheck][I-FAA004002] Failed to exchange debug token`、詳細は
   `HTTP 403 { "message": "App attestation failed." }`が出るようになった。
2. Admin APIで登録済みデバッグトークンの値を確認 → `Secrets.xcconfig`と完全一致(値のズレでは
   ない、今朝の別バグとは別物)。
3. **裸のcurl**(正しいAPI key・正しいJSON body・`X-Ios-Bundle-Identifier`ヘッダ付きも試行)で
   `exchangeDebugToken`を直接叩いても同じ403。アプリ側のバグではなくサーバー側の拒否と確定。
4. **新規デバッグトークンをAdmin APIで作り直しても同じ403**——特定トークンの登録破損ではない。
5. Firebase Status Dashboardを確認 → App Check/Authenticationに関する進行中障害は無し
   (Hosting custom domainsとPerformance Monitoringの障害のみ)。

→ **原因未確定のまま、時間を置いても解消しなかった。** グローバル障害でもトークン値のミスでも
なく、このプロジェクト固有・現在進行中の何かがApp Check debug providerの交換を拒否している。
次回セッションはここから: Firebase Consoleの当該アプリのApp Check設定画面を目視確認する
(Admin APIのGETエンドポイントでは個別アプリのフル設定を引けなかった)、または数時間〜翌日
時間を置いて再試行することを推奨。**アカウント削除の修正自体(6-1)はコードレベルで正しく、
デプロイ済みである**——この6-2の障害が解消され次第、`testRealAccountDeletionSucceeds`
(UITests/SkyGridUITests.swift)を再実行して最終確認すること。

### 6-3. 依頼者の指示による追加の批判的検証(gcloud logging直読み、事実で裏取り)

依頼者から「本当に削除できないのか、Firebaseサーバー側を懐疑的に確認せよ」との指示を受け、
クライアント側のエラー表示を信用せず`gcloud logging read`で`run.googleapis.com/requests`
(Cloud Runの実HTTPレスポンス)を直接確認した。

- **本日(2026-07-31)の4回の削除試行は全てHTTP 401**(App Check拒否、遅延0.02〜2.2秒——
  ハンドラ本体に到達する前に即座に拒否されている)。
- **しかし前日(2026-07-30) 18:03:37 UTCと22:26:41 UTCの2回は、"Callable request verification
  passed"の後、HTTP 200・レイテンシ4.3秒/6.3秒で完了している。** このレイテンシは
  Firestore複数クエリ+Storage一括削除+Auth削除という実処理内容と整合しており、App Check
  さえ通過すれば**削除ロジック自体は正しく完走する**ことが事実で裏取りできた。

**結論**: 「アカウント削除ができない」の実体は、削除処理そのものの欠陥ではなく、
**App Checkの入り口(トークン検証)で100%弾かれていること**に尽きる。6-1の根本原因
(limited-useトークン要求)は昨日〜今日未明までの間は実際に問題で、それを取り除く修正は
正しい。今日発生している6-2の新規障害(App attestation failed)が唯一の残存ブロッカーであり、
これはSkyGridのコードでは直せない外部要因。

### 副産物の技術メモ: App Check debugTokens作成APIの罠

`POST .../debugTokens`のリクエストボディに`{"token": "<好きなUUID>"}`を渡しても**無視される**
——サーバーが独自にUUIDを生成し、レスポンスの`name`フィールド末尾(base64)にその値が入る。
今朝の`app-check-debug-token-mismatch_2026-07-31.md`で見つかった「記録された値と実際の値が
ズレていた」というミスは、おそらくこのAPI仕様(指定値が黙って無視される)が原因だったと
推測できる。**次回このAPIで新規トークンを作る際は、必ずレスポンスの`name`を都度base64デコード
して実際の値を確認すること。**

## 6-4. RevenueCat実購入テスト(Test Store経由、依頼者指示で追加実施)

依頼者から「実際に課金できるか自律的にテストせよ」との指示。ローカル`.storekit`設定ファイルは
このプロジェクトに存在せず、Debug構成は`REVENUECAT_API_KEY_TEST`(Test Store)を使う設計
(`Config/Debug.xcconfig`)。実StoreKit Sandbox経由の検証はApple IDサインインが必須で人間の
関与なしには実行不可(既存ポリシー通り)。

**Test Store経由で実施できる最大限の検証**として、`testRealTestStorePurchaseGrantsEntitlement`
をUITestsに追加し、実際に「Continue with Annual」タップ→RevenueCatのTest Store確認シート
(「Test Store Purchase」/「Test valid purchase」/「Test failed purchase」/「Cancel」)まで到達
することを確認。**重要な罠**: 初回実装時は「Continue with Annual」ボタンが確認シート表示で
覆われて非表示になったことを「ペイウォールが閉じた=購入完了」と誤判定してしまった
(実際にはTest Store確認シートに追加のタップが必要で止まっていた)。「Test valid purchase」を
タップするステップを追加して修正後、実際にペイウォールが閉じ、Settingsに
「Sky Grid Pro is active」が表示されることまで確認済み(`test_sim`パス)。

これは`Purchases.shared.purchase(package:)`という本番と同じコードパスを実際に通す、実購入呼び出し
である点が重要(決済の最終解決だけがReal StoreKitではなくRevenueCat自身によるモック)。
**これ以上の検証(実Apple ID・実StoreKit Sandbox・Release構成)は人間の介在なしには不可能。**

## 6-5. App Store Connectでの実価格変更UIが見つからず未完了(重要、次回セッション必読)

依頼者に再ログインしてもらい、"Sky Grid Pro Monthly"のサブスクリプション価格編集画面
(`/apps/6796222704/distribution/subscriptions/6796226188`)まで到達。「価格および通貨のすべて」
ページ(`/pricing-matrix`)で$3.99ベースの175地域価格プレビュー計算は行えた(有効なApple価格
ティアであることも確認済み)。**しかし実際に確定・保存するUIコントロールを発見できなかった**:

- `pricing-matrix`ページは`read_network_requests`で確認した限りAPIコールを一切発行しない
  ——純粋なプレビュー計算ツールで保存機構がない。
- サブスクリプション詳細ページの「価格を追加」ボタンは、DOM調査(`javascript_exec`)で確認した
  限り「お試しオファーを作成」「オファーコードを作成」「プロモーションオファーを作成」の
  3つのオファー系アクションしか持たず、ベース価格変更の選択肢がない。
- 「価格を再計算」という、前回セッションのdev-noteに記録されていたラベルのUI要素は
  現在のUIには存在しない(見当たらない、または呼称が変わった可能性)。

**次回セッションはここから**: 依頼者に直接「$5.99への変更時にクリックした具体的な画面・
ボタン」を確認するか、Apple公式ドキュメント(App Store Connect Help)の
「サブスクリプション価格の設定」節を確認すること。Monthly/Annual/Lifetime共通の対象値:
Monthly $3.99(元の確定値)、Annual/Lifetimeは依頼者に確認要(元の$19.99/$39.99へ戻すか、
$3.99ベースで別途再計算するか未確定)。

## 7. RevenueCat「Credentials need attention」の解決確認と価格の不一致(依頼者対応待ち)

RevenueCat公式ステータスページで2026-07-31 06:30 UTCに**インシデント解決済み**を確認。
実際にDebug構成でPaywallの実オファリングが読み込めることも確認(ただしDebug構成は
RevenueCat "Test Store"を使うため、Apple側401の実修正確認にはならない——別軸の検証)。

**価格の食い違いを発見**: 依頼者は7/31未明のセッションで月額$5.99ベースに改定したはずだが、
実際に確認された価格は3系統でバラバラだった。
- App Store Connect(本物、依頼者が最後に確認した状態): $5.99/$44.99/$59.99
- RevenueCat Test Store(Debugビルドが使う模擬価格、UI編集不可・削除+再作成が必要): $9.99/$79.99/$99.99
- `SkyGridApp.swift`の`UIAuditPurchases`のハードコード値(UIAudit画面専用、実売上に無関係):
  $3.99/$19.99/$59.99

依頼者からは「月額$3.99ベースに戻してほしい」との指示があったが、**App Store Connectでの実価格
変更にはApple IDサインインが必要で、パスワード等の認証情報入力は本エージェントに禁止された
操作のため代行不可**。依頼者自身の操作が必要(具体的な設定値の提示は可能)。RevenueCat Test
Storeの価格編集もダッシュボードUIに直接編集機能がなく、削除+再作成が必要(Offering紐付けへの
影響を要検討、今回は未着手)。

## 状態まとめ(次回セッション向け)

| 項目 | 状態 |
|---|---|
| 写真キャッシュ | 完了・コード実装済み |
| Sky Gridグリッド再設計 | 完了・スクリーンショットで視覚確認済み |
| Community & Safety(ブロック管理) | 完了・スクリーンショットで視覚確認済み |
| Privacy/Contact Us遷移 | コード上問題なし(実機で再現するなら再デプロイを試すこと) |
| Buddiesリストのタブバー隠れ | 完了・スクリーンショットで視覚確認済み |
| アカウント削除(App Check limited-use) | コード修正・デプロイ完了。**別の新規App Check障害(6-2)で最終E2E確認がブロック中** |
| RevenueCat価格($3.99ベースへ) | 依頼者のApp Store Connect操作待ち(具体的手順は提示可能) |
