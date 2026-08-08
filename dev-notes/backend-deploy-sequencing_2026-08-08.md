# バックエンド反映の順序制約 — storage.rules を先に出すと本番が壊れる

日付: 2026-08-08。書いた経緯: 別セッションがバディシステムと Dynamic Island を
作り直し、「本番 Firestore Rules は未デプロイ」として引き継いだ。その未デプロイ分を
精査したところ、**Rules 単独で出すと現在 App Store で稼働中のビルドが壊れる**組み合わせ
だったため、順序を確定させて記録する。

## 前提(事実)

- アプリは **2026-08-06 に App Store 公開済み**。ユーザーが今持っているのは
  `HEAD` 相当のクライアント。
- 作業ツリーの変更は**全て未コミット**で、まだ誰にも届いていない。

## 危険 1(最重要): `storage.rules` は新クライアントが出るまで反映してはいけない

**何が変わったか.** `storage.rules` からバディ用の直接読み取り許可
(`activeBuddy()` / `hasPostedFor()` を使った cross-service lookup)が削除され、
`allow get: if signedIn() && request.auth.uid == uid` = **持ち主のみ**になった。
代わりに新設の Cloud Function `imageDownloadURL`(`functions/src/index.ts`)が
サーバ側で友達関係と相互投稿を検証して bytes を返す。

**なぜ壊れるか.**

| | バディ画像の取得経路 |
|---|---|
| 公開中のビルド(`HEAD`) | `storage.reference(withPath:).data(maxSize:)` = **Storage を直接読む** |
| 作業ツリーの新ビルド | `functions.httpsCallable("imageDownloadURL")` |

新 `storage.rules` は前者を拒否する。しかも公開中のビルドは `imageDownloadURL` の
存在を知らない(この関数は `HEAD` に無い= **新規**)ので、フォールバックも無い。

→ **今 `storage.rules` を反映すると、全ユーザーでバディの写真が見えなくなる。**
自分の写真は持ち主読み取りなので無事。つまり壊れるのは**相互公開というこのアプリの
社会的フックそのもの**で、しかも新ビルドが審査を通ってユーザーが更新するまで直らない。

**逆方向は安全**: 旧 `storage.rules` + 新クライアントは問題ない。`imageDownloadURL` は
Admin SDK で動くので Storage Rules を迂回する。

## 危険 2(検証済み・問題なし): `firestore.rules` は後方互換だった

新ルールは `users/{uid}` の作成条件を厳しくしている
(`isDefaultInitialProfile()` / `isDefaultInitialProfileWithHandle()`)。
公開中ビルドが壊れないか、実際のペイロードと突き合わせて確認した:

`HEAD` の `FirebaseUserRepository.claimHandle` が書く内容 —
`handle` / `displayName: "Sky Grid member"` / `timezone` / `wakeGoalMinutes` /
`streakCurrent: 0` / `streakLongest: 0` / `isPro: false` /
`createdAt: FieldValue.serverTimestamp()` — は
`isDefaultInitialProfileWithHandle()` の全条件を満たす
(キー集合が完全一致、`displayName` 定数一致、`createdAt == request.time`、
handle は `Handle` 型が `[a-z0-9_]{3,20}` を保証)。

`friendships` の作成条件も、ルール側に**旧ビルド用の分岐が明示的に用意されている**
(`validRequestHandles()` は handle フィールドが無ければ素通し)。

→ **`firestore.rules` は単独で反映してよい。**

## 確定した反映順序

1. **`functions` を先に出す** — `imageDownloadURL` は純粋な追加。旧クライアントは
   呼ばないので何も壊れない。新クライアントの前提が先に揃う。
2. **`firestore.rules`** — 上記の通り後方互換を確認済み。
3. **`storage.rules` は保留。** 新しいアプリのバージョンが公開され、十分に
   行き渡ってから。ここだけは「コードが出来ている」と「出してよい」が一致しない。

## まだ未確認(このセッションでは確認できていない)

- 実機での Dynamic Island の**展開表示**(コンパクト表示はシミュレータで確認済みと
  引き継ぎにある)。
- **本番 Firebase での2アカウント間の招待**フロー。シミュレータは App Check 403 で
  実バックエンドに到達できないため、ここでは検証不能。
- 上記いずれも実機 + 本番プロジェクトが要るので、依頼者の操作が必要。
