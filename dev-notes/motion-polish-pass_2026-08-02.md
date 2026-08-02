# UIモーション強化パス(2026-08-02)

## 背景

VISION.md残タスク#13(§9のUI監査記録が古い件)を受け、依頼者から「§6の儀式的・寡黙なトーンを
壊さない範囲で、既存よりさらにアニメーションを強化する設計判断」を委譲された。設計を
code-architect(Opus)へ委譲し、返ってきた具体的なブループリントに沿って実装した。

## 制約(最優先で守ったもの)

VISION.md §6は「投稿完了時に柔らかいハプティック1回のみ。効果音・紙吹雪・レベルアップ演出なし」
と明記している。**今回のパスは新規ハプティックを一切追加していない**——`Haptics.postCompleted()`
(`Camera/CameraView.swift`の1箇所のみ)は変更していない。architectのレビューでは、シャッター
押下時のハプティックが最も誘惑的な候補として検討されたが、「1つの儀式的瞬間に2回振動する」
ことになるため見送られた(依頼者が明示的に望むなら別途相談、という位置づけで記録のみ残す)。

## 実装した変更(10ファイル)

### 基盤
- `DesignSystem/Layout.swift`: `SGMotion`を1種類(`settle`)から4種類に拡張
  (`settle`/`press`/`exchange`/`drift`)。
- `DesignSystem/ViewModifiers.swift`: `SkyAnimationModifier` + `View.skyAnimation(_:value:)`を追加
  ——`accessibilityReduceMotion`を1箇所で一元的に尊重する仕組み。既存の`SkyPrimaryButtonStyle`
  にはあった押下時の`scaleEffect`+アニメーションが`SkySecondaryButtonStyle`には無かった非対称を
  修正。

### Camera(既存でモーションが皆無だった最重要画面)
- `Camera/CameraView.swift`: live/reviewing/failed の3フェーズ切り替えをクロスフェード化。
  ヘッダーの「現在の空の色」ドットを`SGMotion.exchange`でドリフトさせる(従来は4Hzサンプリングの
  値がそのままスナップしていた)。「Retake / Use this one」ボタンに押下フィードバックを追加。
- `Camera/ShutterButton.swift`: シャッターの塗り(=ライブのアンビエントグラデーション)を
  ドリフトさせ、押下時に`scaleEffect(0.94)`のバネフィードバックを追加(従来は`ButtonStyle`
  自体が無かった)。

### Today
- `Today/TodayView.swift`: 朝の記録カード(写真あり/なし)の切り替えをフェード+スケールに、
  アンビエント背景色のドリフト、週カウンター("0/7")の`numericText`ロールオーバーを追加。

### Sky Grid
- `Grid/SkyGridView.swift`: 月選択チップの塗り替わりと月間アーカイブの切り替え(`.id(selectedMonth)`
  で明示的な入れ替えに変更)を統一したアニメーションでまとめ、年間カウンター("0/365")にも
  numericTextロールオーバーを追加。

### Onboarding / Paywall
- `Onboarding/PersonalizationQuestionsView.swift`(`ChoiceRow`)・
  `Paywall/PaywallPlanStepView.swift`(`PlanOptionRow`): 選択マークのシンボル切り替えを
  `.symbolEffect(.replace)`に、背景/枠線の切り替えを`SGMotion.settle`でバネ化。
- `Paywall/PaywallView.swift`: ステップ切り替え(`advance`/`goBack`)を無アニメーションの
  ハードカットから、進む/戻るで逆方向にスライドする非対称トランジションに変更
  (`isMovingBackward`状態を追加)。
- `Today/BigTimeView.swift`: `.contentTransition(.numericText())`を追加(他画面の大きな数字と
  一貫させるため。影響は小さい——空状態は別テキストで表示されるため実質的な恩恵は`WakeGoalPickerView`
  と同種のパターン統一のみ)。

## 意図的に実装しなかったもの(architectの判断、記録として残す)

- **Sky Gridのマス目1つずつの登場アニメーション。** `GridCanvas`が365マスを1つの`Canvas`に
  命令的に描画しており、SwiftUIのview identityベースのトランジションを個別マスに適用できない。
  加えて、Sky Gridタブは撮影フローと別画面のため、マスが埋まる瞬間を誰も見ていない
  (タブを開いた時にしか発火しない=「記録」ではなく「演出」になってしまう)。
- **数字のカウントアップ演出。** `.contentTransition(.numericText())`の桁ロールオーバーとは別物で、
  スコア演出に近づきすぎる。
- **新規ハプティック全般。** 上記「制約」参照。
- **`.glassEffect()`(iOS 26 Liquid Glass)。** `IPHONEOS_DEPLOYMENT_TARGET = 17.0`のため利用不可。
  既存の`.ultraThinMaterial`(`PaywallStepScaffold.swift`)のままで正しい。

## 検証

- `build_sim`: エラー0件(既存の`RevenueCatService.swift`のSwift 6並行性警告2件は今回の変更と
  無関係、変更前から存在)。
- `build_run_sim` + シミュレータでToday/Sky Grid画面を目視確認、クラッシュなし。
- `test_sim`: 別途実行中(結果は次回セッションのdev-notesに追記、または本ファイル末尾に追記予定)。

## 次回セッションへの申し送り(architectが特定したTier 3、今回は未着手)

1. `OnboardingCoordinatorView.swift`: 8ステップの前進/後退が同じクロスフェードで区別がつかない。
   `OnboardingViewModel`に`isMovingBackward`を追加すれば`PaywallView`と同じ非対称遷移にできる。
2. `OnboardingProgress`バー: 各ステップ画面が個別に生成しているため連続したidentityが無く、
   バーの伸長アニメーションができない。coordinator側への巻き上げが必要(8ファイル規模)。
3. `Haptics.prepare()`: `postCompleted()`が`prepare()`無しで即座に発火しており、最大100ms程度の
   Taptic Engine起動遅延がある。新規ハプティックの追加ではなく、既存1回の反応を速くするだけの
   変更。
4. `WakeGoalPickerView.swift`/`MorningAlarmSettingsView.swift`の`.contentTransition(.numericText())`
   が実は機能していない(DatePickerのbinding setterが`withAnimation`で包まれていないため)。
   実機/シミュレータでのホイール操作時の見え方を確認してから、動くようにするか削除するか判断。
5. `Today/BuddyTile.swift`/`BuddyRow.swift`: `BuddyRow`がどこからもインスタンス化されていない
   デッドコード。これは製品判断(削除するか、配線し忘れか)であり、モーションの話ではない。
