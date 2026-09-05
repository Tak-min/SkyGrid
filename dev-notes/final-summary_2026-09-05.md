# 最終dev-note雛形(2026-09-05) — 下ごしらえ、締めタスク未実施

**注意: これは雛形。** `.loop/VISION.md`の締めタスク(「Full test suite green + Release
build green, final dev-note summarizing before/after — re-shoot screenshots first」)は、
N-wayバディの読み取りファンアウト境界修正(Codexが並行作業中)が完了してから最終確認として
実行する必要があるため、本ファイルではまだ実行していない。git logとVISION.mdの記述から
分かる範囲を埋めてある。スクリーンショット、テスト結果、Release buildの節は空欄のまま
残してあるので、締めタスク実行時にそこだけ追記すればよい。

## Before / After

### Before(このループ開始前の状態、`.loop/VISION.md`「Verified ground truth」セクションより)
- Buddiesタブは1:1バディ前提のUIで、関係性の状態(既読/未読/連続日数)より他の情報が
  優先される構成だった。
- オンボーディングのWelcome画面に「色」が投稿の実体であるかのような古いコピーが残存
  (実際は実写真、`82f39a3`以降)。
- バディは1:1のみで、複数人サークル(N-way)は未実装。
- 共有アーティファクト(シェアカード)はサムネイルサイズでの可読性に課題があった
  (`.loop/archive/audit_2026-08-08.md` C1/C2として記録)。
- アラームは単一時刻・単純な停止のみで、Erly的な「止めても粘る」機構がなかった。
- App Store掲載(ASO)はErlyとの比較検討がされていなかった。

### After(git log全履歴とVISION.mdの`- [x]`項目から確認できる範囲)

- **3B(サーバー側バディ連続日数)**: `onPostCreatedUpdateBuddyStreaks`トリガー+
  `buddyStreaks.ts`の純粋ロジック+`buddyStreakStore.ts`(transaction.update()のみ、
  `firestore.rules`変更なし)が実装・コミット済み(`7464904`)。クライアント表示は
  `FeatureFlags.buddyStreakVisible`(既定オフ)の裏で実装済み(`9afb70f`)だが、
  本番データの前提(実データ≥1日分)が実際に成立しているかは**未検証(unverified)** —
  関数のデプロイが承認されていないため。
- **5C(複数アラーム+再アラームループ)**: `MorningAlarmSchedule`モデル・移行、
  `NotificationRouter`のprefixマッチ、AlarmKit側の複数スケジュール整合、
  Stop intent/captureCompletedへの再アラームループ配線、承認済みの正確なコピー文言
  (`MorningAlarmSettingsView.swift`・`WakeGoalPickerView.swift`)まで全ステップ実装・
  テスト済み(263/263グリーンで独立再検証済み、コミット群 `71712e9`〜`9ab05a8`)。
  「モーション/アクションゲート」方式はオーナーにより明示的に却下され、再アラームループが
  6Cの代替解決として採用された。
- **6C**: 独立実装なし。5Cが完了した時点で6Cの実体(再アラームループ)は既に満たされている
  ([owner-selected-3b-5c-6c-decision-record_2026-09-05.md](owner-selected-3b-5c-6c-decision-record_2026-09-05.md)参照)。
- **Buddiesタブ改修(436)**: 階層の反転(関係性の状態を主役に)、説明文の折りたたみ、
  行タップ先を関係性詳細画面へ変更、招待リンクの空状態表示 — 4つのサブ項目すべて現在の
  ツリーで確認済み、`8fcaecc`でチェックオフ。
- **N-wayバディ(部分)**: サーバー側のサークル上限(~8人、`applyCircleCap`)が
  `claimInviteCode`のトランザクションに実装・コミット済み(`cdcaa2d`)。UI/コピーの
  「1人」前提の除去も一部実施(`b71e3b4`)。**読み取りファンアウト境界(UIが表示する12人に
  バディ再読み込みの範囲を揃える部分)は本セッション時点でまだ未完了 — Codexが別途対応中**、
  今回の私の作業ではこの部分に一切触れていない。
