# VISION.md 残タスク一括処理セッション(2026-08-02、審査提出後)

## 背景

VISION.mdの「現在の残タスク」14項目について、依頼者から一括で状況確認・回答を得た上で、
自律的に処理可能なものから着手した。以下は各項目の実施内容と、途中で見つかったgotcha。

## 1. Git コミット整理(残タスク#6)

**症状:** `ios/`配下に複数セッション分の未コミット変更(70+ファイル)が積み重なっていた。

**対応:** 機能単位で8コミットに分割:
1. tooling config(`.claude/`共有ファイル・`.mcp.json`・`ios/.agents/`・`ios/skills-lock.json`)
2. paywall多段階リデザイン + ExitOffer削除
3. AlarmKit Live Activity + morning follow-up
4. 幽霊投稿自己修復
5. onboarding 4段階復元 + 実機バグ修正一式
6. Firebase/Functions/legal
7. 残りのソース・テスト更新
8. branding/screenshots アセット

**判断が分かれたポイント: どのdotディレクトリをコミットしvs無視するか。**
`.claude/`, `.codex/`, `.gemini/`, `.kiro/`, `.opencode/`, `.vscode/`, `.zed/`, `.mcp.json`,
`opencode.json`, `ios/.agents/` が全て未追跡だった。判断基準:
- **コミットした:** `.claude/settings.json`, `.claude/rules/argent.md`, `.claude/agents/*`,
  `.mcp.json`, `ios/.agents/`, `ios/skills-lock.json` —
  このプロジェクトが明示的に採用しているArgent/Claude Codeワークフローの一部で、
  `.claude/rules/argent.md`自体が「プロジェクトにチェックインされた指示」として
  扱われている(システムプロンプトの記述と整合)。
- **`.gitignore`に追加した:** `.build/`(7.3GB、SPMビルドキャッシュ)、
  `.claude/settings.local.json`(Claude Codeの規約でローカル専用)、
  `.claude/scheduled_tasks.lock`(PIDロックファイル、実行中プロセス固有)、
  `.vscode/`, `.zed/`, `.gemini/`, `.kiro/`, `.opencode/`, `.codex/`, `opencode.json`
  (このプロジェクトのドキュメントが言及しない、個人の代替ツール設定)。

**教訓:** コミット前に`.mcp.json`や新規dotディレクトリの中身を必ず読んで、秘密情報が
無いか確認してから判断すること(今回は無かったが、`grep`での機械的スキャンだけでなく
目視も行った)。

## 2. App Check「デバッグトークン期限切れ」説の再検証(残タスク#10)

**やったこと:** 2026-08-01セッションが見つけた「firebase-ios-sdk#9547/#14743」の期限切れ説を、
`exchangeDebugToken`への直接curlで再検証。

**手法(再利用可能):**
```bash
# 1. gcloud ADCで叩く場合、quota projectヘッダーが必須(無いと403 SERVICE_DISABLED紛いのエラー)
curl ... -H "x-goog-user-project: sky-grid-app"

# 2. exchangeDebugTokenはFirebase Web API Keyで叩く(GoogleService-Info.plistのAPI_KEY)
API_KEY=$(/usr/libexec/PlistBuddy -c "Print API_KEY" GoogleService-Info.plist)
curl -X POST ".../v1/projects/sky-grid-app/apps/${APP_ID}:exchangeDebugToken?key=${API_KEY}" \
  -d '{"debug_token":"<value>"}'
```

**発見:** 現在正しく登録済みのトークン値・一度も登録したことのない新規ランダムUUID・
`X-Ios-Bundle-Identifier`ヘッダー付き、の3パターン全てで同一の`403 App attestation failed`。
**未登録のランダムUUIDが「期限切れ」になることは原理上あり得ない**ため、単純な
「特定トークンの期限切れ」説は誤り(反証)と判断。

**さらに、実際にビルド・起動して実地確認:** `build_run_sim`でシミュレータにインストール後、
Buddies画面を開いてFirestoreリスナーを発火させたところ、oslogに
`observeFriendships(...) listener error: Code=7 "Missing or insufficient permissions."`
が継続発生(2026-08-02 15:11 JST、curl検証と同時刻)。2026-07-31発生から中3日以上、
Debug App Check Providerの障害が解消していないことを一次情報(自分でビルドしたアプリの
実ログ)で確認した——伝聞や過去セッションの記録に頼らず。

**教訓:** 「〇〇の可能性がある」という仮説は、可能なら常に**反証実験**(この場合は
「絶対に期限切れになり得ないはずの入力」を試す)で詰めること。仮説を支持する証拠だけを
探すと確証バイアスにはまる。

