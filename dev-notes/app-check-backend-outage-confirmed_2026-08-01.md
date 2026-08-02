# App Check exchangeDebugToken がバックエンド側で全滅していることを確定(2026-08-01)

## 背景

依頼者から「カメラで取得した画像がサーバーに送信できていない」との報告。VISION.md /
dev-notes には2026-07-31時点で `UploadQueue.enqueue()` の重複防止ロジックのバグ
(2回目以降の同日撮影を黙って握りつぶす)が根本原因として特定・修正済みと記録されていた。
本セッションでまずコードを直接確認し、この修正が実際に現在のソースに反映されていることを
確認した(`UploadQueue.swift`のimageIDベース重複排除、`cancel()`、`PostPublisher`の
補償ロジックすべて実装済み・事実として確認)。

## 発見: 修正済みのはずのコードでも test_sim が同じ症状で失敗する

`test_sim` を実行したところ、84件成功・2件失敗(`testRealCameraCaptureUploadsSuccessfully`
と `testRealAccountDeletionSucceeds`)。両方とも実行ログに以下が出ていた:

```
[FirebaseAuth] Error getting App Check token; using placeholder token instead.
Error Domain=com.google.app_check_core Code=0 "The server responded with an error:
- URL: https://firebaseappcheck.googleapis.com/v1/projects/sky-grid-app/apps/.../exchangeDebugToken
- HTTP status code: 403
- Response body: {"error":{"code":403,"message":"App attestation failed.","status":"PERMISSION_DENIED"}}
```

続いて Firestore の `observePost`/`observeFriendships`/`WriteStream` が軒並み
`Missing or insufficient permissions` で拒否されていた。

## 根本原因の切り分け(直接 curl で検証、伝聞に頼らず事実で確認)

2026-07-31 の dev-note には「クライアントのデバッグトークン値とサーバー登録値が
ズレていた」という**別の**過去の原因が記録されていたため、まず同じ手法(値の一致確認)を
疑ったが、今回は違った:

1. `Secrets.xcconfig` の `APP_CHECK_DEBUG_TOKEN` (`c3bf4641-553e-4cba-862f-e788dbccb201`)
   と、Firebase App Check Admin API (`GET .../apps/{appId}/debugTokens`) で実際に
   登録されている値(base64デコード後)が **完全一致**していることを確認 — 前回のような
   値のズレは無い。
2. ビルド済み `.app/Info.plist` の `SGDebugAppCheckToken` キーも同じ値になっていることを
   `PlistBuddy` で確認済み — Info.plist配線も正しい。
3. `firebaseappcheck.googleapis.com` API自体は有効(`state: ENABLED`)、Firestore/Storage
   両方の enforcement も `ENFORCED`(正しい設定)。
4. **裸の `curl` で `exchangeDebugToken` を直接叩き、以下すべてで同一の
   `403 App attestation failed` を確認:**
   - 現在正しく登録済みのトークン値
   - 別の登録済みトークン値(`ci-simulator-fixed-token`、期限内)
   - 完全にランダムな未登録UUID
   - UUID形式ですらない不正な文字列

**結論: どんなトークン値を送っても同じ拒否が返る。** これはクライアント側(アプリ・
設定ファイル・トークン値)の問題では一切なく、**このFirebaseプロジェクト/アプリに対する
App Checkデバッグトークン交換のバックエンド側が現在完全に機能していない**ことを意味する。
2026-07-31のdev-noteに記録されていた「原因未確定の外部障害」は、24時間以上経過した
2026-08-01時点でも解消されておらず、今回追加検証によりクライアント側要因を完全に除外できた。

## この障害が説明する症状

- カメラで撮影→確定しても、Firestore/Storageへの書き込みが全て`permission denied`で
  拒否される(=「画像がサーバーに送信できていない」の直接原因)。
- `deleteAccount` Cloud Function は独自に `enforceAppCheck: true`
  (`functions/src/index.ts:34`)を持っており、Firestore/Storageのサービスレベル
  enforcementとは**別の**App Check検証ポイント。同じバックエンド障害の影響を受けるため、
  Firestore/Storageのenforcementを変更してもこちらは直らない
  (`testRealAccountDeletionSucceeds`が常に同じ症状で失敗する理由)。
