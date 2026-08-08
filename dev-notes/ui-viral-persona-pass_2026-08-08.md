# UI/UX修正 + バイラル・ペルソナ転換 (2026-08-08)

依頼: 「UIUXの問題点や具体的な違和感を改善」+「静か・淡い色のペルソナをやめ、SNSで
バイラル的に広がる要素を持つアプリに」。作業は `/loop-engineer` で実施。
アンカーファイル: `.loop/VISION.md`(DoD)、`.loop/audit.md`(監査結果)、`.loop/state.json`。

---

## 思考ログ — なぜこの方針にしたか

### 「静か」は密度の話であって、大きさの話ではない

コードベースは静けさを**意図的に**エンコードしている(`TodayView.swift:3`「最初の5秒が
決してソーシャルフィードやダッシュボードに見えないように」、共通カードの名前が
literally `quietCard()`)。一方で依頼は真逆のペルソナを求めている。

採用した原則: **儀式は静かなまま、作品は派手に。**

- 朝6時の撮影は寝起きの人間が行う。ここを賑やかにするのは実際に敵対的。
- ただし `TodayView` は既に74〜96ptの数字を出しており、それは「うるさい」と感じられて
  いない。**1画面に1つ・判断を伴わない**からである。つまり境界は「密度」であって
  「サイズ」ではない。
- よって: **他人の目に触れるもの**(共有カード・連続記録・グリッド・バディ・節目)を
  大胆にし、密度は上げない。

この判断は Opus の `code-architect` に設計委譲し、その blueprint に沿って実装した。

---

## 発見した問題(監査の要旨。全文は `.loop/audit.md`)

### A. 実装済みなのに到達不能だった中核機能 — 最大の発見

| ID | 内容 |
|---|---|
| A1 | `StreakCalculator` は実装・単体テスト済みだが**本番の呼び出し元がゼロ**。`UserProfile.streakCurrent/.streakLongest` は 0 で初期化されたきり誰も書かず誰も表示しない。連続記録アプリに連続記録が存在しなかった |
| A2 | `TodayViewModel` は毎セッション `buddies` を計算しているのに `TodayView` が読んでいない。`BuddyRow`/`BuddyTile`/`BuddyRevealGate` は**全て死んだコード**。Firestore 読み取り課金だけ発生していた |
| A3 | 節目を祝う瞬間が存在しない(`completedCaptureCount` は既にあるのに) |

### B. 見た目の不具合

B1 年間グリッドが約10pt/セルで灰色の帯にしか見えない / B2 内部エラー文字列
`(SkyGrid.RepositoryError error 1.)` がユーザーに露出 / B3 `—:—` が74pt極細で
フォント崩れに見える / B4 アーカイブ告知がタブバーに隠れる / B5 バディ行が情報ゼロ /
B6 無効ボタンが「壊れている」ように見える / B7 **共有カードの地色が非決定的**
(`SGT.background` はトレイト連動色で、`ImageRenderer` は未固定の環境で解決するため
書き出し結果が端末の外観設定に依存していた — 本作業中に新規発見)

### C. バイラル性

C1 共有カードがクリーム色でフィードに埋もれる(サムネイル幅120pxで最大文字が約7px) /
C2 **共有できるのは年間カードのみ = 定着後でないとループが始まらない**(順序の逆転) /
C3 オンボーディングが「quiet」を売り、相互公開にも連続記録にも触れていない

---

## Gotcha(ハマりどころ) — Symptom → Cause → Fix

### 1. ストリークをFirestoreに保存しようとすると必ず失敗する
- **Symptom:** `streakCurrent` を書こうとすると permission denied。
- **Cause:** `ios/firestore.rules:89-98` が `/users/{uid}` の更新を
  `['displayName','timezone','wakeGoalMinutes']` のみに制限。コメントに
  「streak values are server-owned」。かつ計算する Cloud Function も**存在しない**
  (`functions/src/index.ts` は `deleteAccount`/`imageDownloadURL`/`revenueCatWebhook` の3つのみ)。
  つまり本番でこの値は**恒久的に 0**。
- **Fix:** 保存を諦め、**クライアント側で観測済み投稿から計算して表示するだけ**にした
  (`Streak/StreakWindow.swift`)。ルール変更もサーバー実装も不要。
