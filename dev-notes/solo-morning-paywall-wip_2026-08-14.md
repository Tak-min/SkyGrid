# 単独ユーザー向け自動ペイウォール — 実装完了・未コミット(2026-08-14)

**追記(同日、実装続行セッション):** 依頼者の明示的な「進めてください」指示を受け、
7〜11(`PaywallEntryPoint`/`PaywallStep`/`LocalDefaults`/`RootView`配線)を実装完了。
`xcodebuild test -only-testing:SkyGridTests` 全件green(既存193 + 新規11 = 204件、失敗0。
`PaywallFlowTests`に`.soloMorning`を追加した分も含む)。**未コミット・未push**
(コミットは依頼者の別途指示待ち — 下記「再開の手順」参照)。以下は実装前に書いた元のメモ
(背景・製品判断は引き続き正)。実装で埋めた設計の残りギャップは末尾の
「実装時に追加で確定した設計判断」を参照。

## 背景・製品判断(確定済み、再協議不要)

- 現状の`FirstUnlockPaywallPolicy`(バディとの初回相互解禁で1回だけ発火する自動ペイウォール)は、
  **承認済みバディが1人もいない単独ユーザーには構造的に永遠に発火しない**という調査結果を受けて、
  単独ユーザー専用の自動リマインダーを新設することが決まった。
- 「単独」の定義: `friendships.isEmpty`(承認済みバディが1人もいない)。招待claimはサーバー側で
  friendship作成と同時に起きるため、招待直後の人は正しく「単独ではない」扱いになる(検証済み)。
- 初回投稿は`StreakMilestone.thresholds`に`1`が含まれるため必ずDay1祝福と同時に該当する。
  依頼者の指示: **祝福を先に見せてから、同じセッション内でこの新ペイウォールにチェインする**
  (次回投稿まで繰り延べる、ではない)。
- 強度: 技術的にハードブロッキングではない。**現行の`.sheet`(スワイプで閉じられる)のまま**、
  コピー/説得力だけを強める。
- 頻度パラメータ(依頼者が最終確定、通常提案より攻撃的な値):
  - 再提示: 撮影**2回** or 経過**2日**のどちらか早い方
  - 連続**2回**却下 → **4日**封印
  - 連続**4回**却下 → **10日**封映(`SoloMorningPaywallPolicy.swift`の定数)

## 完了済み(ビルド・テスト green)

1. `Sources/Friends/RevealSignal.swift` — `RevealReading`に`acceptedBuddyCount: Int?`追加。
   `nil`=friendshipスナップショット未着(=不明)、`0`=確定で単独、を明確に区別する設計。
2. `Sources/Today/TodayViewModel.swift` — `hasResolvedFriendships`フラグを新設し、
   friendshipリスナーが一度でも`.value`を配信したら`true`。`performRefreshBuddies`で
   `RevealReading`構築時に`acceptedBuddyCount: hasResolvedFriendships ? friendships.count : nil`。
3. `Sources/Paywall/SoloMorningPaywallPolicy.swift`(新規) — 純粋関数`evaluate(...)`。
   `Verdict { present, notEligible, undetermined }`の3値。`FirstUnlockPaywallPolicy`と同じ形。
4. `Tests/SoloMorningPaywallPolicyTests.swift`(新規、11テスト)+
   `Tests/FirstUnlockPaywallPolicyTests.swift`にヘルパー更新+回帰テスト1件追加
   (`acceptedBuddyCount: nil`でも`firstUnlock`は従来通り動く、という既存導線の非破壊を保証)。
5. `xcodegen generate`済み(新規ファイルがターゲットに登録済み)。
6. `xcodebuild test -only-testing:SkyGridTests` 全件green(既存193 + 新規11、失敗0)。

## 未着手(ここから再開)

`code-architect`が出した実装ブループリントの残り。設計は確定済みなので、実装のみ:

7. `Sources/Paywall/PaywallEntryPoint.swift` — `case soloMorning(captureCount: Int)`追加。
   headline文言・`analyticsName = "solo_morning"`・`isAutomaticReminder = true`。
8. `Sources/Paywall/PaywallStep.swift` — `PaywallFlow.make`は**3ステップのまま**
   (`.ritualMilestone`/`.firstUnlock`の短縮組には入れない — 単独ユーザーには何も価値実証されて
   いないため)。`Tests/PaywallFlowTests.swift`に`.soloMorning`を追加。
9. `Sources/Persistence/LocalDefaults.swift` — 新規5キー(`soloPaywallAccountID`,
   `lastSoloPaywallPromptCaptureCount: Int?`, `lastSoloPaywallPromptLocalDate: String?`,
   `consecutiveSoloPaywallDismissals: Int`, `soloPaywallSnoozedUntil: Date?`)+
   `resetSoloPaywallState()`。**`automaticPaywallAccountID`は現役(`completedCaptureCount`の
   境界管理用)につき絶対に流用・上書きしないこと。**
