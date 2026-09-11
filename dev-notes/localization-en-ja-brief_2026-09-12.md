# Sky Grid 英語/日本語 2言語化 — ChatGPT-web 発注書(2026-09-12)

この文書は ChatGPT-web(local MCP でこのリポジトリを直接読み書きする)への発注書である。
実装は ChatGPT-web が行い、Claude Code は実装しない(依頼者指示)。Claude Code の役割は、
この発注書の作成、戻ってきた結果の検証(差分確認・ビルド・テスト・シミュレータでの表示確認)、
および報告に限る。

- リポジトリ: `/Users/taku8/Desktop/SkyGrid`
- 作業ブランチ: `feat/localization-en-ja`(`release/1.0.5-store-assets` から分岐。作成済み)
- 基準コミット: `c2f5af3`

---

## 0. 依頼者が決めた仕様(変更禁止)

| # | 項目 | 決定 |
|---|---|---|
| 1 | 切替方式 | **アプリ内で即時切替**。言語を選んだ瞬間に画面の文言が切り替わる。アプリ再起動を要求しない |
| 2 | 自動判定 | 端末の優先言語が日本語なら日本語、それ以外・判別不能は英語 |
| 3 | 言語確認ページ | オンボーディングの**最初の1枚目**に置く。案内役は Moku |
| 4 | 表示条件 | 端末の言語が日本語でも英語でもない利用者には**必ず**表示する |
| 5 | 次ページ | 言語ページの次(既存 Welcome)で Moku が「自己紹介が遅れたけど、Moku っていうんだ！」と名乗る |
| 6 | 口調 | **全体をカジュアル**(タメ口寄り) |
| 7 | 用語 | **カタカナ中心**(下の用語集に従う) |

### 0.1 仕様4と5の整合について(Claude Code の判断・2026-09-12)

仕様4を文字どおり「日本語・英語の端末には出さない」と実装すると、大多数の利用者が言語ページを
飛ばし、仕様5の「自己紹介が遅れたけど」というセリフが意味不明になる。依頼者は就寝中で確認できない
ため、両方を満たす次の形に確定した。**言語ページは全員に出す。ただし中身を2種類に分ける。**

- 端末が日本語または英語: **確認**として出す。判定結果があらかじめ選ばれた状態で、そのまま
  「これでいい」で進める。もう一方の言語も同じ画面で選べる。
  (依頼者の当初要望「自動選択の場合はこちらで良かったか聞く」に対応)
- それ以外の言語: **選択**として出す。あらかじめ選ばれた状態にはせず、どちらかを選ぶまで
  先へ進めない。(仕様4の「必ず表示」に対応)

どちらの経路でも言語ページを通るので、仕様5のセリフが全員に対して成立する。
**撤回条件**: 依頼者が「日本語・英語の端末には一切出さない」と明示した場合。その場合は
Welcome のセリフを、言語ページを見た人向けと見ていない人向けの2種類に分ける必要がある。

### 0.2 既存利用者の扱い(Claude Code の判断)

オンボーディング済みの既存利用者には言語ページを出さない。自動判定を適用し、設定画面から
変更できるようにする。理由: 既存利用者はオンボーディングを再生しない設計であり、そのためだけに
再生フローを作るのは範囲が広がりすぎる。

---

## 3. 用語集(全画面で統一。逸脱禁止)

| 英語 | 日本語 | 補足 |
|---|---|---|
| Sky Grid | Sky Grid | アプリ名は訳さない |
| Moku | Moku | 相棒キャラクター名。訳さない |
| Buddy / Buddies | バディ | 「友だち」にしない |
| Circle | サークル | バディの人数枠 |
| Sealed | 封印中 | |
| Reveal / Revealed | 解禁 / 解禁済み | |
| Mutual reveal | 相互解禁 | このアプリの中心概念 |
| Streak | 連続記録 | |
| Capture (動詞) | 撮る / 撮影する | |
| Capture (名詞) | 撮影 | |
| Sky | 空 | |
| Grid / Mosaic | グリッド | |
| Share card | シェアカード | |
| Weekly recap | ウィークリーリキャップ | |
| Invite link | 招待リンク | |
| Handle | ハンドル | |
| Photo Mission | フォトミッション | アラームの再鳴動 |
| Pro | Pro | 訳さない |
| Onboarding | オンボーディング | |