- **重要な帰結:** バディの `streakCurrent` も 0 のままなので、**他人の連続記録は絶対に
  表示してはいけない**(嘘になる)。将来バディ同士で見せ合うなら Cloud Function が必須。

### 2. 自分が投稿する前は、バディの投稿を読む権限が無い
- **Symptom:** `BuddyTile` が「Mira · not yet」と表示する設計だった。
- **Cause:** `firestore.rules` がバディ投稿の read を `hasPostedFor(localDate)` で
  ゲートしている。**自分が投稿するまで全て拒否される。** 既存コードは
  `firstValue` が `.unavailable` を返すと `post = nil` → `hasPostedToday: false` と
  解釈していた。
- **Fix:** `BuddyRevealState` を `sealed` / `posted` / `notYet` の**3値**に作り直した。
  拒否・失敗は全て `sealed`(封印=不明)。`notYet` は「自分が投稿済み かつ 読み取り成功
  かつ 空」の時だけ。ついでに、必ず失敗すると分かっている読み取りを送るのを止めた。
- **教訓:** Bool 2値で「不明」を表現できない箇所は、UIが必ずどちらかを**断定**してしまう。
  相手が朝5時に投稿していても「まだ」と嘘をつくところだった。

### 3. `xcodegen` を使っているので新規 .swift はプロジェクト再生成が必要
`project.yml` の `sources: - path: SkyGrid/Sources` はディレクトリ単位なので、
新規ファイル追加後に `xcodegen generate` を実行すれば自動登録される
(pbxproj の手動編集は不要)。`.claude/` のメモリにある「pbxproj手動登録」は
別プロジェクトの話で、ここには当てはまらない。

### 4. SourceKit の編集直後 diagnostics は当てにならない
`Cannot find 'SGT' in scope` 等が大量に出るが、`xcodebuild` は 0 エラー。既知
(メモリ `sourcekit-diagnostics-not-authoritative`)。判断は必ず実ビルドで。

### 5. App Check 403 — 過去メモの論証が逆立ちしていた
- 過去メモの結論:「未登録のランダムUUIDでも403になる **から** Google側の障害」。
- **これは論証として成立しない。** 未登録トークンが403になるのは**正常動作**であり、
  障害の証拠ではない。
- 実測(2026-08-08): 登録済みトークン2つ(`c3bf4641…` / `e4e3ea9d…`、Firebase の
  debugTokens API で登録を確認済み)とも `exchangeDebugToken` で 403。
  発生から8日経過しており、Google側の単純な障害という説明は考えにくい。
- **原因は未特定のまま**とする(推測を別の推測で置き換えない)。UI作業は
  アプリ内蔵の `-SkyGridUIAudit` 擬似データモードで進められるため支障なし。
- なお Firestore の `Code=7 "Missing or insufficient permissions"` は**ルール拒否でも
  同じ文言**が出る。今回 `ensureInitialProfile` の送信内容とルールを突き合わせて
  一致を確認したので、ルール側の問題ではないことは切り分け済み。

### 6. 別の Claude Code セッションが同一リポジトリを並行編集していた
- **Symptom:** 自分が触っていない `Friends/*`・`Data/*Repository.swift`・
  `SettingsView.swift`・`LiveActivity/MorningRitualAttributes.swift` の mtime が
  自分の編集の合間に更新される。ビルドが自分の変更と無関係な箇所で壊れる。
- **Cause:** 11:14 起動の別セッションが `FriendRepository` プロトコルを移行中
  (`sendRequest` に handle 引数追加、`BlockedFriendshipCollectionObservation` 新設)。
- **対応:** 依頼者に報告し、指示に従い `Friends/` 系(B5)には触れず他を先行。
  ただし**共有プロトコルの移行中はビルド自体が不安定**になるため、こちらの変更の
  最終検証はブロックされる。
- **教訓:** 「編集ファイルを分ければ安全」は不十分。**型・プロトコルの共有**が
  あればビルドは同一運命共同体になる。

---

## 実施した変更

