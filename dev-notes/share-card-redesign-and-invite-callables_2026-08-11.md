# 共有カードの再設計と、招待リンク Step 2（4 callable）

日付: 2026-08-11（同日2セッション目）
前セッション: `share-card-qr-removal-and-invite-blueprint_2026-08-11.md`
状態: **両方とも完了・テスト通過。デプロイは未実施（破壊的操作のため依頼者確認待ち）**

---

## 1. 共有カードの再設計（依頼者「デザインが下手だ」に対する対応）

### 1-1. 真因: カードは「不在」に「証拠」より広い面積を与えていた

QR 撤去後も残っていた問題。年間カードは**リテラルな 31×12 カレンダー**を描いていたので、
実ユーザー（撮影20日）では **345日分の空セルが hero の約94%を占める**。写真1枚は 30pt タイル
= ストーリートレイのサムネイルでは**約3px**。結果、「モザイクが売り」の製品が、
灰色の長方形に色の縞が1本入った画像として拡散されていた。

外部設計レビュー（Codex / GPT-5.6、`codex exec` に委譲。リポジトリへの書き込みを禁止した
ブリーフで実行し、`git status` で無変更を確認済み）の診断も同じ順位付けだった。

### 1-2. 修正: 1つのグリッドが兼務していた2つの役割を分離

| 新コンポーネント | 役割 |
|---|---|
| `CapturedSkyMosaicExportView`（`SkyGridExportView.swift` 内 private） | **hero**。撮影した日だけを時系列で詰める。20枚なら **約146pt タイル**（旧30pt） |
| `YearMapExportView`（同上） | **真実の担保**。31×12 カレンダーそのまま。未撮影日は 4pt のガイドドット |

分離が必要な理由: 詰めたコンタクトシートだけだと「その年のどこで撮ったか」を偽ることになる。
下に本物のカレンダーを残すことで、**詰めた並びが日付の主張ではない**ことが明示される。

### 1-3. 実装した変更（ファイル単位）

- `DesignSystem/ExportTheme.swift` — トークン追加: `groundTop` / `inkMuted` / `surface` /
  `surfaceRaised` / `hairline` / `guide` / `groundGradient`。削除: `ink3` / `cellEmpty` /
  `cellPostedNoThumb`（参照ゼロを grep 確認済み）。
  - **`inkMuted` は半透明白（`ink2`）ではなく固定 hex**。パネル（`surface`）の上と地の上の
    両方に載るようになったため、半透明だと同じラベルが2つの異なるグレーで描かれていた。
  - `groundGradient` を共有トークンにしたのは、2枚のカードが**別々に定義すると必ずズレる**から。
- `Grid/SkyGridExportView.swift` — 全面書き換え。
- `Grid/MorningCardExportView.swift` — 全面書き換え。年間カードと同一の文法
  （80pt inset / ヘッダ / 枠付きパネル / 数字＋セリフのロックアップ / フッターチケット /
  下部176pt のストーリーUI回避帯）。
- `Grid/AppStoreIdentityExportView.swift` — 全幅の「チケット」に。虫眼鏡＋**SEARCH**。
- `Grid/ContactSheetLayout.swift` — **新規**。詰め込み幾何の純粋関数。
- `Tests/ContactSheetLayoutTests.swift` — **新規**、10件。

### 1-4. なぜ詰め込み幾何を純粋関数に切り出したか

枚数によって列数・行数・ガター・タイル寸がすべて変わる。そして**意味のある枚数（1 / 20 / 365）は
実ユーザーの人生で数ヶ月〜1年離れている**。365枚でのレイアウト破綻は、放置すれば
1年後にユーザーが先に発見する。`GridLayoutMath` と同じ理由で純粋化した。

テストで固定した不変条件: 空なら layout なし（呼び出し側が空状態を描く）／1枚は 420pt で
キャップ（キャッシュサムネイルを引き伸ばさない）／20枚は 5×4 で 120pt 超／365枚でも全タイルが
パネル内／読み順（左→右、上→下）／重なりなし／ガターの境界値（49・144）。

### 1-5. 意図的にデザイン提案から外した3点

1. **撮影時刻を残した**（Codex は削除を提案）。`SkyPost` は撮影時のタイムゾーンを保存して
   いないので、旅行後にエクスポートすると時刻がズレる — という指摘自体は正しい。しかし
   **「何時に起きたか」はこの製品そのもの**であり、カードから消すのは製品を消すのに近い。
   境界も狭い（カードは撮影直後に共有されるのが普通）。コードにコメントで明記した。
