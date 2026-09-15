---
name: asc-1.0.8-submission_2026-09-16
description: SkyGrid 1.0.8 (build 12) の審査提出記録。en/ja翻訳完了版+Pro価値再設計を同梱、ja-JPのApp Store掲載情報をAPI経由で新規登録。
---

# 1.0.8 (build 12) App Store 審査提出

2026-09-16、依頼者の明示的な指示（自律的にASCへ新バージョンとして公開する）に基づき、
`~/.appstoreconnect`のAPIキーのみでアーカイブ〜審査提出まで完了。

## 内容

- コミット `345c365`（HEAD、336/336 iOSテスト・83/83 Functionsテストpass）を対象。
- 同梱した機能:
  - en/ja 完全ローカライズ（stage1: `9830b29`、stage2: `8cc49e8`）
  - Pro価値再設計（Circle上限撤廃、バディ比較ビュー、週次リキャップ）（`eaa0678`）
  - 追加グロース施策（このセッションで実装、1.0.8には未反映 — 下記「重要な注記」参照）

## 重要な注記：グロース4項目はこのビルドに含まれていない

このセッションで実装した紹介コード欄・共有カード招待リンク・封印カード意匠・通知4種は
コミット `88007e4`/`13aace7`/`345c365`（封印カードのみ）で **1.0.8のアーカイブ後に**
mainへコミットされたため、**build 12には含まれていない**。次回リリース（1.0.9想定）で
含める。C4（通知4種）はさらに別ワークツリーで未マージのまま（Opusレビュー待ち）。

## 実施内容

1. `feat/localization-en-ja` を `main` へfast-forward merge（`4d8d0d5..8cc49e8`）。
2. `ios/project.yml` の `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` を `1.0.6/10` →
   `1.0.8/12` に変更、`xcodegen generate` で反映（コミット `b92e3ca`）。
   - **新事実**: ローカルの`project.yml`は提出済みの1.0.6のまま止まっていたが、
     ASC上では実際には**1.0.7 (build 11)まで既にREADY_FOR_SALE（公開済み）**だった
     （2026-09-09公開、コミット`05ed4bd`「chore: build 11 for 1.0.7」に対応する版）。
     `project.yml`への版数反映を伴わないコマンドライン版数オーバーライドで提出された
     ものと推測される（[[xcodegen-generated-pbxproj-overwrites-manual-version-bump]]の
     再発）。今回は`project.yml`自体を書き換えたため、今後この種の乖離は起きないはず。
   - 既存ビルド番号の最大値（11）をASC APIで確認してから12を採番、衝突を回避。
3. `xcodebuild archive -allowProvisioningUpdates` + ASC APIキー認証で
   `~/.cache/skygrid-1.0.8-b12/SkyGrid.xcarchive` を作成。
4. `-exportArchive`（`ExportOptions.plist`、`destination`キーなし=export専用）+
   同APIキー認証で `.ipa` を書き出し。`codesign -dvvv`で`Apple Distribution: Takumi Eto
   (NVZB82UK53)`署名を実地確認済み。
5. `altool --validate-app` → `--upload-app`（build 12、Delivery UUID
   `99ffb614-30be-4c89-b923-0fcc9e475251`）。アップロード後 `processingState: VALID` まで
   約1分。
6. ASC APIで新規 `appStoreVersions` 1.0.8 を作成（`POST`、409無し — 前バージョンが
   審査待ちのままではなかったため通常のPOSTで通った）。
7. **ja-JPのApp Store掲載情報をAPI経由で新規登録**（依頼者の明示指示により、従来の
   「ASC登録はオーナー自身の作業」というブリーフの分担を今回撤回）。
   - `appInfoLocalizations`（アプリ名・サブタイトル・プライバシーポリシーURL）:
     ロケールコードは **`ja`**（`ja-JP`ではない）でないと`409 ENTITY_ERROR.ATTRIBUTE.INVALID
     'ja-JP' is not a valid locale`になる。**新事実**: appInfo階層のロケールコードは
     `ja`、appStoreVersion階層も同様に`ja`だった（`ja-JP`は使えない）。
   - 新規appStoreVersion作成直後は自動的に編集可能な新しい`appInfo`
     （`appStoreState: PREPARE_FOR_SUBMISSION`）が生成される。既存の
     `READY_FOR_SALE`状態の`appInfo`へは直接ローカライズを追加できない
     （`409 ENTITY_ERROR.RELATIONSHIP.INVALID`）。新しい方を使うこと。
   - `appStoreVersionLocalizations`は新規バージョン作成時に前バージョンの
     ロケール一覧（en-US, ja）が自動的に複製されて存在するため、`POST`ではなく
     `PATCH`で内容を書き換える（`POST`は409 duplicate）。
8. `PATCH /appStoreVersions/{id}` の `relationships.build` でbuild 12を紐付け。
9. `reviewSubmissions` → `reviewSubmissionItems`（appStoreVersion 1.0.8を添付）→
   `PATCH { submitted: true }` で提出完了。ja向けスクリーンショット未整備のまま
   だったが、提出時にブロックされなかった（未検証だが、既存ロケールのスクリーンショット
   への自動フォールバックがある可能性）。

## 結果

- reviewSubmission id: `c40f2dd9-61bc-42f8-92ee-f3db539486fd`
- state: `WAITING_FOR_REVIEW`（submittedDate `2026-09-15T19:20:58Z`）
- releaseType: `AFTER_APPROVAL`（前バージョン1.0.6/1.0.7と同じ設定を踏襲）—
  **承認され次第、追加操作なしで自動的に一般公開される**。依頼者の明示指示
  （「審査承認後、一般公開まで自動で完了」）に合わせた設定。
- 提出前の1.0.7は`READY_FOR_SALE`のまま販売継続中。

## 次回セッションで確認すべきこと

1. 1.0.8の審査結果（承認/却下）。承認されれば自動公開されるはずなので、
   `appStoreVersions/7bbbd831-5db4-4f68-b2aa-1061162d1333`の`appStoreState`が
   `READY_FOR_SALE`になっているか確認する。
2. ja-JPストアページのスクリーンショットが実際に必要か（未登録のまま通ったが、
   Appleのレビューで指摘される可能性は残る）。
3. グロース4項目（紹介コード・共有カード招待リンク・封印カード意匠・通知4種）を
   含む次バージョン（1.0.9想定）の準備。C4はワークツリー
   `.claude/worktrees/agent-a03a14505e69bb8bb`（ブランチ`worktree-agent-a03a14505e69bb8bb`、
   コミット`025a516`）に未マージのまま。

関連: [[skygrid-asc-api-submission-2026-08-08]]
