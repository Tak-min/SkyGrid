# バディ投稿プッシュ通知 — 実装完了・デプロイ未実施(2026-08-14)

## 背景

SkyGridの核心メカニクス(バディとの相互ブラー = 誰かが見ている感覚による継続動機)は、
「バディが投稿したことを知る手段」を欠いたまま機能していなかった。`FirebaseDeviceRegistrar.swift`
がFCMトークン登録の土台だけ用意していたが、送信側(Cloud Functions)は一度も実装されたことが
なかった(`git log --all`全履歴・`ios/functions/src/`全ファイルを再grepして確認済み)。

設計は`code-architect`(Opus)に委譲し、実データモデル・実ルール全文・既存パターンを検証した
ブループリントを得た。以下はその実装ログ。

## 完了した実装

### バックエンド(`ios/functions/`)

1. `src/buddyNotifications.ts`(新規、純関数のみ) — `admin`非依存。
   - `activeBuddyUIDs` — accepted かつ blockedBy空のバディのみ抽出、`MAX_NOTIFIED_BUDDIES=20`で上限。
   - `posterHandleFromFriendship` — friendshipドキュメントに非正規化済みのhandleを読む(追加read不要)。
   - `buddyPostNotificationCopy` — 写真を約束しない文言(バディの写真はUIに一切出ないため)。
   - `isWithinQuietHours` — 22:00–05:00ローカルは送信スキップ、タイムゾーン不正時は**送る側に
     フォールバック**(沈黙の方が害が大きい)。
   - `staleTokenIndices` — `messaging/registration-token-not-registered`等の恒久エラーのみ検出。
   - `postNotificationMarkerExpireAtMs` — 冪等マーカーのTTL(7日)。
   - テスト: `test/buddyNotifications.test.js`(14件、`npm test`でgreen)。

2. `src/buddyNotificationStore.ts`(新規、admin依存グルー) — `inviteStore.ts`と同じ規律で
   `db`/`messaging`を引数DI。`notifyBuddiesOfPost(db, messaging, {posterUid, localDate, nowMs})`。
   - **冪等性**: `users/{posterUid}/postNotifications/{localDate}`への`create()`で先に排他制御
     (ALREADY_EXISTSなら即return)。Eventarcのat-least-once配信+`OrphanedPostRecovery`の
     削除→再撮影フローの両方が実在する重複経路であるため必須(防御的ではなく必須、と
     ブループリントが明記)。
   - 通知先: `friendships`を`array-contains`検索→accepted&非ブロックのバディへ`sendEachForMulticast`。
   - stale token検出後は`users/{uid}/devices/{tokenId}`を削除。
   - **絶対にthrowしない**設計(トリガ元のpostは既に確定済みのため)。
   - テスト: `test/emulator/buddyNotificationStore.test.js`(12件、`npm run test:emulator`でgreen)。

3. `src/index.ts` — `onBuddyPostCreated`(`onDocumentCreated`、
   `document: "users/{uid}/posts/{localDate}"`)を追加。
   - `region: "asia-northeast1"`必須(FirestoreがDBと同一リージョンでの単一リージョン構成のため。
     `gcloud firestore databases describe`で実測確認済み)。
   - `retry: false`(マーカーが冪等性を保証済みなのでリトライに意味がない)。
   - `deleteAccount`の`recursiveDelete`コメントに`postNotifications`を追記(実際に自動で
     カスケード削除されることを確認済み、コード変更は不要)。

4. `firestore.rules` — `users/{uid}/postNotifications/{document=**}`を`invites`/
   `inviteRateLimits`と同じ「サーバ専用、明示deny」パターンで追加。

5. `firestore.indexes.json` — `postNotifications`コレクションに`expireAt`のTTL fieldOverride追加。

### iOS(`ios/SkyGrid/`)

6. `Sources/Notifications/BuddyPushPayload.swift`(新規) — FCMの`data`ペイロード
   (`{type, posterUid, localDate}`)を型付きの値へパースする純粋関数。`InviteLinkParser`と同じ
   「未検証入力は完全一致しない限りnil」の設計。テスト: `Tests/BuddyPushPayloadTests.swift`(5件)。

7. `Sources/App/AppRouter.swift` — `pendingBuddyRevealRoute: Bool`と
   `buddyRevealRefreshTicks: Int`を新設。**既存の`pendingRoute`(単一AppRoute)には
   統合しなかった** — 統合するとモーニングアラームの`.camera`ルートをバディpushが上書きし得る
   (アプリ最重要導線への退行)。

8. `Sources/Notifications/NotificationRouter.swift` — `didReceive`(タップ)で
   `BuddyPushPayload.parse`にマッチしたら`pendingBuddyRevealRoute = true` +
   `buddyRevealRefreshTicks += 1`。`willPresent`(フォアグラウンド中の配信)では
   `buddyRevealRefreshTicks`のみ加算(タップされていないのでナビゲートしない)。

