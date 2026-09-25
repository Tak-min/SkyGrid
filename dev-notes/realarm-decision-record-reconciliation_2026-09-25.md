# 再アラーム仕様の裁定 — 決定記録と実装のずれの解消 (2026-09-25)

## 背景

`dev-notes/alarmkit-departure-feasibility-and-record-drift_2026-09-24.md` で報告した通り、
2026-09-05の決定記録(`owner-selected-3b-5c-6c-decision-record_2026-09-05.md:323,334,355-356,397`)
は「合計3回・最大15分で再アラーム終了」を定めていたが、実装は「5分ごとに補充し続け、写真を
撮るか4時間(またはその日の終わり、早い方)まで継続」という、より強い形に無承認で変わっていた。

オーナーに確認した結果(2026-09-24, AskUserQuestion経由): **コード実装(4時間・補充継続方式)
を正式仕様として採用する。**

## 正式仕様(2026-09-25時点)

- 間隔: 約5分ごと
- 継続条件: 写真を撮るか、アラーム開始から4時間経過、またはその日の終わり — いずれか早い方
- 先読み予約本数: 3本(15分分)。**この値は別途見直しが検討されている**(下記参照)。

## 過去の決定記録との関係

`dev-notes/owner-selected-3b-5c-6c-decision-record_2026-09-05.md` の該当箇所(:323,334,355-356,397、
「合計3回・15分まで」)は本記録により**上書きではなく上位記録として置き換え**とする。当時の
記録は削除・編集しない(履歴の保持)。今後この挙動を参照する際は、2026-09-05の記録ではなく
本記録を正とする。

## 未決着の関連項目

- **先読み予約本数の増強**: オーナーは「3本(15分分)よりもっと増やしたい」との意向。
  具体的な本数はオーナーに別途確認中(このメモの時点で未確定)。確定次第、
  `MorningWakeSession.swift:37-48`(既定値3本の定義箇所)の変更として別途実装する。
- **実機での補充動作確認**: iOS 26.1+の実機で「止める→5分後に補充されて再度鳴る」が、
  アプリ強制終了後も含めて確実に成立するかは未確認(約30分の手作業、オーナー実施が必要)。

## 参照ファイル

- `dev-notes/alarmkit-departure-feasibility-and-record-drift_2026-09-24.md`
- `dev-notes/owner-selected-3b-5c-6c-decision-record_2026-09-05.md`
- `ios/SkyGrid/Sources/Notifications/MorningWakeSession.swift`
- `ios/SkyGrid/Sources/Notifications/MorningAlarmScheduler.swift`
- `ios/SkyGrid/Sources/Notifications/MorningRealarmPolicy.swift`
