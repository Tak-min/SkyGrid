---
name: asc-1.0.9-resubmission-build14_2026-09-17
description: 審査待ちだった1.0.9 (build 13) を依頼者の指示で取り下げ、外観設定機能・オンボーディング競合修正・招待リンク送信必須化を含むbuild 14として再提出した記録。
---

# 1.0.9 build 13 の取り下げ → build 14 の再提出

2026-09-17、依頼者の明示的な指示（「審査に出しているものを一度取り消して、改修版を提出し直す」）に基づき実施。

## 取り下げた理由

同セッション内で以下を実装・コミットした後、審査中のbuild 13にはまだ含まれていないと判断されたため:

- `feat: add explicit light/dark/system appearance setting (iOS)` (`ebf7bfc`)
- `fix: stop the onboarding walkthrough from racing the first-capture camera` (`c6a079f`)
- `fix: require an actual share tap before onboarding invite can continue` (`25f9fd0`)

## 取り下げ手順

1. `reviewSubmissions/635a5849-...`（build 13を含む、`WAITING_FOR_REVIEW`）に対し
   `PATCH { attributes: { canceled: true } }`。
   - `state`が`CANCELING` → 約80秒後に`COMPLETE`へ遷移。
   - 対応する`appStoreVersions/50084add-...`（1.0.9）の`appStoreState`は
     `DEVELOPER_REJECTED`になった（ASC UIの「審査からの削除」と同義の状態）。
2. **新事実**: `reviewSubmissions`のキャンセルは`attributes.canceled: true`のPATCHで行う
   （`state`を直接書き換える方式ではない）。1.0.8提出時のメモには記載がなかった手順。

## 再提出手順（1.0.8/1.0.9初回提出と基本同じ）

1. `ios/project.yml`の`CURRENT_PROJECT_VERSION`を`13` → `14`に変更
   （`MARKETING_VERSION`は`1.0.9`のまま — 未公開のバージョンを差し替えるだけなので
   バージョン番号自体は上げていない）、`xcodegen generate`で反映
   （コミット`ce6311d`）。
2. `SkyGridTests`全359件がHEAD上でグリーンであることを再確認。
3. `xcodebuild archive` → `-exportArchive` → `codesign`で
   `Apple Distribution: Takumi Eto (NVZB82UK53)`署名を確認 →
   `altool --validate-app` → `--upload-app`（build 14、Delivery UUID
   `a9bc4324-8453-4a93-8f21-e13e10782a7c`）。アップロードから`processingState: VALID`
   まで約90秒。
4. **新事実**: `DEVELOPER_REJECTED`状態の既存`appStoreVersion`（1.0.9）に対して、
   新規`appStoreVersion`を作らずそのまま`relationships.build`をPATCHして新ビルドを
   紐付けるだけで、`appStoreState`が自動的に`PREPARE_FOR_SUBMISSION`へ戻った
   （新バージョンの作成もローカライズの再入力も不要だった）。
5. `whatsNew`（en-US/ja）は初回提出時に設定済みのものがそのまま残っていたため、
   再入力不要で`reviewSubmissionItems`のPOSTが一発で通った（前回は409で気づいた
   落とし穴が今回は発生しなかった）。
6. `reviewSubmissions`を新規作成 → `reviewSubmissionItems`（appStoreVersion 1.0.9を
   添付）→ `PATCH { submitted: true }`で提出完了。

## 結果

- reviewSubmission id: `e121beed-f7b2-43ba-9eab-f07f8cc02ee6`
- state: `WAITING_FOR_REVIEW`（submittedDate `2026-09-17T13:56:05Z`）
- releaseType: `AFTER_APPROVAL`（据え置き）— 承認され次第、追加操作なしで自動的に
  一般公開される。
- 対象build: 14（1.0.9、HEADコミット`25f9fd0`まで反映）。

## 次回セッションで確認すべきこと

1. build 14の審査結果。承認されれば自動公開されるはずなので、
   `appStoreVersions/50084add-46db-4c36-9bb8-a622d02a5b23`の`appStoreState`が
   `READY_FOR_SALE`になっているか確認する。
2. `QA_DENYLIST`のFunctionsデプロイは依頼者ご本人が実行済みとの申告あり（本セッションでは
   `firebase functions:list`での再検証はしていない — 次回、必要であれば確認）。

関連: [[asc-1.0.8-submission_2026-09-16]] [[asc-1.0.9-submission_2026-09-17]]