## 3. RevenueCat Test Store価格修正(残タスク#9)

**発見(gotcha):** RevenueCatのProduct作成フォームには
「Saved pricing can't be edited afterwards」と明記されている。既存の`monthly`/`yearly`/
`lifetime`(Test Store)は$9.99等の初期プレースホルダー価格のまま作成されており、
**価格だけを後から編集する手段が無い**。

**対応:** `monthly_v2`($5.99, Auto-renewing subscription, Monthly)・
`yearly_v2`($44.99, Auto-renewing subscription, Yearly)・
`lifetime_v2`($59.99, **Non-consumable**——Lifetimeは定期購読ではないため製品タイプが違う点に注意)
を新規作成し、それぞれに`premium`エンタイトルメントをattach。その後`default` Offeringの
3パッケージ(`$rc_monthly`/`$rc_annual`/`$rc_lifetime`)内のTest Store側プロダクトを
新商品に差し替えてSave。旧`monthly`/`yearly`/`lifetime`はカタログに残るが、
どのOfferingからも参照されなくなるため実害なし(削除は不要と判断)。

**ブラウザ自動化のgotcha(既存記録の再確認):** 2026-07-31のdev-noteが指摘していた
「Reactのcontrolled dropdownは`form_input`では反映されない」問題を再度踏んだ
(「Attach to Entitlement」ドロップダウンが`<div>`ベースのカスタムコンポーネントで、
`form_input`が`Element type "DIV" is not a supported form input`で失敗)。実クリックに
切り替えて解決——過去の教訓が今回も有効だった。

## 4. WakeGoalPickerView / BGProcessingTask の実態調査(残タスク#4・#12)

両方とも「実機検証待ち」として長期積み残されていたが、コードを実際に読んだところ
**そもそも別の状態**だった:

- **WakeGoalPickerView(#4):** 「Save time and continue」ボタンは権限状態に一切依存せず
  常に有効——つまり**現状は既にソフト側の最も緩い実装**。2026-08-01の引き継ぎメモにある
  「確認ダイアログを追加する」提案は、既存コードの検証待ちではなく**新機能の追加**であり、
  かつ`OnboardingCoordinatorView.swift`のdoc comment(権限取得を必須条件にしない設計哲学)と
  衝突しうる。実装ではなく依頼者の設計判断が先に必要と判断し、実装は保留。
- **BGProcessingTask(#12):** `UploadTriggers.swift`のdoc commentに「Phase 2 follow-up」と
  明記されている通り、**実装自体が存在しない**(`BGTaskScheduler.register`呼び出しがコード中
  どこにも無い)。`Info.plist`の`BGTaskSchedulerPermittedIdentifiers`キーだけが先に登録されている
  状態。「実機検証」ではなく「実装するかどうかの判断」が先に必要。

**教訓:** 引き継がれたタスク文言(「〜の実機検証」)を鵜呑みにせず、まずコードを読んで
実際に何が実装済み/未実装なのかを確認すること。今回は2件とも「検証待ち」の前提自体が
誤りだった。

## 5. ビルド・デプロイ確認(残タスク#7・#8)

`xcodebuild` MCPで`build_run_sim`(iPhone 17 Pro, iOS 26.5)を実行、成功・起動確認済み。
Today画面・Buddies画面への遷移は正常。ただし:
- AlarmKit Live Activityの実地検証は、この環境から物理デバイスへの自動デプロイ手段が
  無い(xcodebuild MCPのデバイスワークフローは本環境で未有効化)ため未実施。
- 幽霊投稿バナーの検証は、App Check障害(上記#2)でFirestore読み書きがブロックされているため、
  疑似的な幽霊状態すら作れず未実施。

**tooling gotcha:** `describe`・`native-describe-screen`の両方が、このビルドに対して
空の要素リストを返し続けた(通常のSwiftUIアプリで想定される挙動と異なる)。原因は未特定
——次回、UIタップによる詳細な画面操作が必要な場合は先にこの点を再調査すること。

## 次回セッションへの推奨アクション

1. 依頼者に項目4(WakeGoalPicker権限ダイアログ)・項目12(BGProcessingTask実装要否)の
   設計判断を仰ぐ。
2. App Check debug provider障害が解消したかどうかを毎回セッション冒頭で再確認
   (上記のcurl手法が最速)。解消していれば幽霊投稿バナーのシミュレータ検証が可能になる。
3. AlarmKit Live Activity・幽霊投稿バナーは依頼者の実機での確認が必要(このセッションからは
   検証手段が無い)。
