# セッション引き継ぎ: Live Activity実装完了 + 複数バグ修正 + 未解決タスク(2026-08-02)

**次回セッション開始時、まずこのファイルを読むこと。** 実機(iPhone 15 Pro、有線接続、devicectl
`FF649B7E-F19F-5E73-9AA2-797C297B8916`)には本セッション終了時点の最新ビルド(下記の全修正
込み)をデプロイ済み。

## 今回完了した項目(コード変更・ビルド確認済み)

1. **Paywall多段階フロー再設計** — 完全実装。詳細:
   [paywall-multistep-redesign-implementation_2026-08-01.md](paywall-multistep-redesign-implementation_2026-08-01.md)
2. **AlarmKit Live Activity + フォローアップ通知** — 完全実装(新規Widget Extension
   `SkyGridWidgets`含む)。詳細:
   [live-activity-morning-nudge_2026-08-02.md](live-activity-morning-nudge_2026-08-02.md)。
   **未検証: AlarmKitのStopボタンから実際にLive Activityがバックグラウンド起動できるか
   (U1)。実機でロック→アラーム発火→Stopタップ→ロック画面確認が必要(下記TODO参照)。**
3. **カメラ確認画面「Use this one」ボタンのはみ出し** — `CameraChoiceButtonStyle`
   (`Sources/Camera/CameraView.swift`)に`minWidth: 0`が無かったのが原因(SwiftUIで
   ボタンが縮小できない典型的な罠)。`.frame(minWidth: 0, maxWidth: .infinity, minHeight: 54)`
   に修正。実機デプロイ済み。
4. **オンボーディング質問の初期選択解除** — `PersonalizationProfile`
   (`Sources/Onboarding/PersonalizationProfile.swift`)の5フィールドを全てOptional化。
   以前は`.steadierRhythm`等のハードコード初期値があり、質問画面を開いた瞬間から
   常に1つ選択済み状態になっていた。連動して`PersonalizedMorningPlanBuilder`と
   `PaywallEntryPoint`の switch 文に`?? .default`フォールバックを追加(未回答時は旧デフォルト
   と同じコピーを出す、動作の後方互換性は保持)。既存テスト
   `PersonalizationProfileTests.decodesLegacyProfile`もこの新しい「未回答=nil」の
   仕様に合わせて更新済み。

## 今回のセッションで判明した重要な事実(次回すぐ使えるように記録)

### RevenueCat Test Store価格($9.99問題の正体)

- 実機で見えていた「月額$9.99」は**RevenueCatのTest Store**の`monthly`プロダクトの
  base priceだった(ダッシュボードで直接確認済み)。Debug構成のビルドは
  `REVENUECAT_API_KEY_TEST`を使うため、Test Store側の価格が見える。
- **Test Store商品の価格は作成後に編集不可**(RevenueCat自身の仕様、UI上に編集欄なし)。
- **削除も不可だった**: 「このプロダクトを使った取引記録が既に存在するため削除できません」
  というRevenueCat自身の安全装置に阻まれた(過去のdev-notesの想定より強い制約と判明)。
- **次回の対処案(未実行)**: 同じ`monthly`ではなく新しい識別子(例: `monthly_v2`)で
  $3.99のTest Store商品を新規作成し、`default` Offeringのパッケージ参照先を
  新商品に差し替える。旧`monthly`/`yearly`/`lifetime`は使われなくなるだけで
  DB上に残り続ける(削除できないので許容するしかない)。同様の手順を`yearly`
  ($19.99へ)・`lifetime`($39.99へ)にも適用。
  RevenueCatプロジェクトURL: `https://app.revenuecat.com/projects/40a1ad74/product-catalog/products`

### App Store Connect本番価格($5.99問題)

- 依頼者から確認: 本番の月額価格は現在**$5.99**(審査提出前に変更してそのまま固定されている)。
  依頼者の意図は最終的に**$3.99**へ変更すること(年額/ライフタイムは要相談、過去の記録では
  $19.99/$39.99が「元の予定」)。
