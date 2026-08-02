# セッション引き継ぎ: Paywall再設計ブループリント確定 + アラーム設計判断は次回続行(2026-08-01)

**重要: このセッションはコスト高騰(複数回のCRITICAL警告)のため、依頼者の指示によりここで区切り、
次回セッションで続行する。** 以下は次回セッション冒頭で必ず読むこと。

## 今回完了した項目(コード変更・ビルド確認済み)

1. **アカウント削除後ページ**: `AccountDeletedView.swift`新設、SkyGridデザインに統一済み。
2. **オンボーディング質問の1問1ページ化**: `RitualRhythmQuestionsView`/`PrivacyAndReminderQuestionsView`を
   `PaceQuestionView`/`FrequencyQuestionView`/`PrivacyQuestionView`/`ReminderQuestionView`の4画面に分割。
   `OnboardingStep`に`.pace`/`.frequency`/`.privacy`/`.reminder`を追加、全体8ステップに更新
   (progress表示も6分の◯→8分の◯へ全箇所更新済み)。
3. **カメラ確認画面のボタン幅オーバーフロー修正**: `CameraChoiceButtonStyle`に`lineLimit(1)`+
   `minimumScaleFactor(0.75)`追加(実機で報告された「Retake/Use this oneが画面からはみ出る」不具合)。
4. **アラーム競合の調査(一次結論、要再確認—下記参照)**: iOS 26+はAlarmKit使用でシステムアラームと
   同等の最優先表示。iOS 17-25はUNNotificationフォールバックでその優先度を持たない。
5. **プラン別アーカイブ容量制限**: クライアント側(`ProGate.swift`)は実装済み。ただし`firestore.rules`は
   所有者自身の投稿を全期間読み書き自由にしており、サーバー側では制限を強制していない(セキュリティ
   ホールではないが完全性の観点で記録)。
6. **設定タブ vs 歯車アイコン**: 歯車アイコン維持と判断済み(VISION.mdの最小主義方針、既存3タブ化での
   padding負債履歴を根拠)。コード変更なし。
7. **バックログ2件をproject memoryに保存済み**: App Store側オファーコード作成タスク、バディシステム
   次回調査タスク(`~/.claude/projects/-Users-taku8-Desktop-SkyGrid/memory/`)。

## 次回セッション最優先タスク1: Paywall多段階フロー再設計の実装

code-architect(Opus)による詳細な実装ブループリントが完成済み。**コードはまだ一切変更していない
(設計のみ、Read/Grepのみで実装は次回)。** 以下、ブループリントの全文をそのまま転記する
(再生成すると高コストなため必ずこれを使うこと)。

<details>
<summary>ブループリント全文(クリックで展開)</summary>

### 0. 事前に確認した事実(設計判断の土台)

| # | 観測事実(file:line) | 設計への影響 |
|---|---|---|
| F1 | `Config/Release.xcconfig:1`が`#include? "Secrets.xcconfig"`、`Config/Secrets.xcconfig:13-14`に`SKYGRID_EXIT_OFFER_CODE = SKYGRID20`/`..._DESCRIPTION = 20% off your first annual term.`が実在。よって`ExitOfferConfiguration.current`はReleaseでもnon-nil。 | ExitOfferは「未設定だから出ない」ではなく現に出る。ASC側にコードが無ければ「20%オフ」を約束してredeem失敗する。削除判断の決定打(§6)。 |
| F2 | UIテスト4件が現行の単一画面レイアウトに依存: `SkyGridUITests.swift:72-82`(`SKY GRID PRO`と同一画面に`Annual/Monthly/Lifetime`)、`:111-112`/`:273-274`(`Continue with Annual`を15/20秒待ち)、`:242-243`(`Annual` staticTextを20秒待ち)。 | 3段階化で4件とも落ちる。ブループリントに導線更新を含める必要あり(§9)。 |
| F3 | dev-notesによれば、ASCのサブスク審査用スクショは`screenshots/ui-audit-paywall-final.png`=「Annual/Monthly/Lifetime価格が表示されたペイウォール画面」で、`-SkyGridUIAuditScenario paywall`から生成されている。 | 価格が3ページ目に移ると、この起動引数だけでは審査用スクショが撮れなくなる。Planステップ直行のaudit scenarioが必須(§9)。 |
| F4 | `PaywallViewModel.swift:4`は「Unhookからnear-verbatim移植・app-agnostic」と明記。 | ステップ管理をViewModelに入れると移植元との同期性が壊れる。ViewModelは無改修にする(§1 D2)。 |
| F5 | `OnboardingCoordinatorView.swift`に、`enum Step`+`switch`+`.animation(_, value: step)`という多段フローの既存パターンがある。 | 新規パターンを発明せず、これに揃える(§1 D1)。 |
| F6 | `PaywallView.swift:244-251`のRestoreは現在1画面目に露出。`SettingsView.swift`にRestore行は無い。 | Restoreを Planステップに移すと、再インストール済み購入者の到達性が1タップ→3タップに悪化。補償措置が要る(§8-R)。 |
| F7 | `project.yml`は`sources: - path: SkyGrid/Sources`(ディレクトリ指定)だが`.pbxproj`は明示fileRef列挙(XcodeGen生成物)。 | 新規ファイル追加後に`xcodegen generate`必須。 |
| F8 | `PaywallView.swift:9-10`のドキュメントコメントは「total prices … are all visible before a person initiates a purchase」と現行契約を宣言している。 | 多段化はこの契約文の書き換えを伴う(黙って無効化しない)。 |

