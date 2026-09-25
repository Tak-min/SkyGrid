# Sky Grid 効果音設計・素材調達記録

最終更新: 2026-09-11

## 1. 方針

効果音は、画面・文言・触覚・VoiceOverですでに伝わる状態変化だけを補強する。音だけで成功、
失敗、相互公開、プライバシー状態を伝えない。通常のタップや画面遷移には付けず、初期セットを
次の4場面に限定する。今回の3音追加はその意図的な既存方針からの限定的な拡張であり、
画面遷移音も指定された前進導線だけに付け、通常の画面遷移すべてへは広げない。

| 場面 | アプリ内ファイル | 元ファイル | 長さ | 発火条件 |
|---|---|---|---:|---|
| 撮影保存成功 | `capture_saved.caf` | `Audio/switch36.ogg` | 0.329秒 | 通常のdaily reward peak。相互公開がある場合は鳴らさない |
| 相互公開 | `mutual_reveal.caf` | `Audio/switch21.ogg` | 0.407秒 | server-authoritative readingで公開数が1以上のreward settle |
| streak milestone | `streak_milestone.caf` | `Audio/switch31.ogg` | 0.432秒 | milestone画面が表示された時 |
| 回復可能な失敗 | `recoverable_error.caf` | `Audio/switch7.ogg` | 0.213秒 | カメラ起動・撮影・色抽出・投稿保存の回復可能な失敗。権限拒否では鳴らさない |
| Mokuタップ | `moku_tap.caf` | `Audio/impactSoft_medium_000.ogg` | 0.118秒 | `interactionFeedback == true` のタップ開始時に1回。着地時には鳴らさない |
| 前進ナビゲーション | `forward_navigation.caf` | `Audio/card-slide-4.ogg` | 0.459秒 | Todayの3導線とオンボーディング前進操作のみ。戻る操作・Paywall通常遷移には鳴らさない |
| 購入確定 | `purchase_confirmed.caf` | `Audio/confirmation_001.ogg` | 0.290秒 | 購入処理がsubscribedとして確定した時だけ1回。復元・キャンセル・失敗では鳴らさない |

相互公開は通常の保存成功より希少で意味が強いため、同じreward内では相互公開音を優先し、
2音を重ねない。second-chance paywall専用音は追加しない。Reduce Motionでも意味は同じなので
消音せず、短縮されたsettleで1音だけ鳴らす。アプリ内Settingsで全効果音を停止でき、端末の
消音設定もSystem Sound Servicesにより尊重する。

## 2. 素材とライセンス

4ファイルとも同じ公式配布パックから選定した。

- パック: **UI Audio / UI SFX Set**
- 作者: **Kenney Vleugels (Kenney.nl)**
- 公式紹介URL: <https://kenney.nl/assets/ui-audio>
- 取得した公式ZIP URL:
  <https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip>
- 取得日: 2026-09-11
- ZIP SHA-256: `946fc23a63d535d693eb31b2eabb80c8c28d6351e2186b344ceb71b2cb1d5eb6`
- ライセンス: **Creative Commons Zero v1.0 Universal (CC0 1.0)**
- ライセンスURL: <https://creativecommons.org/publicdomain/zero/1.0/>
- 帰属表示: **不要**。同梱`License.txt`には、Kenneyまたは`www.kenney.nl`のクレジットは
  任意であり必須ではないと明記されている。本記録では追跡可能性のため作者名を残す。
- 利用範囲: 同梱`License.txt`はpersonal / commercial projectsでの利用を明示している。

元ファイルのSHA-256:

| 元ファイル | SHA-256 |
|---|---|
| `switch36.ogg` | `1dd3cf29291219ab2eed0292d5c3b06b1e102ea70821099e741fc127734ffa04` |
| `switch21.ogg` | `8a3fdc5d35c74ae4ce4ec75c1f85c7f5fac1a2a6ac838353b09c48c5d7888fc9` |
| `switch31.ogg` | `bca5f3047e73d28f6619d49a45dee1984340c165da5fa49b239068c2cb9b4be1` |
| `switch7.ogg` | `7a3032d1dae63d1096cf2f1e59cb43e598d5229dcb9617e9d3fb13e96c78d5f2` |

## 3. 変換

元音源はすべて500ms未満だったため切り詰めていない。FFmpegでメタデータを除去し、System
Sound Services向けに44.1kHz・mono・16-bit linear PCMのCAFへ変換した。

```sh
ffmpeg -i <source>.ogg -map_metadata -1 -ac 1 -ar 44100 -c:a pcm_s16le <destination>.caf
```

変換後ファイルのSHA-256:

