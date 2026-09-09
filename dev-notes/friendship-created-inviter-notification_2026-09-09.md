# 招待成立時の inviter 通知（2026-09-09）

## 変更

- `friendships/{pairId}` の作成を監視する `onFriendshipCreated` を追加した。
- Firestore / Eventarc のリージョンは既存トリガーと同じ `asia-northeast1`。
- `status: accepted`、`blockedBy: []`、members・pairId・`requestedBy` が整合する作成だけを対象にし、
  invite creator を表す `requestedBy` の端末へだけ既存 FCM/APNs 経路で通知する。
- 通常の handle リクエストは `pending` で作成されるため対象外。
- 通知の title/body/data/APNs header から UID、handle、invite code、pairId を除いた。
- 既存 pending を invite claim が accepted へ昇格するケースには作成イベントがないため、callable 側の
  fallback を維持した。両経路は同じ Firestore marker を原子的に取得し、二重送信を防ぐ。
- marker の `expireAt` を `firestore.indexes.json` の TTL 対象に追加した。

## 検証

- `cd ios/functions && npm run lint`
- `cd ios/functions && npm test`
- `cd ios/functions && PATH="/opt/homebrew/opt/openjdk/bin:$PATH" npm run test:emulator`

デプロイは実施していない。accepted を直接作成する別の server writer が将来追加された場合は、
invite 起源を明示する schema field なしでは区別できないため、このトリガー条件も同時に見直す。
