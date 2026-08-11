# 共有カードQRの撤去と、招待リンク実装ブループリント

日付: 2026-08-11
状態: 共有カードは完了・commit 済み。招待リンク本体は**未着手**（設計のみ完了）

---

## 1. 完了したこと

### 1-1. Lifetime を $39.99 → $55.00 に改定（ASC、本番反映済み）

- 「グローバルな価格変更」を選択 → 全175地域が連動（EUR €44.99 → €59.00 等）
- **適用は即時**。ASC が「この価格変更はすぐに有効になります」と明示し、反映後の価格表で実値を確認済み
- **再審査は不要だった** — IAP ステータスは「承認済み」のまま変化せず、「審査用に追加」ボタンもグレーのまま
- **既存購入者への影響なし** — 非消耗型は買い切りなので再課金が発生しない。サブスクと違いグランドファザリングの仕組み自体が不要
- 手取りの実測: $33.99 → **$46.75**。**Small Business Program（85%）が実際に適用済み**であることをこの数字で確認（従来は「適用時は」という仮定だった）

### 1-2. 共有カードのQRを、アイコン＋アプリ名に置き換え（commit `83cd15b`）

---

## 2. Gotcha: Story に貼る画像のQRは、構造的にスキャンできない

**症状:** 共有カード（`SkyGridExportView` / `MorningCardExportView`）の footer に 128px の QR があり、App Store URL を指していた。計画書（`codex-viral-single-path_2026-08-10.md` L192）は、これを招待トークンに差し替えろと指示していた。

**原因:** 共有カードは Instagram/TikTok の Story に貼られる前提で設計されている（`ExportTheme.swift` のコメントに "survives being rendered ~120px wide in an Instagram/TikTok Story tray" と明記）。

Story を見る人は、**自分のスマホの画面でそれを見ている**。スマホのカメラを自分自身の画面に向けることはできないので、**その QR は原理的にスキャンできない**。

iOS ならスクショ → 写真アプリ → Live Text で一応たどれるが、4ステップを踏む人はほぼいない。QR が機能するのは相手が**別のデバイス**で見ているとき（PC画面・印刷物・対面で相手の端末を見せる）だけ。

**なぜ見落としやすいか:** QR は「リンクを画像に埋める汎用手段」として反射的に選ばれる。しかし配布面が「受け手が自分の画面で見るもの」の場合、カメラという前提が成立しない。**配布面が同一端末内で完結するか**を先に問うこと。

**さらに悪い点:** 計画書通り単回消費・自動承諾の招待トークンを埋めていたら、汎用 App Store QR より**悪化**していた。Story を見た N 人がスキャンしても成立するのは最速の1人だけで、残りは全員「使用済み」に着地する。しかもその全員が**既にインストールを終えている**。バディゼロの状態はこの製品の価値がゼロの状態なので、そのまま離脱する。

**修正:** QR を撤去し、`Grid/AppStoreIdentityExportView.swift`（`AppStoreIdentity`）に置換。

```
[アイコン 132px]  @handle          28pt semibold ink2
                  Sky Grid         46pt bold ink
                  on the App Store 24pt ink2
```

変更前は名前が「Sky Grid — one sky, every morning」24pt・透明度62%の脇役で、**アイコンは無く**、「App Store で手に入る」とも書いていなかった。読んで検索できる情報に置き換えた。

**関連する未修正の穴:** `ShareSheet(items: [card.image])` は**画像しか渡していない**（`MilestoneView.swift:46`、`GridArchiveView.swift:236`）。URL もテキストも付かない。Messages/DM で共有したときにタップできるリンクが同送されれば QR より確実だが、`UIActivityViewController` に `[UIImage, URL]` を渡すと Instagram の共有 extension の挙動が変わる可能性があり、Story が主目的なので**実機で確認せずに変えるべきではない**。未検証。

**残した死にコード:** `QRCodeGenerator.swift` と `SGExport.downloadURLString` は共有カードからの参照が消えたが、両方とも残した。招待リンク UI で「対面で相手に見せる招待QR」を出す用途が近い将来ありうるため（対面なら**相手のカメラで自分の画面を撮れる**ので成立する）。

**ファイル名の制約:** `ExportTheme.swift` は `SGExport` を参照してよい場所を `Grid/*ExportView.swift` / `Grid/ShareCardRenderer.swift` / `Milestone/*` に限定し、grep コマンドまで書いている。新規ファイルを `AppStoreIdentityExportView.swift` と命名したのはこのルールを変えずに通すため。

