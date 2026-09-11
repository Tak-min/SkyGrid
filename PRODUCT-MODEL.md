# PRODUCT-MODEL — Sky Grid

最終更新: 2026-09-11 / 更新者: Claude Code

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
| `skygrid_invite_link_opened` / `skygrid_invite_fallback_recovered` | `ios/SkyGrid/Sources/App/AppRouter.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-08 実装。Universal Link受信とWeb復旧リンク受信を区別し、UID・invite codeは送らない。実到着未確認 |
| `skygrid_invite_preview_viewed` / `claim_started` / `claim_resolved` | `ios/SkyGrid/Sources/Invite/InviteAnalytics.swift` | Firebase Analytics | — | コード呼出しあり・実到着未確認 |
| `skygrid_alarm_schedule_changed` | `ios/SkyGrid/Sources/Notifications/MorningAlarmAnalytics.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-07 実装。時刻・曜日・UIDは送らず、保存件数/有効件数/backend/成功のみ。実到着未確認 |
| `skygrid_wake_session_started` / `skygrid_wake_retry_horizon_refilled` / `skygrid_wake_session_ended` | `ios/SkyGrid/Sources/Notifications/MorningAlarmAnalytics.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-08 実装。分母はsession開始、完了はended reason=`captured`。時刻・alarm ID・写真情報は送らない。実到着未確認 |
| `skygrid_paywall_value_preview_completed` | `ios/SkyGrid/Sources/Paywall/PaywallAnalytics.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-07 実装。entry point/step/schema versionのみ。実到着未確認 |
| `skygrid_weekly_recap_opened` / `skygrid_weekly_recap_shared` | `ios/SkyGrid/Sources/Publishing/WeeklyRecapAnalytics.swift` | Firebase Analytics | GA4 Data API（既存 impersonation 経路） | 2026-09-09 実装。shared / opened で週次リキャップ内の共有意図率を算出。実到着未確認 |

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

`https://skygrid.my/i/{code}` のAASA、Apple CDNキャッシュ、1.0.5提出IPAのAssociated Domains署名、
アプリ内parser/routerはいずれも2026-09-08に再確認済み。ただし「インストール済みなら必ず直接
アプリを開く」という旧記述は誤りだった。Appleの仕様では、同一ドメインをSafari内でタップした
場合や、利用者が過去にWeb表示を選んだ場合は、インストール済みでもSafariが継続する。旧Web
フォールバックにはApp Store CTAしかなく、この正常なOS分岐からアプリへ戻る経路がなかった。
そこでSmart App Bannerに加え、別のAssociated Domainである
`https://open.skygrid.my/i/{code}`への復旧CTAを追加した。

したがって現時点で必要なのは、受信側の切り分けでも Web ページの計測でもない。**実ユーザーが
いないことが唯一の事実であり、ファネルの形は実ユーザーが付いてから初めて読める。**

### 2.2 次の最小作業

次の最小作業は、新規カスタム install イベントでも plist の未使用キー変更でもなく、到着後、`first_open` を分母にして `capture_completed` → `invite_prompt_viewed` → `invite_share_started` → `preview_viewed` → `claim_resolved` → `mutual_reveal_unlocked` を集計する。UID、handle、invite code は送らない。すべてに `schema_version`、招待導線に `placement` / `experiment_variant` を付ける。

## 3. ユーザー動線（実装の事実）

