# サポート/プライバシーポリシーページのCloudflareデプロイ(2026-07-30)

## 内容

`ios/legal/privacy-policy.md` / `ios/legal/support.md` が原本(実際のデータフロー — Firebase Auth/Firestore/Storage/FCM、RevenueCat、Apple StoreKitに基づく正確な内容。汎用テンプレートの丸写しではない)。`ios/legal/site/` にHTML版を作成し、Cloudflare Workers(静的アセット配信)としてデプロイ。

依頼者の確認事項(このセッションで確認済み):
- ホスティング先: Cloudflare Pagesではなく最終的にWorkers静的アセット(下記理由)
- サポートメール: `taku810616@gmail.com`(個人アドレスをそのまま公開する判断)

## デプロイ先

- https://skygrid-legal.taku810616.workers.dev/ (サポート)
- https://skygrid-legal.taku810616.workers.dev/privacy (プライバシーポリシー)

`ios/SkyGrid/Config/Secrets.xcconfig` / `Secrets.example.xcconfig` の `SKYGRID_SUPPORT_URL` / `SKYGRID_PRIVACY_POLICY_URL` に反映済み、build_sim確認済み。

## ハマった点

**Pages→Workersへの経路変更:** `wrangler pages deploy`を試みたところ`The Pages project "skygrid-legal" does not exist`エラー。Cloudflareは現在Pagesより新規プロジェクトをWorkers(静的アセット機能付き)で作ることを推奨している(エラーメッセージ自体がその旨を明示)。加えてユーザーの既存スタック(`~/.claude/CLAUDE.md`のPrimary Stack表)がそもそも「Cloudflare Workers」であり、Pagesとの併用は不要な二重管理になる。`wrangler.toml`に`[assets] directory = "./site"`を追加し`wrangler deploy`でWorkers側にデプロイする方式に切り替えた。

**事故: Wrangler CLIのローカルキャッシュファイルが一時的に公開アセットとして配信された。** 経緯: `wrangler pages deploy`を`legal/site`ディレクトリ内で実行した際、失敗はしたものの副作用として`site/.wrangler/cache/wrangler-account.json`(CloudflareアカウントIDとアカウント名のみ、APIトークン等の機密は含まない)が作成された。直後の`wrangler deploy`(assetsディレクトリ=`./site`)がこのファイルを「6 files from the assets directory」の1つとして検出し、実際に本番URLへ一瞬アップロードされてしまった。

- 検出: デプロイ後に自分でstray fileの存在に気づきURLを直接叩いて確認
- 対応: `site/.wrangler`と`legal/.wrangler`を削除→再デプロイ(マニフェストが3ファイルのみになったことを確認)→キャッシュバスター付きcrurlで実際に404になったことを確認(Cloudflareエッジキャッシュに一瞬古い200が残っていたが、実体は消えていた)
- 実害: アカウントID+アカウント名(依頼者のメールアドレス由来の表示名)のみで、APIトークン等の機密情報は含まれていなかったため実質的なセキュリティリスクは低いと判断
- **教訓: `wrangler pages deploy`と`wrangler deploy`(assets)を同じディレクトリで試行錯誤する際は、失敗した試行のあとに必ず`.wrangler`ディレクトリの残留を確認してから次のデプロイを実行すること。** 今後の事故防止のため`.gitignore`に`ios/legal/.wrangler/`と`ios/legal/site/.wrangler/`を追加済み

## 結論

App Store提出・App Review Guideline 1.2で必要な実URL(サポート・プライバシーポリシー)が確保された。