### 1. 設計判断(Decision → 理由)

- **D1**: ステップ機構は`switch step`+`.animation`方式(NavigationStack pushでもTabView(.page)でもない)。理由: F5の既存パターンと同型。NavigationPathだとシステム戻るジェスチャがステップ遷移を横取りし、`resolveExit`/analyticsの一元管理が崩れる。
- **D2**: `PaywallViewModel`は1行も触らない。理由: F4。ステップは純粋な画面遷移状態であり購入ドメインではない。
- **D3**: 主CTAは`.safeAreaInset(edge: .bottom)`に固定し、ScrollViewの中に置かない。理由: 依頼者の指摘の実体は「価格・操作に到達するのにスクロールが要る」こと。各ステップでCTAが常時画面内であることが今回の構造変更の本体。
- **D4**: 商品フェッチのタイミングは現行のまま(コンテナの`.task`で即開始)。理由: ステップ1・2を読んでいる数秒がプリフェッチ時間になり、Planステップは実質ノーウェイトで描画できる。
- **D5**: フロー形状はエントリーポイントで1箇所だけ差をつける(詳細は§5)。
- **D6**: ExitOfferは削除(§6)。
- **D7**: Analyticsは「新イベント1種+新パラメータ1個」だけ追加(§7)。

### 2. 状態構造

**新規の純粋型(テスト対象)**: `ios/SkyGrid/Sources/Paywall/PaywallStep.swift`
```swift
enum PaywallStep: String, CaseIterable, Equatable {   // rawValue = analytics用固定タクソノミー
    case value      // "value"
    case features   // "features"
    case plan       // "plan"
}

struct PaywallFlow: Equatable {
    let steps: [PaywallStep]                    // 常に末尾は .plan
    static func make(for entryPoint: PaywallEntryPoint) -> PaywallFlow
    var first: PaywallStep { steps[0] }
    func next(after step: PaywallStep) -> PaywallStep?
    func previous(before step: PaywallStep) -> PaywallStep?
    func isFinal(_ step: PaywallStep) -> Bool
    func index(of step: PaywallStep) -> Int?    // ステップドット表示用
}
```
`ExitOfferPolicy`/`AutomaticPaywallPresentationPolicy`と同じ「純粋enum/struct + Swift Testing」という既存パターンに合わせる。

**`PaywallView`のstate変数**:
| 変数 | 扱い |
|---|---|
| `selectedProductID: String?` | 据え置き |
| `hasResolvedExit: Bool` | 据え置き |
| `didRecordPresentation: Bool` | 据え置き |
| `showExitOffer`/`isPreparingExitOffer` | **削除**(§6) |
| `step: PaywallStep` | **新規** `@State`。初期値は`initialStep ?? flow.first` |
| `viewedSteps: Set<PaywallStep>` | **新規** `@State`。`stepViewed`の重複送信防止 |
| `flow: PaywallFlow` | **新規** `let`。initで`PaywallFlow.make(for: entryPoint)` |

`init`に`initialStep: PaywallStep? = nil`を追加(既定nil=挙動不変)。用途はF3の審査スクショ再現とUIテスト、SwiftUI Preview。

