# AlarmKit「停止をブロックできない」制約への対応: Live Activity + フォローアップ通知(2026-08-02)

## 背景・依頼者の判断

依頼者から「AlarmKitの停止ブロック制約をApple公式ドキュメントで再検証し、必要ならプラット
フォーム範囲内の心理的圧力代替案を検討」との指示を受けた。

**公式ドキュメント裏取り結果(確定事実)**: AlarmKitの`AlarmPresentation.Alert`
ドキュメント(reader proxy経由で本文取得): 「タップされたボタンの種類に応じて、
`AlarmManager`がstop/countdownを自動的に処理する」。つまりStopボタンの動作はシステム
フレームワーク側が握っており、アプリ側の条件でブロック・遅延することはできない
(`stopButton`はUI装飾のみでAppIntentを紐付けられない)。これは既存コード
(`MorningAlarmScheduler.swift`のiOS26.1+分岐で`stopButton`自体を指定しなくなっている点)
の前提と一致することを確認済み。

3案(①アラーム再アーム/②Live Activity+ソフト通知/③Alarmyスタイル全面書き換え)を
App Store審査リスク・ブランドボイスとの整合性込みで提示し、**依頼者が「Live Activity +
ソフトなフォローアップ通知」を選択**。

## 設計への委譲(code-architect / Opus)

新規Widget Extensionターゲットが必要かどうか、Live Activityの起動タイミング(AlarmKitの
Stop操作はバックグラウンドプロセス起動を伴う)、ActivityAttributes設計など、このリポジトリ
固有のパターンに根ざした実装ブループリントが必要と判断しconde-architectへ委譲。iOS 26.5
SDKの`AlarmKit.swiftinterface`を実際に読んで`AlarmConfiguration.alarm(stopIntent:)`という
**ドキュメント化されたフック**の存在を発見(重要: Stopの動作自体はブロックできないが、
Stopが押された「後」にアプリコードを実行するフックは存在する)。

## 実装したもの

- `Sources/LiveActivity/MorningRitualAttributes.swift` — `ActivityAttributes`(app/widget両ターゲット共有)
- `Sources/LiveActivity/MorningRitualPolicy.swift` + `Tests/MorningRitualPolicyTests.swift`(純粋関数、7ケース)
- `Sources/LiveActivity/MorningRitualActivity.swift` — ActivityKit薄いshim
- `Sources/LiveActivity/MorningRitualCoordinator.swift` — capture完了時/フォアグラウンド復帰時の一元窓口
- `Sources/Notifications/MorningFollowUpScheduler.swift` + テスト — 起床+20分、1日1件の使い捨て通知(繰り返しトリガーでは「その日だけキャンセル」ができないため)
- `Sources/Notifications/MorningAlarmScheduler.swift` — `stopIntent: MorningAlarmStoppedIntent()`追加、
  AlarmKit認可成功後に`UNUserNotificationCenter`認可も要求(既存はAlarmKit認可のみでFCM表示認可が
  一度も要求されていなかった欠落の副次的解消でもある)
- `Sources/Notifications/NotificationRouter.swift` — フォローアップ通知のidentifier prefixもカメラ直行対象に
- `Sources/App/RootView.swift` — capture確定直後に`MorningRitualCoordinator.captureCompleted`、
  フォアグラウンド復帰の2フック(`onAppear`/`scenePhase`)に`reconcileMorningRitual`を追加
- `SkyGridWidgets/`(新規Widget Extensionターゲット) — `SkyGridWidgetsBundle.swift`(ホーム画面ウィジェットは
  提供せずLive Activityのみ)、`MorningRitualLiveActivity.swift`(Lock Screen + Dynamic Island)
- `project.yml` — `SkyGridWidgets`ターゲット追加(`xcodegen generate`実行済み)

**build_sim: エラー・警告ゼロで一発green。**(widget extension込み)

## 設計判断で意図的に外したもの

- **App Groupなし。** Live ActivityはActivityKitが`attributes`/`state`をシリアライズして配送する
  仕組みで完結し、`stopIntent`はアプリ自身のプロセス内で実行される(App Intentsの
  `LiveActivityIntent`は「バックグラウンドでアプリプロセスを起動してperform()を実行する」と
  ドキュメントに明記)ため`UserDefaults`を直接読める。エンタイトルメント変更なし。
- **DesignSystemトークン(`SGT`/`SGFont`)を共有しない。** Widget Extensionは別モジュールになるため、
  `Theme.swift`の`UIColor { traits in … }`動的プロバイダが問題なく共有コンパイルできるか未検証だった。
  この程度の小さいカードにはリスクに見合わないと判断し、素のSwiftUIシステムフォント/カラーで実装。
  今後ブランド統一が必要になった場合のみ再検討。
- **URLスキームによるカメラへのディープリンク(P2)は未実装。** タップ時は通常のアプリ起動のみ。

## 未検証(次回、実機で確認が必要)

**これがこの機能の唯一の"賭け"の部分。** `AlarmConfiguration.alarm(stopIntent:)`という
パラメータの存在自体はiOS 26.5 SDKのswiftinterfaceで確認済み(型は`(any LiveActivityIntent)?`)
だが、「AlarmKitのStopボタン起因のバックグラウンドプロセス起動から実際にLive Activityが
開始できるか」を明言したApple公式文一文は見つかっていない(`LiveActivityIntent`が
バックグラウンドプロセス起動をサポートするという事実と、`stopIntent`がその型を要求するという
事実の組み合わせからの推論)。シミュレータはAlarmKitのアラームを確実に発火させないため、
**実機(iPhone 15 Pro)でロック→アラーム→Stopタップ→ロック画面にLive Activityカードが
現れるかを確認するまでは未確定**。もし発火しない場合でも、フォアグラウンド復帰時の
`reconcileMorningRitual`(iOS 17-25と同じ経路)とフォローアップ通知は独立して機能するため、
機能全体が失敗するわけではない(設計上のフォールバックとして機能する)。

## 次のタスク

- 上記の実機検証。
- 実機への最終デプロイ(このLive Activity機能を含む、今回セッションの全変更をまとめて)。