**xcodegen:** `project.yml` の `sources: - path: SkyGrid/Sources` と `SkyGrid/Resources` は再帰的なので、新規 `.swift` と新規 imageset は**自動で入る**。`project.yml` の編集は不要（`xcodegen generate` の実行は必要）。

**SourceKit:** 編集直後に `No such module 'UIKit'` / `Cannot find type 'Handle' in scope` が出たが、**全て誤検知**。`xcodebuild ... build` は `BUILD SUCCEEDED`。既知（`~/.claude` メモリの sourcekit-diagnostics-not-authoritative）。

**シミュレータ:** `iPhone 16` は存在しない。利用可能なのは iPhone 17 / 17 Pro / 17 Pro Max / 17e / Air。

---

## 3. 議論の結論（ハンドル一覧・承認キューの検討）

依頼者から「QRにハンドルを載せると調べるUXが損なわれるのでは。BeReal のようにユーザー一覧から探せる方がよいのでは。あるいはハンドルを廃し、QRは自動承認でなく承認キューに入れる設計もありうる」という論点が出た。バイラル観点で比較した結論:

- **BeReal 型の一覧は今は効かない。** サジェスト一覧が機能するのは掘るべきグラフが既にある場合だけ（BeReal は連絡先アップロード＋友達の友達であって、全ユーザーの閲覧可能ディレクトリではない — ただしこれは一次確認していない）。連絡先アップロードは計画で除外済み、ユーザーはほぼゼロなので**一覧は空になる**。空を埋めるには他人を出すしかなく、それは「親友が起きるまで私の空は見えない」という製品価値を生まない。加えて `users/{uid}` は現在「本人か成立済みバディのみ読める」ので、一覧化はセキュリティモデルの反転を要求する。**正しい機能だが時期が違う。**
- **承認キュー型（トークン、ハンドルをURLに載せない）は @handle 案より構造的に良い。** URL に何も漏れず、トークン失効で対処できる（ハンドルを変える必要がない）。ただし**招待者が次にアプリを開くまで新規ユーザーは価値ゼロで待たされる**。朝のアプリなので6時に開いてその日はもう開かない人が多く、しかも**プッシュ送信路がバックエンドに存在しない**ためキューは不可視。
- **結論: 拡散経路は今回作らない。** 共有カードQRはどの Day 30 成功条件も動かさない（`K7_nextgen` が数えるのは相互投稿後の**アプリ内 1:1 追加招待**）。campaign link を作らない決定により**QR経由のインストールは因果帰属もできない**。承認キューをやるなら30日実験の後、案Aより案Bを採る。
- **1:1 DMリンク（単回・自動承諾）は変更なし。** これがエンジン本体。

---

## 4. 未着手: 招待リンク本体（Day 1-4）

**設計は完了している。** 完全なブループリントは Opus の code-architect が作成済みで、以下に要点のみ。詳細が必要なら再取得すること。

### 4-1. 前提の訂正（計画書との差分）

| 項目 | 計画書 | 実測 |
|---|---|---|
| ドメイン | `skygrid.app` | **`skygrid.my`**（当時の仮記載） |
| `skygrid.my` トップ | 「Join the waitlist のまま」（メモリ記載） | **既に "Available now on the App Store"**。ローカル `waitlist/site/index.html` とデプロイ版はハッシュ一致 |
| AASA | — | `/.well-known/apple-app-site-association` は **404**（未設置） |
| Associated Domains | — | entitlement **未設定**。`skygrid://capture` のカスタムスキームのみ |
| ペイウォール発火 | dev-note は「解除経験済み＋7回目の撮影」 | **依頼者判断で「最初の相互解除の直後」に確定**（メモリ `skygrid-paid-acquisition-pivot-2026-08-10` に記録済み）。`minimumCompletedCaptures = 1` |

### 4-2. 設計の核心

**「発行時に相手UIDが未知」問題:** `friendships/{pairId}` は `sorted(uidA, uidB)` なので発行時点でドキュメントIDを計算できない。既存コレクションの拡張は原理的に不可能。**`invites/{code}` を新設し、両UIDが揃う claim 時点で friendship を生成**する以外にない。

**Rules だけで完結させる案は却下。** 理由: ①受取人が読める＝サインイン済みなら誰でも読める設定になり、コード列挙のオラクルが Firestore 直結で開く ②「friendship作成」と「招待を消費済みにする」の2ドキュメント原子性をクライアントに委ねると griefing が成立する ③これは `imageDownloadURL` が既に下した判断と同型（「複数ドキュメントに跨る述語はサーバに置く」がこのコードベースの既存規範）。

→ **callable + Admin SDK トランザクション**。

