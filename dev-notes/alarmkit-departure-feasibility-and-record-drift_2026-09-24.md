# AlarmKit離脱の実現可能性 & 決定記録とコードのずれ — 2026-09-24

## 背景

オーナーから「アラーム画面をAlarmy風に、ストップスライドなし・アプリを開くボタンのみにしたい」
という要望があった。2回のOpus(architect)レビューで技術検証を行った結果、以下が判明した。

## 結論(サマリ)

1. **AlarmKitのAPI制約により、「アプリを開くボタンのみ・停止操作を一切出さない」画面はどのiOS
   バージョンでも実装不可能。** iOS 26.1+はシステムが停止操作を完全に握りアプリ側で変更不可。
   iOS 26.0は`stopButton`が初期化子の必須引数でありコードから消すとビルドが壊れる。
   (根拠: `AlarmKit.framework/Modules/AlarmKit.swiftmodule/arm64e-apple-ios.swiftinterface`,
   Xcode 26.5 SDK, 行55-65付近)
2. **AlarmKitを離れた独自の常駐実装(バックグラウンド音声トリック等、Alarmy旧来方式とされるもの)
   は非推奨。** 強制終了・メモリ不足・電話割り込み等で常駐が切れ、現状のAlarmKit(システム管理の
   本物のアラームでアプリが死んでも鳴る)より信頼性が下がる。Apple Guideline 2.5.4
   (バックグラウンドサービスの目的外使用)に抵触するリスクが高く、公開中アプリの更新却下リスクを
   負うに値しない。
3. **「再アラームを強める」案(中間案)は、実はほぼ実装済み。** 現行コードは「未来の予約を常に
   3本(15分分)保つ」ローリング方式で、止めるたびに補充し、写真を撮るか4時間/その日の終わり
   (早い方)まで続く。当初の「5分間隔・最大3回・4時間」という理解は不正確だった。
4. **決定記録とコードの間に無承認のずれがある(要オーナー裁定)。**
   - `dev-notes/owner-selected-3b-5c-6c-decision-record_2026-09-05.md:323,334,355-356,397`:
     「合計3回・15分まで、4回目は無し」と明記。
   - 実装(`MorningWakeSession.swift:37-48,84`, `MorningAlarmScheduler.swift:900-902`,
     `MorningAlarmSettingsView.swift:260`): 「5分ごとに補充、4時間または当日終了まで」
     (最大48回相当)。
   - この変更を承認した記録は見つかっていない(dev-notesを"four hours"/"4時間"/
     "rolling horizon"で検索した範囲)。後の会話で決まったが記録に残っていない可能性がある。
   - `MorningRealarmPolicy.decide`は3回上限の古い形のまま残存しているが、呼び出し元は
     `morningRealarmOccurrences`のみで、本体からの呼び出しは調査範囲内では見つからなかった
     (未使用コードの可能性、要確認)。

## 検討した選択肢と評価

| 案 | 内容 | 信頼性 | 審査リスク | 判定 |
|---|---|---|---|---|
| (a) 独自常駐実装 | バックグラウンド音声トリックで常駐 | 低(強制終了で崩れる) | 高(Guideline 2.5.4) | **非推奨** |
| (b) Live Activity拡張 | 音は鳴らせない、マナーモード従う | 目的に寄与しない | 低 | **見送り**(既に類似機能実装済み) |
| (c) AlarmKit再アラーム強化 | 間隔/予約本数/期限の調整 | 高(補充依存部分のみ未検証) | 低 | ほぼ実装済み。**調整の余地はわずか** |
| (d3) バディ可視化 | 止めた後に戻る理由を社会的に作る | 技術に依存しない賭け | 低 | 別途プロダクト仮説として検討可 |

## 未確認事項(実機確認が必要)

- iOS 26.1+の実機で「止める→補充されて5分後に鳴る」が、アプリ強制終了後も含めて成立するか
  (約30分の手作業)。
- カメラボタン(secondaryButton)を押した際、アラーム音が即座に止まるか
  (`MorningAlarmScheduler.swift:1316-1317`のコメントと決定記録:444行が食い違う)。
- iOS 26.1+のシステム停止操作でアプリを開かずに消せるか。
- AlarmKitで1アプリが同時予約できるアラーム数の上限(現在、定期アラーム最大5本+再アラーム予約が
  併存)。
- Apple Review Guidelineの現行本文確認、critical alertの目覚ましアプリへの承認可否
  (一般的には非承認と見られているが未確認)、Alarmyの実際の実装方式(iOS26以降AlarmKitへ
  移行したか含め未確認)。

## オーナー判断が必要な項目(次の一手)

コード変更自体は定数調整+テスト2ファイル更新で半日規模。ループ化する規模ではないため、
このループでは扱わない。以下はオーナー本人の判断を仰いだ(2026-09-24、別セッションで
AskUserQuestion経由):

1. 決定記録(15分)とコード実装(4時間)のずれをどちらで正式採用するか
2. 捕捉ウィンドウの長さ
3. 先読み予約本数(3本→6本などの増強要否)
4. 独自実装(AlarmKit離脱)の正式見送り
5. バディ可視化(d3)を別途プロダクト仮説として検討するか

## 参照ファイル

- `ios/SkyGrid/Sources/Notifications/MorningAlarmScheduler.swift`
- `ios/SkyGrid/Sources/Notifications/MorningWakeSession.swift`
- `ios/SkyGrid/Sources/Notifications/MorningRealarmPolicy.swift`
- `ios/SkyGrid/Sources/Notifications/MorningAlarmSettingsView.swift`
- `ios/SkyGrid/Sources/LiveActivity/MorningRitualAttributes.swift`
- `ios/SkyGrid/Config/Info.plist`
- `ios/SkyGrid/Sources/App/AppDelegate.swift`
- `dev-notes/owner-selected-3b-5c-6c-decision-record_2026-09-05.md`
- `dev-notes/interaction-benchmark_2026-09-07.md`
- `.loop/backlog-triage_2026-09-24/` (並行して進めているコード実装ループ。本件はそのループの
  スコープ外)
