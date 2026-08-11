# 招待リンク Step 4-6 デプロイ（2026-08-11 続き）

updated: 2026-08-11

前セッション（`share-card-redesign-and-invite-callables_2026-08-11.md`、
`~/.codex/claude-memory/skygrid-invite-link-handoff-2026-08-11.md`）からの引き継ぎ。
再開時にまず前セッションの報告内容を実際のコード・git履歴・本番Rules APIと突き合わせて
独立検証し、すべて事実と一致することを確認した（詳細は下記「検証」節）。

## やったこと

### 検証（前セッションの報告の裏取り）

- commit `516cc9c` が HEAD、19コミット未push、`videos/` は無関係な未追跡物 — 一致
- `firestore.rules` の `invites`/`inviteRateLimits` explicit deny、`rules-tests/test.js` の
  拡張テストの内容を実ファイルで確認
- `npm run test:emulator`（`ios/rules-tests`）を再実行 → **34/34 passing**（自分で実行、丸写しでない）
- `firebase deploy --only firestore:rules --dry-run` を再実行 → compile成功
- Firebase Rules REST API（`firebaserules.googleapis.com`）から本番の稼働中 ruleset を
  `gcloud auth print-access-token` + `x-goog-user-project` ヘッダで直接取得し、
  Step 4 前のローカル HEAD とバイト単位で完全一致することを確認（報告は「末尾改行以外一致」
  だったが実際は完全一致だった）

### Step: 東京 Artifact Registry の cleanup policy

- `gcloud artifacts repositories describe gcf-artifacts --location=asia-northeast1` で
  `cleanupPolicies` が `null`（空）であることを事前確認
- `us-central1` の既存ポリシー（`firebase-functions-cleanup`, DELETE, olderThan 86400s, ANY）
  と同一の設定を `gcloud artifacts repositories set-cleanup-policies` で asia-northeast1 に適用
- 適用後に再度 `describe` で反映を確認

### Step 5: firestore:rules デプロイ

- デプロイ直前に本番 ruleset を再取得し、drift がないことを再確認（メモの指示通り）
- `firebase deploy --only firestore:rules --project sky-grid-app` を実行 → 成功
- 新 ruleset ID `2529c4fd-bdfe-4664-9155-d94dc6bc0efb` を Rules API から取得し、
  ローカル `ios/firestore.rules`（Step 4 完成版）とバイト単位で完全一致することを確認
- `invites`/`inviteRateLimits` の explicit deny が本番で有効化された

### Step 6: Worker に AASA と `/i/*` 招待ページを実装（commit `152dc43`）

新規ファイル: `waitlist/src/aasa.ts`, `waitlist/src/invitePage.ts`。
`waitlist/src/index.ts` に2ルート追加。

- **AASA は `env.ASSETS` を経由せず Worker が直接返す。** 本番 `/privacy.html` へのリクエストが
  307 で `/privacy` にリダイレクトされることを実測で確認済み（Workers Assets の拡張子正規化）。
  同じ扱いを受けると AASA 取得（拡張子なしパス）や `/invite.html` 経由の取得が壊れるリスクが
  あったため、招待ページも `env.ASSETS.fetch("/invite.html")` は使わず、HTML をそのまま
  `src/invitePage.ts` の関数として Worker コード内にインライン化した。
- **`components` は `/i/*` のみに限定。** `applinks:skygrid.my` を丸ごと関連付けると
  `/privacy` `/terms` `/support` がアプリに吸われ、`AppRouter` が無視するため設定画面の
  リンクが無反応になる（ブループリントの既知の落とし穴）。
- **`/i/{code}` のコードは検証してから初めて反映する。** Crockford Base32（`invites.ts` の
  `INVITE_ALPHABET`、I/L/O/U 抜き）10文字にマッチしないパスセグメントは
  `app-argument` にも本文にも一切反映しない — XSS の実演テスト
  （`/i/%3Cscript%3Ealert(1)%3C/script%3E`）で反映されないことを確認済み。
  マッチする場合は文字集合が HTML 特殊文字を含みえないので安全にそのまま埋め込める。
- App Store ID・URL は既存 `site/index.html` から再利用（`6796222704`）。
  スタイルも既存 `style.css` のクラス（`.badge` `.hero` `.download-cta` 等）を再利用し、
  新規 CSS は追加していない。

### デプロイ

- `wrangler dev --port 8799` でローカル動作確認: AASA 配信（`.well-known` と root 両方）、
  有効コード・無効コード・XSS試行コードの3パターン、既存 `/privacy` `/api/waitlist` の無回帰
- 依頼者承認のもと `wrangler deploy` 実行 → 成功
- 本番で再確認: AASA が `.well-known/apple-app-site-association` で200・正しいJSON、
  `/i/ABCDEFGH12` が正しい `app-argument` を含むページを返す、`/privacy` `/terms` `/support`
  `/api/waitlist` に回帰なし
  - デプロイ直後の一回だけ AASA への `HEAD` リクエストが 404 を返したが、数秒後の再確認では
    200 になった。Cloudflare のエッジ伝播の一過性の遅延と判断（GET は同時点で既に200だった）。
    継続して起きる場合は再調査すること。

## 次にやること（Step 7以降、iOS側）

`dev-notes/share-card-qr-removal-and-invite-blueprint_2026-08-11.md` §4-3 のビルド順序、
`~/.codex/claude-memory/skygrid-invite-link-handoff-2026-08-11.md` の
「再導出してはいけない設計判断」を先に読むこと。

1. iOS 純粋型（`InviteCode` / `InviteLinkParser` / `FirstUnlockPaywallPolicy`）＋ Swift Testing
2. Associated Domains entitlement を `SkyGrid.entitlements` に追加
   （`applinks:skygrid.my` — Apple Developer Portal 側の capability は依頼者が2026-08-11に
   有効化済み。`ios/SkyGrid/Config/SkyGrid.entitlements` を確認したが、まだ
   `com.apple.developer.associated-domains` キーは無い）
3. リポジトリ配線 → entitlements/ルーティング → `RevealSignal` → UI → ペイウォール移設 →
   計測 → 実機E2E
4. invite client だけ `Functions.functions(region: "asia-northeast1")` を使う
   （既存 delete/image 用の default instance を差し替えない）
5. version bump → ASC 1.0.2 提出（依頼者本人の操作）
