# ASC 提出状況の監査 — 2026-08-09

> **同日追記（対応済み）:** 下記「見つかった問題1」のプロモーション用テキストを補填した上で、
> 1.0.1 を**リリース済み**。1.0.1 は `READY_FOR_SALE`、appInfo（サブタイトル）も
> `READY_FOR_DISTRIBUTION` に遷移。手順は末尾「実施した対応」を参照。
> **未対応で残っているのは「見つかった問題2」の DSA トレーダーステータス申告（本人作業）。**

前セッション（2026-08-08）で 1.0.1 (build 4) を審査提出し `WAITING_FOR_REVIEW` で終わっていた。
その後どうなったかをブラウザ + ASC API の両方で確認した記録。

## 結論: 審査は通過済み。あとは「リリース」ボタンを押すだけ

| 対象 | 状態 |
|------|------|
| 1.0.1 | `PENDING_DEVELOPER_RELEASE`（デベロッパによるリリース待ち） |
| 1.0 | `READY_FOR_SALE`（現在 App Store で公開中のバージョン） |
| reviewSubmission `89a423e2-…`（2026-08-08T12:52:07Z 提出） | `COMPLETE` |
| appInfo `b7c235f7-…`（名前/サブタイトル） | `PENDING_RELEASE` — 同時承認済み |
| build 4 | `processingState: VALID`、1.0.1 に紐付け済み |

`releaseType: MANUAL` なので**承認されても自動公開されない**。これが「審査に出したのに
何も起きていないように見える」状態の正体。前回セッションが手動リリースを選んでいたため。

### リリース時に適用される設定（確認済み・いずれも安全側）

- 段階的リリース: **「すべてのユーザ向けに今すぐアップデートをリリース」**（7日間の段階的リリースではない）
- 評価概要のリセット: **「既存の評価を維持」**（リリース後は復元不可の設定なので確認した。リセットではない）

## 1.0 → 1.0.1 で実際に変わるストア掲載内容

- **サブタイトル: なし → `Real alarm, daily sky ritual`**（28/30字）。2026-08-08 の ASO 対応がようやく反映される
- **キーワード**: `morning routine,sunrise,sky,photo diary,streak,…`
  → `alarm clock,wake up,sunrise,sky,streak,…`（アラーム軸を先頭へ）
- **リリースノート**: バディ修正・ストリーク表示・節目カード・Dynamic Island 改善が正しく記載済み
  （前回指摘の「Metadata update…」のままという問題は修正されている）
- 概要（description）とスクリーンショットは 1.0 から変更なし

## 見つかった問題

### 1. プロモーション用テキストが 1.0.1 で空になっている（要判断）

- 1.0: `Wake up, step outside, and capture the sky. No filters, no feed to scroll — just a quiet daily ritual that slowly becomes a year you can see.`
- 1.0.1: **`None`**

プロモーション用テキストは製品ページで概要の上に出る枠。このままリリースすると
その枠が消える。**プロモーション用テキストは審査不要でいつでも編集可能**なので、
リリース前でも後でも入れ直せる。1.0 の文面をそのまま流用するのが素直。

症状 → 原因: 新バージョン作成時にプロモーション用テキストは自動で引き継がれない。
ASC の UI では文字数カウンタが `170`（＝残り 170 字＝空）と出るだけで、
「空です」という警告は一切出ないため見落としやすい。

### 2. DSA トレーダーステータスが未申告（EU 配信停止リスク）

ビジネス > 契約 のページ最上部に赤いエラーバナー:

> コンテンツを欧州連合（EU）の App Store で配信するには、お客様がトレーダーであるか
> どうかをお知らせいただく必要があります。…「コンプライアンス要件を満たす」

- 契約類は問題なし: 無料アプリ契約・有料アプリ契約とも「有効」、銀行口座「有効」、
  納税フォーム（W-8BEN 等）「有効」
