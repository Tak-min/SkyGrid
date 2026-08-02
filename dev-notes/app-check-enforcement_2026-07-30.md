# App Check enforcementの有効化(2026-07-30)

## 背景

VISION.mdで2回以上「App Check APIは有効化済みだが、Firestore/Storageへの強制モードは未設定」と記載されていた既知の残課題。

## 現状確認(実行前)

Firebase App Check Admin API(`firebaseappcheud.googleapis.com`)を直接叩いて事実を確認:
- `GET .../projects/sky-grid-app/services` → `{}`(全サービス未設定=UNENFORCED、コンソールを開かなくてもAPIで確認可能)
- `GET .../apps/{appId}/appAttestConfig` → 既に存在(`tokenTtl: 3600s`)。**iOS側の`AppAttestProviderFactory`(Release)に対応するApp Attestプロバイダ登録は、手動作業不要で既に自動生成されていた**(VISION.mdの「未確認」だった点はこれで解消)
- `GET .../apps/{appId}/debugTokens` → `{}`(Debug用トークン未登録)

## 懸念とその解消手順

Debug buildは`AppCheckDebugProviderFactory`を使う(`AppDelegate.swift`)。これはアプリ起動のたびにランダムなトークンを生成する仕組みのため、**Firebase Console(またはAPI)に固定トークンを事前登録し、テスト実行時にそのトークンを使うよう固定しない限り、enforcement有効化直後にtest_sim/シミュレータでのFirestore/Storageアクセスが全滅する**リスクがあった。

**対応:**
1. `POST .../apps/{appId}/debugTokens`でUUID固定トークンを1件発行(`displayName: ci-simulator-fixed-token`)
2. `project.yml`のtest/runスキームに`environmentVariables: { FIRAAppCheckDebugToken: "<UUID>" }`を追加、`xcodegen generate`
3. **この時点(enforcement有効化前)でtest_simを実行し、47件パスのベースラインを確立**(デバッグトークン配線自体が既存動作を壊していないことを先に確認)
4. `PATCH .../services/firestore.googleapis.com?updateMask=enforcementMode` / 同Storage版で`{"enforcementMode": "ENFORCED"}`に変更
5. 再度test_sim実行 → 51件(その時点で実写真テスト追加済みだったため)全パス、回帰なしを確認

## 重要な安全プロセス上の注意

**このPATCH実行は、Claude Codeの自動モード分類器に「本番設定への破壊的変更」として一度ブロックされた。** ブロック理由は妥当と判断し、無理に回避せず一旦停止、依頼者に状況(準備完了・ベースライン確認済み・ロールバック手順あり)を説明した上で明示的な許可を得てから再実行した。本番Firebaseプロジェクトのセキュリティ強制モードを切り替えるような操作は、たとえ手順が整っていて可逆であっても、実行前にこの一段階を踏むべき。

## ロールバック手順(次回セッション用、もし何か問題が起きた場合)

```bash
TOKEN=$(gcloud auth print-access-token)
curl -X PATCH "https://firebaseappcheck.googleapis.com/v1/projects/sky-grid-app/services/firestore.googleapis.com?updateMask=enforcementMode" \
  -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: sky-grid-app" \
  -H "Content-Type: application/json" -d '{"enforcementMode": "UNENFORCED"}'
# 同様に firebasestorage.googleapis.com も
```

## 結論

Firestore/Storage双方が`ENFORCED`。Cloud Functions(`deleteAccount`)は元々コード側`enforceAppCheck: true`で個別にfail-closedだったため変更なし。

## 追記: 明示的な Info.plist の反映漏れ（2026-07-31）

`project.yml` の `INFOPLIST_KEY_SGDebugAppCheckToken` を設定しただけでは、
このプロジェクトのように明示的な `SkyGrid/Config/Info.plist` を使う場合、
カスタムキーは生成済みアプリの plist に自動追加されない。したがって
`Bundle.main.object(forInfoDictionaryKey:)` は `nil` となり、`devicectl` 起動時は
未登録のランダムな Debug token が使われて Firestore に拒否される。

`Info.plist` に `SGDebugAppCheckToken` を明示し、その値を
`$(INFOPLIST_KEY_SGDebugAppCheckToken)` としてビルド設定から展開する必要がある。
修正後は Debug simulator の生成済み Info.plist に非空の値が含まれることを確認した。
これはビルド時の検証であり、実機へのインストールおよび本番 Firestore への書き込みは
まだ行っていない。