**遷移図**:
```
呼び出し元(sheet/fullScreenCover: 4箇所とも変更不要)
   ↓
PaywallView(コンテナ: ツールバー・分析・購入/復元・.task/.onDisappearを所有)
   .task → recordPresentationIfNeeded() → .presented → preparePaywall()(現行のまま、ステップ1表示中に裏で走る)
      .subscribed → onEntitlementGranted() → dismiss()(不変)
      それ以外 → viewModel.stateを更新
   [短絡] viewModel.state == .entitlementUnavailable → PaywallStatusView(ステップ機構をバイパス)

switch step:
  .value: PaywallValueStepView 【価格なし】
    RitualGridMark(108)/"SKY GRID PRO"/entryPoint.headline/"Keep the newest 30 days free…"/personalizedValueNote
    [主]"See what Pro opens" → advance()  [従]"Continue with Free" → resolveExit(.continueWithFree)
  .features: PaywallFeaturesStepView(showsHeadline:) 【価格なし】
    entryPoint.firstArchiveBenefit/"Browse a month at a time"/"A full-year share card"/freeChoice
    [主]"See plans and pricing" → advance()  [従]"Continue with Free"
  .plan: PaywallPlanStepView 【★価格の初出はここだけ】
    .loading/.failed/.loaded(3件を1つのリストに統合、Annual既定選択)
    [主]"Continue with Annual"  Restore purchases / Terms・Privacy  [従]"Continue with Free"

ツールバー: leading="Back"(step != flow.firstのときのみ) trailing="Close" → resolveExit(.close)(ExitOffer分岐は削除)
```

### 3. ファイル計画

**新規作成**:
- `Sources/Paywall/PaywallStep.swift` — PaywallStep/PaywallFlow(純粋・View非依存) [P0]
- `Sources/Paywall/PaywallStepScaffold.swift` — 共通の器: paywallBackground/ScrollView/.safeAreaInset CTA領域/PaywallStepIndicator(3点ドット)。現行`PaywallBenefit`/`PaywallLegal`をprivate解除して移設 [P0]
- `Sources/Paywall/PaywallValueStepView.swift` — ステップ1(現行heroをverbatim移設) [P1]
- `Sources/Paywall/PaywallFeaturesStepView.swift` — ステップ2(現行benefits+freeChoiceをverbatim移設) [P1]
- `Sources/Paywall/PaywallPlanStepView.swift` — ステップ3(現行contentの.loaded/.loading/.failed + restoreAndLegal + PlanOptionRowを移設) [P1]
- `Tests/PaywallFlowTests.swift` — PaywallFlowの順序・末尾必ず.plan・エントリーポイント別段数を固定 [P1]

**変更**:
- `Sources/Paywall/PaywallView.swift` — コンテナ化。各ステップへ移設、step state・advance()・goBack()・短絡判定・ツールバーBack追加。ExitOffer関連削除。F8のドキュメントコメント書き換え。目標200行前後 [P0]
- `Sources/Paywall/PaywallAnalytics.swift` — `case stepViewed`追加、`record`に`step: PaywallStep? = nil`追加(§7) [P1]
- `Sources/App/SkyGridApp.swift` — UIAuditScenarioに`case paywallPlan = "paywall-plan"`追加、initialStep: .planを渡す(F3審査スクショ再現用) [P1]
- `UITests/SkyGridUITests.swift` — 4テストの導線更新(§9) [P1]
- `Sources/Paywall/PaywallEntryPoint.swift` — `permitsExitOffer`削除(他に利用者なしをgrep済み) [P2]
- `Tests/PaywallPolicyTests.swift` — `@Suite("ExitOfferPolicy")`削除。AutomaticPaywallPresentationPolicyTestsは無傷 [P2]
- `Sources/Persistence/LocalDefaults.swift` — `didPresentExitOffer`と`resetAccountScopedValues()`内の参照削除 [P2]
- `Config/Info.plist` — `SkyGridExitOfferCode`/`SkyGridExitOfferDescription`削除 [P2]
- `Config/Secrets.example.xcconfig`および**ローカルの**`Config/Secrets.xcconfig` — `SKYGRID_EXIT_OFFER_*`の2行削除(F1) [P2]
- `Sources/Settings/SettingsView.swift` — "SKY GRID PRO"セクションの非Pro分岐に`Restore purchases`行を追加(F6の到達性回帰の補償) [P2]
- `Sources/Purchases/EntitlementStore.swift` — `func restore() async -> Bool`を追加(View に購入ロジックを散らさないため) [P2]

**削除**: `Sources/Paywall/ExitOffer.swift`全体(§6)。

追加/削除後は必ず`xcodegen generate`(F7)。`.pbxproj`を手編集しないこと。

### 4. 既存コードの移設対応表

