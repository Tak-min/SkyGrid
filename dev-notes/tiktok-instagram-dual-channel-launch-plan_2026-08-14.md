# TikTok+Instagram 二経路ローンチ計画(準備のみ・未実行) — 2026-08-14

## 背景・今回の決定変更

2026-08-10確定の「単一経路(Verified TikTokブランドアカウント1つのみ、現金$0、他SNS一切禁止)」
([[skygrid-paid-acquisition-pivot-2026-08-10]])を、依頼者の指示で修正した。

- **Instagram(`@skygrid.app`)を除外していたのはエージェント側の見落としだった**、と依頼者が
  判断。理由: 同一コンテンツを複数プラットフォームに出す方がバズる可能性が上がる。
  → **TikTok + Instagram の二経路に変更。** Reddit/Discord/個人アカウント/YouTube Shortsは
  引き続き対象外(この部分は変更なし)。
- **TikTok One(Creator Marketplace・有償クリエイター発注)は一旦停止。**
  ただし整理すると、2026-08-10の単一経路決定は元々「Verified**ブランド**アカウントからの
  **オーガニック**投稿のみ」であり、TikTok Oneでの有償発注は最初から対象外だった
  ([[skygrid-paid-acquisition-pivot-2026-08-10]]の却下リスト参照)。よって今回の指示は
  **新しい制約ではなく、既存方針の再確認**。Verified認証(アカウントID
  `7671547171623239697`)自体はオーガニック投稿にも有効なアカウントなので、そのまま使う。
- **本セッションは計画準備のみ。投稿・デプロイ・動画確定など実行は一切行っていない。**
  依頼者のレビュー後に着手する。

## 前提事実の確認(本セッションで検証済み)

- **v1.0.2は配信完了・公開中。** App Store公開ページを直接確認(`id6796222704`、
  "Current Version: 1.0.2"、"What's New"更新は11時間前)。招待リンク機能とバディぼかし解除
  バグ修正が含まれる。依頼者の「配信が完了している」という認識は正しい。
- `main`ブランチはローカル・リモートで差分なし(全コミット済み・push済み)。ただし直近3コミット
  (`38ec9b3` ソロモーニング自動ペイウォール、`ac58438` バディ投稿プッシュ通知バックエンド、
  `c433a2a` バディ成立時の通知許可プロンプト)は**version 1.0.2(build 5)の提出より後に書かれた
  コード**であり、現在配信中の1.0.2には含まれていない。
  - `ac58438`(Cloud Functions側)は`firebase deploy`だけで有効化できる可能性が高い
    (アプリ新バイナリ不要)。ただしFirebase ConsoleでのAPNs Auth Key登録状況が未確認
    (詳細: [[buddy-post-push-notification-2026-08-14]] — 未確認事項参照)。
  - `c433a2a`(通知許可プロンプト、iOSクライアント側)は次回ASC提出(1.0.3想定)まで反映されない。
  - `38ec9b3`(ソロモーニングペイウォール)も同様に次回ASC提出待ち。
- 既存アセット:
  - `branding/promo/video-v1/skygrid-promo-download-hook-v1.mp4`(11秒/1080x1920) —
    IG Web投稿で3回連続失敗した動画本体([[skygrid-instagram-account-rebrand-2026-08-11]])。
    ファイル自体は正常と検証済み。
  - `videos/sky-grid-instagram-reel/`(未コミット・gitに存在しないディレクトリ、HyperFramesプロジェクト
    一式) — 2026-08-11頃に着手された別のInstagram Reel制作物とみられるが、完成状態・内容は
    本セッションで未検証。次回、中身を確認してから使うか判断が必要。

## 計画: チャネル運用

| 項目 | 内容 |
|---|---|
| TikTok | Verified `Sky Grid`ブランドアカウントからオーガニック投稿のみ。TikTok One(Creator Marketplace・DM発注・有償クリエイター)は使わない。 |
| Instagram | `@skygrid.app`(リブランド完了済み)からReelsとして投稿。IG Web版は動画アップロードで3回失敗しているため、**iPhone実機のInstagramアプリから直接投稿**する(依頼者本人の操作が必要)。 |
| 対象外(変更なし) | 個人TikTok(`@takumin8301`、コミュニティガイドライン違反判定済みで危険)、個人Instagram(`@takminium`)、Reddit、Discord、YouTube Shorts、Product Hunt |
| 現金予算 | $0(広告・有償クリエイターなし、変更なし) |

### 投稿の運用ルール(要・依頼者確認)

2026-08-10時点の仕様は「TikTok 1本のみ、23日間で毎日2本・計46本」だった。二経路化にあたり、
以下は依頼者に確認してから確定させる:
1. **同一動画をTikTokとInstagramに同時投稿するか、プラットフォームごとに変えるか。**
   (Reelsは横型無音自動再生など挙動が異なるため、字幕焼き込み・音源選定の調整が要る場合がある)
2. **1日の本数はTikTok2本+Instagram2本の計4本に増やすか、TikTok2本と同じ動画をInstagramにも
   流用して実質2本のままにするか。** 前者は制作負荷が倍増、後者は工数据え置き。
3. AI合成部分には**TikTokのAIラベル**に加えて**Instagramの類似ラベル(「AI情報」表示)**も
   必要になる可能性がある — 要調査(未着手)。

## 計画: 投稿前の技術的な並行タスク