**AASA は Worker が直接返すこと（`env.ASSETS` に落とさない）。** 実測で `/privacy.html` が **307 リダイレクト**を返しており、Workers Assets の拡張子正規化が AASA 取得を壊す現実的リスクがある。加えて Workers Assets がドットディレクトリ（`.well-known`）を配信するかは未確認。

**AASA の `components` は `/i/*` に限定すること。** `applinks:skygrid.my` を丸ごと関連付けると、`SkyGridWeb` の support/privacy/terms URL（すべて `https://skygrid.my/...`）がアプリに吸われ、`AppRouter` が無視するので**設定画面のリンクが無反応になる**。

**相互ぼかし解除はクライアントで信頼できる形で観測可能。** `TodayViewModel.refreshBuddies` の `BuddyRevealState.posted(SkyPost)` が立つ条件は「自分が投稿済み ∧ サーバがバディ投稿の読みを許可した」であり、後者は `firestore.rules` の `activeBuddy(uid) && hasPostedFor(localDate)` が真でないと通らない。**`.posted` が立つこと自体が相互解除のサーバ検証済み証明**。RootView への配線は `StreakSignal` の完全な写し（`RevealSignal`）を作れば済む。

**`bdfe12f`（節目がペイウォールを翌日に繰り越す）との衝突は例外ではなく既定。** `StreakMilestone.thresholds` に **1 が含まれる**ため、受取人にとって初回相互解除と Day-1 節目は**同じ朝に起きるのが標準ケース**。守るべき不変条件は「繰り越しは*提示されなかった*ことを記録しないことで実現される」。新ペイウォールは一発限りなので、**節目に譲った時点で一発を消費してはいけない**。`unlockPaywallPresentedAt` は実際に提示した経路でのみ書くこと。ここを間違えると Day-1 節目に当たった全ユーザーが自動ペイウォールを**永久に**見なくなる。

**帰結（再検討不要・事実の報告）:** この変更後、**バディがいない単独ユーザーには自動ペイウォールが一度も出なくなる**（相互解除が起きないため）。現行は撮影3回目で出ていた。手動プラン画面・アーカイブロック・`Continue Free` は維持されるので収益経路が消えるわけではない。

### 4-3. ビルド順序（`backend-deploy-sequencing_2026-08-08.md` の functions → rules → client に従う）

1. `functions/src/invites.ts` + `test/invites.test.js`（純粋関数、Firebase不要で `npm test`）
2. `functions/src/index.ts` に4 callable（`createInvite`/`previewInvite`/`claimInviteCode`/`revokeInvite`）＋ `deleteAccount` に invites 掃除を追加（**現状これが無いと孤児招待が残る**）
3. functions デプロイ（純粋追加＝旧クライアントに無害）
4. `firestore.rules` に invites deny ＋ `rules-tests/test.js`
5. rules デプロイ
6. Worker: AASA ルート＋`/i/*`＋`invite.html` → `wrangler deploy`
7. iOS 純粋型（`InviteCode` / `InviteLinkParser` / `FirstUnlockPaywallPolicy`）＋ Swift Testing
8〜15. リポジトリ配線 → entitlements/ルーティング → `RevealSignal` → UI → ペイウォール移設 → 計測 → 実機E2E
16. version bump → 提出

**`previewInvite` のレート制限は省略不可。** 50bit のコード空間に対する唯一の実用的攻撃経路がそこにある。

### 4-4. 依頼者本人の操作が必要

1. **Apple Developer Portal**: App ID `com.takmin.skygrid` に **Associated Domains** capability を有効化。あわせて **App ID Prefix が `NVZB82UK53` と一致するか**確認（`DEVELOPMENT_TEAM` は Team ID であって App ID Prefix とは別概念。古い App ID では食い違う）
2. Cloudflare / Firebase デプロイ（破壊的操作）
3. ASC: 1.0.2 の新ビルド添付＋審査提出
4. **DSA トレーダーステータス未申告**（ASC にバナー継続表示中、未申告だと EU App Store から削除）— 法的な自己申告なので本人操作

---

## 5. 並行セッションの検出

本セッション中、`git status` に自分が作っていない `branding/promo/`（実写の空からモザイクを生成する Python 群、`video-v1`、`ATTRIBUTION.md`）と dev-note 2件（`genflow-promo-asset-generation_2026-08-11.md` / `promo-mosaic-from-real-skies_2026-08-11.md`）が現れた。`ps aux` で**土曜から起動しっぱなしの別 claude プロセス（PID 32039）**を確認。TikTok 動画素材の制作作業と思われる。**一切触れず、削除もしていない。** コミットもしていないので未追跡のまま残っている。