| 現行`PaywallView.swift` | 移設先 | 変更 |
|---|---|---|
| `hero`(:94-116) | `PaywallValueStepView` | verbatim |
| `benefits`(:118-139) | `PaywallFeaturesStepView` | verbatim。ただし`showsHeadline == true`のとき上に`entryPoint.headline`を追加(§5の2段フロー用) |
| `freeChoice`(:141-150) | `PaywallFeaturesStepView` | verbatim |
| `content` `.loaded`(:184-240) | `PaywallPlanStepView` | 「選択中+OTHER PLANS」の2分割をやめ、orderedProducts全件を1リスト表示に統合。isBestValue/orderedProducts/recommendedProduct/primaryActionTitleのロジックは無改変で移設 |
| `content` `.loading/.failed/.entitlementUnavailable`(:154-183) | `.loading/.failed`→PaywallPlanStepView、`.entitlementUnavailable`→PaywallStatusView(Scaffold内) | ロジック不変 |
| `restoreAndLegal`(:244-272) | `PaywallPlanStepView`の固定インセット | verbatim |
| `paywallBackground`(:274-280) | `PaywallStepScaffold` | verbatim |
| `purchase/restorePurchases/preparePaywall/resolveExit/recordPresentationIfNeeded` | `PaywallView`に残す | resolveExitにstep:を渡す1行のみ追加 |

文言は書き換えない。既存のbenefit文は実装済み機能(ProGate.freeArchiveWindowDays=30/GridArchiveViewのlockedPhotoCount・月別ブラウズ/ShareCardRenderer)と対応が取れており、審査提出物とも整合している。VISION.md記載の未実装Pro機能(HealthKit・タイムラプス・週次統計等)を訴求に足さないこと。新規に増える文字列はCTAラベル2種のみ。

### 5. エントリーポイント別の見せ方

**結論: 形状の差は1箇所だけ。**
```
PaywallFlow.make(for:)
  .onboarding / .home / .archive / .settings → [.value, .features, .plan]   // 3段
  .ritualMilestone                            → [.features, .plan]          // 2段
```

- **onboardingも3段のままにする理由**: `PersonalizedPlanView`は一見「価値ページ」だが、実際の中身は無料の朝ルーティン計画・プライバシー・カメラ許可の説明であり、Proの価値には一切触れていない。entryPoint.headline(= plan.proLead)とpersonalizedValueNoteはオンボーディング時のみ生成される最も強い訴求文で、置き場所はvalueステップしかない。
- **home/archive/settingsを短縮しない理由**: 能動的に開いた=意図が高い導線であり、短縮の主目的(離脱削減)が薄い。フローを揃えておけばstepViewedで同一フロー上のエントリーポイント間比較ができる。
- **ritualMilestoneだけ2段にする理由(コード根拠あり)**: `RootView.swift`の`recordAutomaticPaywallDismissalIfNeeded`はどのステップで閉じてもconsecutiveAutomaticPaywallDismissalsを加算し、AutomaticPaywallPresentationPolicy.snoozeUntil(2回で14日スヌーズ)を発火させる。つまり自動導線だけは「ステップが増える=離脱機会が増える=将来の提示機会そのものを失う」という非対称なコストを持つ。
  この場合`flow.first == .features`になるので`showsHeadline = (flow.first == .features)`としてfeaturesステップがentryPoint.headlineを自前で表示する。
- **確信度の申告**: 「3段 vs 2段のどちらがCVRで勝つか」の実データはこの環境に無い。上の判断は「離脱機会の非対称コスト」という構造的根拠に基づく仮説であり、stepViewedはこの仮説を後から反証できるようにするために入れる。

### 6. ExitOfferの扱い → 削除(置き換えはSettingsへのRestore行のみ、割引導線は作らない)

**理由(重い順)**:
1. 現状が壊れている(F1)。`Secrets.xcconfig`に`SKYGRID20`が実在しReleaseにも入るため、`ExitOfferPolicy.shouldPresent`はonboarding初回でtrueになる。ASC側にコードが無ければ、初回セッションで「20% off」を提示してredeem失敗させることになる。これはCVR以前に約束違反であり、審査上も実在しないオファーの広告になりうる。
2. 新フローと構造的に矛盾する。ExitOfferはClose時に発火するが、多段化後のCloseはステップ1・2(=価格を一度も見ていない状態)からも起きる。定価を知らない人に割引コードだけ提示するのは意味が通らない。
3. アプリ外に出す最悪のタイミング。offerCodeRedemptionはApp Storeの引き換えシートに遷移する。
4. 依頼者の示唆と整合。価格設計をASC側に一本化するなら、アプリ内の割引導線は二重管理になり、SKYGRID20のような不整合を再生産する。