コンテンツ投稿のブロッカーではないが、投稿する動画が約束する体験("バディが投稿するまで
空が見えない")を実際に機能させるために優先度が高い:

1. **Firebase ConsoleでAPNs Auth Key登録状況を確認**(依頼者本人、CLI不可)。
2. 登録済みなら `firebase deploy --only functions:onBuddyPostCreated` と
   `firebase deploy --only firestore:rules,firestore:indexes` を実行し、バディ投稿プッシュ通知を
   本番有効化。
3. Instagram初回投稿の再開(iPhoneアプリから)。

## 計画: 投稿前のコンテンツ確認タスク

1. `videos/sky-grid-instagram-reel/`の中身を確認し、使える状態か判断。
2. 既存の`skygrid-promo-download-hook-v1.mp4`をIG初回投稿として使うか、新規テンプレート動画
   (2026-08-10確定の9〜15秒テンプレ: ぼかし空→アラーム→撮影→解除→7日グリッド→CTA)を
   先に作るか決める。

## ゲート(2026-08-10確定分、変更なし)

招待リンクのE2Eテスト(ペア成立まで中央値60秒未満、意図した相手との正答ペア80%以上、翌朝の
ぼかし解除が正しく動く)は実機2台がないため未実施のまま。v1.0.2は既に配信され招待リンク機能は
本番稼働中だが、**このゲートの正式な合格確認はまだ行われていない**。依頼者の判断で「配信済み
だから投稿を進める」に切り替わったため、正式なE2E合格待ちではなく本番の11イベント計測
(`invite_created`〜`monthly_or_annual_purchased`)で実地に見ていく運用になる。

Day30失敗ライン([[skygrid-paid-acquisition-pivot-2026-08-10]]参照)は据え置き。二経路化により
「TikTokが何件生んだか」の因果特定はさらに難しくなる(元々campaign linkを作らない設計のため
プラットフォーム別の帰属は最初から不可能だった点は変更なし)。

## 未確定・要依頼者確認(次回セッション優先)

1. TikTokとInstagramの同時投稿 vs 差別化投稿、本数配分。
2. `videos/sky-grid-instagram-reel/`をどう扱うか。
3. Firebase ConsoleのAPNs Auth Key登録状況。
4. InstagramのAI生成コンテンツラベル要否の調査。
5. Instagram初回投稿(iPhoneアプリ経由)を依頼者本人がいつ実施できるか。

## 追記(2026-08-14 後半): Instagram API連携は断念、新規TikTokアカウントを立ち上げ・初投稿完了

- **Instagram API(Content Publishing API)連携は断念。** `developers.facebook.com`にアクセスすると
  依頼者の個人Facebookアカウント(江藤拓海)でも`You don't have access`となり、Meta Developer登録
  自体が未完了と判明。SMS等の本人確認が必要な可能性がありエージェント側では完了できないため、
  依頼者の判断で**Instagram経由は撤退**(手動でちまちま投稿する運用に切替)。
- Meta Business Suite経由の投稿も試したが、「Create reel」「Create post」どちらの動画アップロード
  ボタンも標準の`<input type=file>`を生成せず(File System Access API等を使用と推定)、
  claude-in-chromeのfile_uploadツールでは注入不可と判明。IG Web版本体の既知バグ(進捗バー無限ループ)
  とは別種の壁。
- **依頼者が新規TikTokアカウント`@skygrid.app`を作成**(旧`skygrid-tiktok-creator-marketplace-rates-2026-08-08`
  記載のTikTok One Verifiedブランドアカウント「Sky Grid」(ID `7671547171623239697`)とは別物 —
  新アカウントは0フォロワーの完全新規)。プロフィール設定を実施:
  - 表示名: `Sky Grid · Morning Alarm`(Instagramと統一、7日に1回しか変更不可のため要注意)
  - 自己紹介(80字制限): `One sky, every morning ☁️ Streak it with a friend. skygrid.my`
  - プロフィール写真: `branding/app-icon/skygrid-app-icon-v1-1024.png`
  - 「ビジネス認証」メニューは法人書類(認証書・法律上の企業名・事業者免許番号)が必須の重い認証
    フローと判明、SkyGridは法人登録がないため未実施(架空情報は入力していない)。ウェブサイト欄・
    カテゴリ設定はTikTok Web版に軽量な切替手段がなく持ち越し(モバイルアプリでの確認待ち)。
  - `skygrid-promo-download-hook-v1.mp4`を初投稿(TikTok Studio経由、AI生成コンテンツラベルON、
    音楽著作権チェック・コンテンツ簡易チェックともに問題なし)。投稿直後は「コンテンツ審査中」
    (自分のみ表示)、審査通過後に公開範囲が「誰でも」へ切り替わる想定。

**残タスク**: TikTokモバイルアプリでのビジネスアカウント軽量切替(ウェブサイトリンク・カテゴリ)、
Instagram側は依頼者本人がiPhoneアプリから随時手動投稿。

## 関連

[[skygrid-paid-acquisition-pivot-2026-08-10]](単一経路決定の原文、本メモが修正した対象)、
[[skygrid-instagram-account-rebrand-2026-08-11]](IG投稿が止まっている理由の詳細)、
`dev-notes/buddy-post-push-notification_2026-08-14.md`(未デプロイのプッシュ通知実装ログ)、
`dev-notes/codex-viral-single-path_2026-08-10.md`(元の動画テンプレ仕様)
