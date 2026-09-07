# PRODUCT-MODEL — Sky Grid

最終更新: 2026-09-04 / 更新者: Codex

## 0. 北極星指標

| 指標 | 定義（分子/分母を明記） | 現在値 | 計測日 | 出典 |
|---|---|---|---|---|
| D7 相互公開率 | インストールから7日以内に、本人の投稿後に1人以上のバディ投稿を読めたインストール数 / 同期間のインストール数 | 未測定 | 2026-09-04 | Console 側の Analytics 連携は依頼者報告で有効。現行 Firebase iOS SDK 12.17 は `IS_ANALYTICS_ENABLED` を読まないため、この plist の `false` は収集停止の根拠にならない。実イベント到着と BigQuery export は未検証。 |

> 変更しない場合、招待・相互公開の導線が見つからないままになり、外部プロモーションは相互公開に至らない線形成長のインストールを増やすだけになる、というのが現時点のコードからの推論である。

## 1. ファネル

```
[Install] → [Onboarding complete] → [Capture completed] → [Invite shared]
   → [Invite claimed] → [Mutual reveal within 7 days]
```

| 辺 | 意味 | 実測値 | 標本数 | 計測日 | 確信度 | 出典 |
|---|---|---|---|---|---|---|
| Install→Onboarding complete | 初回設定の完了 | 未測定 | — | — | 未測定 | 自動 `first_open` の実到着は DebugView / Realtime report で未確認 |
| Onboarding complete→Capture | 初回投稿 | 未測定 | — | — | 未測定 | コード呼出しあり。実到着は未確認 |
| Capture→Invite shared | 投稿者が招待リンクを共有 | 未測定 | — | — | 未測定 | コード呼出しあり。実到着は未確認 |
| Invite shared→Claimed | 受信者がリンクを受諾 | 未測定 | — | — | 未測定 | コード呼出しあり。実到着は未確認 |
| Claim→Mutual reveal D7 | ペア双方が同日に投稿し公開 | 未測定 | — | — | 未測定 | コード呼出しあり。実到着は未確認 |

## 2. 計測の実装状況

| イベント | 実装場所 | 送信先 | 読み取り経路 | 状態 |
|---|---|---|---|---|
| `skygrid_capture_completed` | `ios/SkyGrid/Sources/Publishing/PostPublisher.swift` | Firebase Analytics | — | コード呼出しあり・実到着未確認 |
| `skygrid_mutual_reveal_unlocked` | `ios/SkyGrid/Sources/Today/TodayViewModel.swift` | Firebase Analytics | — | コード呼出しあり・実到着未確認 |
| `skygrid_invite_link_created` / `shared` / `code_copied` | `ios/SkyGrid/Sources/Invite/InviteAnalytics.swift` | Firebase Analytics | — | コード呼出しあり・実到着未確認 |
| `skygrid_invite_preview_viewed` / `claim_started` / `claim_resolved` | `ios/SkyGrid/Sources/Invite/InviteAnalytics.swift` | Firebase Analytics | — | コード呼出しあり・実到着未確認 |

次の最小作業は、新規カスタム install イベントでも plist の未使用キー変更でもなく、DebugView / Realtime report で新規 debug build の `first_open` と既存カスタムイベントの到着を確認することである。到着後、`first_open` を分母にして `capture_completed` → `invite_prompt_viewed` → `invite_share_started` → `preview_viewed` → `claim_resolved` → `mutual_reveal_unlocked` を集計する。UID、handle、invite code は送らない。すべてに `schema_version`、招待導線に `placement` / `experiment_variant` を付ける。

## 3. ユーザー動線（実装の事実）

- AlarmKit / 通知 → カメラ → `PostPublisher` による投稿永続化 → Today の投稿表示。
- Today は、本人が投稿済みの場合だけ各バディの当日投稿を読み、成功時に相互公開として表示する。
- 招待リンクは Buddies タブのハンドル取得後に作成・共有でき、受信者の claim はサーバーで即時に pairwise friendship を作成する。
- 投稿通知は全 accepted / unblocked buddy に送る。招待受諾を招待者へ知らせるトリガーは未実装。

## 4. 仮説台帳

