# ASC 1.0.2(build 5)提出完了(2026-08-13)

updated: 2026-08-13

依頼者から「ASC提出は自律的に行なってよい、ログイン情報(=ASC APIキー)は残してある」と
明示承認を得たため、`~/.appstoreconnect/private_keys/AuthKey_8NP27G4GSX.p8`
(Key ID `8NP27G4GSX` / Issuer `58c05121-f8df-456e-bff8-00455e0fbc79`、
[[skygrid-asc-api-submission-2026-08-08]] で確立済み)を使い、Xcode GUIなしで
アーカイブ〜審査提出まで完結させた。

## 結果

- **build 5(1.0.2)が `WAITING_FOR_REVIEW` で審査キューに入った**
  (reviewSubmission `fad0f7f5-…`、`submittedDate: 2026-08-13T06:13:03Z`)
- `releaseType: MANUAL` — 承認されても自動公開はされない(1.0.1と同じ安全設定を踏襲)。
  承認後の「リリース」ボタン相当の操作(`appStoreVersionReleaseRequests` POST)は、
  push/本番反映と同様に**依頼者の明示承認を待って別途実行する**
- What's New(en-US): 招待リンク・バディのライブ反映修正・ペイウォール頻度低減の3点を
  実際の変更内容に基づいて記載(過去に「Metadata update…」のまま放置していた反省を踏まえ、
  提出前に内容を実態と突き合わせ済み)
- プロモーション用テキストは1.0.1のものをそのまま継承(空のまま提出すると製品ページの
  枠が消える、という既知の落とし穴を踏まえ先回りで設定)

## 実施した手順(すべて自分で実行・確認、報告の丸写しなし)

1. `xcodebuild archive -allowProvisioningUpdates` + ASC APIキー認証
   → **アーカイブ自体は `Apple Development: taku810616@icloud.com (32ZRVW6HP8)` という
   別チームの開発証明書で署名された**(下記Gotcha参照)。ARCHIVE SUCCEEDEDの表示だけでは
   配布可能とは判断せず、次のexport結果で実際に検証した
2. `xcodebuild -exportArchive`(`method: app-store-connect`, `destination: export`,
   `teamID: NVZB82UK53`)→ **exportステップが正しいDistribution証明書で再署名**することを
   `codesign -dvvv` と埋め込みprovisioning profileの実地確認で検証
   (`Authority=Apple Distribution: Takumi Eto (NVZB82UK53)`、
   `iOS Team Store Provisioning Profile: com.takmin.skygrid`)
3. `xcrun altool --validate-app` → `xcrun altool --upload-app`(共にAPIキー認証、
   Xcodeアカウントログイン不要)
4. ASC REST API(自作JWT署名、`dev-notes/tools/asc.py`)で:
   - `GET /apps?filter[bundleId]=...` でapp ID確認(`6796222704`)
   - `POST /appStoreVersions` で1.0.2バージョン新規作成(`releaseType: MANUAL`)
   - `PATCH /appStoreVersionLocalizations/{id}` でWhat's New・プロモーション文言を設定
   - `GET /apps/{id}/builds` でbuild 5の`processingState`が数分以内に`VALID`になったことを確認
   - `PATCH /appStoreVersions/{id}` でbuildを紐付け
   - `POST /reviewSubmissions` → `POST /reviewSubmissionItems` → `PATCH .../{id}`
     (`submitted: true`)で審査提出

## Gotcha

- **archiveステップの署名アイデンティティは信用できない。exportステップの出力を必ず
  実地検証すること。** `xcodebuild archive -allowProvisioningUpdates`は、
  `project.yml`の`DEVELOPMENT_TEAM: NVZB82UK53`を指定していても、ローカルkeychainに
  たまたま存在した別チーム(`32ZRVW6HP8`、実機デバッグ用の個人Apple ID)の
  Development証明書で黙って署名してARCHIVE SUCCEEDEDを返した。これだけを見て
  「正しいチームで署名された」と判断するのは誤り。実際にはexportArchiveのステップで
  `-exportOptionsPlist`に明示`teamID: NVZB82UK53`を指定すれば正しいDistribution証明書
  (存在しなければ自動生成)で再署名される。**署名の正しさは`codesign -dvvv`の
  `TeamIdentifier`/`Authority`出力で確認する、ログの"SUCCEEDED"文字列だけでは判断しない。**
- **`PATCH /reviewSubmissions/{id}` with `submitted: true` が初回HTTP 500で失敗した。**
  即座にリトライせず、まず`GET`で`submittedDate`/`state`を確認して未送信
  (`READY_FOR_REVIEW`のまま)であることを確かめてから再試行した。500エラーは
  Apple側で実際に処理が進んでいる可能性もあるため、確認なしの機械的リトライは
  二重送信のリスクがある。再試行は成功し`WAITING_FOR_REVIEW`に遷移した。
- `GET /apps/{id}/builds` に `sort` パラメータを付けると
  `PARAMETER_ERROR.ILLEGAL: The parameter 'sort' can not be used with this request`
  で400。buildsエンドポイントはsort非対応、`limit`のみで十分(直近アップロードは
  先頭付近に出る)。

## 未対応・引き継ぎ

- **承認後のリリース操作(依頼者の承認待ち)**: 審査通過後、`PENDING_DEVELOPER_RELEASE`に
  なった時点で`asc-submission-status-audit_2026-08-09.md`と同じ手順
  (`POST /appStoreVersionReleaseRequests`)でリリースできる。ただし実行前に
  依頼者の承認を得ること(pushと同じ扱い)
- **Slice 9-10の実機E2E・Associated Domains実機検証は今回も未実施**
  (`invite-link-version-bump-slice9_2026-08-12.md`参照、物理デバイスが必要なため)。
  審査通過までに依頼者側で実施しておくのが望ましい(招待リンクのUniversal Linkが
  実機で機能しない場合、審査自体は通っても機能が壊れた状態でリリースすることになる)
- ローカルコミット(push未実施)は Slice 1〜9 の9コミットに加えてバージョン管理系の
  変更なし(build成果物`ios/build/`はgit管理外、`.gitignore`要確認)

関連ツール: `dev-notes/tools/asc.py`(JWT署名込みのASC APIクライアント、Key ID/Issuer IDは
ハードコードなので使い回す場合は要確認)。