- Debug buildは`AppCheckDebugProviderFactory`を使うため、依頼者が実機
  (iPhone 15 Pro、ワイヤレスデバッグ)でXcodeから直接ビルド・実行して撮影を試した場合も
  **同じ経路・同じ障害**に当たる。Release/TestFlight配布(`AppAttestProviderFactory`)が
  同じ障害の影響を受けるかは今回未検証(この障害がDebug Providerのトークン交換に固有か、
  App Check全体のバックエンド不調かは切り分けられていない)。

## 依頼者の許可を得て実施した一時検証(実施済み・ロールバック済み)

依頼者に確認の上、Firestore/Storageの App Check enforcement を一時的に `UNENFORCED` に
変更→検証→**`ENFORCED`へ確実に戻した**(2026-08-01T05:43 UTC時点で両サービスとも
ENFORCED、Admin APIで確認済み)。ロールバック手順は
[app-check-enforcement_2026-07-30.md](app-check-enforcement_2026-07-30.md)と同じ。

### UNENFORCED化で分かったこと

- `test_sim`は`account deletion`失敗が変わらず継続(Cloud Function側の独立した
  `enforceAppCheck: true`が別途あるため、Firestore/Storageのenforcement変更だけでは
  直らない ⁠— 上記の通り想定通り)。
- `testRealCameraCaptureUploadsSuccessfully`は相変わらず失敗するが、**症状が変わった**:
  App Check起因の permission denied ではなく、**シミュレータにカメラハードウェアが
  存在しないことによる失敗**に変わった(詳細は次項)。
- 新たに3件のテスト(`testRealPaywallOfferingsLoadAfterRevenueCatIncident`,
  `testRealSandboxPurchaseReachesStoreKitConfirmationSheet`,
  `testRealTestStorePurchaseGrantsEntitlement`)が、`SettingsView`の
  "Unlock the full archive" ボタンをXCUITestが見つけられずに失敗するようになった
  (詳細は下記「副次的な発見」参照、UNENFORCED化が直接の原因かは未確定)。

## 副次的な発見1: シミュレータではカメラ撮影が原理的に検証不能(現在の設計)

`CameraSessionController.swift`のコード自体のコメントに明記されている:
「Camera capture requires a physical device; the simulator correctly reports that
no capture device is available.」— `ServiceFactory.makeCameraSource()`には
シミュレータ用フィクスチャ分岐が一切なく、常に実機用AVFoundation実装
(`CameraSessionController`)を返す。

VISION.mdのPhase 1記述(2026-07-29時点)には「カメラ撮影(シミュレータはフィクスチャ画像
巡回、実機はAVFoundation実装)」とあるが、**この巡回フィクスチャの仕組みは現在のソースには
存在しない**(全ソースをgrepしても`Sources/`配下に"fixture"の参照は無い。git履歴は
initial commit以降すべて未コミットのため、いつ・なぜ削除されたかは追跡不能)。

**結果として `testRealCameraCaptureUploadsSuccessfully`(および恐らく将来同種のテストも)
は、シミュレータ実行(`test_sim`)では原理的に絶対にパスできない。** 実際に本セッションで
argentからシミュレータの「Capture the sky」を手動でタップして確認したところ、
「The camera could not start.」の失敗画面に到達することを実地確認済み。

**未確定の判断:** これを直すべきか(a: シミュレータ用フィクスチャ画像巡回を復元する、
b: `testReal*`系テストを`#if targetEnvironment(simulator)`でスキップし実機専用と
明示する、c: 何もしない)は、依頼者と相談が必要な設計判断。現状は「毎回2件(または
App Check状態次第で5件)の失敗」が`test_sim`のノイズとして常態化しており、本当の
リグレッションを埋もれさせるリスクがある。

## 副次的な発見2: Settingsの"Unlock the full archive"ボタンのXCUITest自動化タイプ不一致
(原因切り分け完了 — App Checkとは無関係と確定)

`test_sim`で断続的に、`SettingsView.swift`の`settingRow`をラップしたButtonに対して以下の
エラーが発生する:

```
Automation type mismatch: computed Button from legacy attributes vs Link from
modern attribute.
```

`app.buttons.matching(predicate: label CONTAINS "Unlock the full archive")`が0件ヒットに
なる — SwiftUIの当該Buttonが、XCUITestの新旧アクセシビリティブリッジ間で「Button」と
「Link」のどちらとして扱われるか一致せず、Button型で絞り込むクエリが見つけられない状態。