| アプリ内ファイル | SHA-256 |
|---|---|
| `capture_saved.caf` | `3e43c216c9e7695caa67423a5ea5ba8f7452c6082227d2c07bc231395864410e` |
| `mutual_reveal.caf` | `122612d7e9f9bb0599bb86331fe9c18e74203e4eac1913e9f2231096c944001d` |
| `streak_milestone.caf` | `0860705b7ff8fcf63a60011f56760876cdc2b34020bdb538476c092cec5fdbfe` → **`04c3c793d59870f46649cda43f8dd8787c7045888f9fb692caff512d04ee9e05`** (2026-09-25: `volume=-2.3dB` applied — see `.loop/backlog-triage_2026-09-24/VISION.md` T2a-T2d; original true peak measured at +0.79 dBTP, i.e. already over 0 dBTP / clipping risk, corrected to -1.51 dBTP) |
| `recoverable_error.caf` | `47d64b606f4f490e780c94f79543f4aaf7866bc2f8d95377ecc788f636365f44` |

## 4. 効果判定

- 対象指標: 保存成功後の翌日撮影率、およびClaimから7日以内の相互公開率。
- 現在値: 未測定。現行標本では効果音単独の因果効果を判定できない。
- 変更しない場合: DESIGN.mdで定義済みの重要な成功・公開・節目・失敗の演出が視覚と触覚に
  限定され、音を利用できる人への状態フィードバックが増えない。
- Bet: 少数の意味的な音だけを既存の成功・回復タイミングへ同期すると、過剰な騒がしさを
  作らず、保存完了と相互公開の理解・記憶を補助する。
- 最安検証: 既存`skygrid_capture_completed`と`skygrid_mutual_reveal_unlocked`を用い、導入後の
  7日成熟コホートを導入前と比較する。効果音専用イベントやA/B割付は追加しない。
- 撤回条件: 十分な比較母数が得られても翌日撮影率・相互公開率が改善せず、音や消音制御に
  関する不具合・苦情が増える場合は、既定値または発火場面を見直す。
## 2.1 追加3音の素材とライセンス

既存4音源の `UI Audio` とは別の公式パック／元ファイルから新規に選定した。いずれも
Kenney.nl公式配布、**Creative Commons Zero v1.0 Universal (CC0 1.0)**。AI生成音源は使用していない。

| 用途 | パック | 公式紹介URL | 取得ZIP URL | ZIP SHA-256 | 元ファイル | 元SHA-256 |
|---|---|---|---|---|---|---|
| Mokuタップ | Impact Sounds | <https://kenney.nl/assets/impact-sounds> | <https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip> | `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8` | `Audio/impactSoft_medium_000.ogg` | `7d3ba0bb5e60a11b5d3e558c141303dcf494256675fbf753c0d252d2cf0481e3` |
| 前進ナビゲーション | Casino Audio | <https://kenney.nl/assets/casino-audio> | <https://kenney.nl/media/pages/assets/casino-audio/2472606a04-1721639069/kenney_casino-audio.zip> | `f36250766ac5bc378c13708ddf12a23a8e54a3251f8d482c7536e51b5dbafa18` | `Audio/card-slide-4.ogg` | `b9c82bcdbe6b7d00a06e2546bd2683a9ab082ca5fd090a42882f33eddd925b7f` |
| 購入確定 | Interface Sounds | <https://kenney.nl/assets/interface-sounds> | <https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip> | `f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232` | `Audio/confirmation_001.ogg` | `063564703b6094d70718a3e787a55cc9141611e4ecd6b6637f8828f79b4a8c3a` |

- 取得日: 2026-09-11
- ライセンス: **CC0 1.0**（各パック同梱 `License.txt` およびKenney公式ページ）
- ライセンスURL: <https://creativecommons.org/publicdomain/zero/1.0/>
- 帰属表示: 不要。ただし追跡可能性のため本記録にKenney.nlを明記する。

## 3.1 追加3音の変換

既存4音と同じ手順で、メタデータを除去し、44.1kHz・mono・16-bit linear PCMのCAFへ変換した。

```sh
ffmpeg -i <source>.ogg -map_metadata -1 -ac 1 -ar 44100 -c:a pcm_s16le <destination>.caf
```

| アプリ内ファイル | SHA-256 |
|---|---|
| `moku_tap.caf` | `bf934c82d7790708c30df227df808c7faf56397744f2e3ce2378db7b35c60c78` |
| `forward_navigation.caf` | `74855047c1237940d1e95cb5bdad8a34e60234a8e0fbf42cb91f1dbb62f123a5` |
| `purchase_confirmed.caf` | `dd99d04b5fb98096aa0c0b8e813e535ca9f712010eb46c5cb8a7306d3220f06b` |

