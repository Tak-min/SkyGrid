---
name: asc-1.0.6-submission_2026-09-08
description: SkyGrid 1.0.6 (build 10) の審査提出記録
---

# 1.0.6 (build 10) App Store 審査提出

2026-09-08、codexが実装した1.0.6 build 10（複数曜日アラーム、日付境界修正、
コンパニオンオンボーディング、初回報酬後ペイウォール）を
`~/.appstoreconnect`のAPIキーのみ（ブラウザ・Xcodeアカウントログイン未使用）で
アーカイブ〜審査提出まで完了。

## 実施内容

1. コミット `4b737ab`（HEAD、テスト309/309 pass）を対象に
   `xcodebuild archive -allowProvisioningUpdates` + ASC APIキー認証で再アーカイブ。
   - 既存の `~/.cache/skygrid-1.0.6-b10/SkyGrid.xcarchive` は
     `Apple Development` 証明書で署名されており流用不可と判明
     （[[skygrid-asc-api-submission-2026-08-08]]で警告されていた通り、
     archiveログだけでは正しい署名を保証しない）。
   - ローカルキーチェーンに `Apple Distribution` 証明書が存在しなかったため、
     `-exportArchive -allowProvisioningUpdates` にAPIキー認証を渡すことで
     証明書を自動作成させ、`Apple Distribution: Takumi Eto (NVZB82UK53)` で
     再署名したIPAを取得（`codesign -dvvv`で実地確認済み）。
2. `altool --validate-app` → `--upload-app`（build 10、Delivery UUID
   `ea4e6e11-b925-4955-a8f7-6f594dea4eed`）。アップロード後、
   `processingState: VALID` まで数分で到達。
3. ASC APIで `appStoreVersions` 1.0.6 を新規作成し、build 10を紐付け。
4. リリースノート（en-US）を実際の変更内容に合わせて記載
   （複数アラーム/日付境界修正/コンパニオンオンボーディング/
   ペイウォール位置変更の4行）— 前回の「Metadata update」使い回しの
   ハマりどころを回避。
5. `reviewSubmissions` → `reviewSubmissionItems`（appStoreVersion 1.0.6を添付）→
   `PATCH { submitted: true }` で提出完了。

## 結果

- reviewSubmission id: `2771c2b4-8833-442e-8e81-35e50af9a421`
- state: `WAITING_FOR_REVIEW`（submittedDate `2026-09-08T05:48:46Z`）
- 提出前の1.0.5は`READY_FOR_SALE`のまま販売継続中（審査中も旧バージョンは
  引き続き配信される）。

## 新たに判明したハマりどころ

- **ローカルにDistribution証明書が1つも無い状態からの提出は、archiveだけでなく
  `exportArchive`側にも`-allowProvisioningUpdates`+APIキー認証を渡す必要がある。**
  `xcodebuild archive -allowProvisioningUpdates`は（Automatic Signingでも）
  必ずしもDistribution証明書を新規作成してくれるとは限らず、
  ローカルにあった`Apple Development`証明書で署名して`ARCHIVE SUCCEEDED`を返した。
  実際に証明書が新規作成されたのは`exportArchive`にも同じ認証情報を渡した時点。

関連: [[skygrid-asc-api-submission-2026-08-08]]