- AlarmKit / 通知 → カメラ → `PostPublisher` による投稿永続化 → Today の投稿表示。
- Today は、本人が投稿済みの場合だけ各バディの当日投稿を読み、成功時に相互公開として表示する。
- Today 訪問時には、当日未表示の場合に限り約30%の確率で、現在の投稿・buddy・streak状態に合うMokuの短いアンビエント発話を表示する（計測対象外）。
- 招待リンクは Buddies タブのハンドル取得後に作成・共有でき、受信者の claim はサーバーで即時に pairwise friendship を作成する。
- 投稿通知は全 accepted / unblocked buddy に送る。招待受諾は `onFriendshipCreated` で招待者へ通知する（2026-09-11 に `firebase functions:list` でデプロイ済みを確認）。

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
| 10 | Mokuの弱り表現は将来の継続動機になり得る | D7/D30が改善せず、通知停止・離脱・否定的反応が増える | 今後実装すべきタスク（未着手） | 「欠席への罰にしない」という倫理的判断ではなく、現時点でのタスク規模上の都合により先送りしている。継続データ取得後に着手を検討する | 2026-09-08（2026-09-08訂正: 先送り理由の記述が不正確だったため修正） |
| 11 | 保存後の任意の気分・一言は空を語れる共有物になり得る | 投稿完了率または相互公開率を悪化させ、共有率が上がらない | 保留 | 投稿完了率が安定した後、撮影保存後の任意入力として試す | 2026-09-08 |
| 12 | Stop後も写真保存まで5分ごとにPhoto Missionを再鳴動すると、alarm起点の保存成功率が上がる | wake session開始群で保存成功が改善せず、alarm無効化・権限拒否・当日終了が増える | 実装済み・検証待ち | AlarmKitのOS Stopは阻止できないため、4時間窓内の真のone-shot alarm再予約で実現 | 2026-09-08 |
| 13 | Web着地時の明示的な「Open Sky Grid」復旧CTAは、招待リンク→アプリ内preview到達率を上げる | Web着地数に対するfallback recoveryとpreview到達が改善しない、または誤起動報告が増える | 実装済み・検証待ち | 現在値は未測定。最安検証はCloudflareの`/i/*`着地数と匿名のopened/recovered/previewイベントを同じ期間で比較 | 2026-09-08 |
| 14 | 初回撮影後のonboarding paywallを明示的に閉じたintro eligible利用者へ、一度だけ感情表現のあるsecond-chance stepを出すと購入確定率が上がる | 依頼者が既存paywallイベントの`step=second_chance`で離脱増または購入確定不足を確認する | コード実装済み・外部商品設定待ち | 現在値は未測定。A/B割付と専用イベントは追加せず、全対象者を既存イベントで観測する | 2026-09-08 |

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
| 2026-09-08 | 主リンクのAASA契約を維持し、Web着地後は別Associated Domainの`open.skygrid.my`で復旧する | iOSはSafari内の同一ドメインリンクをWebに保つ一方、Universal Linkはcustom schemeと違って他アプリに横取りされないため | Apple一次資料・本番AASA/CDN・提出IPA・コード観測 | 仮説13の反証条件成立、または副ドメインのApple CDN取得が安定しない場合 |
| 2026-09-08 | 「静かな朝」をユーザー体験の制約から外し、Mokuの感情表現、アニメーション、華やかな演出を利用可能にする | 直近のplayful redesignと依頼者の明示的な設計判断に合わせるため | 依頼者判断 | 新しい表現方針が明示された場合 |
| 2026-09-08 | second-chance paywallは会議用記録で詳細を決め、決定済みの範囲だけを実装する | 価格商品、提示条件、紹介成立条件を推測で結合しないため | 依頼者判断・コード観測 | `dev-notes/second-chance-paywall-decision-record_2026-09-08.md`の各議題が決定された場合 |
| 2026-09-08 | second-chanceは既存paywallの動的な追加stepとし、専用月額SKUの実intro価格とApple / RevenueCat eligibilityが揃う場合だけ表示する | 通常月額への意図しないintro適用、架空価格、過去課金者への誤表示を防ぐため | 依頼者判断・ASC実測・RevenueCat SDK一次ソース | 仮説14の継続判断で撤回された場合 |
| 2026-09-08 | second-chance専用イベント、A/B割付、自動停止、効果音は追加しない | 既存step analyticsを使い、依頼者が実測判断する今回の会議決定に従うため | 依頼者判断 | 新しい計測・音響方針が明示された場合 |
| 2026-09-08 | 2026-08-10確定の「有償クリエイター発注停止・自社ブランドアカウント($0現金・オーガニック投稿のみ)」方針は、ユーザー数が伸びず失敗に終わったと結論づける | 依頼者が運用結果を確認した上での判断。定量指標は本書2章の通り依然未測定のため、この結論は依頼者の定性判断であり、install/first_open の実測データによる裏付けはまだない | 依頼者判断 | 実測データが揃い、オーガニック単独運用の成果を定量的に再評価できる場合、または新しいマーケティング方針が明示された場合 |
| 2026-09-09 | Proの価値訴求を「アーカイブ軸の強化(A)」「バディ軸への新価値追加(B)」「Circle上限差別化(C)」の3方向すべてで再設計する | 既存Proは自分のアーカイブ閲覧・書き出しという単一軸のみで、報酬が遅く非社交的なため薄いままだった。差別化の核である相互解禁(バディ)に課金価値を重ねる | 依頼者判断 | 実装後の購入確定率が改善せず、代替設計が必要と判断される場合 |
| 2026-09-09 | 「課金後に機能は隠れない。Freeは完全な日課であり続ける」という既存paywall文言・方針を撤回する | この制約は依頼者が定めたものではなく、AIが無断で導入した方針であり、依頼者の意図に反するため | 依頼者判断 | 依頼者が改めてこの制約を明示的に指示した場合 |
| 2026-09-09 | 無料Circle上限を5人、Pro Circle上限を15人にする(現行の一律8人ハードキャップ`MAX_ACCEPTED_BUDDIES`を置き換える) | 6人目以降の招待という具体的な購入動機を作りつつ、招待リンクの分母(バイラルループの入口)を大きく狭めない規模として依頼者が判断 | 依頼者判断 | 実測データで招待送信数の顕著な悪化、または購入確定率の改善が見られない場合 |
| 2026-09-09 | 既存ユーザー向けの移行措置(グランドファザリング)は設けない | 実利用データ(2.1b: 稼働ユーザーはfirst_open 7件のみで依頼者本人+テスター中心)上、上限付近までCircleを使っているユーザーが実質存在しないため | 依頼者判断・GA4実測(2.1b) | 実ユーザー数が増え、5〜8人のCircleを持つ既存無料ユーザーが確認された場合、遡って移行措置を検討する |
| 2026-09-09 | 方針Bのv1スコープを「バディの過去アーカイブ閲覧」「2人分の比較ビュー/カード」の2機能に限定する | 実装スコープを一度に広げすぎないため。「リビール演出強化」は今回見送り | 依頼者判断 | v1出荷後、追加需要が確認された場合に別途着手 |
| 2026-09-09 | 方針Aは既存の1年シェアカードに加え、週次リキャップでも報酬を得られるようにする | 既存軸の弱点である「報酬が遠い」を緩和するため。年次カードは維持し置き換えない | 依頼者判断 | 実装後の購入確定率が改善せず、週次リキャップ自体が離脱要因と判明した場合 |
| 2026-09-09 | 方針A(週次リキャップ)は今回のスコープから外し、C(Circle上限差別化)・B-2(比較ビュー)のみで先に進める | Codex発注結果を検証したところAが実装されておらず記録も残っていなかったため。範囲を広げすぎず検証済みの部分から進める | 依頼者判断・Codex実装検証 | 依頼者がAの着手を改めて指示した場合 |
| 2026-09-10 | 有償クリエイター獲得を前払い型から前払いなしのレベニューシェア型に転換し、Instagramで実在確認済みの7名に打診(依頼者が最終送信済み) | 08-10確定の有償クリエイター発注(価格不透明)・$0オーガニック単独(09-08失敗判断)のいずれも機能しなかったため、第三の型を試す | 依頼者判断 | 詳細は`dev-notes/influencer-revshare-outreach_2026-09-10.md`。返信率・成立数が判断材料になり次第再評価 |
| 2026-09-09 | 上記「Aを今回スコープから外す」を撤回し、週次リキャップもCodexへ再発注する | 依頼者が直後に方針転換。動画書き出しへの発展性も合わせて検討したいため | 依頼者判断 | — |
| 2026-09-09 | 新規paywall計測イベントは追加せず、既存の`skygrid_paywall_*`系イベントのみで観測する | second-chance paywallの前例と同じ方針を踏襲 | 依頼者判断 | 新しい計測方針が明示された場合 |
| 2026-09-09 | B-1(バディの過去アーカイブ閲覧)は実装しない。バディ軸の強化はB-2(今日の比較カード)と週次リキャップのみで確定させる | 相互解禁は「今日」に紐づく設計であり、他人の過去投稿を能動的に遡る行動には閲覧トリガーが無く実利用が見込みにくい。一方的な閲覧という性質が既存の相互性の信頼設計とも噛み合わない | 依頼者判断 | 実ユーザーからB-1相当の明確な需要が確認された場合、バックログとして再検討する |
| 2026-09-10 | Circle上限を無料5人・Pro 15人から、無料5人・Pro実質無制限(内部上限100人・UI上は「無制限」と表示)に変更する | 依頼者が15という数字は不十分と再検討。無料5人は購入トリガーとして維持しつつ、Proは真の無制限ではなく乱用防止のための内部上限(100)を保つ | 依頼者判断 | 実運用でPro利用者が100人上限に到達する、または不正利用の兆候が確認された場合 |
| 2026-09-11 | 計測の読み取り経路(install cohort集計・Analyticsのテスト可能化)の整備は後回しにし、先に人を集めて招待・相互公開のループを回すことを優先する | 実ユーザーがいない現状では、読み取り経路を作っても読む対象が無いため | 依頼者判断 | ユーザー獲得が進み、施策の効果判定に実測が必要になった場合 |
| 2026-09-09 | 方針A(週次リキャップ)を将来実装する際の提示タイミングは「7回投稿ごと(ローリング週)」とする | 既存の`WeekRhythmCalculator`のローリング週ロジックと相性が良く、実際の利用ペースに合わせられるため | 依頼者判断 | 実装時に別の設計上の制約が判明した場合 |