### 3.1 口調の運用

全体をカジュアル(タメ口寄り)にする。ただし次の箇所は、カジュアルさより正確さを優先する。
誤解が実害(金銭・データ消失)につながるためである。

- 課金の金額、更新条件、解約方法、無料期間の終了(`Paywall/` 配下)
- アカウント削除、サインアウト、データの扱い(`Settings/`)
- 権限(カメラ・通知)の説明文

---

## 1. 第1弾: 仕組みだけ(翻訳の中身はまだ入れない)

第1弾の完了条件は「**英語表示が今までどおりで、日本語に切り替える土台が動く**」ことである。
全文翻訳は第2弾で行う。第1弾では、日本語訳が未整備の文言は英語のまま表示されてよい。

### 1.1 やること

1. **String Catalog の導入**
   - `ios/SkyGrid/Resources/Localizable.xcstrings` を新規作成する。
   - `ios/project.yml` は XcodeGen の入力であり、こちらが真の定義である。`SkyGrid/Resources` は
     既に `buildPhase: resources` として登録済みなので、ファイルを置けば取り込まれるはずだが、
     **必ずビルド成果物に `ja.lproj` が生成されることを確認すること**。
   - `ios/SkyGrid.xcodeproj/project.pbxproj` の `knownRegions` は現在 `Base, en` のみ。`ja` を
     追加する必要がある。pbxproj を直接編集するのではなく、`project.yml` 側で表現し
     `xcodegen generate`(`/opt/homebrew/bin/xcodegen`、`ios/` で実行)で再生成する。
     生成後の pbxproj もコミット対象である(このリポジトリは pbxproj も追跡している)。
   - 対象は `SkyGrid` アプリターゲット。`SkyGridWidgets` は 1.5 を参照。

2. **言語の保存と自動判定**
   - 新規に `ios/SkyGrid/Sources/Localization/` を作り、選択言語の保存・読み出し・判定を担う型を置く。
   - 保存先は既存の `Persistence/LocalDefaults.swift` の作法に合わせる(既存の書き方を読んでから決めること)。
   - 判定: `Locale.preferredLanguages` の先頭が `ja` なら日本語、それ以外・判別不能は英語。
   - 保存値は `en` / `ja` の2値と、「未選択」を区別できる形にする(既存利用者への自動適用と、
     オンボーディングでの明示選択を区別するため)。

3. **即時切替**
   - 選択した瞬間に、表示中の画面を含むアプリ全体の文言が切り替わること。再起動を要求しない。
   - SwiftUI の `Text("...")` は既定では `Bundle.main` の優先ローカライズを見るため、
     `.environment(\.locale)` を差し替えるだけでは切り替わらない。実現方法は実装者の判断に任せるが、
     **採用した方法と、その方法で切り替わらない箇所(あれば)を必ず記録に残すこと**。
   - 非 View コード(`String(localized:)` 等)からの参照も同じ言語に従うこと。

4. **オンボーディングに言語ページを追加**
   - `ios/SkyGrid/Sources/Onboarding/OnboardingCoordinatorView.swift` の `OnboardingStep` に
     新しい step を**先頭**(`welcome` の前)に追加する。`next` / `back` の遷移表、および
     ページ見出しの `switch` も併せて更新する(いずれも同ファイル内)。
   - 表示内容は 0.1 の2種類。Moku が案内する。既存ページの Moku の出し方
     (`MokuView(state: .ready, ...)`、237行目付近)に合わせること。
   - 既存の `WelcomeView.swift` の Moku のセリフを、仕様5に沿って「自己紹介が遅れたけど、
     Moku っていうんだ！」系に差し替える。現在は `"Meet Moku, your little morning companion."`
     (16行目)と、タップ時の `"Hi! I'm Moku."`(130行目)がある。**英語版のセリフも
     同じ意味に揃えること**(英語が正式言語であり、英語側が置き去りになってはならない)。
   - 既存利用者には表示しない(0.2)。

