# カメラ撮影クラッシュの根本原因特定・修正、アップロード問題は未解決(2026-07-31)

## 背景

依頼者から「カメラで取得した画像がやはりサーバにあげれていない」との指摘。VISION.mdには
2026-07-30時点で「写真アップロード失敗」バグは調査・修正済みだが**実機での最終確認は未実施**と
記録されていた。本セッションでその実機確認を行った。

## 発見1: 撮影確定のたびにアプリがクラッシュしていた(修正済み)

実機(iPhone 15 Pro)で実際にカメラ撮影→「Use this one」確定を行うUIテスト
(`SkyGridUITests.testRealCameraCaptureUploadsSuccessfully`)を実行したところ、確定直後に
アプリがSIGABRTでクラッシュすることを`.xcresult`内の自動キャプチャされたクラッシュログ
(`.ips`)から発見。

**根本原因(クラッシュバックトレースで完全特定):**

```
CameraView.confirm(image:)
  → RootView.cameraSheet(services:) closure #2
    → RootView.considerAutomaticPaywall(afterCompletedCapture:services:)
      → RootView.prepareAutomaticPaywallState(for:)
        → LocalDefaults.resetAutomaticPaywallState()
          → LocalDefaults.automaticPaywallAccountID.setter (= nil)
            → UserDefaultBacked.wrappedValue.setter
              → UserDefaults.standard.set(newValue, forKey:)
                → _CFPrefsValidateValueForKey → objc_exception_throw → abort
```

`UserDefaultBacked<T>`(`SkyGrid/Sources/Persistence/LocalDefaults.swift`)の setter が
`UserDefaults.standard.set(newValue, forKey: key)` を無条件に呼んでいた。`T` が `String?` の
ようなOptional型で `newValue` が `nil` の場合、ジェネリクス経由で `Any?` へブリッジされる際に
二重にラップされた `Optional` になり、CoreFoundationのプロパティリスト妥当性チェック
(`_CFPrefsValidateValueForKey`)が不正な値として例外を投げる — Swiftの `UserDefaults` ラッパー
実装でよく知られた罠。

**修正:** `AnyOptional` プロトコルでジェネリックにnil判定し、nilの場合は `set` ではなく
`removeObject(forKey:)` を呼ぶよう変更(`LocalDefaults.swift`)。

**検証:** 実機で同じUIテストを2回連続再実行し、クラッシュが再現しないことを確認済み。

## 発見2: クラッシュを直してもFirebase Storageへの実アップロードは未確認(未解決)

クラッシュが直った後の実機テストでは:
- Firestoreの投稿ドキュメント(`users/{uid}/posts/{date}`)は毎回正常に作成される
- しかし `gsutil ls gs://sky-grid-app.firebasestorage.app/posts/{uid}/{date}/` で対応する画像
  ファイルが**一度も見つからない**(複数回・時間を置いて再確認済み)

UIテスト自体は「PASS」判定になったが、これは誤った安心材料だった: 撮影確定後にアプリが
Today タブ(`PostStatusBanner`が表示される場所)ではなく **Sky Grid(Grid/アーカイブ)タブへ
自動遷移する**ため、テストが「Retry now」ボタンの不在を確認していたスクリーンには、そもそも
アップロード状態バナー自体が存在しなかった。

**次回セッションでの調査の進め方(引き継ぎ):**
1. Today タブに明示的に遷移してから `PostStatusBanner` の状態("Sending…"/"Retry now"/バナー
   なし)を確認するようUIテストを直す(現状のテストはこの遷移ステップが欠けている)。
2. `UploadQueue.upload(_:)` 内の `Self.logger.error(...)` ログを実機コンソールで確認できる
   仕組みを用意する(`log stream`相当がiOS実機に効かないため、テスト経由で
   `pendingSummary()`の`lastError`を何らかの形で可視化する必要がある可能性)。
3. Storage Rules・App Check enforcement(Storage側)が正しく`putFileAsync`を許可しているか、
   実際のFirebase Consoleの使用状況/エラーログ(Cloud Loggingの`firebasestorage.googleapis.com`
   リソース)を確認する。
4. テストで作成したテスト用Firestoreドキュメント(`users/Y9ZVcRM53FVkhzMCRY6LDqwE2kq2/posts/*`)
   は依頼者確認の上で削除済み(2026-07-31時点)。次回、同じUIDで新規投稿を試す場合は既存ドキュメント
   の有無を先に確認すること(1日1投稿の制約があるため)。

## 副次的な技術メモ

- `xcresulttool export attachments` で自動キャプチャされたスクリーンショット・クラッシュログを
  取得できる。特に`.ips`クラッシュログは `xcresulttool get test-results activities --test-id
  "<Suite>/<test>()"` の出力からpayloadIdを見つけ、`xcresulttool export object --legacy --id
  <id> --type file --output-path <path>` でエクスポート可能(`--legacy`フラグ必須、新しい
  `xcresulttool`では非推奨警告が出る)。
- `.ips`クラッシュログの`lastExceptionBacktrace`フィールドに、シンボリケート済みの完全な
  Swift関数呼び出しスタックが入っている(`exception`フィールドの`codes`/`type`/`signal`だけでは
  SIGABRTの理由まではわからず、必ず`lastExceptionBacktrace`も見ること)。
