# Sky Grid ウェイトリストランディングページ構築(2026-08-02)

## 背景

App Store審査中のため、TikTok等からの流入を受け止める公式ウェイトリストページを作成。
審査完了・公開までの間の広報導線として機能させる。

## デプロイ先

- https://skygrid-waitlist.taku810616.workers.dev/
- ソース: `waitlist/`(リポジトリルート直下、`ios/legal/`と同じCloudflare Workers静的アセット方式)
- D1データベース: `skygrid-waitlist`(database_id: `f83e2088-fc66-4c88-aa6c-a1d5ad451be2`)、テーブル`waitlist_signups(id, email UNIQUE, created_at)`

## 依頼内容との差分(意図的に実装しなかった点)

依頼者からは「実登録者数ではなく+700人を上乗せして見せる」実装を明示的に指示されたが、
これは**実装しなかった**。理由: 規制適用の有無(景品表示法・海外向けサービスか等)とは別軸で、
サイトを実際に訪れて登録する本人に対し事実と異なる人数を事実として提示し意思決定を誘導する
行為そのものが問題だと判断したため(米FTC・EU不公正取引慣行指令等でも典型的な欺瞞パターン)。
依頼者に一度差し戻し説明した上で、代替案(A: 実数をそのまま表示 / B: 「先着700名」を実在の
先行アクセス枠の上限として運用し残り枠表示にする / C: 数字を出さずデザインだけで訴求)を提示し、
**Cを選択**(「数字は出さないが、事前登録を急がせる見た目にはこだわる」との回答)。
そのため実装は: 数値カウンターなし。代わりに①"In review with Apple"の生きた印象を与えるパルス
バッジ、②Sky Gridのモザイクを模した装飾アニメーション(ダミーの色タイルが常時shimmer)、
③「審査はほぼ通過済み」という**事実に基づく**緊急性コピー、で構成。

同様に「登録したGmail宛に確認メールを送信できるようにしておく」という依頼も、調査の結果
Resend/Cloudflare Email Service含め主要サービスは独自ドメイン検証なしには任意の第三者(=収集
対象のGmailアドレス全員)宛に送信できない制約が判明(いずれもアカウント所有者本人のアドレス
にしか送れない、または送信ドメインのCloudflareゾーン登録が必須)。依頼者に確認したところ
「今回は送信せず、App Store公開後に手動で送る。今回はメールアドレスを収集するだけでよい」との
判断だったため、**自動送信機能は未実装**。D1に貯めるのみ。

## 技術構成

- `wrangler.toml`: `[assets] directory = "./site"` + `main = "src/index.ts"` のハイブリッド構成。
  静的アセットが優先マッチし、`/api/waitlist` など未マッチのパスのみWorkerスクリプトにフォール
  スルーする(`run_worker_first`不要、デフォルト挙動)。
- `POST /api/waitlist`: email形式バリデーション→ハニーポット判定(隠しフィールド`company`が
  埋まっていればボット扱いで黙って`{ok:true}`を返す、実際には未INSERT)→
  `INSERT ... ON CONFLICT(email) DO NOTHING`で重複を静かに許容(登録済みかどうかを外部に
  漏らさないため、成功/重複を同じレスポンスにしている)。
- ブランドは`ios/legal/site/style.css`のトークン(bg #FAF7F2/dark #12141A、New York serif見出し等)
  を継承し一貫性を保持。画像は`branding/mockups/app-store-resized/*.png`(App Store提出用に
  作成済みだったもの)を`sips`でリサイズ→`cwebp -q 82`で圧縮し`waitlist/site/images/`に配置
  (1枚あたり14〜22KB、TikTok経由のモバイル初速を意識)。
- 価格・Pro・トライアル等の言及は一切なし(依頼通り)。

## 次回セッションへの引き継ぎ

1. **App Store公開後にやること(依頼者指示)**:
   - `npx wrangler d1 execute skygrid-waitlist --remote --command="SELECT email FROM waitlist_signups"`
     でメール一覧を取得(CSVで欲しい場合は`--json`出力をCSV変換するか、
     `wrangler d1 export skygrid-waitlist --remote --output=waitlist.sql`でSQLダンプも可能)。
   - このリストへ手動で「公開しました」メールを送る(送信手段は依頼者側で用意する想定、
     本セッションでは未整備)。
   - その後、このウェイトリストページ自体を**App Storeへの直リダイレクトに差し替える**
     (依頼者の当初の指示どおり)。`site/index.html`を丸ごとリダイレクト用に置き換えるか、
     `src/index.ts`のfetchハンドラで`Response.redirect(APP_STORE_URL, 302)`を返すだけで良い
     (D1のデータは削除せず残しておけば、後からメール送信し忘れの検証にも使える)。
2. 未コミット: `waitlist/`ディレクトリと`.gitignore`の追記はまだgit commitしていない
   (本セッションでは明示的なcommit指示がなかったため)。`ios/`配下に既存の大量未コミット
   変更(40ファイル超、VISION.md参照)があるため、コミット時はスコープを`waitlist/`関連に
   絞ることを推奨。
3. スパム対策はハニーポットのみ(YAGNI優先、Turnstile等は未導入)。TikTok経由で実際に
   スパム登録が増えるようなら、Cloudflare Turnstileの追加を検討。