- トレーダーステータスの申告**だけ**が未完了
- 未提供のままだと EU の App Store からアプリが削除される、と Apple は告知している
- これは事業実態にもとづく**法的ステータスの自己申告**であり、住所等の個人情報の
  フォーム送信を伴う。エージェントが代行せず、本人が実施すること

### 3. 年齢制限指定に関する新しい質問（未確認・優先度低）

アプリ一覧に「ソーシャルメディア機能に関する新しい質問があなたのアプリに該当するか
確認してください」という告知。SkyGrid の年齢制限は 4+（172の国・地域）で設定済みで
審査も通っているため即時のブロッカーではないが、バディ機能があるため
「該当する」と判定される可能性はある。次回 ASC を触るときに確認する。

## 現在の実績値

- 評価: **5.0（1件）**、レビュー本文は 0 件
- 1.0 は 2026-08-06 から公開中

## 調査に使ったもの

- ASC API クライアント: 前セッションの `asc.py` をそのまま流用
  （Key ID `8NP27G4GSX` / Issuer ID は [[skygrid-asc-api-submission-2026-08-08]] 参照）
- 確認に使ったエンドポイント:
  - `GET /apps/{id}/appStoreVersions` — `appStoreState` と `releaseType`
  - `GET /apps/{id}/reviewSubmissions` — 審査の `state`
  - `GET /apps/{id}/appInfos` — 名前/サブタイトル変更の審査状態
  - `GET /appStoreVersions/{id}/appStoreVersionLocalizations` — 掲載文面の新旧比較
- **段階的リリース設定は API の `appStoreVersionPhasedRelease` が `data: null` を返す**
  （＝未設定＝即時全ユーザー公開）。`null` を前提にしないコードは例外で落ちるので注意

## 実施した対応（2026-08-09、依頼者承認のうえ実行）

### 1. プロモーション用テキストの補填

1.0 の文面をそのまま 1.0.1 へコピー（141字 / 上限170字）:

> Wake up, step outside, and capture the sky. No filters, no feed to scroll — just a quiet daily ritual that slowly becomes a year you can see.

```
PATCH /appStoreVersionLocalizations/852e763c-4cd1-4623-ad05-117a2ba15d84
{"data": {"type": "appStoreVersionLocalizations", "id": "…",
          "attributes": {"promotionalText": "…"}}}
```

- `PENDING_DEVELOPER_RELEASE` の状態でも**プロモーション用テキストは PATCH できる**（200）。
  再審査にも入らず、状態は `PENDING_DEVELOPER_RELEASE` のまま維持された
- 文面に em dash（`—`）が入るので、シェル引数で渡さずスクリプト内のリテラルで持ち、
  **PATCH 後に GET で読み戻して文字化けしていないことを確認した**

### 2. 1.0.1 のリリース

```
POST /appStoreVersionReleaseRequests
{"data": {"type": "appStoreVersionReleaseRequests",
          "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": "7c632151-…"}}}}}
→ 201
```

- **リリースは `appStoreVersions` の PATCH ではなく、`appStoreVersionReleaseRequests` の
  POST**。「リリース」を状態更新だと思って PATCH を探すと見つからない
- 実行前に `appStoreState == PENDING_DEVELOPER_RELEASE` をガードしてから POST するスクリプトにした
  （不可逆操作なので、状態が想定外なら実行しない）
- 反映は速い: POST から**5秒後のポーリングで既に `READY_FOR_SALE`**
- 副作用として appInfo（名前/サブタイトル）も同時に `READY_FOR_DISTRIBUTION` へ遷移し、
  ASC 上の 1.0 の行は消えて 1.0.1 が現行バージョンになった

スクリプトは `/private/tmp/claude-501/-Users-taku8/<session>/scratchpad/`（`asc.py`,
`set_promo.py`, `release.py`）。scratchpad はセッション毎に消えるので、再利用するなら
`asc.py` だけプロジェクトに移すこと。