- 本番Firestore/Storageの内容を`gcloud auth print-access-token` + `curl`で直接クエリ/削除する
  手法は、実機テストの結果を安価に検証する上で非常に有効(高コストな実機再テストを繰り返す前に、
  まずこちらでground truthを確認すべき)。削除(DELETE)は自動モード分類器にブロックされたため
  依頼者に確認を取ってから実行した。

## 続報(2026-08-01): 根本原因特定・修正完了。上記「一度も保存されていない」は誤りだった

前回の結論を訂正する。**Storageには実際に成功したアップロードが存在していた** —
`gsutil ls`で「無い」と確認した時刻が、たまたま成功アップロードの7分前だったための誤検知
(レースコンディション、バグではない)。

**真の根本原因(一文):** `UploadQueue.enqueue()`の重複防止ロジックが、その日すでに
`.failed`以外の状態(`.pendingLocal`/`.uploading`/`.done`)の行が存在する場合、**2回目以降の
撮影を黙って握りつぶしていた**(キューに登録すらせず、ローカルファイルだけ`pending/`に残る)。
`PostPublisher.publish()`は`enqueue()`→`createPost()`の順で呼ぶため、1回目の`createPost()`が
(App Check障害等で)失敗し、2回目の`createPost()`が成功する、という順序が起きると、
**Firestoreの投稿ドキュメントは2回目の画像を参照するのに、Storageには1回目の画像しか
アップロードされない**(=写真のない投稿)という実データ不整合が本番に実在した
(`users/Y9ZVcRM53FVkhzMCRY6LDqwE2kq2/posts/2026-07-31`で確認)。

**実機でしか見えなかった副次的な発見:** UIテスト`testRealCameraCaptureUploadsSuccessfully`が
偽PASSしていた理由も、以前の「Sky Gridタブへ自動遷移するから」という仮説は誤り。実際は
`CameraView.confirm(image:)`が`onConfirmed`のthrowをcatchして`confirmationError`を出すだけで、
`RootView`側の`showCamera = false`は`publish()`成功時のみ実行されるため、**失敗時はカメラの
`fullScreenCover`が閉じずTodayタブ(`PostStatusBanner`の置き場)を覆い続ける** —
コード上「撮影後に別タブへ自動遷移する」経路は存在しない。

**修正内容(実装済み、テスト9件パス):**
- `UploadQueue.enqueue()`: 重複防止キーを状態ベースから`imageID`ベースに変更。同じdraftの
  再送信は冪等no-op、`imageID`が異なる(=別の撮影)なら状態に関わらず行を差し替える。
- `UploadQueue.upload()`: `pending.localFullImageURL`を直接使わず、
  `ImageFileStore.pendingImageURL(filename:)`でファイル名から都度再解決する
  (コンテナUUID再割り当てへの耐性)。ローカルファイルが存在しない場合は8回リトライせず
  即`.failed`(`UploadQueueError.localFileMissing`)。
- `UploadQueue.cancel(queueID:imageID:)`を新設。`PostPublisher.publish()`が
  `RepositoryError.alreadyPostedToday`を検知したら呼び、握りつぶされず登録されてしまった
  行をロールバック。
- `RootView.consumePendingCameraRequestIfNeeded()`: アラーム/通知経由のカメラ起動が
  `todayPost`の存在チェックを素通りしていたのを修正(`TodayView`のキャプチャボタンと同じ
  ゲートを適用)。
- `CameraView.confirm(image:)`: `RepositoryError.alreadyPostedToday`を汎用エラーと区別し、
  「今日はもう記録済み」という専用メッセージに変更(リトライしても直らないため)。
- `UploadQueueTests.swift`: `makeDraft()`が`/tmp/skygrid-test-full.jpg`という**実在しない
  ファイル**を指していたため、ローカルファイル存在チェックを追加する既存テストが構造的に
  検出不能だった。`ImageFileStore.writePendingImage`経由で実ファイルを書くよう修正し、
  「同日再撮影で握りつぶされない」「ローカルファイル欠落で即failed」「cancel」の回帰テストを
  追加(計9件パス)。

**未実施(依頼者承認済み、次回実施):** 実機でのE2E最終確認。App Check enforcement
(`exchangeDebugToken`が403 "App attestation failed"を返す外部障害、Apple側の障害告知は
2026-07-31 06:30 UTC解消済みだがこの個別事象は未解消)が実機での検証をブロックしているため、
Firestore/Storage両方を一時的にUNENFORCEDへ変更→実機で新規撮影を1回試す→ENFORCEDへ戻す、
という手順が必要(ロールバック手順は`dev-notes/app-check-enforcement_2026-07-30.md`参照)。

**副次的な技術メモ(今回の調査で新たに得た知見):**
- `devicectl device copy from --domain-type appDataContainer --user <uid> ...`
  (`--username`ではなく`--user`)で、実機のSwiftDataストア(`default.store`/`-wal`)や
  `UserDefaults`のplistを直接取得できる。シミュレータでは再現しない実機固有の状態
  (コンテナUUID再割り当て、`GACAppCheckDebugToken`の残留値等)を調べる決定打になった。
- App Check `exchangeDebugToken`の403は、登録済み・未登録どちらのトークンでも同一の
  `{"message":"App attestation failed.","status":"PERMISSION_DENIED"}`を返す。裸の`curl`
  (v1/v1beta、プロジェクトID/番号、`X-Ios-Bundle-Identifier`有無の全パターン)で独立再現でき、
  RevenueCat側のApp Store Connect APIキー(P8)は無関係に「Valid credentials」のまま —
  App Check固有の問題であって認証キー全体の障害ではないと切り分けられた。
