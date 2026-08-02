# Paywall多段階フロー再設計: 実装完了(2026-08-01)

前回セッション(`session-handoff-paywall-alarm_2026-08-01.md`)で確定した code-architect
ブループリントを、そのまま全実装した。ブループリント自体は変更していない(設計判断の
根拠はそちらを参照)。ここには実装時に見つかった具体的な差分・落とし穴・レビュー指摘を残す。

## 実装したもの

ブループリント§10のビルド順序どおり:

1. `Sources/Paywall/PaywallStep.swift` + `Tests/PaywallFlowTests.swift`(新規、Swift Testing)
2. `Sources/Paywall/PaywallStepScaffold.swift`(共通コンテナ。`PaywallBenefit`/`PaywallLegal`を
   `PaywallView.swift`からここへ移設・private解除。`PaywallStatusView`もここに新設)
3. `PaywallValueStepView.swift` / `PaywallFeaturesStepView.swift` / `PaywallPlanStepView.swift`
   (3ステップ分のView。既存ブロックをverbatim移設)
4. `PaywallView.swift`をコンテナ化(step状態・advance/goBack・Close/Backツールバー・
   `.entitlementUnavailable`時のステップ機構バイパス)
5. `PaywallAnalytics.swift`に`stepViewed`イベント+`step:`パラメータ追加
6. `SkyGridApp.swift`に`paywall-plan`(`initialStep: .plan`)のUIAuditシナリオ追加、
   `SkyGridUITests.swift`の4テストを新フロー(2タップ追加/起動引数変更)に対応
7. `ExitOffer.swift`一式を削除(`PaywallEntryPoint.permitsExitOffer`、
   `LocalDefaults.didPresentExitOffer`、`PaywallPolicyTests.swift`の`ExitOfferPolicy`suite、
   `Info.plist`/`Secrets{,.example}.xcconfig`の`SKYGRID_EXIT_OFFER_*`含む)
8. `SettingsView.swift`に"Restore purchases"行を追加、`EntitlementStore.restore()`を新設

## 目視確認(シミュレータ、iPhone 17 Pro / iOS 26.5)

- `.settings`エントリポイント(3段: value→features→plan)、`.ritualMilestone`エントリポイント
  (2段: features→plan)の両方をUIAuditシナリオ経由で確認。Back/Closeボタンの出現条件、
  ステップドット、プラン選択→CTAラベル変化(Continue with Annual/Monthly)まで実機シミュレータで
  タップして確認済み。

## swift-reviewerによる指摘と対応(実装後レビュー、批判的検証)

レビュー観点は「App Store Guideline 3.1.2準拠」「SwiftUI再描画の正しさ」「ExitOffer削除の
網羅性」を明示的に指定。指摘2件、いずれも修正済み:

1. **CRITICAL — `.ritualMilestone`フロー(features→planの2段)に「SKY GRID PRO」という
   商品名テキストが一度も出現しない**。価格・更新条件・Restore・利用規約はplanステップに
   揃っているが、"Sky Grid Pro"という名称自体は`PaywallValueStepView`(=value step)にしか
   存在せず、`.ritualMilestone`はvalue stepを通らない設計(§5の意図的な2段短縮)だったため、
   最も高頻度な自動リマインダー導線で「何を買うか」が一度も表示されないまま価格だけ見せる
   状態になっていた。**修正: `PaywallPlanStepView`の先頭(state不問、loading/failed/loadedの
   どの状態でも表示)に"SKY GRID PRO"のeyebrowテキストを追加。** エントリポイント別分岐にせず
   全フロー共通にしたことで、今後どのエントリポイントを2段/3段に変えても再発しない設計にした。
2. **HIGH — SettingsのRestore purchasesが失敗時に無反応**。`EntitlementStore.restore()`が
   `try?`でエラーを握りつぶし、`SettingsView.restore()`も`Bool`を破棄していたため、
   ネットワーク障害でも「購入なし」でも同じく無言でボタンが元に戻るだけだった
   (`PaywallViewModel.restore()`は同じ呼び出しに対しちゃんと`errorMessage`を出しているのに、
   Settings単独導線だけ退行していた)。**修正: 既存の`unblockError`/`deletionError`と同じ
   alertパターンで`restoreError`を追加、失敗時に汎用メッセージを表示。**