10. `Sources/App/RootView.swift` — 本命の配線。前回のcode-architectブループリントの§8に
    具体的な差分(擬似コード相当)が全て書いてある。要点:
    - `resolvePostCaptureMoment`内で`soloVerdict = SoloMorningPaywallPolicy.evaluate(...)`を
      計算し、`decide(isPaywallEligible: firstUnlockEligible || soloEligible, ...)`に**必ず
      合流させる**(ここを忘れるとレビュー依頼ダイアログと二重発火するバグを埋め込む)。
    - `.milestone`分岐で`soloEligible`なら`deferredSoloPaywallDate = arming.localDate`
      (`LocalDate?`。`Bool`にすると日跨ぎで失効しない事故になる)。
    - milestoneの`.fullScreenCover`を`onDismiss:`パターンに変更(現行`MilestoneView.onDone`内で
      直接`showPaywall`を立てる形だとcover dismissアニメーションと同一runloopで飲み込まれる
      リスクがある。カメラ側の既存パターンに合わせるだけ)。
    - 新規`resolveSoloPaywall(services:)`を`resolveFirstUnlockPaywall`の直後に追加、
      `resolvePendingPresentations`の最後に呼び出しを追加。
11. テスト: `Tests/PostCaptureMomentPolicyTests.swift`は**変更しない**(変更が必要になったら
    `decide`のシグネチャを触ってしまった合図、既存18テストへの非破壊を保証する形にしたはず)。

## 実装者向けの罠(先出し、code-architectブループリントより)

- `decide`への`isPaywallEligible`合流を忘れるとレビュー依頼との二重発火。ユニットテストでは
  検出できないので目視レビュー必須。
- `LocalDefaults.lastSoloPaywallPromptCaptureCount`は`Int?`(非Optionalにすると初回提示が
  区別できず二重発火し得る)。
- `deferredSoloPaywallDate`は`LocalDate?`(`Bool`にすると日跨ぎで失効しない)。
- 新規`.swift`追加後は`cd ios && xcodegen generate`必須。

## 再開の手順(実装完了・以下は履歴として保持)

1. `git status`で本ファイル含む未コミット差分を確認(既存ファイル4件+新規2ファイル)。
2. 依頼者から明示的な実装続行の許可を得てから着手する
   ([[feedback-wait-for-explicit-go-before-implementing]]、2026-08-13に確定した方針)。
3. 上記7〜11の順で実装、各ステップ後に`xcodebuild test -only-testing:SkyGridTests`。
4. 全部green確認後、依頼者の指示があればコミット(push・本番反映は`AGENTS.md`により別途承認要)。

## 実装時に追加で確定した設計判断(2026-08-14実装セッション、code-architectブループリント外)

元ブループリントの要点(§8)には無く、実装時に既存パターン(`resolveFirstUnlockPaywall`/
`prepareUnlockPaywallState`等)に倣って埋めた箇所。将来の変更時に参照:

- **`resolveSoloPaywall`の評価日**: `deferredSoloPaywallDate ?? services.clock.today()`。
  milestoneが解除paywallを繰り延べた直後は`deferredSoloPaywallDate`(繰り延べ元のcapture日)を
  優先し、`.undetermined`(reading未到達)の間はクリアしない。conclusiveな答え(`.present`/
  `.notEligible`)が出て初めてクリアする。それ以外(通常のreveal signal更新等)は`services.clock.today()`
  にフォールバック。
- **却下(スヌーズ)の記録配線**: `PaywallView`には元から`onDismissed: (PaywallDismissalReason) -> Void`が
  あったが、`RootView`の呼び出し側は未配線(デフォルトの空クロージャのまま)だった。これを
  `recordSoloPaywallDismissalIfNeeded`に配線し、`.soloMorning`からの離脱(購入以外の全終了経路)ごとに
  `consecutiveSoloPaywallDismissals`を加算+`SoloMorningPaywallPolicy.snoozeUntil`で
  `soloPaywallSnoozedUntil`を更新。これを配線しないと「頻度パラメータ」節の連続却下スヌーズが
  永遠に発火しない死んだ状態になる(`LocalDefaults`にフィールドだけ存在して書き込まれない)ため、
  実装スコープに含めた。購入成功時(`onEntitlementGranted`)は`.soloMorning`なら両方リセット。
- **`.paywall`分岐でのエントリポイント選択**: `isFirstUnlockEligible`と`isSoloEligible`は
  構造的に同時にtrueになり得ない(`mutuallyUnlockedBuddyCount`は`acceptedBuddyCount`から
  数え上げるため、後者が0であることを要求する`SoloMorningPaywallPolicy`とは背反)。よって
  `presentPaywall(from: isFirstUnlockEligible ? .firstUnlock : .soloMorning(captureCount:))`で
  単純に振り分けた。
- **`MilestoneView`の`fullScreenCover`をonDismissパターンへ変更**(ブループリント記載通り実施): 従来は
  `onDone`内で直接`resolvePendingPresentations`を呼んでいたが、cover自体の`onDismiss:`に移動。
  `onDone`は`milestoneMoment = nil`を立てるだけに変更(カメラ側の既存パターンと統一)。