## 6. 未解決の不明点

- Firebase Analytics のイベントを install cohort / 7日窓で読める経路、および現在の実測値。
- 新規 debug build から `first_open` と既存カスタムイベントが Firebase DebugView / Realtime report に実際に到着するか。到着後に BigQuery export を設定し、install cohort の7日集計を作る。
- 招待受諾通知の通知文面、同意状態、失敗時の再試行要件。
- buddy 数の上限を置くか。厳密に上限を置くなら、handle 経由とリンク claim の両方の作成経路をサーバーで集約する必要がある。
- 週末に欠席が集中しているか（複数アラームの投資判断）。
- second-chance専用SKUのASC作成、米国`$0.99`基準の174地域equalization、RevenueCat `second_chance` offering / `premium` entitlement接続、Webhookマッピングのデプロイ。
- second-chance提示履歴は端末内でアカウントID別に保持している。再インストール・別端末をまたぐ厳密な生涯1回制御が必要なら、intro eligibilityとは独立したサーバー側提示予約を設計する。
- 初月オファーと紹介を結合するか。結合する場合、紹介成立を受諾・初回撮影のどこで判定し、招待者と受信者へ何を付与するか。
- Pro価値訴求の再設計は、Circle上限差別化(無料5人/Pro15人)・2人分の比較ビュー・週次リキャップ(静止画版)の3機能で確定。Codexが実装し、Firebase Functionsは2026-09-09にClaude Codeがデプロイ済み(`dev-notes/pro-value-proposition-decision-record_2026-09-09.md` 14章)。iOSクライアント側(UI・paywall文言)は未ビルド・未提出で、ローカルの変更はcommitしていない。動画書き出しは8章バックログ#2として着手時期未定。バディの過去アーカイブ閲覧(B-1)は不採用決定済み。

