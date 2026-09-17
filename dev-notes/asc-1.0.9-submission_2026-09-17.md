---
name: asc-1.0.9-submission_2026-09-17
description: SkyGrid 1.0.9 (build 13) の審査提出記録。1.0.8以降のHEAD(バディ通知強化・早期採用者Pro付与・Moku/Today刷新・日本語化バグ修正)を同梱。実機ビルド確認後に提出。
---

# 1.0.9 (build 13) App Store 審査提出

2026-09-17、依頼者の明示的な指示に基づき提出。

## 経緯

- セッション開始時、依頼者から「実機で確認してからApp Storeへ提出」の指示。
- 調査の結果、1.0.8 (build 12) はセッション開始時点で既に **READY_FOR_SALE**（審査承認・一般公開済み）と判明（当初、私はdev-notesの古い記述からWAITING_FOR_REVIEWだと誤認したが、依頼者の指摘でASC APIを直接叩いて READY_FOR_SALE を確認）。
- 1.0.8のアーカイブ以降、HEADは12コミット進んでいた（バディリクエスト/連続記録通知、早期採用者100名無償Pro付与、Moku/Today home刷新、ペイウォール日本語化バグ修正、日本語化の大幅追加など）。
- 実機（"俺のGALAXY Pro Max"、iPhone 15 Pro、iOS 26.6.2、USB接続）へ現HEADからDebugビルドをインストール・起動し、プロセスが安定して稼働することを確認（`xcrun devicectl`経由。argent MCPはiOS実機を未サポートのため使用不可、xcode-native MCPも本セッションでは未接続）。
- 依頼者の指示: 「スクリーンショットはASC提出用途ではなく、UI把握・改善用途で別途撮影する。既存のASC素材（1.0.5時点）のままでよいので、現在のバージョンの作業が完了しているなら先に審査提出を進めてほしい」。

## 実施内容

1. `SkyGridTests`全351件がHEAD上でグリーンであることを確認（iPhone 17シミュレータ）。
2. `ios/project.yml`の`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`を`1.0.8/12` → `1.0.9/13`に変更、`xcodegen generate`で反映（コミット`12877c0`）。
   - 既存ビルド番号の最大値（12）をASC APIで確認してから13を採番。
3. `xcodebuild archive -allowProvisioningUpdates` + ASC APIキー認証で`~/.cache/skygrid-1.0.9-b13/SkyGrid.xcarchive`を作成。
4. `-exportArchive`（`ExportOptions.plist`、method=app-store-connect）+ 同APIキー認証で`.ipa`を書き出し。`codesign -dvvv`で`Apple Distribution: Takumi Eto (NVZB82UK53)`署名を実地確認。
5. `altool --validate-app` → `--upload-app`（build 13、Delivery UUID `2f5df994-a596-43ff-8970-0db424ec16fb`）。アップロード後`processingState: VALID`まで約2分。
   - 検証時、PrivacyInfo.xcprivacyが未整備であることを確認済みだが、`--validate-app`はエラーなしで通過した（1.0.6〜1.0.8も同様に通過しているため、現状のAPI利用範囲では必須ではない模様）。
6. ASC APIで新規`appStoreVersions` 1.0.9を作成（`releaseType: AFTER_APPROVAL`を前バージョンに合わせて明示指定）。
7. `PATCH /appStoreVersions/{id}`の`relationships.build`でbuild 13を紐付け。
8. `appStoreVersionLocalizations`の`whatsNew`（en-US / ja、ロケールコードは`ja-JP`ではなく`ja`）を今回の変更点に基づいて新規記入（前バージョンからは空の状態で複製されるため必須。1.0.8提出時は気づかず未設定だった可能性あり、今回`reviewSubmissionItems`のPOSTで409エラーとして表面化し判明）。
9. `reviewSubmissions` → `reviewSubmissionItems`（appStoreVersion 1.0.9を添付）→ `PATCH { submitted: true }`で提出完了。

## 結果

- appStoreVersion id: `50084add-46db-4c36-9bb8-a622d02a5b23`
- reviewSubmission id: `635a5849-ed5e-456a-a5be-a75580b65cd8`
- state: `WAITING_FOR_REVIEW`（submittedDate `2026-09-17T12:34:58Z`）
- releaseType: `AFTER_APPROVAL` — 承認され次第、追加操作なしで自動的に一般公開される。
- ja向け・en向けスクリーンショットは1.0.5時点のものを流用（依頼者の明示指示により、今回は更新不要と判断）。

## 新事実（次回セッション向け）

- **`whatsNew`は新規`appStoreVersion`作成時に前バージョンから複製されない/空になる。** `reviewSubmissionItems`をPOSTする前に、対象ロケール全ての`appStoreVersionLocalizations.whatsNew`を明示的にPATCHしておく必要がある（さもないと409 `ENTITY_ERROR.ATTRIBUTE.REQUIRED`）。
- **`/apps/{id}/builds`エンドポイントは`filter[version]`をサポートしない。** `sort`パラメータも同様に拒否される（1.0.8提出時のメモには記載なし）。ビルド番号で絞り込みたい場合は`limit`を上げて全件取得しクライアント側でフィルタする。
- 実機実行はargent MCPの対象外（iOSシミュレータ/Android/Chromiumのみ対応）。物理iOS実機の起動確認は`xcrun devicectl device process launch`、画面キャプチャは`idevicescreenshot`（screenshotr要件で失敗する場合あり、現行iOSでは要検証）で代替。

## 次回セッションで確認すべきこと

1. 1.0.9の審査結果（承認/却下）。承認されれば自動公開されるはずなので、`appStoreVersions/50084add-46db-4c36-9bb8-a622d02a5b23`の`appStoreState`が`READY_FOR_SALE`になっているか確認する。
2. `QA_DENYLIST`（`ios/functions/src/earlyAdopterGrantStore.ts:20`）へ運用者自身のuidを登録し、`campaigns/earlyAdopter100`の`phase`を`"live"`に変更する作業は依頼者自身の対応のまま、未着手。
3. 依頼者の指示通り、実機で実際にアプリを操作しながらUI把握用のスクリーンショットを撮影する（ASC提出用途ではない）。必要であれば既存アカウントを削除してオンボーディングから撮り直してよいとの了承あり。
4. `PrivacyInfo.xcprivacy`は依然未整備。現状は提出のブロッカーになっていないが、将来のApple側ルール強化に備えて追加を検討。

関連: [[skygrid-asc-api-submission-2026-08-08]] [[asc-1.0.8-submission_2026-09-16]]
