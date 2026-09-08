# PRODUCT-MODEL — Sky Grid

最終更新: 2026-09-08 / 更新者: Codex

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
| `skygrid_alarm_schedule_changed` | `ios/SkyGrid/Sources/Notifications/MorningAlarmAnalytics.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-07 実装。時刻・曜日・UIDは送らず、保存件数/有効件数/backend/成功のみ。実到着未確認 |
| `skygrid_wake_session_started` / `skygrid_wake_retry_horizon_refilled` / `skygrid_wake_session_ended` | `ios/SkyGrid/Sources/Notifications/MorningAlarmAnalytics.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-08 実装。分母はsession開始、完了はended reason=`captured`。時刻・alarm ID・写真情報は送らない。実到着未確認 |
| `skygrid_paywall_value_preview_completed` | `ios/SkyGrid/Sources/Paywall/PaywallAnalytics.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-07 実装。entry point/step/schema versionのみ。実到着未確認 |

### 2.1 送信経路の検証結果（2026-09-07 実測・Claude Code）

**収集は有効で、イベントは実際に Google に到達している。** 以下はシミュレータ実機ログによる直接観測であり、推測ではない。

- `GoogleService-Info.plist` の `IS_ANALYTICS_ENABLED = False` は**無効**である。firebase-ios-sdk 12.17.0 のチェックアウトを全文検索したところ、この文字列は `docs/FirebaseOptionsPerProduct.md` にしか現れず、コードからは一度も読まれない。実際のゲートキーは `FIROptions.m` の `FIREBASE_ANALYTICS_COLLECTION_ENABLED` / `FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED` で、いずれも **Info.plist** から読む。`ios/SkyGrid/Config/Info.plist` にはどちらも存在しないため、収集は既定どおり有効。
- `-FIRDebugEnabled` 付きで Debug ビルドを起動し、`log stream` を取得した結果:
  `first_open` / `session_start` / `user_engagement` が記録 → `Bundle added to the upload queue` → `Uploading data. Host: https://app-analytics-services.com/a` → **`Successful upload. Got network response. Code: 204`**。
  つまり自動イベントの送信経路は端から端まで機能している。
- GA4 側の紐付けも実在する: property `552768124`（account `364874961`）、iOS stream `15716675392`。

**未解決は「読み取り」と「カスタムイベントの発火」の2点に絞られた。**

- 読み取り経路が無い。BigQuery エクスポートは未設定（`bq ls --project_id=sky-grid-app` が空）。GA4 Data API は ADC のスコープ不足で 403（`ACCESS_TOKEN_SCOPE_INSUFFICIENT`）。どちらの解除にも `analytics.readonly` を含む対話ログインが要る。
- カスタム `skygrid_*` の到達は**未確認のまま**。起動のみでは 1 件も発火しなかった（サインイン画面で停止するため当然）。加えて 9 箇所すべてが `Analytics.logEvent` の静的呼び出しで、抽象化もテストダブルも無く、`ios/SkyGrid/Tests` に Analytics を検証するテストは 1 件も無い。よって「その行が実際に実行されるか」を保証する仕組みが現状ゼロである。最小の是正は、送信を protocol 越しにしてテストで観測可能にすること。

### 2.1b 実測値（2026-09-07・GA4 Data API 直読み）

読み取り経路が開通した。`skygrid-analytics-reader@sky-grid-app.iam.gserviceaccount.com` を
GA4 property `552768124` の閲覧者に追加し、鍵ファイルなしの impersonation で取得する:

```sh
TOKEN=$(gcloud auth print-access-token \
  --impersonate-service-account=skygrid-analytics-reader@sky-grid-app.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/analytics.readonly)
```

**カスタムイベントは届いている。** 90日レンジで 24 種類、うち 18 種類が `skygrid_*`。
「コード呼出しあり・実到着未確認」は解消。実機も報告している（1.0.4 が iPhone16,1 /
iPhone15,2 / iPhone17,3 / iPhone18,5 の4機種）。