いずれもファイル内の既存パターンをそのまま踏襲する機械的な修正だったため、
Opus(architect等)へのエスカレーションはせず自分(Sonnet)で直接対応。

## テスト結果

- `PaywallFlowTests`(新規11ケース)含め、全体テストは複数回green化を確認。
- **既知の非関連failure(このセッションの変更が原因ではない)**: `testOnboardingMovesFromWelcomeIntoTheQuestionFlow`
  `testRealAccountDeletionSucceeds` `testRealCameraCaptureUploadsSuccessfully`は、既存の
  App Check 403(`app-check-debug-token-mismatch_2026-07-31.md`等で追跡中)およびFirestore
  `Missing or insufficient permissions`エラーに起因する既知の失敗で、Paywall変更前の
  最初のtest_sim実行でも同じ3件が失敗していたことを確認済み(=このセッションの回帰ではない)。
- **要再確認・未確定の症状**: `testRealPaywallOfferingsLoadAfterRevenueCatIncident` /
  `testRealSandboxPurchaseReachesStoreKitConfirmationSheet` /
  `testRealTestStorePurchaseGrantsEntitlement`の3件が、Settings画面の
  "Unlock the full archive"ボタンタップで`Automation type mismatch: computed Button from
  legacy attributes vs Link from modern attribute`というXCTest内部エラーで2回連続失敗した。
  **ただし同じビルドをargent MCP経由で実際に手動タップしたところ、ボタンは正常に動作し
  正しくpaywallのvalue stepへ遷移した**(スクリーンショットで確認済み)。実使用上のバグでは
  ないと判断し、これ以上のrabbit holeには踏み込まなかった。App Check 403の既存障害と
  同じテスト実行内で発生していることから、Firestoreリスナーのエラーによる画面の
  settle待ちタイミングのずれが引き金の可能性が高いが未確定。**次回、App Check 403が
  解消した後にこの3件を再実行し、まだ再現するか確認すること。**

## ExitOffer削除に関する未検証の外部事実(依頼者確認が必要)

ブループリント§11で明示されていた懸念そのまま: `Secrets.xcconfig`(gitignore対象)に
実際に`SKYGRID_EXIT_OFFER_CODE = SKYGRID20`という値が入っていた(プレースホルダーではない)。
削除は構造的に正しい判断だが(App Store Connect側にオファーが存在しなくてもコードだけ
出してしまっていた既存バグの解消が主眼)、**このコードが実際にApp Store Connect側で
作成済み・外部に告知済みかどうかは、この環境からは確認できない。** 「審査へ提出」を押す前に
依頼者側でASC Offer Code一覧を確認することを推奨。

## 審査用スクリーンショットの再撮影が必要

`SkyGridApp.swift`に`paywall-plan`シナリオ(`-SkyGridUIAuditScenario paywall-plan`)を
追加済み。既存の`screenshots/ui-audit-paywall-final.png`(ASCのサブスクリプション2件の
「審査に関する情報」に添付済み)は旧・単一画面レイアウトのものなので、新レイアウトで
撮り直しApp Store Connect側の差し替えが必要。**「審査へ提出」を依頼者が押す前に対応する
かどうかは依頼者判断。**

## 次のタスク

- AlarmKit「アラーム停止をアプリ側条件でブロックできるか」の公式ドキュメント裏取りは完了
  (`AlarmManager`がstop/countdownを自動処理する旨をApple公式ドキュメントで確認、
  stopButtonはUI装飾のみでAppIntentを紐付けられない)。依頼者に3案(再アーム/Live Activity/
  Alarmyスタイル全面書き換え)を提示し、**「Live Activity + ソフトなフォローアップ通知」を
  選択済み**。code-architect(Opus)へ実装ブループリントを委譲中(Widget Extension要否・
  Live Activity起動タイミング・ActivityAttributes設計・フォローアップ通知のスケジューリング)。
- 上記完了後、実機(iPhone 15 Pro、devicectl `FF649B7E-F19F-5E73-9AA2-797C297B8916`)への
  最終デプロイ。