2. **日付は `post.localDate` から導出**（`capturedAt` の再フォーマットをやめた）。
   グリッドが記録している日と食い違わないため。**UI監査フィクスチャでこの食い違いが実際に
   露見した** — 旧カードは "Thursday, Jul 30" と表示していたが、その post の `localDate` は
   Jul 18 だった（フィクスチャの構成上の不整合だが、まさにこの変更が守る種類のバグ）。
3. **`streak <= 0` で "day one" と書くのをやめた**。0 は「初日」だけでなく「連続が途切れた」
   状態でもあるので、旧実装は 0 を根拠に嘘をつく可能性があった。今は "a morning sky"。

### 1-6. Gotcha

- **`SGExport` 境界ルールは新規ファイルの命名で守る。** `ExportTheme.swift` が参照可能な場所を
  `Grid/*ExportView.swift` / `Grid/ShareCardRenderer.swift` / `Milestone/*` に限定している。
  `ContactSheetLayout.swift` は `SGExport` を**参照していない**ので命名制約の対象外
  （純粋幾何のみ）。private サブビューは `SkyGridExportView.swift` の中に置いた。
- **編集直後の SourceKit 診断は今回も全て誤検知**（`No such module 'UIKit'`,
  `Cannot find 'SGFont' in scope` 等）。`xcodebuild` は一貫して BUILD SUCCEEDED。
- **UI監査のサムネイルは合成グラデーション**なので、シミュレータのスクショではタイルが
  のっぺりして見える。実写では違う。フィクスチャの見た目を実機の見た目と誤認しないこと。

---

## 2. 招待リンク Step 2/16 — 4 callable（完了）

設計は Opus の `code-architect` に委譲し、その設計を実装した。**設計書の指摘のうち、
前セッションの計画書が間違っていた点が3つある**（後述 2-5）。

### 2-1. 追加・変更したファイル

| ファイル | 内容 |
|---|---|
| `functions/src/rateLimit.ts` | **新規**。固定ウィンドウのレート制限判定（純粋） |
| `functions/src/inviteStore.ts` | **新規**。Firestore I/O 全部。`db` は引数、`HttpsError` を投げない |
| `functions/src/invites.ts` | 純粋関数を7個追加（`previewState` / `newestLiveInvite` / `inviteGeneration` / `inviteFromDocument` / `inviteDocumentFields` / `existingFriendshipFrom` / `inviteLinkURL` / `inviteTTLPurgeAtMs`） |
| `functions/src/index.ts` | 4 callable（薄いシェル）＋ `deleteAccount` の掃除 |
| `functions/test/rateLimit.test.js` | **新規** 8件 |
| `functions/test/invites.test.js` | +14件（計45件） |
| `functions/test/emulator/inviteStore.test.js` | **新規** 14件（エミュレータ必須） |
| `rules-tests/test.js` | +5件（計32件） |

**callable の実体を `index.ts` に書かなかった理由**: 4本インライン化すると `index.ts` が
600行超（現状301行、house ルールは「200-400行が標準」）。それ以上に、**claim トランザクションを
`onCall` の中に置くとエミュレータでテストできない**。`inviteStore.ts` は `admin.firestore()` を
内部で呼ばず `db` を受け取るので、Functions/Auth/App Check なしで Firestore エミュレータだけで
テストできる。export される4本の名前は `index.ts` にある（計画書通り）。

### 2-2. 設計の核（再導出しないこと）

**エラー経路は原理的に何も漏らさない。** 4本とも `not-found` / `permission-denied` を**一切**
返さない。コードの存否に依存する結果は**全て 200 + `state`/`outcome` フィールド**。投げる
エラーは全て「コードを読む前に決まる呼び出し元の状態」（未認証・ハンドル無し・レート超過・
型不正）だけに依存する。この**順序**が「メッセージ文字列を監査しなくてもコードを読めば
漏れていないと分かる」性質を作っている。

**レート制限は `previewInvite` だけでは不十分。** `claimInvite` は同じ存在オラクルなので、
preview だけ制限しても攻撃者は claim を呼ぶだけで回避できる。両方に適用した。
`revokeInvite` だけ免除 — 「他人のコード」と「存在しないコード」の応答を**バイト単位で同一**に
したので、そこに列挙する対象がない。逆に言えば**この同一性を崩すと revoke が最も安い
無制限オラクルになる**。

