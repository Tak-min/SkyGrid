# App Checkの切り分け完了(実機で解決確認)+ 批判的レビューで発見した実バグの修正(2026-08-01)

## 結論(最重要)

**アプリ側に「カメラ画像がサーバーに届かない」バグは存在しない。** 依頼者が実機(iPhone 15 Pro)で
Release構成(App Attest経路)のビルドを使い、実際に撮影→サーバーへの送信まで成功することを
確認済み。問題は**Debug App Check Provider(`exchangeDebugToken`)がこのFirebaseプロジェクトに
対してのみ、外部要因で機能不全**という一点に切り分けが完了した。

## 切り分けの根拠(2系統の独立した証拠)

1. **サーバー側の生ログ(前回セッション、`gcloud logging read`でCloud Runの実HTTPレスポンスを
   直接確認)**: 2026-07-30 18:03/22:26 UTCは"Callable request verification passed" → HTTP 200・
   レイテンシ4.3秒/6.3秒(実処理と整合)で完了。2026-07-31以降は全て401/403、レイテンシ
   0.02〜2.2秒(ハンドラに到達する前に即座に拒否)。→ App Checkさえ通れば中身は完全に正常。
2. **実機でのRelease構成による実地確認(今回)**: Debug Providerとは別の検証経路である
   App Attestを使うRelease構成を実機にビルド・インストールし、依頼者が実際に撮影→アップロード
   成功を確認。→ **本番で使われる経路(TestFlight/App Store配布はRelease構成)は健全**。
   実ユーザーへの影響は無い(現時点でユーザー自体が存在しないことに加え、経路自体も生きている)。

Debug Provider側の`exchangeDebugToken`は本セッションでも直接curlで再現確認済み(正しい値・別の
登録済み値・ランダムUUID・不正な文字列の全てで同一の`403 App attestation failed`)。Firebase
Console GUIでもインシデント表示なし、デバッグトークン登録・enforcement設定・アプリ登録(重複無し、
1件のみ)全て正常。**これはSkyGridのコードでは直せない、Googleのバックエンド側の問題**と結論。
次にすべきことはFirebase/Googleサポートへのエスカレーション、または時間を置いての再確認。

## 批判的コードレビューで新たに発見・修正した実バグ

依頼者の指示に基づき、まだ読んでいなかったアップロード経路の残り(`FirebasePostRepository`,
`FirebaseDocumentCodec`, `FirebaseRepositoryError`, `ImageFileStore`, `ImageProcessor`,
`storage.rules`, `firestore.rules`, `functions/src/index.ts`)を全て読み込み、批判的に検証した。

### 発見: 同日の再撮影時、`alreadyPostedToday`が検知されない可能性が高かった

`FirebasePostRepository.createPost`は`document.setDataAsync(...)`(非merge の`set`)を使う。
Firestoreの仕様上、既存ドキュメントに対する非merge `set`は、ルール評価上「create」ではなく
「update」として扱われる。`firestore.rules`の`posts/{localDate}`は`allow update: if false`
なので、2回目以降の同日投稿は**ルール拒否**される——ただし、この拒否は`transaction`や
`exists: false`プレコンディション付き書き込みでのみ発生する`ALREADY_EXISTS`(code 6)には
**ならず**、通常のセキュリティルール拒否と同じ**`PERMISSION_DENIED`(code 7)**、メッセージも
"already exists"を含まない一般的な"Missing or insufficient permissions"になるはずである。

しかし既存コードは`nsError.code == 6 || message.contains("already exists")`のみを
`.alreadyPostedToday`として扱っており、実際に起きるはずの`code 7`ケースを見ていなかった。

**確認方法の限界:** ローカルのFirestoreエミュレータ(`rules-tests/`に既存)で実地検証を試みたが、
このマシンにJavaランタイムが無く実行できなかった(`java -version`が失敗)。したがって
100%の実地確認はできていないが、Firestoreのルール評価モデル(create/updateの判定根拠は
書き込みメソッドの種類ではなくドキュメントの存在有無)から高い確度で推論した内容である。
**次回、Javaが使える環境でこの推論の実地検証を強く推奨する。**

**この不具合が引き起こしていた実害:** `PostPublisher.publish()`は`RepositoryError.
alreadyPostedToday`を検知した場合のみ`UploadQueue.cancel()`を呼びキュー行をロールバックする。
このcatchが発火しない場合、**同日の2回目以降の撮影で、Firestoreへの投稿には失敗しつつも、
ローカルの画像バイトはアップロードキューに残ったまま**になり、二度とマッチする投稿ドキュメントが
現れないStorageへのアップロードを永遠にリトライし続ける(オーファンになったキュー行)。
UIも「You've already recorded today's sky」という正しいメッセージではなく、汎用的な
「Your post could not be saved」を表示し、リトライしても直らない理由をユーザーに伝えられて
いなかった。

**修正:** `FirebasePostRepository.swift`の`createPost`に、`FIRFirestoreErrorDomain`かつ
`code == 7`(permission-denied)のケースも`.alreadyPostedToday`として扱う分岐を追加。
このドキュメントパスの`create`はこのアプリ自身が構築する正しい形のデータでのみ呼ばれるため
(`validPostKeys()`等のフィールド検証は常に満たされる設計)、実運用でここが拒否される理由は
事実上「既に存在する」の一択という判断に基づく。

**認識しているトレードオフ:** 理論上、端末の時計がサーバー時刻より進んでいる場合
(`capturedAt <= request.time`のルール違反)も同じ`permission-denied`になり得るため、極めて
稀なケース(端末の時計が数分以上ズレている)では「もう投稿済みです」という誤ったメッセージに
なる可能性がある。ただし現状(汎用エラー+無限リトライ)よりは実害が小さいと判断し、この
トレードオフを許容した。

**検証:** `build_sim`成功(エラー・警告0件)。emulatorでの実地確認は上記の通りJava不在で
未実施——次回セッションの優先タスクとする。

## 次回セッションへの推奨アクション

1. **最優先:** Javaをインストールした上で、上記`alreadyPostedToday`修正をFirebaseエミュレータで
   実地検証する(`ios/rules-tests/`に既存のテスト基盤あり、`npm run test:emulator`)。
2. Firebase/GoogleサポートへApp Check debug providerの障害をエスカレーション(または数日待って
   再確認)。実ユーザーには影響しないため緊急度は低いが、ローカル開発・シミュレータでのテストが
   引き続きブロックされる。
3. `testRealAccountDeletionSucceeds`/`testRealCameraCaptureUploadsSuccessfully`は
   シミュレータでは原理的に検証不能(前者はDebug App Check、後者はカメラハードウェア不在)。
   `test_sim`の結果を見る際はこの2件の失敗を「既知・無害」として扱うこと。