**置き換え**: ペイウォール上には何も置かない。代わりにSettingsViewの"SKY GRID PRO"セクションにRestore purchases行を追加。将来ASCでオファーコードを作った場合の引き換えはApp Store標準の「コードを使う」で完結、アプリ内引き換えUIは不要。

**削除の影響範囲(grep済み・全件)**: `ExitOffer.swift`全体 / `PaywallView.swift:20-21,76-91,263-268,335-355` / `PaywallEntryPoint.swift:27-30` / `LocalDefaults.swift:66-68,127` / `Tests/PaywallPolicyTests.swift:5-39` / `Config/Info.plist:11-14` / `Config/Secrets{,.example}.xcconfig:13-14`。

### 7. 分析イベント

既存7種では不足。ただし追加は「イベント1種+パラメータ1個」に留める。
```swift
enum Event {
    ... 既存7種そのまま ...
    case stepViewed = "skygrid_paywall_step_viewed"     // 新規
}
static func record(_ event: Event, entryPoint: PaywallEntryPoint, period: PurchasePeriod? = nil,
                    dismissalReason: PaywallDismissalReason? = nil, step: PaywallStep? = nil)
```
- stepViewed: 各ステップ初到達時に1回だけ(viewedStepsで重複抑止)。
- dismissedにstepを付与: 離脱がどのページで起きたかは最重要の診断値。
- purchaseStarted/planSelectedには付けない(必ず.planなので情報量ゼロ)。
- presentedは残す(コンテナ1回)。
- 運用注意: GA4ではstepをカスタムディメンションとして登録しないとレポートに出ない。

### 8. 壊してはいけない制約 → 担保方法チェックリスト

| 制約 | 新構造での担保 |
|---|---|
| requiresEntitlementVerification(自動リマインダーの二重課金防止) | preparePaywall()は無改変。.subscribed→即dismiss。.entitlementUnavailable→ステップ機構を短絡してPaywallStatusView表示。購入UIは.planにしか存在しないため現行より強い保証 |
| ExitOfferPolicy.shouldPresent | 機能ごと削除するため制約自体が消滅 |
| PaywallAnalyticsの非PII方針 | 追加パラメータは固定語彙3種のみ |
| 価格・更新条件・復元・法的リンクが購入操作の直前に同時提示(Guideline 3.1.2/F8の契約) | PaywallPlanStepViewに価格3件+billingDescription+Restore+Terms+Privacy+無料導線を全部同居 |
| 無料導線の常時可用性 | "Continue with Free"を全ステップの固定インセットに配置(現行は最下部までスクロールが必要だった=改善) |
| 呼び出し元4箇所の契約 | initの既存引数は不変、initialStepは既定値付き追加のみ |
| **R: Restoreの到達性(F6)** | SettingsViewの"SKY GRID PRO"セクションにRestore purchases行を追加して補償 |

### 9. UIテスト・審査スクリーンショットへの影響

現行の4テストは3段階化で確実に落ちる。
- `testPaywallShowsOnlyTheThreePaidPurchaseOptions`: 起動引数を`-SkyGridUIAuditScenario paywall-plan`に変更(initialStep: .plan)。
- `testRealPaywallOfferingsLoadAfterRevenueCatIncident`/`testRealTestStorePurchaseGrantsEntitlement`/`testRealSandboxPurchaseReachesStoreKitConfirmationSheet`: "See what Pro opens"→"See plans and pricing"の2タップを追加してから既存の待ち処理へ。

CTAラベル"See what Pro opens"/"See plans and pricing"/"Continue with Annual"はテストが依存する契約文字列になる。実装後に気軽に変えないこと。

**審査スクショ**: `-SkyGridUIAuditScenario paywall-plan`から審査提出物相当(Annual/Monthly/Lifetimeの価格が写る1206x2622)を再撮影し、ASCのサブスク2件の「審査に関する情報」を差し替える必要あり。**この判断は依頼者に確認すること**(「審査へ提出」を押すか否かは依頼者判断待ちの状態と既存VISION.mdに記録あり)。

### 10. ビルド順序(依存順)