| # | 仮説 | 反証条件 | 状態 | 結果 | 日付 |
|---|---|---|---|---|---|
| 1 | 投稿直後の招待導線は Capture→Invite shared を上げる | 導線追加後も install あたりの `link_shared` が変わらない | 検証待ち | 未測定 | 2026-09-04 |
| 2 | 2人以上の独立した buddy edge は D7 相互公開率を上げる | 1 buddy と 2+ buddies で相互公開率が上がらない | 検証待ち | 未測定 | 2026-09-04 |
| 3 | 通常日の share 導線は共有数を上げる | 導線追加後も capture あたりの共有意図が変わらない | 検証待ち | 未測定（share-card 固有イベントなし） | 2026-09-04 |
| 4 | オンボーディング最終画面の任意招待は Invite shared を上げる | 7日成熟コホートで onboarding placement の共有率・D7相互公開率が改善しない | 実装済み・検証待ち | 実イベント到着未確認のため未測定 | 2026-09-04 |
| 5 | 昨日の空を pre-capture card に出すと、昨日投稿した人の翌朝 capture 率を上げる | 同一導線の7日成熟コホートで翌朝 capture 率が改善しない | 実装済み・検証待ち | Analytics 実到着未確認のため未測定。最安検証は card exposure と翌朝 `capture_completed` の cohort 比較 | 2026-09-04 |

## 5. 意思決定履歴

| 日付 | 決定 | 理由 | 根拠の種類 | 撤回条件 |
|---|---|---|---|---|
| 2026-09-04 | group データモデルを導入せず、pairwise friendship を維持する | 現行ルールが relationship ごとに公開を判定し、既存メンバーの同意を守るため | コード観測・依頼者判断 | 本当に B↔C の可視性を必要とする新しい同意モデルが明示される場合 |
| 2026-09-04 | プロモーション判断より先に D7 相互公開率を計測する | 現在値が未測定であり、導線変更の因果を評価できないため | 依頼者判断・コード観測 | 集計経路で install / first-open cohort の分母を含む実測が取得できた場合 |
| 2026-09-04 | `IS_ANALYTICS_ENABLED` を手動変更しない | Firebase iOS SDK 12.17 はこの GoogleService-Info 項目を未使用と明記し、実際の制御キーにも含めないため | SDK 一次ソース・ローカル設定観測 | DebugView でイベントが到着せず、別の有効な収集停止条件が確認された場合 |
| 2026-09-04 | pace / frequency を残し、任意の9画面目として招待を追加する | 両回答は個別プランと paywall の文面に使用されるため | コード観測・依頼者判断 | オンボーディング完了率の実測低下が招待導線の増分を上回る場合 |

## 6. 未解決の不明点

- Firebase Analytics のイベントを install cohort / 7日窓で読める経路、および現在の実測値。
- 新規 debug build から `first_open` と既存カスタムイベントが Firebase DebugView / Realtime report に実際に到着するか。到着後に BigQuery export を設定し、install cohort の7日集計を作る。
- 招待受諾通知の通知文面、同意状態、失敗時の再試行要件。
- buddy 数の上限を置くか。厳密に上限を置くなら、handle 経由とリンク claim の両方の作成経路をサーバーで集約する必要がある。
- 週末に欠席が集中しているか（複数アラームの投資判断）。

## 7. App Store release measurement — 2026-09-06

- Target metric: page-attributed first-time downloads / unique product-page viewers, aligned by date, storefront and source. Current value: **unmeasured**; do not substitute all downloads divided by page views.
- Created ongoing ASC analytics request `11e25502-8655-4a78-a377-4d2032e9a088`. Read with `asc analytics view --request-id 11e25502-8655-4a78-a377-4d2032e9a088`; report definitions exist, but no report instances are available yet.
- 1.0.5 creative bet: current UI plus one concise benefit per screenshot helps visitors understand the capture→mosaic→buddy loop. Without the change, 1.0-era screens and obsolete color-only/Pro descriptions persist.
- Cheapest check: compare a complete seven-day post-publication window with a matched prior window when reports exist; if volume is insufficient, leave the result unmeasured. Do not attribute conversion changes to creative alone because the app version changes simultaneously. Preserve the former set; revise if qualified conversion drops with adequate comparable data.
- Submission prerequisite found: current iOS handle requests/acceptance require two missing production Functions. See `dev-notes/asc-1.0.5-release_2026-09-06.md`; no global eight-person-cap claim in this release copy.