**ただしデータは 2026-09-04 以降の4日分しか存在しない。原因は確定した。** Admin API が返す
`properties/552768124` の `createTime` は `2026-09-04T03:43:07Z` であり、GA4 プロパティ自体が
その日に作られている。1.0.4 は 8/14 に公開済みで SDK は 8/2 から入っていたが、それ以前は
送り先が存在しなかった。紐付けの不具合ではなく、取りこぼしですらない。約3週間分の実利用は
記録されておらず、遡って取得する方法はない。母数は `first_open` 7 人であり、
**この標本で率を語ってはならない。**

| イベント | count | users |
|---|---:|---:|
| `skygrid_onboarding_step_viewed` | 58 | 2 |
| `skygrid_paywall_step_viewed` | 20 | 4 |
| `skygrid_paywall_presented` | 12 | 5 |
| `first_open` | 7 | 7 |
| `skygrid_capture_completed` | 6 | 2 |
| `skygrid_onboarding_completed` | 5 | 2 |
| `skygrid_invite_link_created` | 4 | 2 |
| `skygrid_invite_link_shared` | 3 | 1 |
| `skygrid_invite_code_copied` | 1 | 1 |

### 2.1c ファネル後半のゼロは、標本の性質であって異常ではない（2026-09-07 訂正）

`skygrid_invite_preview_viewed` / `claim_started` / `claim_resolved` /
`mutual_reveal_unlocked` はいずれも0件である。ただしこれを不具合の兆候として読んではならない。

**この4日間のユーザーは所有者ともう1名、およびシミュレータであり、招待の受け手が存在しない。**
受け手がいない以上、受信側イベントが0なのは定義どおりの結果であって、観測ではない。
`first_open` 7 のうち実機は4機種、残りはシミュレータである。この標本からファネルについて
言えることは何もない。

招待リンクの仕様は確認済みで、正しく動作している。`https://skygrid.my/i/{code}` は Universal Link
であり、AASA (`/.well-known/apple-app-site-association`) は `/i/*` を
`NVZB82UK53.com.takmin.skygrid` に紐付けて 200 を返す。**アプリが入っている端末では
リンクは直接アプリを開き、Web フォールバックページは表示されない。** 未導入の端末にのみ
フォールバックが出る。遅延ディープリンクは意図的に持たず
(`ios/SkyGrid/Sources/Invite/InviteLinkCard.swift:114`)、フォールバックページは
「インストール後に同じリンクをもう一度開く」よう案内している。

したがって現時点で必要なのは、受信側の切り分けでも Web ページの計測でもない。**実ユーザーが
いないことが唯一の事実であり、ファネルの形は実ユーザーが付いてから初めて読める。**

### 2.2 次の最小作業

次の最小作業は、新規カスタム install イベントでも plist の未使用キー変更でもなく、到着後、`first_open` を分母にして `capture_completed` → `invite_prompt_viewed` → `invite_share_started` → `preview_viewed` → `claim_resolved` → `mutual_reveal_unlocked` を集計する。UID、handle、invite code は送らない。すべてに `schema_version`、招待導線に `placement` / `experiment_variant` を付ける。

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
| 6 | 曜日別に最大5件のアラームを保存できると、alarm設定者の24時間以内初回撮影率と翌日撮影率が上がる | 単一アラーム群と比べて改善せず、設定失敗率または通知離脱が悪化する | 実装済み・検証待ち | 現在値は未測定。最安検証は匿名の有効件数コホート別に `capture_completed` を比較 | 2026-09-07 |
| 7 | CTAを塞がないMokuの短い導入会話と回答即時反映は first_open→初回撮影完了率を上げる | 7日成熟コホートで改善せず、onboarding完了率が悪化する | 実装済み・検証待ち | 現在値は未測定（既存7 first_openはシミュレータ混在・非コホート） | 2026-09-07 |
| 8 | 7日→30日→1年の短い操作可能プレビューは paywall view→purchase started を上げる | preview完了者を含む十分な標本で purchase started または confirmed が改善しない | 実装済み・検証待ち | 価格・商品構成は固定。preview完了イベントの実到着は未確認 | 2026-09-07 |
| 9 | 初回の実写真とセル着地を課金より先に置くと、説明先行より24時間以内の初回保存成功率が上がる | 7日成熟コホートで初回保存が改善せず、paywall到達またはpurchase startが悪化する | 実装済み・検証待ち | 初回paywallは保存成功とrewardの後に保留解除する | 2026-09-08 |
| 10 | Mokuの弱り表現は将来の継続動機になり得る | D7/D30が改善せず、通知停止・離脱・否定的反応が増える | 保留 | 欠席への罰にせず、回復可能な表現として継続データ取得後に試す | 2026-09-08 |
| 11 | 保存後の任意の気分・一言は空を語れる共有物になり得る | 投稿完了率または相互公開率を悪化させ、共有率が上がらない | 保留 | 投稿完了率が安定した後、撮影保存後の任意入力として試す | 2026-09-08 |
| 12 | Stop後も写真保存まで5分ごとにPhoto Missionを再鳴動すると、alarm起点の保存成功率が上がる | wake session開始群で保存成功が改善せず、alarm無効化・権限拒否・当日終了が増える | 実装済み・検証待ち | AlarmKitのOS Stopは阻止できないため、4時間窓内の真のone-shot alarm再予約で実現 | 2026-09-08 |