| # | 内容 | 主なファイル | 検証 |
|---|---|---|---|
| 1 | エクスポート専用トークン `SGExport`(固定の暗色地 `#0B0E14`)+ `SGFont.display`/`fixedDisplay` + `IdentityColor` + `SkyLoudButtonStyle` | `DesignSystem/ExportTheme.swift` ほか | ビルド |
| 2 | **B2** `RepositoryError: LocalizedError` 化 + `StartupFailureMessage` 新設で内部文字列の露出経路を遮断 | `Data/RepositoryError.swift`, `App/StartupFailureMessage.swift`, `AppStartupView.swift` | ビルド |
| 3 | **B6** 無効ボタンを「枠線のみの未入力状態」に | `DesignSystem/ViewModifiers.swift` | ビルド |
| 4 | **A1+B3** ストリークを本番接続。既存リスナーの観測窓を7日→120日に拡張(**リスナーは増やさない**)し、週表示と連続記録を同一ストリームで賄う。`—:—` を連続日数のヒーロー数字に置換 | `Streak/StreakWindow.swift`, `TodayViewModel.swift`, `TodayView.swift` | **スクショ目視OK** |
| 5 | **A2** バディ相互公開をホームに接続。3値state化 + 拒否確定の読み取りを停止 | `TodayViewModel.swift`, `BuddyTile.swift`, `BuddyRow.swift`, `TodayView.swift` | **スクショ目視OK** |
| 6 | ヒーロー数字のコントラスト回帰を修正(グラデ下端のクリーム色に白文字が乗っていた)。既存の撮影済みカードと同じ scrim 方式に統一 | `TodayView.swift` | **スクショ目視OK** |
| 7 | **B1** 年間グリッドを正方形ブロック化(1セル約10pt→約29pt)+ 月ごとの帯 + spacing 1。月末以降の「白い四角のバグに見える部分」がカレンダーの形として読めるように | `Grid/GridCanvas.swift`, `Grid/SkyGridView.swift` | **スクショ目視OK** |
| 8 | **B4** `.padding(.bottom,128)` → `.safeAreaInset(edge:.bottom)`。padding は内容と一緒にスクロールするため停止位置がタブバー下に潜っていた | `Grid/SkyGridView.swift` | **スクショ目視OK** |
| 9 | **C1+B7** 年間共有カードを暗色地に再設計。ヒーローを300pt `.black` の「N mornings」に(過去年でも常に真である事実。current streak は過去年カードでは無意味) | `Grid/SkyGridExportView.swift` | **スクショ目視OK** |
| 10 | **C2** 初日から共有できる1朝分カード `MorningCardExportView` 新設 + `ShareCardRenderer.renderMorning` | `Grid/MorningCardExportView.swift`, `ShareCardRenderer.swift` | **スクショ目視OK** |

### 意図的に変更していないもの
`SGT` の全色・明朝見出し・`body`/`caption`/`numeric`・`SGSpacing`・`SGMotion`・
`quietCard()`。静かな系は儀式にとって正しいので、塗り替えていない。

### `SGExport` の境界ルール(重要)
`SGExport` は `Grid/*ExportView.swift` / `ShareCardRenderer.swift` / `Milestone/*`
からのみ参照してよい。これが「儀式は静か・作品は派手」を**grep で機械的に検証できる形**
にしたもの。Today/Camera 画面に漏れたらルール違反。

---

## 未完了 / 次にやること

1. ~~項目9・10の目視検証。~~ **完了。**
2. ~~**A3 節目演出**~~ **完了(2026-08-08 午後)。** → 下の「A3 節目演出」節を参照。
3. **B5 バディ行**(`BuddiesView`)。**並行セッションが同ファイルを大幅改修済み**
   (バディシステム全体の作り直し。下の「並行セッションからの引き継ぎ」を参照)。
   着手前に相手の変更内容を読むこと。実装時は gotcha 2 の通り、状態(投稿済み等)は
   出せない。出せるのは identity(`IdentityColor` の色ディスク + handle)だけ。
4. Today の共有ボタン(撮影済みカード右上)から `renderMorning` を呼ぶ導線。
5. ~~`VISION.md §6` の更新。~~ **完了。** §6 に「改訂(2026-08-08)」節を追加し、
   静けさが**儀式に対する掟であってアプリ全体の掟ではない**と範囲を限定した上で、
   解禁したもの(streak の主役サイズ表示 / `SGExport` / 節目の全画面演出 +
   成功ハプティック1回)と**禁止のまま残すもの**(ランキング・レベル・バッジ・
   コイン・マスコット・ポイント報酬、カメラ/今日画面を騒がしくすること)を
   書き分けた。`Haptics.swift` のヘッダは前回作業時に改訂済み。
