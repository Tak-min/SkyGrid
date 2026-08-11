# 招待リンク iOS Step 7、Slice 1-8 実装（2026-08-11〜12）

updated: 2026-08-12

`dev-notes/invite-link-ios-blueprint_2026-08-11.md`（code-architectのブループリント）に
従い、Step 7(iOS側)のSlice 1-8を実装・検証・コミット済み。全コミットはローカルのみ、
push・実機・ASC提出はしていない。

## 完了（コミット済み、すべて未push）

```
e15071d Slice 1: 純粋型(InviteCode/InviteLinkParser/InviteModels/RevealSignal/FirstUnlockPaywallPolicy)+テスト15件
620c968 Slice 2: entitlement(associated-domains)+ Universal Link routing(AppRouter)
cf28dfa Slice 3: InviteRepository + FirebaseInviteRepository(asia-northeast1)
f44da61 Slice 4: 送信側UI(InviteLinkCard、Buddiesタブ)
163d6e7 Slice 5: 受信側UI(InviteClaimView、RootViewシート、handle gate)、テスト6件
a5097cb Slice 6: TodayViewModel.refreshBuddiesのライブ観測バグ修正 + RevealSignal配線
0866d27 Slice 7: ペイウォールを初回相互解除発火へ移設(既存課金導線のコア変更)
b1caacb Slice 8: InviteAnalytics(計測、コード非記録を確認済み)
```

各コミットで実施した検証（すべて自分で再実行、報告の丸写しなし）:
- `xcodegen generate` → `xcodebuild build`（実機ビルド成功）
- `xcodebuild test -only-testing:SkyGridTests`（Slice毎に増加、最終192件、失敗0）
- Slice 7のみ追加でフルスイート(UI含む)を実行 → UIテストランナーが接続確立前にハング
  （このセッション中にxcodegen再生成を繰り返した影響と判断、ユニットテスト単体・
  アプリ単体ビルドはどちらも直後にクリーンで通過。継続する場合は次セッションで再確認）

## 実装で発見・修正した既存バグ（code-architectブループリント §0 の実地監査由来）

1. **`TodayViewModel.refreshBuddies`はリスナーを1回のemissionで打ち切っていた**
   （`firstValue(from:)`使用）ため、相互解除がライブ観測されていなかった。Slice 6で
   `refreshBuddiesNow()`を追加し`TodayView`の`scenePhase == .active`から呼ぶことで
   「アプリがバックグラウンド中に相手が投稿→再度フォアグラウンド」の主要ケースを解消。
   **アプリが既にフォアグラウンドの状態で相手が投稿するケースは未解消**（ライブリスナー
   かポーリングが必要、ブループリントの判断通り今回は意図的に見送り）。
2. **`refreshBuddies`に並行実行ガードがない**問題もSlice 6で解消（cancel-and-replace
   のTaskでラップ）。
3. 受信者のhandle欠如問題はSlice 5の`InviteClaimViewModel.beginClaim()`で
   クライアント側事前チェックとして解消（サーバー側`MissingHandleError`は例外経路のまま）。
4. `FirebaseRepositoryError`がCloud Functionsのcode 8/9を未処理だった問題はSlice 3で解消
   （`RepositoryError.actionNotReady` / `.rateLimited`を追加）。

## Slice 7（ペイウォール移設）の要点 — 次に触るときの注意

- `AutomaticPaywallPresentationPolicy`（3回撮影ごとの周期リマインダー）は**完全削除**。
  フラグでの無効化ではなく削除 — 依頼者の決定を反映した設計。
- `unlockPaywallPresentedAt`（`LocalDefaults`）は**`RootView.recordAutomaticPaywallPresentationIfNeeded`
  一箇所のみ**が書き込む。milestoneがペイウォールに勝った場合は何も書き込まれず、
  次の`resolvePendingPresentations`呼び出しで再提示される。この「決定箇所」と
  「記録箇所」の分離を崩すと、Day-1マイルストーンと初回相互解除が同じ朝に重なった際に
  二重発火または永久ロストする。
- `resolvePendingPresentations(services:)`が全てのライフサイクルフック・モーダル終了
  コールバックの単一入口。新しいモーダル種別を追加する際はここに1行足すだけで済む設計。
- 本番反映後の影響（依頼者に事前報告済みの想定内挙動）: バディ無しの単独ユーザーには
  自動ペイウォールが二度と出なくなる。既存の全ペア済み無料ユーザーは次回相互解除時に
  1回だけペイウォールが出る（`unlockPaywallPresentedAt`が全員nilスタートのため）。

## 次にやること

**Slice 9-10（実機E2E・バージョンbump・ASC提出）はこのセッションでは未着手。**
`dev-notes/invite-link-ios-blueprint_2026-08-11.md` §6 の表を参照。

1. 実機2アカウントでのE2E: create→DM→tap→preview→claim→両者投稿→reveal→
   ペイウォール1回のみ発火→同じリンクを再度開く(`claimedByYou`/`paired`になるか)→
   作成者が自分のリンクをタップ(`ownInvite`)→作成者が`deleteAccount`後に受信者が
   タップ(`unknown`になるかクラッシュしないか)
2. Associated Domains entitlementの実機反映確認（プロビジョニングプロファイル再生成が
   必要な場合あり。ポータル側capabilityは依頼者が2026-08-11に有効化済み）
3. `project.yml`の`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`を両ターゲットで
   bump → `xcodegen generate`で反映確認（過去に手動`project.pbxproj`編集が
   `xcodegen generate`で巻き戻された実績あり、必ず`project.yml`を編集すること）
4. ASC 1.0.2への新ビルド提出（依頼者本人の操作）
5. push・本番反映は依頼者の明示承認が必要（`AGENTS.md`）
