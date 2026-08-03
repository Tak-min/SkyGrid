# ウェイトリストUI再設計 + ドメイン調査(2026-08-02)

## 背景

App Store審査中の集客用ウェイトリストページ([dev-notes/waitlist-landing-page_2026-08-02.md](waitlist-landing-page_2026-08-02.md)
で構築済み)について、依頼者から「UIがウェブサイトネイティブでなく未完成に見える」との指摘。
参考として類似アプリ Erly(https://erly.co/、朝の目覚まし習慣化アプリ)のサイトを提示された。
併せて、SkyGrid用の独自ドメインを安価なレジストラで調査し、購入画面まで到達させる依頼。

## UI再設計(`waitlist/site/index.html` + `style.css`)

erly.coをPlaywrightのaccessibility snapshotで構造分析(スクリーンショットはこの環境の
Playwright MCPで撮影不可 — 下記Gotcha参照)した結果、以下がSkyGridの旧ページに欠けていた
「ネイティブアプリランディングページ」の型と判断:

1. ヒーローに実機フレーム風のモックアップ画像(erlyは2枚重ねの端末画面)
2. 番号付き「How it works」ステップ構成
3. FAQアコーディオン(信頼性・完成度のシグナル)
4. eyebrowラベル(セクション見出し上の小さい大文字ラベル)
5. ブランド列+リンク列に整理されたフッター

実装した変更:
- `.phone-frame`というCSSコンポーネントを新規追加(ダークベゼル+ノッチ疑似要素+角丸)。
  ヒーローに2枚重ね(`--front`/`--back`)、howitworksの3ステップ、buddies機能ハイライトの
  計6箇所で再利用。
- 既存の4つの`.feature`ブロックを、番号付き3ステップ(`.steps`/`.step`、One sky a day /
  A year, one grid / Share your sky)+ 独立ハイライト1枚(`.highlight`、Do it with someone)
  に再構成。
- FAQは`<details>/<summary>`のネイティブHTML(JS不要、キーボード操作・アクセシビリティ標準対応)。
  質問5件はすべて**既存の承認済みコピーの言い換えのみ**で構成 — VISION.md記載のPro/ストリーク/
  通知仕様等、waitlistページでは意図的に触れない(依頼者確定方針、
  [dev-notes/waitlist-landing-page_2026-08-02.md](waitlist-landing-page_2026-08-02.md)参照)
  未実装/未検証の挙動を新規に断定しないため。
- デスクトップ幅(min-width: 860px)でヒーロー2カラム化・stepsを3カラムグリッド化する
  レスポンシブ強化を追加(旧実装は全幅640pxのモバイル専用レイアウトだった)。
- ヘッダーに`backdrop-filter: blur`のスティッキーnav(iOSネイティブ的なすりガラス感)。

コピー・画像アセット(`branding/mockups/app-store-resized/*.png`由来のwebp)・フォーム送信ロジック
(`app.js`)・D1連携は無変更。

### Gotcha: このセッションのPlaywright MCPで`browser_take_screenshot`が常にタイムアウトする

**症状:** `mcp__playwright__browser_take_screenshot`が外部サイト(erly.co)・ローカル
`python3 -m http.server`経由の自サイトの両方で、フルページ/ビューポート/PNG/JPEG問わず
常に`TimeoutError: ... waiting for fonts to load... fonts loaded`のログを最後に5000msで
タイムアウトした。

**切り分けた原因候補と結果:**
- フォント読み込み自体が原因か → `page.evaluate(() => document.fonts.status)`は`"loaded"`を
  即座に返した。フォント自体は原因ではない(ログのメッセージは信用できない)。
- 無限CSSアニメーション(badge の pulse、mosaic の shimmer)が「安定待ち」を妨げているか →
  `*{animation:none!important}`を注入後も再現。原因ではない。
- 外部サイト固有の問題か → ローカルの静的ファイルサーバー(自分で書いたシンプルなHTML)でも
  同一のタイムアウトが再現。**ページ内容とは無関係の、この環境のPlaywright MCPサーバー側の
  既知の不具合と判断。**

**回避策:** `browser_snapshot`(accessibility tree)は正常に動作する。ピクセル単位の見た目確認は
できないが、DOM構造・要素の存在・フォーム動作(`browser_click`→`browser_evaluate`でopen属性を
確認等)・コンソールエラーの有無・アセットの200応答は`curl`と組み合わせて検証できるため、
今回はこれで代替した。**次回スクリーンショットが必要な作業では、まずこの既知の問題を疑い、
`browser_snapshot`＋`curl`での構造検証にフォールバックすること。** 環境側の修正(MCPサーバーの
再起動やアップデート)を試す価値はあるが未検証。

## ドメイン調査(未購入、カート追加まで)

### レジストラ選定

WebSearchで2026年時点の比較を確認: Cloudflare Registrarは**新規登録不可(移管・更新専用)**の
ため今回は対象外(SkyGridは既にCloudflare Workersでホスティング中だが、ゾーンを後からCloudflareに
向けるのはドメイン取得後でも容易)。Porkbunが「バラ色の初年度価格→高額更新」のような価格トリック
がなく(多くの候補で"At Cost"表示、初年度と更新年が同額)、かつ主要レジストラ最安値帯という
結論のため採用。

### ドメイン名調査結果(すべてPorkbunでの実際の検索結果)

「SkyGrid」は既に実在ブランド(推定: Boeing/SparkCognitionの空域管理JV等)またはドメイン業者に
主要TLDを広く押さえられている状態と判明:

| ドメイン | 状態 |
|---|---|
| skygrid.com | 取得済み(Inquire = 直接登録不可) |
| skygrid.org | Aftermarket、$799+ |
| skygrid.co | Aftermarket、$1,988+ |
| skygrid.tech | Aftermarket、$4,500+ |
| skygrid.xyz | Aftermarket、$1,950+ |
| skygrid.app / .io / .us / .dev / .online / .cloud / .shop / .space | いずれも`knownDomain`
  (取得済み)と判定、aftermarket確認中で価格表示すらされず |
| getskygrid.com | 取得済み(Inquire) |
| getskygrid.app | **空き**、$8.75(初年度)→$14.93/年(更新) |
| **skygrid.day** | **空き**、$10.81/年(初年度・更新とも同額、"At Cost") |

### 選定: `skygrid.day`

理由:
1. **価格:** $10.81/年固定。getskygrid.appの更新$14.93/年より安く、かつ初年度だけの
   セール価格ではないため2年目以降の値上がりショックがない。
2. **ブランド適合:** プレフィックスなしの正確な「SkyGrid」そのもの。`.day`はGoogle Registry運営の
   gTLDで、プロダクトの核である「毎朝一枚」という日課の訴求と意味的に一致する
   (`.app`は「アプリである」以上の意味を持たないが、`.day`は具体的な価値提案そのものを表す)。
3. `.day`はGoogleのHSTS preloadリストに含まれ常時HTTPS必須だが、Cloudflare Workers配信は
   元々常時HTTPSのため実質的な制約にはならない。無料Let's Encrypt証明書もPorkbun側で提供される。

Porkbunのカートに追加し、Order Summary(合計$10.81 USD、隠れ費用なし、WHOIS privacy/SSL/
メール転送等は無料付帯)まで到達・確認済み。**この先の「Continue → Create Account / Login」は
依頼者本人のアカウント作成・支払い情報入力が必要なため、意図的に停止した**(実際の決済という
不可逆な金銭コミットメントを本人確認なしに進めることは越権のため)。

### 追記(2026-08-02、同日): 依頼者が実際に購入したのは `skygrid.my`

上記の流れを受けて依頼者自身のBraveブラウザでPorkbunのアカウント作成・決済を実施。
**最終的に購入したのは`skygrid.day`ではなく`skygrid.my`**(依頼者の判断による変更、理由は
未確認)。購入時に「.myはWHOIS privacy非対応」という警告(Porkbunの`.my`標準の注記、
個人登録なら基本非公開のまま・組織登録の場合のみレジストリ側で公開されうる)が表示された旨、
依頼者から報告あり。エージェント側では確認していないため、以下は未検証:
- `skygrid.my`の登録者情報欄が個人/組織のどちらで入力されたか。
- `.my`のセカンドレベル直接登録(`skygrid.my`、`skygrid.com.my`ではない形)にMYNIC側の
  現地プレゼンス要件がなかったか(Porkbunのチェックアウトが通った時点で問題なしと推定するが、
  レジストリ側の追加書類提出を求められる可能性はゼロではない)。

## 次回セッションへの引き継ぎ

1. **実際に取得されたドメインは`skygrid.my`。** 以降のCloudflare連携・Custom Domain設定は
   `skygrid.day`ではなく`skygrid.my`を対象にすること(本ファイル前半の`.day`推奨は調査時点の
   ものとして残すが、最終決定は`.my`)。
2. Cloudflareダッシュボードにゾーンを追加し、Porkbun側のネームサーバーをCloudflareのものに
   変更 → `waitlist/wrangler.toml`にCustom Domainとして`skygrid.my`を追加する
   (現状は`skygrid-waitlist.taku810616.workers.dev`のworkers.dev URLのみ)。
3. Porkbunのアカウント設定で、登録者情報(Registrant Contact)が個人名義になっているか確認する
   ことを推奨(組織名義だと`.my`は情報が公開されうるため)。
4. `waitlist-landing-page_2026-08-02.md`の引き継ぎ(App Store公開後にウェイトリストページを
   App Storeへの直リダイレクトに差し替える計画)は今回のUI再設計後も有効。差し替え時は
   今回追加したFAQ・howitworksセクションごと丸ごと置き換わる想定で問題ない。
4. `waitlist/`配下は今回の変更も含めてまだgit commitされていない(前回セッションの引き継ぎ
   メモの通り、`ios/`の大量差分と分けてスコープすることを推奨)。

## 追記(2026-08-03): Cloudflareゾーン接続・Custom Domain設定完了

依頼者がPorkbunでネームサーバーをCloudflareの指定値(`malavika.ns.cloudflare.com` /
`sage.ns.cloudflare.com`)に変更し、ゾーンが`active`化。その後を自律的に実施:

- `wrangler.toml`に`routes = [{ pattern = "skygrid.my", custom_domain = true }]`を追加、
  `wrangler deploy`。**Gotcha:** `routes`(custom_domain)を追加すると`workers_dev`が
  デフォルトで`false`になり、既存の`skygrid-waitlist.taku810616.workers.dev`が無効化される
  (デプロイ後の警告ログで発覚)。既存URLが外部(TikTok等)で既に案内されている可能性を考慮し、
  `workers_dev = true`を明示追加して両URLを併存させた。
- `https://skygrid.my/`が200・再設計後のコンテンツを正しく返すことを確認済み。
- **未完了:** Zone Settings API(`/zones/{id}/settings/always_use_https`)がwranglerの
  OAuthトークンの権限外(GETですら`Authentication error`、ゾーン作成時と同じ権限の壁)で
  操作不可。現状`http://skygrid.my/`はHTTPSへリダイレクトされず200を直接返す。フォームで
  メールを収集するサイトなので、依頼者がダッシュボードの
  SSL/TLS → Edge Certificates → Always Use HTTPS を有効化することを推奨(1クリック)。
  2026-08-03にWorkerコードで補完できるか再調査したところ、Static Assetsの既定
  (`run_worker_first = false`)ではHTML/CSS/画像はWorkerを経由しないため、Worker内の
  リダイレクトだけでは不完全と判明。`run_worker_first = true`なら全リクエストを捕捉できるが、
  静的アセットにもWorker invocationの課金・上限を発生させる。費用・可用性の面で劣るため、
  部分的なWorkerリダイレクトは実装せず、上記ダッシュボード設定を正とする。
- **wranglerのOAuthトークンの権限境界(判明した事実、次回の判断材料):** `account:read`,
  `user:read`, `workers:write`, `workers_routes:write`, `d1:write`, `zone:read`等は使えるが、
  ゾーン作成(`zones` POST)・ゾーン設定変更(`zones/{id}/settings/*`)は権限外。これらは
  ダッシュボードでの手動操作か、`Zone:Edit`スコープを持つ別のAPIトークン発行が必要。

## 追記(2026-08-03): ヒーロー画像を「App Store提出用マーケティング画像」から「生のUIスクリーンショット」に差し替え

依頼者から指摘: これまでヒーロー・howitworksで使っていた`00〜03-*.webp`は
`branding/mockups/app-store-resized/`由来 — つまり**App Store提出用に、端末フレーム+
マーケティングコピー(「ONE SKY. EVERY MORNING.」等の大見出し)を画像自体に焼き込み済み**の
素材だった。これを自作の`.phone-frame`(CSS製ベゼル)の中に入れると、フレームの二重掛け+
無関係な見出しテキストが写り込む状態になっていた。加えて同じ画像を2〜3箇所で使い回していた
(`00-skygrid-overview-v1`をヒーローとstep3、`01-today-one-sky-v1`をヒーローとstep1で重複)。

**対応:** `screenshots/`ディレクトリ(2026-07-30のUI監査セッションで撮影済みの、フレーム・
テキスト一切なしの生シミュレータスクリーンショット)から`ui-audit-today-final.png` /
`ui-audit-grid-final.png` / `ui-audit-buddies-final.png`を採用。新規にシミュレータを起動する
必要はなかった(既存の高品質な生スクリーンショットで要件を満たせたため)。`sips -Z 480`で
リサイズ→`cwebp -q 82`で圧縮(各4〜8KB、旧素材の14〜22KBよりむしろ軽量化)、
`waitlist/site/images/{today,grid,buddies}-screen-v1.webp`として配置。

**構成変更:** 画像が3枚(today/grid/buddies)しかない事実に合わせてページ構造を単純化。
ヒーローの端末モックアップ(2枚重ね)を廃止しテキスト+CTAのみに変更(直後のモザイク装飾で
視覚的な間は確保)。howitworksの3ステップに1枚ずつ充当し、「Share your sky」ステップは
実際のshareフロー画像が用意できなかったため廃止 — 代わりにGrid画面のスクリーンショットに
実際に写り込んでいる「Share」ボタンに言及する形でstep2のコピーに統合。独立していた
`.highlight`(buddies)セクションはstep3に統合し廃止。Buddies画面のコピーは、実機に
写っている「Invite → Capture → Reveal」の実際のUIフローに合わせて書き直した(空想では
なく画面の実物に基づく)。

**削除:** 旧`01〜03-*.webp`(3ファイル)は全参照箇所から削除済みのため
`waitlist/site/images/`から削除(コード上に未使用資産を残さない方針)。
`00-skygrid-overview-v1.webp`だけは`og:image`のSNSシェアカード用途として残した
(テキスト焼き込み画像が正解のため、意図的にそのまま)。

デプロイ・検証済み(`https://skygrid.my/`で新コンテンツ確認、旧`01-today-one-sky-v1.webp`は
404を確認)。