1. PaywallStep.swift作成 → Tests/PaywallFlowTests.swift(順序・末尾必ず.plan・ritualMilestoneが2段・next/previous/isFinalの境界)を先に書いてRED→GREEN。xcodegen generate → test_sim。
2. PaywallStepScaffold.swift作成、PaywallBenefit/PaywallLegal/paywallBackground移設。build_simが通ること(UI未変更)。
3. ステップView3種を作成(既存ブロックをverbatim移設)。まだPaywallViewからは呼ばない。build_sim。
4. PaywallViewをコンテナ化。ここで初めて挙動が変わる。build_sim + シミュレータ目視(全5エントリーポイントをUIAuditで確認)。
5. Analytics拡張(stepViewed+stepパラメータ)。
6. UIAuditシナリオ追加+UIテスト4件更新 → test_sim。
7. ExitOffer撤去: Swift→PaywallEntryPoint→LocalDefaults→Tests/PaywallPolicyTests.swift→Info.plist→Secrets{,.example}.xcconfigの順(コンパイルエラーで漏れを検出できる順序)。xcodegen generate → test_sim。
8. Settingsのrestore行+EntitlementStore.restore()(到達性回帰の補償)。
9. 審査スクショ再撮影とASC差し替え可否を依頼者に確認。
10. dev-noteを新規作成: 特にF1(SKYGRID20がReleaseに載っていた事実)、F2/F3(UIテストと審査スクショの結合)、§5の2段仮説と検証方法を記録。

### 11. 実装前に依頼者判断が要る点(推測で進めないこと)

1. 審査スクショの差し替えタイミング(提出済みかどうかで手順が変わる)。
2. SKYGRID20がASCに実在するか。実在するなら「削除=既存オファーの廃止」になるため、外部に告知済みでないかの確認が要る。
3. ritualMilestone 2段の是非(§5の確信度申告どおり、データ不在の構造的推論。3段統一を選ぶならPaywallFlow.make(for:)の1行変更のみ)。

</details>

## 次回セッション最優先タスク2: アラームの「送信完了までアラームが止まらない」設計の再検証

依頼者から: 「実際にAppleのAlarmKitドキュメントで制約を再確認して、必要であれば、プラットフォームの
範囲内で心理的圧力を高める代替案を検討してください」との指示。**まだ着手していない。**

**現状の私の理解(未検証、次回に公式ドキュメントで裏取りすること)**:
- `MorningAlarmScheduler.swift`のコードは、アラーム停止(`stopButton`、iOS 26.1+はシステム標準)と
  カメラ誘導(`secondaryButton`/`OpenMorningCameraIntent`)を意図的に分離している。
- 私の推測: AppleのAlarmKitはアプリ内条件でアラーム停止自体をブロックするAPIを提供していない
  (安全性のための意図的なプラットフォーム制約の可能性が高い)。**ただしこれは一般知識からの推測であり、
  実際のApple公式ドキュメント(AlarmKit Framework Reference、Human Interface Guidelines)は
  未確認。**

**次回セッションでやること**:
1. Apple公式のAlarmKitドキュメント(developer.apple.com)を実際に確認し、アラームのdismiss/stop
   操作をアプリ側条件でブロック・遅延できるAPIが存在するか裏取りする。英語クエリで検索すること
   (CLAUDE.mdの海外情報源ポリシーに従う)。
2. 制約が確認された場合、プラットフォームの範囲内で「心理的圧力を高める」代替案を設計する
   候補(未検討、ゼロから検討すること):
   - スヌーズを短時間隔で自動再スケジュールし続ける(ユーザーがカメラで撮影するまで、より頻繁に
     再通知が来るようにする)
   - アラーム音自体は止められても、ロック画面/通知センターに「今日はまだ空を撮っていません」という
     持続的な訴求(Live Activity等)を残し続ける
   - Alarmy等の競合が実際どう実装しているか(VISION.md §5参照、"解除ミッション"の実装方式)を調査する
3. **この設計判断はApp Store審査リスクを伴うため、実装前に依頼者に選択肢と根拠を提示してから
   進めること(推測で実装しない)。**

## 次回セッション最優先タスク3: 実機への最終デプロイ

Paywall再設計とアラーム設計判断の実装が終わり次第、今回のセッションで行った全変更
(オンボーディング分割・アカウント削除ページ・カメラボタン修正・Paywall再設計・アラーム改善)を
まとめてビルドし、実機(iPhone 15 Pro、`俺のGALAXY Pro Max`、devicectl ID
`FF649B7E-F19F-5E73-9AA2-797C297B8916`)へワイヤレスデプロイすること。依頼者からの明示的な依頼済み。

## 次回セッション起動フレーズ

「このdev-note(`session-handoff-paywall-alarm_2026-08-01.md`)を読んで続きから進めて」
