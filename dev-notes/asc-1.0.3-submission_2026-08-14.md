# ASC 1.0.3(build 6)提出完了(2026-08-14)

依頼者から「バディ投稿のプッシュ通知に関して新しく作成してそのビルドをAppleの審査に提出しておいて」
と明示指示を受け、[[skygrid-asc-api-submission-2026-08-08]]の確立済み手順(Xcode GUI・ブラウザ
不要、ASC APIキーのみ)で3回目の実証を行った。

## 結果

- **build 6(1.0.3)が `WAITING_FOR_REVIEW` で審査キューに入った**
  (reviewSubmission `ca5a89ef-5e5e-4d7c-9bad-b44f0320de22`、
  `submittedDate: 2026-08-14T05:06:11.54Z`)
- `releaseType: MANUAL` — 承認されても自動公開はされない。承認後のリリース操作は
  push/本番反映と同様、依頼者の明示承認を待って別途実行する。
- What's New(en-US): 今回の3コミット(バディ投稿プッシュ通知・通知許可リクエスト拡張・
  単独ユーザー向け自動ペイウォール)の実際の変更内容に基づいて記載。

## このセッションに含まれる変更(1.0.2以降の3コミット)

1. `38ec9b3` — 単独ユーザー(バディ0人)向け自動ペイウォール
2. `ac58438` — バディ投稿プッシュ通知(バックエンド+iOS側配線)
3. `c433a2a` — バディペアリング時の通知許可リクエスト拡張

バックエンド(Cloud Functions・Firestore rules/indexes)は本ビルドの提出前に別途
`firebase deploy`済み(現行1.0.2でも動作する設計、[[buddy-post-push-notification-2026-08-14]]参照)。
このビルドが審査を通ることで、タップ時の自動遷移・フォアグラウンド中の一覧自動更新・
バディペアリング時の通知許可リクエストという**クライアント側の残り**が有効になる。

## 実施した手順(前回と同一の確立済み手順を再実行)

1. **前提確認(ブラウザで直接確認)**: Firebase Console → Cloud Messaging → Apple app
   configurationでAPNs Auth Key(Development/Production両方)が登録済みであることを確認。
   Team ID `NVZB82UK53`が`project.yml`の`DEVELOPMENT_TEAM`と一致することも確認済み。
2. `project.yml`の`MARKETING_VERSION`を`1.0.2`→`1.0.3`、`CURRENT_PROJECT_VERSION`を
   `5`→`6`に変更(SkyGrid/SkyGridWidgets両ターゲット)。**pbxprojを直接編集せず、
   project.yml編集後に`xcodegen generate`で反映**([[xcodegen-generated-pbxproj-overwrites-manual-version-bump]]
   の教訓通り)。
3. `xcodebuild archive -allowProvisioningUpdates`(バックグラウンド実行、RevenueCat等の
   依存ビルドを含め約数分)。
4. `xcodebuild -exportArchive`(`ExportOptions.plist`は前回同様
   `method: app-store-connect`, `teamID: NVZB82UK53`, `destination`キー無し)。
5. **archiveの署名を信用せず、exportしたIPAを`codesign -dvvv`で実地検証**:
   `Authority=Apple Distribution: Takumi Eto (NVZB82UK53)`、
   `TeamIdentifier=NVZB82UK53`を確認(想定通り、ミスマッチなし)。
6. `xcrun altool --validate-app` → `xcrun altool --upload-app`(APIキー認証、
   Delivery UUID `7dbad920-6be0-4f7c-93c2-3c919e24de31`)。
7. ASC REST API(`dev-notes/tools/asc.py`)で:
   - `GET /apps/6796222704/builds`(`sort`パラメータ無し)でbuild 6の
     `processingState`が`VALID`になるまでポーリング(約2分半)。
   - `POST /appStoreVersions`で1.0.3バージョン新規作成(`releaseType: MANUAL`)。
   - `PATCH /appStoreVersionLocalizations/{id}`でWhat's Newを設定
     (description/keywords/marketingUrl/promotionalTextは1.0.2から自動継承済みで
     未変更)。
   - `PATCH /appStoreVersions/{id}`でbuild 6を紐付け、`GET`で実際に紐付いたことを
     再確認。
   - `POST /reviewSubmissions` → `POST /reviewSubmissionItems` →
     `PATCH .../{id}`(`submitted: true`)で審査提出。**今回は初回でHTTP 500は
     発生せず一発成功**(前回1.0.2では発生した既知gotcha、再発なし)。

## 新たに確認できた事実

- 1.0.2は今回確認時点で既に`READY_FOR_SALE`(公開済み)だった。ただし
  `GET /appStoreVersions`で見えた`releaseType`は`AFTER_APPROVAL`——[[asc-1.0.2-submission_2026-08-13]]
  の提出時記録(`MANUAL`)と食い違う。公開済みバージョンのreleaseTypeがAPI上どう
  報告されるかの詳細は未調査(本タスクのスコープ外、公開後の値の意味を深掘りする
  必要が生じたら要再検証)。

## 未対応・引き継ぎ

- **承認後のリリース操作は依頼者の承認待ち**(push/本番反映と同じ扱い)。
- 実機2台でのE2E検証(招待リンク・バディ投稿プッシュ通知の実配信)は今回も未実施
  (物理デバイス1台の制約、依頼者本人の作業)。
- DSAトレーダーステータス未申告は引き続き未対応(依頼者本人の作業、EU配信停止リスク)。

関連ツール: `dev-notes/tools/asc.py`。関連メモリ: [[skygrid-asc-api-submission-2026-08-08]]、
[[buddy-post-push-notification-2026-08-14]]。
