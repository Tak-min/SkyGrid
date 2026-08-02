# App Check デバッグトークンの不一致 — 写真アップロード失敗の再発（2026-07-31）

## 症状

依頼者から「写真が撮れない(=投稿できない)問題がまだ残っている」との報告。
[dev-notes/real-device-bugfix-round_2026-07-30.md](real-device-bugfix-round_2026-07-30.md) の
「1. 写真アップロード失敗」で一度根本原因を特定・修正したはずだったが、実機での再現が続いていた。

## 調査手順（サーバー側を直接確認）

`gcloud auth print-access-token` でFirebase App Check Admin APIを直接叩いて事実を確認:

```bash
curl .../v1/projects/sky-grid-app/services
# → firestore.googleapis.com / firebasestorage.googleapis.com ともに ENFORCED（正しい）

curl .../v1/projects/sky-grid-app/apps/{appId}/debugTokens
# → 1件登録あり: name=".../debugTokens/ZTRlM2VhOWQtNDdlNy00OGVlLTk5Y2YtZWZmODBmYTdhYTlk"
```

## 発見した根本原因

**Firebase App Check の debugTokens リソース名の末尾セグメントは、トークン文字列そのものの
base64エンコードである。** これをデコードすると:

```
echo "ZTRlM2VhOWQtNDdlNy00OGVlLTk5Y2YtZWZmODBmYTdhYTlk" | base64 -d
→ e4e3ea9d-47e7-48ee-99cf-eff80fa7aa9d
```

つまり **サーバー側に実際に登録されているデバッグトークンの値は `e4e3ea9d-47e7-48ee-99cf-eff80fa7aa9d`**
だった。しかし `ios/SkyGrid/Config/Secrets.xcconfig` の `APP_CHECK_DEBUG_TOKEN` には
`2920ed9c-3a77-4d4d-ad35-85bbfa4eec33`（前回セッションのdev-noteに記載されていた値）が入っていた
——**この2つの値は一致していなかった**。

クライアントが送るデバッグトークンの値がサーバーに登録された値と一致しない限り、App Check の
デバッグプロバイダはトークン交換に失敗し、enforcement が ENFORCED である以上 Firestore/Storage への
全リクエストが拒否される。これは前回セッションで特定した「schemeのenvironmentVariablesがdevicectl
経由の起動に伝播しない」問題とは**別の、独立した原因**であり、Info.plist配線自体（2026-07-30〜31に
修正済み）は正しく機能していた——配線されていた**値そのものが最初から間違っていた**。

**原因の推測(未確定):** 前回セッションのdev-noteに記録された `2920ed9c-...` が、実際にPOSTで
登録した値と最初から異なっていた(記録ミス、またはPOST時に別のUUIDを生成してしまった)可能性が高い。
検証はしていない——重要なのは「今、サーバーとクライアントの値が不一致だった」という事実。

## 対応

`Secrets.xcconfig`(gitignore対象、ローカルのみ)の `APP_CHECK_DEBUG_TOKEN` を、サーバーに実際に
登録されている値 `e4e3ea9d-47e7-48ee-99cf-eff80fa7aa9d` に書き換えた。Firebase側は一切変更していない
(追加登録も削除も無し)——クライアント側の値をサーバーの実際の値に合わせただけ。

## 検証

1. `build_sim` → 生成された `.app/Info.plist` の `SGDebugAppCheckToken` が
   `e4e3ea9d-47e7-48ee-99cf-eff80fa7aa9d` になっていることを`PlistBuddy`で確認。
2. 実機(`俺のGALAXY Pro Max` / iPhone 15 Pro)向けに `xcodebuild ... -destination 'id=00008130-...'`
   でビルド → 同様にInfo.plistの値を確認 → `xcrun devicectl device install app` →
   `xcrun devicectl device process launch` で実機に再インストール・起動済み。
3. **実際にFirestore/Storageへの書き込みが成功するかは、依頼者本人が実機で写真を撮って確認する
   必要がある。** このセッションからは実機のコンソールログ/画面を直接観測する手段がなく、
   「サーバー側の値と一致した状態で最新ビルドを実機に再インストールした」ところまでしか確認できていない。

## 次回セッションへの教訓

- **debugTokensのリソース名からトークン値を逆引きできる**ことを知っておくと、「登録したはずの値」と
  「実際にサーバーにある値」がズレていないかを、Firebase Consoleを開かずAPI経由で直接検証できる。
  今回のように、dev-noteに記録された値を疑いなく信頼して次のセッションに引き渡すと、記録ミスに
  気づかず同じ症状が再発する。**登録済みトークンの「値」は、その場でこの方法で確認し、
  設定ファイルの値と文字列比較してから「一致している」と結論づけること** — displayNameや
  updateTimeだけでは値の一致を保証しない。
- App Check関連の不具合調査では、(a) enforcementモード、(b) Info.plist配線の到達、(c) 配線されている
  「値」そのものの妥当性、の3つを別々に検証すること。前回セッションは(a)(b)を修正したが(c)を
  検証しておらず、症状が再発した。