## 5. 意思決定履歴

| 日付 | 決定 | 理由 | 根拠の種類 | 撤回条件 |
|---|---|---|---|---|
| 2026-09-04 | group データモデルを導入せず、pairwise friendship を維持する | 現行ルールが relationship ごとに公開を判定し、既存メンバーの同意を守るため | コード観測・依頼者判断 | 本当に B↔C の可視性を必要とする新しい同意モデルが明示される場合 |
| 2026-09-04 | プロモーション判断より先に D7 相互公開率を計測する | 現在値が未測定であり、導線変更の因果を評価できないため | 依頼者判断・コード観測 | 集計経路で install / first-open cohort の分母を含む実測が取得できた場合 |
| 2026-09-04 | `IS_ANALYTICS_ENABLED` を手動変更しない | Firebase iOS SDK 12.17 はこの GoogleService-Info 項目を未使用と明記し、実際の制御キーにも含めないため | SDK 一次ソース・ローカル設定観測 | DebugView でイベントが到着せず、別の有効な収集停止条件が確認された場合 |
| 2026-09-04 | pace / frequency を残し、任意の9画面目として招待を追加する | 両回答は個別プランと paywall の文面に使用されるため | コード観測・依頼者判断 | オンボーディング完了率の実測低下が招待導線の増分を上回る場合 |
| 2026-09-07 | 複数アラームは最大5件、各時刻/曜日を独立保存し、起動時に保存集合をそのまま再同期する | fallbackの64 pending通知予算と既存owner decisionを守り、全時刻が最早時刻へ潰れる再同期欠陥を防ぐ | 既存意思決定記録・コード観測 | OSの通知上限またはfallback設計が変わり、別の安全な上限を実測できた場合 |
| 2026-09-07 | 日付跨ぎの当日投稿リセットは既存実装を維持し、manual clock changeの監視だけ追加する | `NSCalendarDayChanged`/timezone/foregroundと`TodayViewModel.start(for:)`の即時clearで報告原因は既に修正済みだったため | コード観測 | 実機回帰で前日postが当日postとして残る場合 |
| 2026-09-07 | オンボ会話とpaywallプレビューは操作を待たせず、価格/プラン構成を同時に変えない | 初回撮影までの遅延を増やさず、演出の効果を分離して測るため | 45アプリ調査・製品Bet | 仮説7/8の反証条件成立時 |
| 2026-09-08 | オンボーディング由来のpaywallは最初の実写真保存とrewardの後に出す | 説明ではなくSkyGrid固有のセル完成を先に体験させるため | 45アプリ調査・依頼者判断 | 仮説9の反証条件成立時 |
| 2026-09-08 | Mokuの弱り表現と任意の気分・一言は将来採用候補として保留する | 継続・共有価値はあり得るが、現在の初回投稿へ摩擦を加えないため | 依頼者判断・製品Bet | 投稿ファネルの十分な実測後に再評価 |
| 2026-09-08 | Photo MissionをAlarmKitの再鳴動として実装し、ローカル保存成功だけを完了条件にする | 撮影を起床アラームの付加機能ではなくSkyGridの中心ループにするため | 依頼者判断・Apple AlarmKit仕様・コード観測 | 仮説12の反証条件成立、または実機で再予約の信頼性を満たせない場合 |

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