9. `Sources/App/RootView.swift` — 本命の配線:
   - `consumePendingBuddyRevealIfNeeded()`を新設、`consumePendingCameraRequestIfNeeded()`と
     **全く同じ4フック**(onAppear/scenePhase.active/destination変化/`.task`)から呼ぶ。
   - `.onChange(of: router.buddyRevealRefreshTicks)`で`buddyRefreshToken`を加算
     (こちらは4フック不要 — フォアグラウンド配信はアプリが既に生きている前提のため、
     `.onChange`だけで安全に拾える。タップの方だけがコールドスタート問題を持つ)。
   - `TodayView`に`buddyRefreshToken`を渡す。

10. `Sources/Today/TodayView.swift` — `buddyRefreshToken: Int`パラメータ追加(デフォルト値0、
    既存呼び出し元`SkyGridApp.swift`は無変更)。`.onChange(of: buddyRefreshToken)`で
    `viewModel.refreshBuddiesNow()`(既存の公開メソッド、コード変更不要 — 元々
    「フォアグラウンド中にバディが投稿するケースは意図的に未解決」と明記されていたdocコメント
    通りの、まさにその穴を埋める形になった)。

11. docコメント訂正: `BuddyTile.swift`(「封印されているのは内容であって投稿の有無ではない」を
    明記)、`TodayViewModel.refreshBuddiesNow()`(未解決だったギャップがpushで解消された旨)。

## 実装者向けの罠(実際に踏んだもの)

- **`node --test`の並行ファイル実行がFirestoreエミュレータ上で相互汚染する**: 2つ目の
  `test/emulator/*.test.js`ファイルを追加した瞬間、既存`inviteStore.test.js`が
  `"The caller has no handle."`という無関係なエラーで落ち始めた。原因は両ファイルの`reset()`が
  ともに`users`/`friendships`コレクションを丸ごと削除する設計で、Node組み込みテストランナーは
  デフォルトで**テストファイルを並行実行する**ため、片方のresetがもう片方の実行中データを
  消していた。修正: `package.json`の`test:emulator`スクリプトに`--test-concurrency=1`を追加
  (`ios/functions/package.json`)。今後3つ目のemulatorテストファイルを追加する際もこの制約は
  残る。
- Firestoreエミュレータの「Javaが無い」エラーは既知の誤診([[firestore-emulator-needs-unlinked-keg-only-openjdk]]参照)。
  `export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"`で解消。
- `apns-collapse-id`は64byte上限。UID長+日付では実際には超えないが、`.slice(0, 64)`で
  防御的に切り詰めている。

## 未検証・未実施(スコープ外として明示)

- **実機2台でのE2E配信検証は未実施**(依頼者の制約: 実機1台のみ)。到達できた保証は
  「純関数テストgreen」「エミュレータでの冪等性・絞り込み・stale token削除の検証」
  「TypeScriptコンパイル通過」「iOS側`xcodebuild test`全209件green」まで。
- **Firebase ConsoleでのAPNs Auth Key登録状況は未確認**(CLIから確認する方法が無く、
  Console UIでしか確認できない)。未登録の場合、コードが完全でも配信は0件になる。
  **依頼者に確認を推奨**。
- **通知許可(`requestAuthorization`)は現状`MorningAlarmScheduler`からしか要求されない**。
  モーニングアラームを一度も有効化していない人には、この機能は無音のまま機能しない。
  バディ成立時(招待claim直後)に許可を求める設計は製品判断のため、このパスでは未実装。
  → **次回、依頼者に許可プロンプト追加要否を確認**。
- **Quiet hours(22:00–05:00)は仮の値**。製品リサーチに基づくものではなく、
  `buddyNotifications.ts`冒頭の定数。依頼者の判断で変更可能。
- **デプロイ未実施**。`git commit`のみ完了、push・`firebase deploy`は別途承認要
  (`AGENTS.md`方針通り)。

## 再開の手順(デプロイする場合)

1. Firebase ConsoleでAPNs Auth Key登録状況を確認(未検証事項の最重要項目)。
2. `firebase deploy --only functions:onBuddyPostCreated`(単体指定 — 既存7関数のリージョン
   構成に触れないため)。
3. `firebase deploy --only firestore:rules,firestore:indexes`。
4. 初回Firestoreトリガのデプロイは Eventarc サービスエージェントの伝播待ちで
   "Permission denied while using the Eventarc Service Agent" が出ることがある —
   数分待って再実行すれば解消する既知挙動(権限を書き換えて回避しないこと)。
5. 実機での送達確認は依頼者本人の作業(実機2台制約)。