**レート制限の本当の目的は秘匿ではなく課金・可用性の上限。** 生存コードは 10²〜10⁴ 個、
コード空間は 2⁵⁰ なので、1ヒットの期待試行回数は 10¹¹〜10¹³。制限の有無に関わらず到達不能。
前セッションの計画書は「50bitのコード空間に対する唯一の実用的攻撃経路」と書いていたが、
**経路の特定は正しく、脅威の見積もりが誤り**。この違いは重要で、秘匿が制限に依存していると
考えると、シャード化カウンタや人工遅延といった過剰な機構を正当化してしまう。

**制限はトランザクションを使わない。** 単一ホットドキュメントへの read-modify-write
トランザクションは競合で ABORT する → 攻撃者の洪水が自分たちの500エラーになる。
非トランザクションなら遅延に劣化するだけで、しかも Firestore の「1ドキュメント約1write/秒」が
**実装しなくても効く第2の制限**として働く。代償は同時実行分のオーバーシュート（許容）。

**friendship は `accepted` で直接書く（rules の `pending` 強制に意図的に違反）。**
あのルールは*クライアントの権限*の制約であって、スキーマ不変条件ではない
（クライアントは相手の同意を主張できない）。サーバは両方の同意を持っている（作成者がリンクを
発行し、受取人が開いた）ので、**rules が既に許している遷移列の不動点**を書いている
（pending 作成 → 非requester が accepted に更新）。中間状態は全て合法で、新しいのは原子性だけ。

**それ以外の rules 制約は全部満たす。これは几帳面さではない。**
`activeBuddy()` は `relationship.data.blockedBy.size()` を呼ぶ。`blockedBy` 無しで書かれた
friendship はこの式を**エラーにし**、rules のエラーは読みを拒否する →
**この機能が触っていないコードパスで、相手側のバディ読み取りが静かに壊れる**。
rules はこのコレクションの唯一の書かれたスキーマ。

**`createInvite` は既存の生きたリンクを再利用する（計画書からの変更）。** 毎回発行すると
`invitesToRevokeBeforeCreating` と組み合わさって、**招待画面を4回開くと最初に DM で送った
リンクが黙って失効する**。`fresh: true` で明示的に新規発行。

**`expireAt`（TTL用 Timestamp）は `expiresAtMs` とは別の瞬間**（expiry + 30日）。
同じにすると、①8日目にリンクを開いた人が "expired" ではなく "unknown"（＝打ち間違い）と
言われる ②`resolveClaim` の「同じ人の再claim は `paired`」分岐が、ドキュメント消滅で壊れる。

### 2-3. `deleteAccount` の掃除 — 作成分と claim 分で扱いが違う

- **自分が作ったリンク → 物理削除。** 自分のデータだし、既に死んでいる（作成者プロフィールが
  消えれば claim は `unknown` に解決する）。計画書が指摘した孤児招待はこれで解消。
- **自分が claim したリンク → `claimedByUid` を `null` に潰すだけ（削除しない）。**
  これは**他人（作成者）のデータ**。消すとその人の記録が壊れる上に、コードが `unknown` に
  戻る＝**使えそうに見える**状態になる。`status: "claimed"` のまま `claimedByUid: null` なら
  `resolveClaim` が正しく「使用済み」と扱う。**新フィールドは不要**（Step 1 の型が
  `claimedByUid: string | null` を既に許している）。
- **`writer.update()` はこの関数で初めて「本当に失敗しうる書き込み」。** 既存の書き込みは
  全て冪等な delete。`NOT_FOUND` はリトライ不可なので、未処理だと
  「部分的に完了した削除のリトライは成功しなければならない（500にしない）」という
  この callable の文書化された性質を破る。`.catch()` + `logger.warn` を付けた。
  握りつぶしではない: 現実的な原因は作成者の同時アカウント削除だけで、結果は望んだものと同一。

### 2-4. Gotcha（実際に踏んだもの）

- **Firestore エミュレータには Java が要る。`java` は PATH に無い。**
  `firebase emulators:exec` が `Process 'java -version' has exited with code 1` で落ちる。
  **openjdk は brew で入っているが keg-only でリンクされていない。** 解決:
  ```bash
  export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
  npm run test:emulator
  ```
  npm script にこのパスを埋め込むのはマシン固有なのでやめた。**エミュレータテストを走らせる
  次のエージェントは、この export を先に打つこと。**
- **`test/emulator/` をサブディレクトリにしたのは意図的。** `npm test` のグロブは
  `test/*.test.js` なので、この階層なら**通常のテスト実行がエミュレータを要求しない**。
