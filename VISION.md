# VISION — Sky Grid(朝の空ストリークアプリ)

## ⭐ HANDOFF — 次セッションはここから読む (2026-07-30時点)

**Sign in with Apple 一式 + RevenueCatダッシュボード設定が完了(2026-07-30、詳細は[dev-notes/apple-signin-and-revenuecat-setup_2026-07-30.md](dev-notes/apple-signin-and-revenuecat-setup_2026-07-30.md))。** Apple Developer PortalのCapabilityは実機デプロイ時に自動登録済みだった。Firebase ConsoleのAppleプロバイダ有効化、App Store Connectでのアプリレコード作成(名前衝突のため「Sky Grid: Morning & Wake」で登録)とサブスクリプション/IAP商品3件(月額$3.99/年額$19.99/ライフタイム$39.99、ドル建て)作成、RevenueCatダッシュボードのApp/Entitlement(`premium`)/Product/Offering設定、`Secrets.xcconfig`へのAPIキー投入まですべて完了。**ただしRevenueCat公式ステータスページで判明した進行中のApple側障害**(2026-07-24以降登録のBundle IDでApp Store Server APIが401を返す)**の影響で、商品のStore Statusが「Could not check」のまま未検証。2026-07-30時点で再確認したが、ステータスページの最新更新(2026-07-29 09:18 UTC)は依然「Not Resolved」(Appleの修正待ち)。次回セッション開始時に改めて[ステータスページ](https://status.revenuecat.com/incidents/mr3l9wqygn3d)を確認すること。** 次に残る優先事項は (1) 上記障害解消確認、(2) iOS 26 実機での AlarmKit 発火・ロック画面・Focus・App Intent の回帰確認。Simulator は UI とスケジュールコードのビルド／遷移確認に使ったが、実アラームの音・ロック画面発火の証明には使えない。

**現在地:** 企画フェーズ完了後、依頼者指示により**デザイン制作より先にアプリコードの実装を最優先で進めた**(下記「方針転換」参照)。`~/Desktop/SkyGrid/ios/`にXcodeGenベースのプロジェクトが実在し、**オンボーディング→ハンドル設定→今日画面→撮影→投稿作成→アップロードキュー登録→(通知タップ時)カメラ直行、までLocalモックバックエンドでシミュレータ上に一気通貫に動く。** ユニットテスト39件パス、`build_sim`/`test_sim`両方エラー・警告ゼロ。**iPhone 15 Pro(「俺のGALAXY Pro Max」)へのワイヤレスデバッグ実機デプロイも2026-07-29に成功済み**(手順は[dev-notes/ios-phase1-implementation_2026-07-29.md](dev-notes/ios-phase1-implementation_2026-07-29.md)の「実機デプロイ手順」節)。~~Firebase/Firestore/Auth(Phase 2)は未着手~~ **→ 2026-07-30時点で本番構築済み(下記参照)。** 詳細な実装ログ・落とし穴は同dev-notesを参照(次回セッション必読、特に「エージェント委譲の失敗」節)。

**Codex実装更新(2026-07-29):** Today／カメラ／Grid／オンボーディングを全面再設計し、Today と Sky Grid を常時到達可能な2タブに変更。Grid は全365日が一望できる12か月×31日の配列へ更新し、画面内の共有操作から9:16書き出しを行う。`MorningAlarmScheduler` は iOS 26+ で AlarmKit の毎日・現地時刻アラームを設定し、アラーム画面の「空を撮る」操作から `LiveActivityIntent` でカメラへ直行する。iOS 17–25 は同等機能と偽らない通常リマインダーにフォールバックする。`NSAlarmKitUsageDescription`、明示的な許可要求、削除時のアラーム取消、設定画面の状態表示も実装済み。**iPhone 17 Pro Simulator (iOS 26.5) で `xcodebuild test` は42テスト成功（UIテスト2件を含む）、Today/Grid の実レンダリングを確認済み。** ~~Firebase/Auth/Firestore/Storage本番実装~~**→2026-07-30完了。** 実際に受信できるサポートURL・プライバシーポリシーの投入、AlarmKit の物理 iPhone 実機回帰は引き続き未完了(下記「次回セッションTODO」参照)。

**Claude(Sonnet)によるFirebase本番構築(2026-07-29〜30、上記Codex更新の後続作業):** Codexが書いたFirebase向けコード(`Data/Firebase/`、`firestore.rules`、`storage.rules`、`functions/`)を実際のFirebaseプロジェクトに接続。`sky-grid-app`プロジェクト作成、Blazeプラン+予算アラート(¥750)、Firestore Native DB(asia-northeast1)、Storageバケット(ユーザー本人がConsoleで"Get Started"クリック済み)、Firestore/Storage両セキュリティルールのデプロイ、匿名認証有効化、Cloud Functions `deleteAccount`デプロイまで**全完了**。シミュレータでの実疎通(匿名サインインが実Firebaseにユーザーを作成すること)も確認済み。build_sim/test_sim 47件全パス。詳細・ハマった点は[dev-notes/firebase-backend-provisioning_2026-07-29.md](dev-notes/firebase-backend-provisioning_2026-07-29.md)。

### 次回セッションTODO(2026-07-30時点、依頼者の指示によりコスト都合で一旦区切り。着手前に本節から読むこと)

**1. ~~Sign in with Apple 一式~~ → 2026-07-30完了(下記参照)**
- ~~(a) Apple Developer Portal~~ → Capabilityは既に有効化済みだった(手動作業不要と確認)
- ~~Firebase Console側の設定~~ → Services ID/Team ID/秘密鍵は不要と確認、Appleプロバイダ有効化のみで完了
- ~~(b) App Store Connect~~ → 完了。ただし「Sky Grid」は名前衝突のため実際の登録名は「Sky Grid: Morning & Wake」(アプリ内表示名は「Sky Grid」のまま)
- ~~(c) RevenueCatダッシュボード設定~~ → 完了(Entitlement `premium`、商品3件、Offering設定、APIキー投入済み)。詳細・ハマった点・**未解決のApple側障害**は[dev-notes/apple-signin-and-revenuecat-setup_2026-07-30.md](dev-notes/apple-signin-and-revenuecat-setup_2026-07-30.md)を参照。価格はドル建てで確定(月額$3.99/年額$19.99/ライフタイム$39.99、依頼者指示により円建てドラフトから変更)

**2. 上記以外に残っている必要タスク(このセッションで洗い出し済み)**
- **APNsキーのFirebase登録(未着手・新規に判明した項目):** バディ投稿通知(Cloud Functionsの`deleteAccount`と同様のFCMトリガー、VISION.md§4)が実機に届くには、Apple Developer Portalの「Keys」でAPNs Authentication Key(.p8)を発行し、Firebase Console → プロジェクト設定 → Cloud Messaging → Appleアプリの構成、にアップロードする必要がある。現状未着手で、他のどの節にも記載がなかったため今回追加
- ~~App Check enforcement~~ → **2026-07-30完了。** Firestore/Storage両サービスをApp Check Admin APIで`ENFORCED`に変更済み。iOS側`AppAttestProviderFactory`(Release)に対応するApp Attestプロバイダ登録はAPI確認の結果既に存在していた(手動登録不要と判明)。Debug/Simulator用に固定デバッグトークンを発行してtest schemeの`FIRAAppCheckDebugToken`環境変数に配線し、有効化前後でtest_sim 51件パスのベースライン→回帰なしを確認済み(手順・ハマった点は[dev-notes/app-check-enforcement_2026-07-30.md](dev-notes/app-check-enforcement_2026-07-30.md))。Cloud Functionsの`deleteAccount`は元々コード側で`enforceAppCheck: true`済み(変更なし)
- ~~Storage Rulesのクロスサービス参照の実地検証~~ → **2026-07-30完了。** Firebase Emulator Suite(`@firebase/rules-unit-testing`)で承認済み/pending/ブロック済み/無関係/未認証の全パターンを検証し、`activeBuddy()`のクロスサービス参照(Storage→Firestore)が意図通り動くことを実証済み。詳細・ハマった点(プロジェクトID不一致で検知不能になる罠)は[dev-notes/rules-emulator-verification_2026-07-30.md](dev-notes/rules-emulator-verification_2026-07-30.md)参照。次回以降`npm --prefix rules-tests run test:emulator`で再実行可能
- ~~サポートURL・プライバシーポリシーの実URL投入~~ → **2026-07-30完了。** Cloudflare Workers(静的アセット)に`skygrid-legal`としてデプロイ: https://skygrid-legal.taku810616.workers.dev/ (サポート) / https://skygrid-legal.taku810616.workers.dev/privacy (プライバシーポリシー)。`Secrets.xcconfig`/`Secrets.example.xcconfig`の両方に反映済み、build_sim確認済み。ページ内容(実際のデータフローに基づく)は`ios/legal/privacy-policy.md`・`ios/legal/support.md`が原本、`ios/legal/site/`がデプロイ用HTML。サポートメールは依頼者確認の上でtaku810616@gmail.com。デプロイ時のハマった点は[dev-notes/legal-pages-cloudflare-deploy_2026-07-30.md](dev-notes/legal-pages-cloudflare-deploy_2026-07-30.md)参照
- **アプリアイコン/ビジュアルデザイン:** 依頼者の方針転換により中断されたまま(§6参照)。再着手のタイミングは依頼者と相談
- **BGProcessingTaskトリガーの実機検証・実装、AlarmKitの物理iPhone実機回帰確認:** 既存の既知の残課題(上記Codex更新メモ参照)
- ~~実写真でのSkyColorExtractor回帰テスト~~ → **2026-07-30完了。** Wikimedia Commonsの実写真4枚(快晴/曇天/夕焼け/劇的な雲+シルエット)を追加し、Pillowによる独立クロスチェック計算値を根拠にテストを実装、51件全パス確認済み。副産物として、テストフィクスチャが誤って本体アプリのApp Storeバイナリに同梱されていた設計ミスも発見・修正(`SkyGridTests`専用リソースへ移設)。詳細は[dev-notes/sky-color-extractor-real-photos_2026-07-30.md](dev-notes/sky-color-extractor-real-photos_2026-07-30.md)

**方針転換の経緯(2026-07-29、同日中に2段階):**
1. 依頼者指示によりデザイン制作(Canva MCP + Opus)を開始 → デザイン用HTMLモックアップ(`design/screens-mockup.html`)は完成
2. 直後に依頼者から「クラウドのアーティファクト更新は不要、実際のアプリコード完成を最優先に」と明確な方針転換指示 → デザイン制作エージェントを中断し、実装計画をcode-architect(Opus)に委譲 → 返ってきたブループリントに基づき、タスク#1〜#11を全てSonnet(自分自身)が直接実装

**確定事項(変更なし):**
- アプリ名: **Sky Grid**
- コンセプト: 朝起きて外の写真を1枚撮るだけ。365マスの色モザイク「Sky Grid」が核となる差別化要素
- 技術アーキテクチャ: Firebase(Auth/Firestore/Storage/FCM/Cloud Functions 1本)+ SwiftUIネイティブ、iOS 17.0以上、Bundle ID `com.takmin.skygrid`(既存プロジェクトの命名規則`com.takmin.{app}`に準拠、当初案の`com.taku8.skygrid`から変更)
- 課金基盤: UnhookのRevenueCat/Paywall実装を移植・SGTトークンで再スキン済み(コードは完成、実APIキー未設定でPhase 1はプレビュー実装で動作)
- 広報方針: プレローンチ導線(ウェイトリスト)は不採用、早期ローンチ優先(変更なし)

**未確定・次回セッションで詰めること:**
1. **ペイウォール設計は依頼者と協議しながら深掘りする(意図的に未確定のまま)。** `Purchases/PreviewPurchasesService.swift`には下記「マネタイズ/ペイウォール」節のドラフト価格をそのまま転記しただけ
2. **アプリアイコンは単色プレースホルダー。** デザイン制作(Canva MCP等)は中断されたままなので、次回改めて着手するか判断すること

**次の開発フェーズの優先順位(2026-07-29更新):**

1. **【最優先】Apple Developer / Firebase / RevenueCat のセットアップ。** 下記「実装前チェックリスト」節を参照。コードは既にプロトコル境界越しにFirebase版へ差し替え可能な設計(`ServiceFactory`が唯一の分岐点)なので、外部セットアップさえ終われば`Data/Firestore/`の実装(Phase 2)に進める
2. **デザイン制作の扱いを依頼者と確認。** アイコン・共有カードのビジュアル制作は方針転換により後回しになったまま。改めて着手するタイミングを依頼者と相談すること
3. **BGProcessingTaskトリガーの実機検証・実装。** `UploadTriggers`は現状フォアグラウンド復帰+ネットワーク疎通の2トリガーのみ

**次回セッションの起動フレーズ:**
- 「Sky Gridの実装を進めて」または「Sky Grid、続き」
- 確実に本ファイルから始めたい場合は「`~/Desktop/SkyGrid/VISION.md`を読んで進めて」と明示してもよい

---

## 1. 競合調査

**依頼者判断(2026-07-29): Daybreakは無視して構わない。** 規模が小さく(レビュー8件)、iCloud同期のみで実質的なバックエンドがなく、競合になり得る要素はほとんどないと判断。以下は記録として残すが、差別化戦略の前提には使わない。

| アプリ | 型 | メモ |
|---|---|---|
| Daybreak - Sunrise Habits | 75日チャレンジ型、進捗写真記録 | **依頼者判断により無視してよい競合。** 無料+Pro $4.99買い切り、レビュー8件、iCloud同期のみ |
| GoOutside | 屋外フォトミッション(木/消火栓探し)+AI写真検証(自称) | 起床儀式ではなく汎用アウトドア促進が主眼、ファミリー向け |
| Sunsets Reminder / Riseroo / SunSeek / Kairis / Daylight Goals | 日照センサー(lux計測)系 | 写真×ソーシャル軸ではなくメカニクスが異なる |

---

## 2. マネタイズ / ペイウォール設計 (初期ドラフト、要協議 ⚠️)

> **この節は確定ではない。** 次回セッションで依頼者と対話しながら深掘りして更新すること。以下はOpus(planner)による初期ドラフト。

判断: フリーミアム+年額主体のサブスク。ペイウォールは「ソーシャルの広さ」ではなく「時間の深さ」に置く案。

| ティア | 内容(ドラフト) |
|---|---|
| 無料(永久) | 撮影・投稿・自分のストリーク・バディ数無制限・招待・共有カード書き出し(標準デザイン)・通知・直近30日のアーカイブ |
| Pro | 全期間アーカイブ+Sky Grid年間ビュー・原本画質の永久保存・年間タイムラプス書き出し・共有カードのデザイン違い・週次サマリー統計・HealthKit(睡眠)連携・ストリークFreeze月2回 |

価格目安(ドラフト、要検証): 月額¥600 / 年額¥2,900(ヒーロー、3日間無料トライアル)/ ライフタイム¥5,800

提示タイミング案: 起動直後のハードペイウォールは禁止。7日ストリーク達成の瞬間に文脈提示。

**次回、協議すべき論点の例:** 無料枠(30日アーカイブ)は妥当か/年額ヒーローの価格弾力性/ライフタイムの要否/そもそも「時間の深さ」軸で正しいか、他の軸(バディ人数上限、Sky Grid解像度、等)はどうか。

---

## 3. ペインポイント → 機能マッピング(確定)

| # | 本当のペイン | 機能・UI上の解 |
|---|---|---|
| 1 | 誰も見ていないので、サボっても何も起きない | **相互ブラー**: バディの今朝の写真は、自分が投稿するまでぼかされたまま |
| 2 | 布団の中の30秒で負ける | 通知タップ→アプリ内カメラ直行(ホーム画面もフィードも経由しない) |
| 3 | 寝坊した日の自己嫌悪と離脱 | 主指標を「連続日数」でなく週単位のリズム(今週5/7)に。無料でも週1日Rest Dayを許容(要検証: 緩さと継続率のトレードオフ) |
| 4 | "映え"のプレッシャー | 加工・フィルタ排除。撮った空の自動抽出平均色で「今日の色」カードを構成、写真が下手でも成果物は必ず美しい |
| 5 | 続けた証拠が手元に残らない/見せる場所がない | **Sky Grid**: 365マスのモザイク、1日1マスがその朝の空の色。9:16縦型で共有書き出し |

---

## 4. 技術アーキテクチャ / MVP最小構成(確定)

判断: Firebase(Auth / Firestore / Storage / FCM / Cloud Functions 1本のみ)+ SwiftUIネイティブ。

```
users/{uid}
  handle, displayName, avatarPath, timezone, wakeGoalMinutes,
  streakCurrent, streakLongest, lastPostLocalDate, isPro

handles/{handle} -> { uid }            // Firestoreに一意制約が無いため必須

users/{uid}/posts/{localDate}          // ★docID = "2026-07-28"
  capturedAt, uploadedAt, imagePath, thumbPath,
  skyColorHex, minutesFromGoal, reactions: { uid: emoji }

friendships/{pairId}                   // pairId = sorted(uidA,uidB).joined("_")
  members: [uidA, uidB], status: pending|accepted, requestedBy, createdAt

users/{uid}/devices/{tokenId}          // fcmToken
reports/{id}                           // 通報(App Review必須)
```

- docIDを`YYYY-MM-DD`にすることで「1日1投稿」を構造で強制(Security Ruleで`create`のみ許可・`update`禁止)
- フィードのファンアウトは持たない。`where members array-contains uid`で友達一覧→各友達のtoday docを並列取得

| サービス | 用途 | MVP |
|---|---|---|
| Auth | 匿名認証で即開始→バディ追加時にSign in with Appleへリンク | ✓ |
| Firestore | 全エンティティ、オフライン永続化はデフォルトON | ✓ |
| Storage | 写真原本+サムネ | ✓ |
| FCM | バディ投稿通知・申請通知 | ✓ |
| Cloud Functions | Firestoreトリガー1本(post作成→バディへFCM)のみ | ✓(1本) |
| ローカル通知 | 朝のリマインダーはサーバー不要・コスト0で完結 | ✓ |

**実装前に潰しておくべき落とし穴:**
1. Storage SDKにはオフラインキューが無い。撮影した瞬間にローカル保存+Firestoreのpost docだけ先に書き、画像アップロードは独自の再試行キューで後追いする(UX上は撮った時点でストリーク確定)
2. 日付境界: `localDate`は端末のローカル暦日で決定。時差移動・DSTで「同日2投稿」「1日消失」が起きうるため`timezone`を保存し変更検知時の扱いを明示(推奨: 過去は書き換えない)
3. Cloud FunctionsはBlazeプラン必須で予算暴走リスクがある唯一の箇所。Budget Alertを$5に設定。要検証: 新規プロジェクトのCloud Storage既定バケット作成自体にBlazeが必要になっている可能性
4. 画像サイズがコストの支配項。アップロード前に長辺1440px/JPEG q0.7(200〜400KB)+サムネ320pxに圧縮
5. ~~要検証: Storage Security Rulesから友達関係を参照できるか~~ → 2026-07-30、Firebase Emulator Suiteで実証済み(動作する)。詳細は[dev-notes/rules-emulator-verification_2026-07-30.md](dev-notes/rules-emulator-verification_2026-07-30.md)
6. UGCを含むためApp Review Guideline 1.2(通報・ブロック・不適切コンテンツ対応・連絡先明示)とアプリ内アカウント削除(5.1.1)はMVP必須、後回し不可

**不正対策はUIに落とす(技術検証ではなく社会的説明責任):**
- アプリ内カメラのみ、ライブラリ選択は設計上「存在させない」
- 投稿カードに撮影時刻を刻印(「6:42撮影 / 9:10投稿」の二段表示)
- バディの写真は自分が投稿するまでブラー
- リアクションより先に「見た」を表示
- 通報導線は「不正」ではなく「気になる投稿」という穏当な表現に

**CoreML/Vision:** 空・屋外シーンの自動判定はV2に送る(誤検知が初期離脱を招くリスクの方が大きい)。空の平均色抽出はMVPに含める(`CIAreaAverage`で数十行、CoreML不要)。

---

## 5. 広報・マーケティング施策(2026-07-29 改訂)

**改訂: プレローンチ導線(ウェイトリスト)は削除。** 依頼者判断により、ローンチ前の期待値作りより「実物を早くローンチし、実物に対してマーケティングする」を優先する。

**(a) 一般的な広報**
- **できるだけ早くローンチする。** ローンチ前の準備に時間をかけすぎない
- Build in public: 開発者自身がTikTok/Instagramで制作過程を発信(費用0円)
- 既存トレンドへの便乗: 「Circadian Sunmaxxing」「#thatgirl」「#morningroutine」、Sky Gridの共有カード(9:16縦型)がそのまま投稿できる設計
- ASO: 「sunrise habit」「morning walk streak」等ロングテールキーワード、最初の2枚のスクリーンショット+アイコンに投資優先度を置く

**(b) インフルエンサー協業**
- 現金タイアップ(相場$200〜$1,500/本)は初期非現実的。ギフティング(Pro無料提供)+アフィリエイト/紹介コードのハイブリッド型
- 「LOCKED」創業者の実例のように、創業者本人が直接、朝活/Sunmaxxing/That Girl系のナノ/マイクロクリエイターにDMする

---

## 6. デザインの方向性(確定、次回はこれを土台にビジュアル制作へ)

ポジショニング: 「that girl」の高彩度・完璧主義には乗らず、その隣にある"静けさ"を取る。

- **トーン:** 儀式的・寡黙・非評価的。褒めない、煽らない。コピーは1画面1行まで(「おはよう!今日も頑張ろう」ではなく「6:42」とだけ出す)
- **色:** アプリ自身が固定のブランドカラーを持たない。その日撮った空の平均色がアクセントカラーとして流れる。ベース: 温白`#FAF7F2`/墨`#1A1A18`(Light)、夜明け前の濃紺`#12141A`(Dark)
- **タイポグラフィ:** 主役は写真ではなく数字(時刻・日数)。見出しはiOS標準セリフ「New York」のLarge Title、本文・数値はSF Pro
- **主要3画面:**
  1. カメラ(起床直後) — 全画面ライブビュー、シャッター1つのみ、撮影後は「これにする/撮り直す」の2択で即終了(起床から投稿完了まで5秒が目標)
  2. 今日(ホーム) — 今朝の1枚+撮影時刻の巨大な数字+今週のリズム(7マスのみ)、無限フィードにしない
  3. Sky Grid — 365マスの色モザイク、季節推移が一目でわかる、9:16縦型で共有書き出し
- **触感:** 投稿完了時に柔らかいハプティック1回のみ。効果音・紙吹雪・レベルアップ演出なし
- **明確に置かないもの**(GoOutsideとの境界線): ランキング・レベル・バッジ・コイン・マスコットキャラ・ポイント報酬

**次回セッションでの制作方針(依頼者指示、2026-07-29):**
- Canva MCPでローカルにビジュアル案(アイコン、オンボーディング、Sky Grid画面、共有カード)を作成する
- モデルは高位のものを意図的に使う(このマシン上のOpus、または`codex` MCP経由のSol)。デザインはこのアプリで勝てる唯一の要素という位置づけのため、コストより品質を優先する(通常のSonnet優先ルーティングをこのフェーズに限りオーバーライド)

---

## 7. 実装前チェックリスト(2026-07-29 Firebase本番構築更新)

- [x] **Xcodeプロジェクト雛形作成。** `~/Desktop/SkyGrid/ios/`(XcodeGen、`project.yml`)。Bundle ID `com.takmin.skygrid`(既存プロジェクトの命名規則`com.takmin.{app}`に準拠、Team `NVZB82UK53`)。iOS 17.0以上
- [ ] Apple Developer Programの既存アカウントで`com.takmin.skygrid`のBundle ID登録・Sign in with Apple/Push Notifications capability有効化(**未着手**)
- [x] **Firebaseプロジェクト`sky-grid-app`を実際に作成・構築済み(2026-07-29)。** Auth(匿名 済み/Sign in with Apple 未・Apple側設定待ち)/Firestore(Native、asia-northeast1)/Storage/Cloud Functions(Blaze、予算アラート¥750相当)を全て有効化、`GoogleService-Info.plist`を`ios/SkyGrid/`に配置・`project.yml`にも反映済み。詳細・ハマった点は[dev-notes/firebase-backend-provisioning_2026-07-29.md](dev-notes/firebase-backend-provisioning_2026-07-29.md)
- [x] Firestore Security Rules・Storage Security Rulesともに実プロジェクトにデプロイ済み(2026-07-30)
- [ ] App Store Connectで新規アプリレコード作成、アプリ名「Sky Grid」の空き確認(**未着手**)
- [ ] RevenueCatダッシュボードで新規App作成、月額/年額/ライフタイムの3商品を設定(価格は要協議のため仮設定でよい)、APIキーを`ios/SkyGrid/Config/Secrets.xcconfig`に設定(`Secrets.example.xcconfig`参照)。コード側(`Purchases/RevenueCatService.swift`)は移植済み・未検証(**未着手**)

---

## 8. iOS実装状況(Phase 1完了、2026-07-29)

`~/Desktop/SkyGrid/ios/`にXcodeGenベースのプロジェクトが実在。詳細な実装ログ・落とし穴は[dev-notes/ios-phase1-implementation_2026-07-29.md](dev-notes/ios-phase1-implementation_2026-07-29.md)。

**動く範囲(Localモックバックエンド、外部アカウント一切不要):**
- オンボーディング(3画面)→ハンドル設定→今日画面 の起動フロー一式
- カメラ撮影(シミュレータはフィクスチャ画像巡回、実機はAVFoundation実装)→`CIAreaAverage`による空色抽出→圧縮→投稿作成→オフラインアップロードキュー登録
- Sky Grid画面(365マスモザイク、季節推移する決定論的モックデータ)、共有カード書き出し(9:16)
- ストリーク/週リズム計算(タイムゾーン変更・休息日の免除ロジック込み)
- バディ機能(申請・承認・相互ブラー)、ローカル通知→カメラ直行
- RevenueCat/Paywall(Unhookから移植・SGTトークンで再スキン、プレビュー実装で動作)
- ユニットテスト39件、`build_sim`/`test_sim`ともにエラー・警告ゼロで通過確認済み(2026-07-29時点)

**未着手(2026-07-29 Firebase本番構築更新後の最新状態):** Cloud Storageバケット作成(Console一クリック待ち)、Sign in with Apple(Apple Developer側設定待ち)、実アイコン/デザイン制作、BGProcessingTaskトリガー、実写真でのSkyColorExtractor回帰テスト。Firebase本体(Auth匿名/Firestore/Cloud Functions)は実プロジェクトとして構築済み — 詳細は[dev-notes/firebase-backend-provisioning_2026-07-29.md](dev-notes/firebase-backend-provisioning_2026-07-29.md)参照。

**設計判断の要点(code-architectブループリントより):** `ServiceFactory`が唯一の分岐点でLocal⇔Firebase切替。`GoogleService-Info.plist`の有無だけで自動判定(`-SGForceLocalBackend`起動引数で強制ローカルも可)。Firestoreの`post`ドキュメントはFirestore自身のオフライン永続化に任せ、画像バイトだけを独自の`UploadQueue`(SwiftData)で管理する設計。Storage画像パスは`posts/{uid}/{UUID}.jpg`でuid+推測不能UUID方式(クロスサービスRulesは試みず)。

---

## 9. UI改善(2026-07-29完了、下記は刷新前の監査記録)

**実施内容:** 儀式的なToday状態（未撮影／記録済み）、大きな時刻、空色由来のアクセント、7日リズム、カメラの二択レビュー、Grid共有、AlarmKit設定画面、視覚的オンボーディングを実装済み。下記は改修前に残した監査記録であり、現状の評価ではない。

### 現状のUI実装に対する具体的なギャップ分析(コード監査済み、2026-07-29)

`ios/SkyGrid/Sources/`を実際にgrepして確認した事実(推測ではない):

| # | 事実 | 何が問題か |
|---|---|---|
| 1 | **アニメーション修飾子(`withAnimation`/`.animation(`/`.spring(`/`.transition(`)がコードベース全体で0件** | 投稿完了・週リズムのマス埋まり・バディタイルの色明滅(相互ブラー解除)・ストリーク更新など、本来「毎朝の小さな喜び」になるはずの瞬間が、現状すべて無演出でインスタントに切り替わる。VISION.md §6が明示する「投稿完了時に柔らかいハプティック1回」はコード上に実装済み(`Haptics.postCompleted()`)だが、**それに対応する視覚的な動きが伴っていない** — 触感と視覚が噛み合っていない状態 |
| 2 | **`.shadow()`の使用は`ShutterButton.swift`の1箇所のみ** | ほぼ全ての画面が完全にフラットで、階層・奥行きの手がかりがない |
| 3 | **spacing/paddingの数値がハードコードで11種類以上バラバラに散在**(`spacing: 16`が5箇所、`.padding(24)`が5箇所、`.padding(.vertical, 14)`が4箇所...と、名前付き定数を経由せず各Viewで直書き) | 画面間で微妙な余白の不揃いが起きやすい(coding-style.mdの「マジックナンバー禁止」にも抵触) |
| 4 | **アプリアイコンは単色プレースホルダーのまま**(Canva等でのデザイン制作は依頼者の方針転換により中断・後回しになっている) | ホーム画面上での第一印象が「未完成」に見える最大の要因になりうる |
| 5 | **Onboarding3画面(Welcome/WakeGoalPicker/PermissionsPrimer)が純粋にテキスト+ボタンのみ** | 初回起動の第一印象を作る画面が現状最も作り込みが薄い |
| 6 | 絵文字を構造的アイコンとして使っている箇所は0件(監査済み・良好) | 特に問題なし — この点は既にクリア |

### 次回セッションでの進め方(推奨)

1. **設計判断としてOpus(このマシン上)への委譲を検討すること。** 依頼者は過去に「デザインが競争優位の唯一要素な案件では高位モデルにコストをかけてよい」と明示している。今回のUI改善は「実際に毎日使いたくなる」という主観的・感性的な品質判断を伴うため、実装の前に一度設計方針(アニメーション設計・エレベーション体系・スペーシングスケール・アイコン層の扱い)をOpus(architect/code-architect)に整理させてから、Sonnetが実装するのが望ましい。
2. **`~/.claude/rules/ecc/swift/ui-design.md`(iOS UI Design Quality)の監査手順に沿うこと。** このルールは「なぜアプリが"generic"に見えるか」の監査順序(①アイコン層→②配色トークン→③マテリアル/シャドウの重複→④スペーシング/タイポグラフィ)を定めており、上記の事実整理は概ねこの順序に沿っている。特に「投稿完了・マイルストーン級の状態変化には`.spring()`アニメーション+ハプティックの両方を組み合わせるべき」という同ルールの指摘が、上表#1と直接一致する。
3. **具体的な着手候補(優先度順):**
   - 週リズムの7マスが埋まる瞬間・バディタイルの相互ブラー解除の瞬間に`.spring(response:dampingFraction:)`アニメーションを追加(ハプティックとの対応関係を作る)
   - `DesignSystem/`にスペーシングトークン(例: 4/8/12/16/24/32の名前付き定数)を新設し、既存Viewの直書き数値を置換
   - Onboarding3画面に最低限のビジュアル要素(SF Symbolベースのブランドマーク等、絵文字は使わない)を追加
   - アプリアイコンのデザイン制作(中断されたまま — Canva MCP+高位モデルでの再着手を依頼者と確認)
4. **実機(iPhone 15 Pro、ワイヤレスデバッグ設定済み)で視覚確認しながら進めること。** シミュレータのbuild_sim/test_simだけでなく、実際の画面での見え方・触感の一致を都度確認する(手順は本ファイル上部のdev-notes参照)。

---

## 参考: 企画書アーティファクト(Claude Artifacts)

- [アプリ・アイデア台帳(42件、AP-02含む)](https://claude.ai/code/artifact/5960fee5-2894-4cfc-b709-d83246d44403)
- [Sky Grid 製品企画書(6方向の初期検討、本ファイルが最新の正)](https://claude.ai/code/artifact/c249d1b7-e14b-4cf0-a860-f430a6e777d8)

**重要:** 上記アーティファクトは2026-07-29の依頼者フィードバック反映**前**の版。本VISION.mdが常に正。アーティファクト側も更新済みだが、齟齬があれば本ファイルを優先する。