6. ~~テスト~~ **完了。** `StreakMilestoneTests`(8ケース)/
   `PostCaptureMomentPolicyTests`(14ケース)。

---

## A3 節目演出 — 実装記録(2026-08-08 午後)

### 中心にあった設計問題: 節目はどうやって streak を知るのか

閾値は streak だが、調停が走る `RootView` は streak を知らない。streak を計算して
いるのは `TodayViewModel` の履歴リスナーで、しかも**撮影確定より後に非同期で届く**。
一方 `RootView` は `TodayViewModel` への参照を持たない(`TodayView` が `@State` で
抱えている)。

**却下した案と、その理由:**

- **`LocalDefaults` に連続日数カウンタを置く** — `StreakCalculator` の並行実装に
  なる。休息日・再インストール・複数端末でTodayの表示と食い違う。
  「UIが自分で導出していない値を断定する」型の不具合そのもの。
- **`RootView` が履歴を読み直して `StreakCalculator` を自分で呼ぶ** — 同じ純粋関数
  でも**別スナップショット**なので、Todayが7と出している朝に6と出しうる。
  `StreakWindow` の窓拡大ロジックも二重実装になる。
- **`considerAutomaticPaywall` の中で streak を待つ** — ペイウォールの判断が
  ネットワーク待ちに依存する。凍結対象の経路なので論外。
- **`TodayViewModel` の所有権を `RootView` に引き上げる** — OO的には最も綺麗だが、
  タブ切り替え時のリスナー生存期間(= Firestore読み取りコスト)が変わる。
  派生値1つのために挙動を変える取引としては割に合わない。

**採用: 算出しているその行から、post ごと上に publish する。**
`TodayViewModel.swift` の `self.streak = StreakCalculator.summarize(...)` の直後で
`StreakSignal.record(.observed(localDate:summary:post:))` を呼ぶ。streak と post を
**同じスナップショットから**一緒に運ぶので、カードの数字とTodayの数字は「一致する
はず」ではなく定義上同一。計算器は増えず、Firestore読み取りも増えない。

### 調停順「ペイウォール > 節目 > レビュー依頼」をどう保証したか

`PostCaptureMomentPolicy.decide` は**ペイウォールの判定結果を `Bool` で受け取るだけ**で、
entitlement / snooze / 日付といった入力を一切持たない。つまり**構造的にペイウォールの
発火条件を変えられない**。`considerAutomaticPaywall` 側は述語もその引数も無変更で、
変えたのは2つの出口だけ:

- ペイウォールが出る枝 → `postCaptureArming = nil`(下位はこの撮影を主張できない)
- 出ない枝 → 従来の即時 `considerAppReviewPrompt` を `armPostCaptureMoment` に置換

節目は**ペイウォールが辞退した枝でしか arm されない**。arm は `shouldPresent` が
返った後にしか起きないので、どの順序で割り込んでも順序が崩れない。

### 受け入れた失敗モード(依頼者判断が要る点)

**ペイウォールと同じ撮影に当たった節目は恒久的に捨てられる**(その閾値は二度と
発火せず、次の閾値まで飛ぶ)。ペイウォールの条件に一切触れないための代償。
なお**day 1 は構造的に無傷** — `AutomaticPaywallPresentationPolicy.minimumCompletedCaptures = 3`
なので1回目の撮影をペイウォールが取ることはありえない。
→ 嫌なら「ペイウォールの後ろに節目を待たせる」案がある(ペイウォールの発火条件は
変わらず、閉じた後の挙動だけ変わる)。全画面が2枚続くのでUX判断。**未実装。**

### 多重発火を止めている3つのガード

1. arm は1撮影につき1つ、解決時に必ず消費される
2. `LocalDefaults.lastCelebratedStreakMilestone` を**提示の前に**書く
   (再入・提示中クラッシュでも二度出ない)
3. `StreakSignal.record` は同値なら no-op(リスナーの再送で `onChange` が
   再発火しない)

### 「嘘をつかない」ための分岐