- **これは依頼者自身がApp Store Connect側で編集できるようになり次第、依頼者自身が行う想定。
  今回のセッションではコード側・エージェント側からの対処は行っていない。**
  過去セッションでASC側の価格編集UIコントロールが見つけられず行き詰まった記録があるため
  (`VISION.md`の2026-07-30時点の記録参照)、次回試みる場合はこの過去の記録を先に読むこと。

### App Check「断続的失敗」の原因再調査(重要な訂正 — 前回セッションの結論を覆す可能性)

- 前回セッション(`app-check-backend-outage-confirmed_2026-08-01.md`等)の結論は
  「Googleバックエンド側の障害」だったが、**Firebase公式ステータスダッシュボード
  (status.firebase.google.com)を確認したところ、直近1週間(7/25〜8/1)でApp Check関連の
  インシデントは一件も記録されていなかった。**
- GitHub上のFirebase公式リポジトリのIssue調査により、この`exchangeDebugToken`の
  403エラー(`App attestation failed`)は**何年も前から繰り返し報告されている既知の
  カテゴリの問題**で、多くの場合**デバッグトークンの期限切れ(約1時間で失効)**や
  設定不一致が原因と判明([firebase-ios-sdk#9547](https://github.com/firebase/firebase-ios-sdk/issues/9547)、
  [firebase-ios-sdk#14743](https://github.com/firebase/firebase-ios-sdk/issues/14743))。
- **次回セッションでの推奨アクション**: 「Googleの外部障害を待つ」という前回の結論を
  一旦保留し、「デバッグトークンが時間経過で失効し、キャッシュされた古い値を使い続けている」
  という設定側の問題として再調査する。具体的には、`exchangeDebugToken`を叩くタイミングと
  実際のトークン発行・失効時刻を突き合わせて確認すること。
- これは**アカウント削除の断続的失敗**および**同時リクエストの遅延**、両方の説明になりうる
  (Cloud Functionsログで本日中に成功/失敗が混在していたことと整合)。

## 次回セッションでやること(優先順位順)

1. **App Checkデバッグトークン期限切れ説の検証。** 上記の新しい仮説に基づき、実際に
   トークンの発行・失効タイミングを確認。解決すれば「アカウント削除の断続的失敗」と
   「リクエストの遅延」の両方が同時に片付く可能性が高い。
2. **AlarmKit Live Activityの実機検証(U1)。** iPhone 15 Proで、アプリ内Morning Alarm
   設定から数分後にアラームを設定→ロック→アラーム発火→**Stop**をタップ(カメラには行かない)
   →ロック画面に「Today's sky / Not captured yet」カードが表示されるか確認。表示されなくても
   フォローアップ通知は独立して動作するため機能全体は壊れない。
3. **RevenueCat Test Store価格の修正**(上記「対処案」参照、依頼者の許可は既に得ている
   — `monthly_v2`等の新規商品作成+Offering差し替え)。
4. **タイマー/通知の権限確認ダイアログの仕様確認。** 依頼者の依頼(
   `WakeGoalPickerView`の「Save time and continue」を押した際、通知/AlarmKit権限が
   未取得なら確認ダイアログを出し、許可取得を確認してから次ページへ進む)は、既存の
   意図的な設計原則(`OnboardingCoordinatorView.swift`のdocコメント:
   「Permissions are requested only at the moment a person explicitly enables an
   alarm or opens the camera; neither is a condition for reaching their first
   morning.」— 権限取得を絶対に必須条件にしない、という設計哲学)と衝突する可能性がある。
   ソフトな確認ダイアログ(それでも進める)か、ハードなゲート(許可されるまで進めない)か、
   依頼者に仕様を確認してから実装すること。推測で進めない。
5. **App Store Connect本番価格の変更**(依頼者自身が対応予定、上記参照)。
6. `ios/`配下の大量未コミット変更(今回分含む、40ファイル超)について、依頼者にコミット方針の
   確認が必要な状態が継続中(これは複数セッション前から繰り返し記録されている積み残し)。

## 次回セッション起動フレーズ

「このdev-note(`session-handoff-liveactivity-and-bugfixes_2026-08-02.md`)を読んで
続きから進めて」