- **共有アーティファクト**: 「day-1アーティファクト」「サムネイル可読性」(C1/C2)は
  VISION.mdの記録によれば既に解消済みとしてチェックオフされている(919行目)。
  招待クレーム時の通知(`d3ae515`)、実際の朝の写真をシェアカードのヒーロー画像に使う変更
  (`26904f3`)なども含まれる。
- **ASO(Erlyとの比較)**: `dev-notes/aso-comparison-vs-erly_2026-09-04.md`として
  具体的な比較が記録済み、VISION.mdでチェックオフ済み(928行目)。
- **デザイン研究パス**: 59ソースの実外部デザイン/プロダクト参照調査が
  `dev-notes/design-research-sources_2026-09-04.md`として記録済み(要件は≥50ソース)。
- **視覚デザインパス**: Today/Grid/Buddies/オンボーディング/共有/課金画面にわたる
  再設計がVISION.mdの複数項目(416行目 Today再設計、436行目 Buddies再設計 等)として
  チェックオフ済み。

## まだ残っている作業

1. **オンボーディングのpace/frequency判断 — 意図的に保留中。** `PersonalizationProfile`の
   `pace`/`frequency`ステップを削るべきかは、ステップ到達/離脱の実測データが無いため
   「クレーム」ではなく「賭け(bet)」の状態にとどまっている。2026-09-04にステップ到達/
   離脱のアナリティクス計測(`OnboardingAnalytics`)は追加済みなので、実データが溜まって
   から判断する方針(VISION.md 491-535行目)。本セッションではこの判断に一切踏み込んで
   いない。
2. **N-wayバディの読み取りファンアウト境界。** サーバー側サークル上限は実装済みだが、
   バディ再読み込みの読み取り範囲をUI表示件数(12人)に揃える部分は未完了。**Codexが
   別途対応中であり、本セッションはこの領域に触れていない。**
3. **スクリーンショットの再撮影。** `screenshots/ui-audit-*.png`は現在stale。
   `dev-notes/app-check-debug-token-investigation_2026-09-05.md`に記録した通り、
   実アプリ起動フロー(UIAuditホストではない)からのオンボーディング/設定画面撮影は、
   Firebase App Check の`exchangeDebugToken`バックエンド不調(未解決、原因未特定)により
   ブロックされている可能性が高い。この障害の解消(または回避策)が先決。

## 次に必要なアクション

1. **App Check問題の解消。** 上記dev-note記載の通り、まずオーナー本人がFirebase
   Console(GUI)のApp Check画面を確認するのが最短。読み取り専用のAPI再検証には
   オーナーの明示的な承認が必要(Claude Codeの自動モード分類器が本番Firebaseプロジェクト
   への外部呼び出しとして一律ブロックするため)。
2. **スクリーンショットの再撮影。** App Check問題解消後、実アプリ起動フローから
   オンボーディング/設定画面を含む`screenshots/ui-audit-*.png`一式を撮り直す。
3. **Release buildの最終確認。** `xcodebuild build -project SkyGrid.xcodeproj
   -scheme SkyGrid -configuration Release -destination 'generic/platform=iOS'`が
   0エラーで成功することを確認(N-wayファンアウト修正完了後)。
4. **フルテストスイートの最終確認。** `xcodebuild test -project SkyGrid.xcodeproj
   -scheme SkyGrid -only-testing:SkyGridTests -destination 'platform=iOS Simulator,
   name=iPhone 17'`が全件グリーンであることを確認(直近の独立再検証では263/263、
   ただしN-wayファンアウト修正後に再実行が必要)。
5. **firebase deployの明示的なオーナー承認。** 3Bのサーバー側関数(`buddyStreaks`
   関連)は実装・コミット済みだが未デプロイ。これをデプロイしない限り、
   `FeatureFlags.buddyStreakVisible`を有効化しても実データの前提が満たされない。
   本ループは`firebase deploy`を一切実行しない方針(このセッションを含め継続)。
   実施するかどうかはオーナーの明示的な承認が必要。
