# 招待リンク iOS実装ブループリント（Step 7-15、code-architect作成）

updated: 2026-08-11

`dev-notes/invite-link-steps-4-5-6-deploy_2026-08-11.md`（Step 4-6完了・本番反映）の続き。
Step 7以降（iOS側）の着手前に、`code-architect`(Opus)エージェントへ既存コードベースの
実地調査込みで設計を委譲した。単なる16段階の一行要約(`share-card-qr-removal-and-invite-blueprint_2026-08-11.md`
§4-3)では足りない、このリポジトリの具体的な実装計画。

## 前提として読んだ既存の設計制約

- `dev-notes/share-card-qr-removal-and-invite-blueprint_2026-08-11.md` §4
- `~/.codex/claude-memory/skygrid-invite-link-handoff-2026-08-11.md` 「再導出してはいけない設計判断」12項目

## このエージェントが実地調査で発見した、一行要約が想定していなかった事実（0節）

1. **`TodayViewModel.refreshBuddies`はリスナーを1回emissionで終了させており、相互解除はライブ検知
   できていない。** `firstValue(from:)`が`AsyncStream`を1回受けて即終了＝Firestoreリスナーが
   `FirebasePostRepository.observePost`側で解除される。相互解除の観測はfriendshipリスナー発火時か
   自分の投稿発生時のスナップショットのみ。ペイウォール移設の前提（相互解除をライブで観測して発火）
   はこのままでは成立しない。
2. **招待リンクの受信者は大半handleを持っていない。** `claimInvite`はhandle無しだと
   `failed-precondition`で即失敗するが、handle取得はBuddiesタブ内でのみ行われる導線。
   claim前にhandle取得を挟まないと新規ユーザーが詰む。
3. **`FirebaseRepositoryError.map`は招待callableが返すcode 8(`resource-exhausted`)と
   9(`failed-precondition`)を処理しておらず、両方`.unknown`に潰れる。**
4. **AASAの`components`を`/i/*`に限定しないと、`PaywallPlanStepView`内の利用規約/プライバシー
   リンク（App Store Guideline 3.1.2で審査必須）が無反応になる。** Worker側は既に`/i/*`限定済み
   （Step 6で確認済み）だが、iOS側もこの前提を壊さないよう設計する必要がある。

## 全文

以下、code-architectからの返答をそのまま保存（実装時はこのファイルを正本として参照）。

---

（本文は会話ログの `Agent` 呼び出し結果を参照。要点は下記サマリ）

### ファイル一覧（作成）

`Invite/InviteCode.swift` / `InviteLinkParser.swift` / `InviteModels.swift`,
`Paywall/FirstUnlockPaywallPolicy.swift`, `Friends/RevealSignal.swift`,
`Data/InviteRepository.swift` + `Data/Firebase/FirebaseInviteRepository.swift`,
`Invite/InviteLinkViewModel.swift` + `InviteLinkCard.swift`,
`Invite/InviteClaimViewModel.swift` + `InviteClaimView.swift`,
`Invite/InviteAnalytics.swift`,
Tests: `InviteCodeTests` / `InviteLinkParserTests` / `FirstUnlockPaywallPolicyTests` /
`InviteClaimViewModelTests`

### ファイル一覧（変更）

`SkyGrid.entitlements`（associated-domains追加）、`AppRouter.swift`、`SkyGridApp.swift`
（`.onContinueUserActivity`追加）、`FirebaseRepositoryError.swift`（code 8/9追加）、
`AppServices`/`ServiceFactory`、`BuddiesView.swift`、`TodayViewModel.swift` + `TodayView.swift`
（`revealSignal`配線、scenePhase active時の再取得）、`PostCaptureMomentPolicy.swift`
（`isPaywallEligible`を`decide`の引数へ移動）、`PaywallEntryPoint.swift`
（`AutomaticPaywallPresentationPolicy`削除、`.firstUnlock`追加）、`PaywallStep.swift`、
`LocalDefaults.swift`（snooze系4キー削除、`unlockPaywallPresentedAt`等追加）、
`RootView.swift`（最大の変更、§4参照）、`project.yml`（バージョンbump、Step 10）

### ビルド順序（10スライス）

1. 純粋型+テスト（アプリ配線なし、安全） 2. entitlement+routing（実機必須） 3. リポジトリ
（実機smoke test） 4. 送信側UI 5. 受信側UI 6. RevealSignal配線（実機2アカウント） 7. ペイウォール
移設（**課金導線に触れる唯一のスライス、テスト先行でコミット分離**） 8. 計測 9. 実機E2E 10. リリース

### 日次衝突（Day-1マイルストーンと初回相互解除が同日）の解決

`PostCaptureMomentPolicy.decide`が milestone > paywall > review の優先順位を維持したまま、
`isPaywallEligible`を凍結済みarmingでなく**再評価可能な引数**にする。milestoneに譲った場合は
`unlockPaywallPresentedAt`を書かず、milestone `onDone`後の`resolvePendingPresentations()`で
再判定され、armingが消費済みなら`resolveFirstUnlockPaywall()`が発火して1回だけ提示される。

### 難所（優先度順）

1. [High] 相互解除のライブ観測が現状ない（0-1の修正が前提）
2. [High] `refreshBuddies`に並行実行ガードがない
3. [High] 受信者のhandle欠如（0-2）
4. [Medium] カメラ・ペイウォール・マイルストーン・招待の4モーダル競合 →
   `resolvePendingPresentations()`一本化で対処
5. [Medium] 招待機能はシミュレータでテスト不可（App Check 403）→ UI audit stub必須
6. [Medium] リンクからの新規インストールでコードが失われる（deferred deep link非対応）→
   コード手動貼り付け導線で緩和
7. [Low] `TodayViewModel`はRootView再評価毎に再生成される → `revealSignal`は`streakSignal`同様
   `@State`で注入する必要がある
8. [Low] レート制限(previewInvite 20/h, claimInviteCode 10/h)のため自動リトライ禁止