**当初「App Check enforcement状態と相関があるのでは」と疑ったが、これは誤りだった。**
UNENFORCED化後に2回連続で発生したため一時的にそう見えたが、依頼者の許可を得て
ENFORCEDへ確実に戻した**後**にもう一度`test_sim`を実行したところ、**同じ3件が同じ
Automation type mismatchで再現した**(ENFORCED状態でも発生)。したがってenforcement状態は
無関係であり、iOS 26.5のSwiftUI/XCTestアクセシビリティブリッジ側の断続的な既知の不整合
(タイミング依存のflakiness)である可能性が高い。

**実ユーザー影響は無いと判断できる根拠:** argentの`describe`(ax-service経由、XCUITestとは
別のアクセシビリティ検査パス)で同じボタンを確認したところ
`AXButton "Unlock the full archive, Keep more than your latest 30 days."`として正しく
Buttonに分類されており、実際に手動タップでもPaywallへ正常に遷移することを確認済み
(スクリーンショットで検証)。つまりこれは**XCUITestというテストハーネス固有の断続的な
分類バグであり、アプリのUIやアクセシビリティ自体は正しく動作している。**

**次回セッションへの引き継ぎ:** 優先度は低い。もし対処するなら、`SettingsView.swift`の
`settingRow`(Image + VStack(Text, Text) + Spacer + Image のHStackをButtonでラップし
`.buttonStyle(.plain)`)のアクセシビリティ表現を単純化する、またはテスト側で
`app.buttons` ではなく `app.descendants(matching: .any)` 等より緩いクエリに変更する、の
どちらかが候補。緊急性は無い。

## 実施した修正: BuddiesViewのリスト行スタイル不整合(UI違和感、修正済み)

依頼者の依頼(UI上の違和感の自律的な改善)に沿って、実機/シミュレータのUI監査
(`-SkyGridUIAudit -SkyGridUIAuditScenario buddies`)で発見した具体的な視覚不整合を1件修正:

**症状:** `BuddiesView.swift`の「YOUR BUDDIES」セクション(`Mira`/`Ren`の行)と
「INCOMING REQUESTS」セクションが、`List`のデフォルト行スタイル(白背景+細い区切り線)の
まま描画されていた。同じ画面内の他の全要素(ritual card、招待フォーム)や他画面
(Settingsの各行、Todayのアラーム行)は、共通の`SGT.fill`の暖色カード+区切り線なしの
見た目で統一されている中、この2セクションだけ素のシステムリストの見た目が残っており、
"未完成"に見える典型的な不整合(`~/.claude/rules/ecc/swift/ui-design.md`が指摘する
「画面間の余白・スタイルの微妙な不揃い」の実例)だった。

**修正:** 「YOUR BUDDIES」の各行(空状態・NavigationLink行の両方)と「INCOMING REQUESTS」
セクションに`.listRowBackground`/`.listRowInsets`/`.listRowSeparator(.hidden)`を追加し、
既に同ファイル内の他セクション(ritual card、招待フォーム)で使われているのと同じ手法で
デフォルトのList行装飾を除去。`FriendRequestsView`は既に自前で`.quietCard()`を描画して
いたため、外側のList行の装飾を消すだけで二重の箱型ネストが解消される。

**検証:** `build_sim`成功(エラー・警告0件、新規追加なし)。シミュレータで実際に
Mira/Renの行が暖色の統一背景・区切り線なしで表示されることをスクリーンショットで確認済み。
`INCOMING REQUESTS`側は監査用フィクスチャデータに保留中リクエストが無く実地確認は
できていないが、同一ファイル内で既に検証済みの同じパターンを適用したのみ。
`test_sim`を2回(修正前後)実行し、この修正による新規のテスト失敗が無いことを確認済み
(失敗内容・件数は修正前後で完全に同一)。

## 次回セッションへの推奨アクション(優先順位順)

1. **Firebase Console(GUI)でApp Check画面を直接確認する。** Admin API経由では見えない
   情報(例: プロジェクト全体のインシデント表示、再発行が必要な旨の警告等)がGUI側にのみ
   表示されている可能性がある。依頼者本人による確認が最短。
2. **解消しない場合はFirebase/Google Cloudサポートへの問い合わせを検討。** 24時間以上・
   全トークン値で再現する障害はクライアント側で打つ手がなく、外部エスカレーションが必要。
3. カメラのシミュレータ検証不能問題(上記)への対応方針を依頼者と決定する。
4. 実機での最終確認(App Check障害が解消してから): 撮影→Firestore投稿ドキュメント作成→
   Storage画像アップロード→`gsutil ls`での実在確認、を一気通貫で行う。