- `.unavailable`(読み取り失敗)を**明示的に publish** する。握りつぶすと
  「streak不明」と「streak無し」が区別できず、失敗した読み取りを祝ってしまう。
  → 失敗時は節目には絶対に進まず、レビュー依頼/何もしない に落ちる。
- `summary.hasPostedToday == false` の読み取りは保留する。`StreakCalculator` は
  その日が終わるまで**昨日の数**を生かし続ける猶予仕様なので、投稿が着地する前の
  読み取りは「今朝」の話ではない。
- 窓が拡大中(`needsWidening`)の間は publish しない。次の広い窓が上方修正しうる
  数で祝ってしまうため。

### 目視検証

`-SkyGridUIAudit -SkyGridUIAuditScenario milestone` / `milestone-day-one` を追加。
後者は**わざと `photo: nil`** にして、写真が無いとき空色へ退化する経路も目視できる
ようにしてある。両方スクショ確認済み。

`MilestoneView` のヒーローは **実物の `MorningCardExportView` を 1080×1920 のまま
縮小表示**している(`ShareCardAuditView` と同じ手法)。プレビューが共有物の近似では
なく**共有物そのもの**になる。

### ついでに直したもの

`SGExport.cellEmpty` を 0.06 → 0.09。サムネイル縮小時に空セルが消えて格子が
読めなくなっていた(スクショで確認)。

---

## Gotcha 7: `ContentUnavailableView` の文言は XCUITest から一切引けない

**Symptom.** A3実装後のフルスイートで `testMissingFirebaseConfigurationIsExplained`
が新規失敗。`app.staticTexts["Sky Grid needs setup"]` が見つからない。

**最初の(誤った)診断.** 「B2修正で文言が
`StartupFailureMessage` 経由になり `"Sky Grid isn't configured."` に変わったから、
テストが古い文言を握っているだけ」。→ **新文言に直しても失敗した。**

**2番目の(誤った)診断.** 「アポストロフィが typographic に変換されている」。
→ **反証。** アポストロフィを含まない説明文
`"This build is missing its Firebase configuration file."` も同様に見つからない。

**実際の Cause.** `ContentUnavailableView` は title / description を
**個別にアドレス可能なアクセシビリティ要素として公開しない**。同じ画面の
`Try again` ボタンは `app.buttons[...]` で引けるので、「画面に到達していない」
のではなく「その2つのテキストだけが引けない」。スクショでは文言は確実に見えている
(`-SkyGridForceFirebaseUnconfigured` で起動して目視確認済み)。

**なぜ以前は通っていたのか(重要).** 旧アサーションの文字列が、たまたま別の場所で
公開されていたラベルと同一だったため一致していた。つまり**このテストは最初から
意図した対象を検証していなかった** — 文言を変えた瞬間に露見しただけ。

**Fix.**
1. 本番の a11y 構造はテストのために歪めない(`.accessibilityElement(children: .combine)`
   を一度入れたが、`Try again` ボタンごと1要素に潰して既存アサーションを壊すので撤回)。
2. 本来守りたかったもの = 「内部エラー文字列がユーザーに漏れない」は純粋関数で
   検証できるので、`Tests/StartupFailureMessageTests.swift` に移した
   (`SkyGrid.` / `RepositoryError` / `error 1` 等を含まないことを全ケースで表明)。
3. UITest は実際に観測可能なもの(失敗画面に到達し `Try again` が押下可能)だけを
   表明し、**なぜ文言を検証しないのか**をコメントで固定した。放置すると次の
   エージェントが「文言チェックが無い」と善意で再追加して同じ罠を踏む。

**教訓.** UIテストが落ちたとき、まず「テストが古い」と決めつけない。
`app.staticTexts` で引けないことと、画面に出ていないことは別の事実。
スクショで実物を見るまでは、どちらかを断定してはいけない。

---

## 独立レビューで指摘され、対応したもの(2026-08-08)

`swift-reviewer` を作成者以外のゲートとして実行し、**Block** 判定を受けて対応した。