- **複合クエリ（`creatorUid ==` かつ `status ==`）を避けた。** 設計書は使う想定だったが、
  **複合インデックス欠如はエミュレータでは検出できず、本番でのみ 100% 失敗する**
  （`FAILED_PRECONDITION`）。`creatorUid` だけで引いてメモリ側で絞る形にした。
  上限3本なので結果は数件。この判断で本番専用の失敗モードが1つ消えた。
- **`batch.create` を使う（`set` ではない）。** 50bit の衝突は約10億分の1だが、`set` だと
  **他人の生きた招待を上書きして2人に同じコードを渡す**。`create` なら `ALREADY_EXISTS`
  （gRPC status 6）でリトライできる。3回で打ち切り（RNG が壊れている場合の無限ループ回避）。
- **招待コードを丸ごとログに出さない。** ドキュメントIDが秘密そのもの。`logger.info({ code })`
  一つで、ログ閲覧権限のある人間がレート制限を完全に迂回して生きた招待を収穫できる。
  `codeForLog()`（先頭4文字＋…）を用意した。

### 2-5. 前セッションの計画書が間違っていた点

1. **`claimInvite` も列挙オラクル** — 計画書は preview だけを挙げていた。
2. **`revokeInvite` も第3のオラクル** — 応答を同一にしない限り。計画書に記載なし。
3. **Step 4 の「invites deny ルール追加」は既に効いている** — `firestore.rules:247` の
   catch-all `match /{document=**} { allow read, write: if false }` が既に拒否している。
   Step 4 のルールは文書化と多層防御であってゲートではない。**だからこそ deny テストを
   今（Step 2 で）書けたし、書いた**（Step 4 はこれを green に保つ回帰ガードになる）。

### 2-6. テスト結果

```
functions:   45 passed / 0 failed   (npm test — Firebase 不要)
emulator:    14 passed / 0 failed   (npm run test:emulator — 要 Java PATH)
rules-tests: 32 passed / 0 failed   (npm run test:emulator — 要 Java PATH)
iOS:         ContactSheetLayoutTests 10 passed / 0 failed
```

エミュレータテストで**純粋テストでは到達できない**ことを確認した項目:
friendship の**キー集合が rules のホワイトリスト7個と完全一致**・members がソート済み／
2人が同じコードを同時に claim して**成立は1人だけ**（`Promise.all` で実測）／
同一人物の再claim が**2度目は書き込みゼロ**（`updateTime` 比較）／
pending の昇格が重複を作らない／ブロック時にコードが焼かれない／
作成者削除後の claim が中途半端なペアを作らない／再利用と `fresh` の挙動／
revoke の応答同一性／レート制限の実挙動／`generation` の記録。

---

## 3. 未実施・次にやること

**Step 2 は完了。次は Step 3（functions デプロイ）だが、これは破壊的操作なので依頼者確認待ち。**

デプロイ順序は `backend-deploy-sequencing_2026-08-08.md` の functions → rules → client。
Step 3 の functions デプロイは**純粋追加なので出荷済み 1.0.1 クライアントに無害**
（1.0.1 はこれらの callable を一切呼ばない）。

デプロイ後すぐに確認すべきこと:
1. **本番で `createInvite` を1回呼ぶ。** インデックス関連の失敗は本番でしか出ない。
2. **`expireAt` の TTL ポリシーは `firebase deploy` では作られない。**
   `firebase.json` に TTL/インデックス設定が無いので、コンソールか
   `gcloud firestore fields ttls update` で手動作成が必要。忘れると `invites` と
   `inviteRateLimits` が無限に増える（静かに、やがて課金と `deleteAccount` の遅延として）。
3. **課金アラート。** 匿名認証なので UID は使い捨て可能＝レート制限は「身元の上限」ではなく
   「コストの上限」。実際のバックストップは Cloud Billing の予算アラート。

### 依頼者本人の作業

1. ~~Apple Developer Portal の Associated Domains~~ → **2026-08-11 完了（本人報告）**
2. **DSA トレーダーステータス未申告**（未申告だと EU App Store から削除）
3. Cloudflare / Firebase デプロイ、ASC 1.0.2 提出

---

## 4. 並行セッションの状況（前セッションから継続）

`branding/promo/`（実写の空からモザイクを作る Python 群）と dev-note 2件に加え、
**今回 `.gitignore` にも変更が入っていた**（`branding/promo/skies/` 等の除外、73MB の
Wikimedia 元画像）。`ps aux` で土曜から起動しっぱなしの別 claude プロセス（PID 32039）を再確認。
**一切触れず、コミットにも含めていない。** 本セッションのコミットは自分が触ったファイルのみに
厳密にスコープした。