5. **設定画面から変更できるようにする**
   - `ios/SkyGrid/Sources/Settings/SettingsView.swift` に言語の項目を追加する。
     既存の行の作法(セクション構成、タップ領域、アクセシビリティ)に合わせること。

6. **混在している日本語の英語化**
   - `ios/SkyGrid/Sources/Paywall/PaywallSecondChanceStepView.swift:46`
     「ちょっと待って！\n最初の1か月を\n試してみない？」
   - `ios/SkyGrid/Sources/App/AppStartupController.swift:55`「新しいアカウントを準備できませんでした。…」
   - `ios/SkyGrid/Sources/App/AppStartupController.swift:74`「Apple へのサインインを完了できませんでした。…」
   - これらは英語を正とし、日本語は String Catalog の `ja` 側に移す。英語の文面は、
     second-chance については既存 paywall の口調に合わせること(`Paywall/` の他ファイル参照)。

7. **ローカル通知の言語追従**
   - 朝のアラームとフォローアップ通知は、予約時点の文言が OS 側に残る。
     言語を変更したら、予約済みの通知を選択言語で組み直すこと。
   - 対象: `ios/SkyGrid/Sources/Notifications/MorningAlarmScheduler.swift`(821行目付近)、
     `MorningFollowUpScheduler.swift`(99行目付近)。
   - 既存の再同期の仕組み(起動時に保存集合をそのまま再同期する設計)を壊さないこと。

### 1.5 ウィジェットと Live Activity の扱い(第1弾では対象外)

`SkyGridWidgets` は別バンドルの App Extension であり、アプリ内の選択を共有するには App Group が要る。
App Group の追加は entitlements とプロビジョニングの変更を伴い、リリース直前に触るには危険が大きい。
**当面、ウィジェットと Live Activity は端末の言語に従う**。アプリ内で別言語を選んだ場合に
表示がずれるのは既知の制約として受け入れる。App Group の導入は別タスクとする。

### 1.6 やってはいけないこと

- 新しい Analytics イベントを追加しない。既存の `skygrid_onboarding_step_viewed` に新しい step 値が
  増えるだけにとどめる(PRODUCT-MODEL.md §5 の既存方針)。
- 価格、商品構成、paywall の出し分け条件を変更しない。
- `GoogleService-Info.plist`、`Secrets.xcconfig`、entitlements、`firebase.json` を変更しない。
- 既存のテストを、通すために書き換えない。仕様変更でテストが実態と合わなくなった場合は、
  何をなぜ変えたかを記録に残すこと。
- サーバー(`ios/functions/`)は第1弾では触らない。

### 1.7 第1弾の完了条件

1. `cd ios && xcodegen generate` が成功し、生成された pbxproj に `ja` が含まれる。
2. `cd ios && xcodebuild test -project SkyGrid.xcodeproj -scheme SkyGrid -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkyGridTests` が成功する(現状 336 件が通っている。減らさないこと)。
3. シミュレータで次を確認し、スクリーンショットまたは手順を記録する。
   - 端末言語が英語: オンボーディング1枚目に確認形の言語ページが出る。英語が選ばれている。
   - 端末言語が日本語: 同ページで日本語が選ばれている。
   - 端末言語がそれ以外(例: フランス語): 選択形で出る。選ぶまで進めない。
   - 言語を切り替えると、その場で画面の文言が切り替わる。
   - アプリを再起動しても選択が保持されている。
   - 設定画面から変更できる。
4. 画面に出る文言の中に、英語表示時の日本語混在が残っていない。
   確認コマンド(0件になること):
   `rg -n --pcre2 '^(?!\s*//).*"[^"]*[\x{3041}-\x{3096}\x{30A1}-\x{30FA}\x{4E00}-\x{9FFF}][^"]*"' ios/SkyGrid/Sources ios/SkyGridWidgets -g '*.swift'`
   (String Catalog の `ja` 側に入った日本語はこの対象外。`.xcstrings` は JSON なので上のコマンドには掛からない)