**HIGH 1 — `SGExport` の境界ルール違反(実際に違反していた)。**
`SkyLoudButtonStyle` が `DesignSystem/ViewModifiers.swift` にあり、そこから
`SGExport` を参照していた。共有デザインシステム上にあるということは
Today/Camera からも `.buttonStyle(SkyLoudButtonStyle())` と書けてしまうということで、
**このルールが塞ごうとしていた扉そのもの**。利用者が `MilestoneView` の1箇所だけ
だったので `Sources/Milestone/MilestoneLoudButtonStyle.swift` へ移動した。
`ExportTheme.swift` のルール本文に検査コマンドを埋めたので、次回は
`grep -rn 'SGExport\.' Sources/ | grep -v ': *//'` で機械的に判定できる。
(なお `Grid/GridCanvas.swift` と `DesignSystem/Haptics.swift` の `SGExport` 参照は
**コメント内の言及のみ**で違反ではない。grep するときは注意。)

**HIGH 2 — 節目演出にUIテストが無かった。** 監査シナリオ(`milestone` /
`milestone-day-one`)は追加したのに、それを起動して表明するテストを書いていなかった。
`testMilestoneMomentOffersTheShareableCard` と
`testDayOneMilestoneRendersWithoutAPhoto` を追加。後者は**写真なしで空色に退化する
経路**という、ユニットテストからは見えない部分を守る。

**MEDIUM — 手動でペイウォールを開くと節目が取りこぼされる(実バグ)。** 撮影後
arm された状態でユーザーが自分でペイウォールを開くと、`resolvePostCaptureMoment` は
保留し、`StreakSignal.record` は同値 no-op なので `onChange` も二度と鳴らない。
= 誰も再度尋ねないまま消える。ペイウォールの `.sheet` に `onDismiss` を追加して
解決。**ただし回復するのは素早く閉じた場合のみ**で、`armingLifetime`(10秒)を
超えるペイウォール滞在では期限切れになる。これは意図通り(購入フローを1分触った後に
祝祭が出てきても「撮影の結果」には見えない)。

**MEDIUM — `didPresentPaywall` は本番では常に `false`** という指摘は事実。
本番では「ペイウォールが撮影を取った時点で arm 自体を消す」ことで優先順位を
担保しており、フラグより強い。ただし分岐が死んでいるように見えるのは確かなので、
**なぜ残すのか**(優先順位をここで宣言しテストで守るため)をコメントに明記した。

**MEDIUM — メインアクタ上の同期ディスクI/O。** 同期のまま維持したが、
**最初に書いた理由付けは間違っていた**ので記録しておく(再レビューで指摘され、
コードを追って確認した)。

私は当初「ここを async にすると判定と書き込みの間に再入の窓が開く」と書いたが、
実際の順序は `lastCelebratedStreakMilestone` の書き込み → `postCaptureArming = nil`
→ **その後に** `localPhoto` 呼び出し。つまり `await` が入るとしても**両ガードの後**で、
並行呼び出しは `resolvePostCaptureMoment` 冒頭の
`guard let arming = postCaptureArming` で弾かれる。→ **async にしても安全**。
同期のままにしているのは単に「1インストールあたり数回・小さなJPEG1枚に非同期化は
割に合わない」という簡潔さの理由だけ。コメントもこの通りに修正した。

**教訓**: 存在しない因果を説明するコメントは、無いより有害。「なぜ安全か」を書くときは
実際の実行順序を追ってから書く。

**LOW — 日付跨ぎで arm が宙に浮く**件は、10秒で自然に期限切れになり誤った祝祭は
起きないため許容。

---

## 方針転換: ペイウォールより節目を優先し、ペイウォールは翌日に回す(2026-08-08、依頼者決定)

**それまでの掟「ペイウォールの発火条件を1ビットも変えない」は依頼者の判断で撤回された。**
節目とペイウォールが同じ撮影に当たった場合、**その日は節目を出し、ペイウォールは
次の撮影に回す。**

### 難所は前回と同じ構造だった

ペイウォールの適格判定は**撮影確定時＝streak が判る前**に走る。だから「節目なら
ペイウォールを遅らせる」を判定時点では決められない。

**採用: 判定を遅らせるのではなく、判定結果を arm に載せて解決時に選ぶ。**
`AutomaticPaywallPresentationPolicy.shouldPresent` の**述語も引数も一切変えず**、
その真偽を `PostCaptureArming.isPaywallEligible` として持ち回る。実際に出すかどうかは
streak 到着後に `PostCaptureMomentPolicy.decide` が決める。
`decide` は「ペイウォールが妥当か」を判断する入力を**構造的に持たない**まま、
「今日出すか」だけを決める。