## 8. バックログ(依頼者確定・着手時期未定)

| # | タスク | 理由 | 記録日 |
|---|---|---|---|
| 1 | **完了(2026-09-11 依頼者確認)**。`9167818` / `80cddb3`「sealed reveal-gateに視覚的な重みを与える」と、作業ツリー上のsealedタイル意匠(identity motif)で対応済み。以下は起票時の記述。Buddy画面(封印状態)の意匠改善。現状 `Friends/BuddiesView.swift` の`.sealed`表現は`lock.fill`の単色SF Symbolのみで、写真・グロー・モーションが無い。2026-09-06のダーク基調全面刷新(`443d9d0`)は配色トークンをカスケードしたが、この情報表現自体は09-05のcritical design audit時点から変化していない。 | プロダクトの唯一の差別化要素(相互解禁)であり、UXの核。マーケティングで人を呼んだ場合に新規ユーザーが最初に触れる差別化ポイントが最も安っぽいままだと、指標が測れる前に離脱リスクが上がる。依頼者も2026-09-09に必要性を明示的に確認済み。 | 2026-09-09 |
| 2 | 週次リキャップを含む各種シェアカードの動画書き出し対応 | 現状の静止画は既存の`ImageRenderer → UIImage → ShareSheet`に収まる一方、動画にはAVAssetWriter/CoreVideoのフレーム生成、進捗・キャンセル、エンコーダのback-pressure、一時ファイル寿命管理、端末別検証が新たに必要で、今回の週次リキャップ実装とは難易度差が大きいため。 | 2026-09-09 |
| 3 | 通知の棚卸しと不足分の追加。**実装済み**: ①バディ投稿通知 `onBuddyPostCreated`(「{name} caught the sky. / Yours is still sealed.」、相互公開時「Both skies are in.」、22:00〜5:00は送らない) ②招待受諾通知 `onFriendshipCreated`(「Your invite was claimed.」、デプロイ済み) ③朝のアラーム(AlarmKit、未保存なら5分ごと再鳴動) ④朝のフォローアップ(ローカル「Today's sky / Not captured yet.」) ⑤Live Activity。**不足候補**: (a) ハンドル経由のバディ申請を受け取った側への通知(pendingの作成は通知対象外) (b) `acceptBuddy` で申請が承認されたことを申請者へ知らせる通知(pending→acceptedは更新なので `onDocumentCreated` に掛からない) (c) ストリーク途切れ前のリマインド (d) 週次リキャップ完成の通知。どれを入れるかは依頼者判断。全通知文言は多言語化(#6)の対象に含める。 | 招待受諾以外の関係成立経路に通知が無く、相手の行動が本人に届かないため | 2026-09-11 |
| 4 | 効果音の音量最適化。実測(ffmpeg volumedetect): `capture_saved` / `mutual_reveal` は平均-30dB、`forward_navigation` -28dB、`recoverable_error` -27dB と小さい一方、`purchase_confirmed` -11dB・`moku_tap` -14dB と音ごとの差も大きい。ピークは既にほぼ0dBなので、単純なゲイン上げでは割れる。コンプレッサー/リミッターで音圧(ラウドネス)を揃えて上げる必要がある。加えて再生は `AudioServicesPlaySystemSound`(`DesignSystem/SoundEffects.swift`)で、音量は着信音量に従い、マナースイッチで無音になり、個別の音量制御ができない。普通に使っていて聞こえる音量にするには、音源の再マスタリングと再生方式(AVAudioPlayer + AVAudioSession `.ambient` 等)の見直しを合わせて検討する。 | ChatGPT-web + Claude Codeで実装した効果音が小さすぎて聞こえないと依頼者が報告 | 2026-09-11 |
| 5 | 先着N人(例: 100人)にPremium 1〜2か月を無料で贈る施策。演出はルーレットで「1か月無料」が当たる形など遊び心のあるものにする。未決定事項: N・期間・判定のタイミング(初回起動/初回撮影など)・先着枠のサーバー側での厳密な採番(端末側だけでは再インストールで何度でも取れる)・付与方法(App Storeのオファーコード/RevenueCatのプロモーション付与など。Apple審査上、ルーレットは「全員当たる」確定演出にしてギャンブル的表現を避ける必要があるかの確認)。既存のsecond-chance paywall・オンボーディングpaywallとの表示順の整理も要る。 | 最初から課金を迫るとアプリ自体が敬遠され、使われずに終わる可能性が高いと依頼者が判断。初期ユーザーにまず習慣と招待ループを体験させるため | 2026-09-11 |
| 6 | 英語/日本語の2言語化。**実装はChatGPT-webで行い、Claude Codeは実装しない(依頼者指示)**。(a) 英語UIに混ざった日本語の検出と英語化: 2026-09-11時点の検出結果は `Paywall/PaywallSecondChanceStepView.swift:46`「ちょっと待って！…」、`App/AppStartupController.swift:55` / `:74` のサインイン失敗メッセージの3箇所(コメント除く)。(b) 日本語版の作成: 現状 `.xcstrings` / `.lproj` が無く、`Text("...")` 直書きが約170箇所あるため、String Catalog(`Localizable.xcstrings`)の導入から必要。サーバー側の通知文言(`functions/src/buddyNotifications.ts` / `inviteNotifications.ts`)、ウィジェット/Live Activity、paywall文言、App Storeメタデータも対象。(c) 言語の自動判定: 端末の優先言語(`Locale.preferredLanguages`)が日本語なら日本語、それ以外・判定不能は英語。(d) オンボーディングに言語確認ページを1枚追加(自動判定の結果を初期選択にして「この言語でよいか」を聞き、変更可能にする)。サーバー通知を選択言語で送るには、選んだ言語をFirestoreのユーザー/端末情報に保存する必要がある。 | 英語が公式言語だが日本語が混在して不自然なため、混在を解消しつつ日本語利用者向けに正式な日本語版を用意する | 2026-09-11 |
| 7 | 古いメモリの一括整理。SkyGrid関連メモリ(プロジェクトmemory 3件、`~/agent-intelligence` 約22件、`claude-harness-migration-windows` 16件、Codex側2件)を全件洗い出し、コード・デプロイ・dev-notesと照合して「現在も正しい/実装で解消済み/方針変更で置換/確認不能」に振り分け、依頼者承認後にsupersede・retractイベントとして一括記録する(元記録は削除・書き換えしない)。既知の陳腐化例: 「バディ投稿のpush通知が無い」(8/2、現在は`onBuddyPostCreated`稼働)、「ExitOfferのオファーコード未作成」(8/1、画面ごと削除済み)。 | 古い記録が現状と矛盾し、次のセッションが誤った前提で作業する原因になるため | 2026-09-11 |

## 7. App Store release measurement — 2026-09-06

- Target metric: page-attributed first-time downloads / unique product-page viewers, aligned by date, storefront and source. Current value: **unmeasured**; do not substitute all downloads divided by page views.
- Created ongoing ASC analytics request `11e25502-8655-4a78-a377-4d2032e9a088`. Read with `asc analytics view --request-id 11e25502-8655-4a78-a377-4d2032e9a088`; report definitions exist, but no report instances are available yet.
- 1.0.5 creative bet: current UI plus one concise benefit per screenshot helps visitors understand the capture→mosaic→buddy loop. Without the change, 1.0-era screens and obsolete color-only/Pro descriptions persist.
- Cheapest check: compare a complete seven-day post-publication window with a matched prior window when reports exist; if volume is insufficient, leave the result unmeasured. Do not attribute conversion changes to creative alone because the app version changes simultaneously. Preserve the former set; revise if qualified conversion drops with adequate comparable data.
- Submission prerequisite found: current iOS handle requests/acceptance require two missing production Functions. See `dev-notes/asc-1.0.5-release_2026-09-06.md`; no global eight-person-cap claim in this release copy.