5. 実装の要点(特に即時切替の実現方法と、その限界)を
   `dev-notes/localization-en-ja-stage1_<日付>.md` に記録する。

---

## 2. 第2弾: 翻訳の中身

第1弾が Claude Code の検証を通ってから着手する。

### 2.1 対象

1. **アプリ内の全文言**: 画面に出る文字列は 47 ファイル・約 343 行ある(下のコマンドで再確認できる)。
   `rg -c --pcre2 'Text\(\s*"|Label\(\s*"|Button\(\s*"|\.accessibility(Label|Hint)\(\s*"|\.navigationTitle\(\s*"' ios/SkyGrid/Sources ios/SkyGridWidgets -g '*.swift'`
   文言が多い順: `Friends/BuddiesView.swift`(30)、`Settings/SettingsView.swift`(26)、
   `Today/TodayView.swift`(23)、`Notifications/MorningAlarmSettingsView.swift`(19)、
   `Grid/SkyGridView.swift`(17)。
   VoiceOver 用の `accessibilityLabel` / `accessibilityHint` も**必ず**訳す。読み上げだけ英語になるのは不可。
2. **Moku のセリフ**: `Today/MokuAmbientMessage.swift`(19件)、`Milestone/StreakMilestone.swift`(12件)。
   キャラクターの声なので、直訳せず日本語として自然なタメ口にする。
3. **権限の説明文**: `ios/SkyGrid/Config/Info.plist` の `NSAlarmKitUsageDescription` と、
   `ios/project.yml` の `INFOPLIST_KEY_NSCameraUsageDescription`。
   `InfoPlist.xcstrings` を追加して訳す。審査で読まれる文面なので、ここは丁寧語でよい。
4. **サーバーから送る通知**: `ios/functions/src/buddyNotifications.ts`(85-86行目)、
   `ios/functions/src/inviteNotifications.ts`(44-49行目)。
   - 送信先の言語を知る必要がある。端末登録 `users/{uid}/devices/{tokenId}` に `language` を
     追加する(`ios/SkyGrid/Sources/Data/Firebase/FirebaseDeviceRegistrar.swift`、49行目付近)。
   - `ios/firestore.rules:226-234` は現在キーを `fcmToken` / `updatedAt` / `platform` に限定している。
     `language` を許可し、値を `'en'` / `'ja'` に制限する。
   - `ios/rules-tests/` のルールテストと `ios/functions/test/` を更新する。
     現在サーバー側テストは 80 件通っている。減らさないこと。
   - 端末ごとに言語が違う場合がありうるので、端末単位で文面を出し分けること。
     言語未設定の端末は英語にする。
5. **App Store の説明文**: `metadata/` 配下に日本語版の下書きを作る。
   **App Store Connect への登録は依頼者本人の作業**であり、ChatGPT-web は行わない。

### 2.2 第2弾の完了条件

1. 第1弾の完了条件がすべて維持されている。
2. 日本語に切り替えた状態で、主要画面(Today / Buddies / カメラ / グリッド / 設定 /
   アラーム設定 / 課金 / オンボーディング全ページ)に英語が残っていない。
3. サーバー側テストが通る(`cd ios/functions && npm test`)。
4. ルールテストが通る。
5. 文字あふれ・改行崩れがないこと。日本語は英語より行が長くなりやすい。
   特に `PaywallPlanStepView`、`WeeklyRecapView`、シェアカード
   (`Grid/ShareCardRenderer.swift`、`Grid/*ExportView.swift`)を確認する。
   シェアカードは画像として書き出されるため、はみ出すと外から見えてしまう。
6. 記録を `dev-notes/localization-en-ja-stage2_<日付>.md` に残す。

---

## 4. 検証の分担

ChatGPT-web は上の完了条件を自分で確認してから引き渡す。そのうえで Claude Code が、
差分の確認、ビルド、テスト、シミュレータでの英語/日本語表示、既存機能の非破壊を独立に検証し、
依頼者へ報告する。ChatGPT-web の自己申告は、検証されるまで未確認として扱う。