### 「翌日に回す」に新しい永続状態は要らなかった(重要)

`AutomaticPaywallPresentationPolicy` は既に
「前回提示から N 撮影 or N 日」で門番をしている。したがって**繰り延べ = 出さない、
かつ提示として記録しない**だけでよい。記録しなければ次の撮影で同じ条件が再び真になる。

- 新しい `LocalDefaults` キーはゼロ。
- 永続状態が無い＝**繰り延べが詰まってペイウォールが永久に出なくなる状態が作れない**。
- 提示の記録(`recordAutomaticPaywallPresentationIfNeeded`)は実際に出した経路でのみ走る。

### 潰した穴: 読み取りが来ないとペイウォールが永久に出ない

解決のきっかけはカメラ dismiss と streak 到着の2つしかない。履歴リスナーが
そもそも張られていない場合、**どちらも来ない**ので arm が宙に浮き、
本来出るはずのペイウォールが黙って消える(収益上のリグレッション)。
→ `armPostCaptureMoment` で **1発限りのバックストップ Task** を張り、
`armingLifetime + 0.5秒` 後にもう一度 `resolvePostCaptureMoment()` を呼ぶ。
期限切れ後の `decide` は streak を待つのをやめ、適格なら `.paywall` を返す。
これは「提示を遅らせるタイマー」ではない(その頃カメラはとうに閉じており、
`resolvePostCaptureMoment` は他モーダルが出ていないことを引き続きガードする)。
arm を消費する全経路を `consumePostCaptureArming()` に集約し、そこで Task も破棄する。

なお**オフラインはタイムアウト経路に落ちない** — リスナーは `.unavailable` を即座に
publish するので、`decide` はそれを読んで「節目は主張できないがペイウォールは妥当」と
判断して即座に出す。タイムアウトは「リスナー未接続」という病的ケース専用。

### 併せて削除できたもの

`pendingAutomaticPaywall` と `presentPendingAutomaticPaywallIfNeeded` は不要になった。
提示経路が `resolvePostCaptureMoment` の1本に統合されたため。

### 反転させたテスト

`paywallWinsWithNoReading` / `paywallOutranksMilestone` は**新方針と正面から矛盾する**
ので削除し、以下に置換した:
`milestoneOutranksEligiblePaywall`(節目が勝つ) /
`paywallFiresWithoutAMilestone`(平常日は従来通り出る) /
`eligiblePaywallWaitsForTheStreak`(判断前に先回りしない) /
`staleArmingStillPresentsThePaywall`(バックストップ) /
`unavailableDoesNotDeferThePaywall`(証明できない日に繰り延べない)。

## テストのベースライン(重要)
本作業**開始前**の測定値: **144 passed / 4 failed / 5 skipped**(272.9s)。
4件の失敗は変更前から存在する。3件は `signal kill`(長時間UITest実行時の
シミュレータ不安定)、1件は `testGridReadFailureNeverMasqueradesAsAnEmptyArchive` が
App Check 403 のせいで audit 画面でなく起動失敗画面に着地したもの。
したがって合格基準は「全緑」ではなく「**このベースラインから新規失敗を増やさない**」。

## リスク / 依頼者判断が必要な項目
- **R1 rest day(休息日)は未実装のまま。** `RestDayPolicy` は呼び出し元ゼロ、
  `TimeZonePolicy.exemptDays` に必要な変更ログの生成元(`TimeZoneWatcher`)が
  そもそも存在しない。有効化するには「どこに永続化するか」(クライアントから書ける
  フィールドが無い)と「無料/Proの差にするか」(=課金設計に触れる)の決定が要る。
  今回は `exemptDays: []` で出荷。
- **R2 読み取りコスト増。** Today の投稿リスナーが 7 → 120 ドキュメント。ただし
  `GridArchiveView` は既に365ドキュメントのリスナーを貼っており、それより安い。
  一方で gotcha 2 の対応により**撮影前の無駄なバディ読み取りは削減**された。
- **R3 App Store のスクショが実機と乖離。** Today のヒーローが変わったため。
  次回のビルド提出(サブタイトル変更の件)とまとめて差し替えるのが効率的。
