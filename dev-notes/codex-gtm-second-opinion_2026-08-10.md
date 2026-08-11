# Sky Grid の有償ユーザー獲得戦略 — 第二意見と独自調査

調査日: 2026-08-10

対象: 米国・英語圏、現金支出上限 $300

前提: 依頼文に記載されたプロダクト、公開日、価格、レビュー数、既存施策の事実は所与とした。アカウント内だけに見える TikTok One の数値は、依頼者による観測値であり、本調査では再ログイン・送信・課金を行っていない。

## 結論

1. TikTok One の `Expected rate` はクリエイターが登録する開始価格・概算であり、`Platform-suggested rate` も自動請求額ではない。実際の支払根拠は、プロジェクトで提示し、必要なら相手がカウンターし、ブランドが最終承認した価格である。TikTok は「検索は無料、合意したレートで選んだクリエイターにだけ支払う」と明記している。[TikTok One overview](https://getstarted.tiktok.com/phase3/tiktok-one?lang=en&phase=3)、[広告主向け支払ヘルプ](https://ads.tiktok.com/help/article/about-payments-on-tiktok-one?lang=en)
2. Invite の送信だけでは自動課金されない。ただし、承諾済み案件を払わない、合意後のキャンセルを反復する、誠実に交渉しない行為は制裁対象である。したがって「1000人へ低額を一斉送信」ではなく、**予算内で全件成立しても履行できる3件程度の小ロット**で価格発見するのが妥当である。[Brand Code of Conduct](https://ads.tiktok.com/help/article/tiktok-one-brand-code-of-conduct?lang=en)
3. 一覧価格 ÷ 過去の median views を「実効 CPM」と呼ぶのは誤りである。これは、未合意価格と保証されない過去視聴数を割った仮想値にすぎない。安い大量リーチが絶対に無価値とは言えないが、Sky Grid の目的は視聴ではなく、App Store 遷移、初回起床行動、課金である。クリエイターと課題の適合、デモの説得力、測定可能性を先に見るべきである。
4. $300 以下で「有料転換そのもの」を成果報酬で確実に買える、かつ日本の個人が利用できる現行サービスは確認できなかった。現時点の最善策は、**$0 のニッチコミュニティ獲得でレビューと実需を作り、その後 Apple Ads の検索結果広告を最大 $120 まで段階検証し、残額は勝ち筋が出るまで使わない**ことである。
5. Whop Content Rewards は現行ブランド規約上 CPM キャンペーン最低 $500 のため予算外。Noise は Shipaton の 1:1 マッチングクレジットにより例外的に試せるが、買えるのは基本的に views であり、Noise 自身が install をキャンペーン別に帰属できないと明記している。これは「転換獲得」ではなく、クリエイティブ量産・Shipaton の Most Viral 枠を狙う別目的の選択肢である。

## エビデンスの扱い

- **確認済み**: 現行の公式ヘルプ、規約、Apple/RevenueCat/Shipaton の一次情報。
- **実測・自己申告**: 開発者本人またはブランド担当者が公開した管理画面数値。監査済みではない。
- **推定**: 確認済みの価格・率から本稿で計算した値。
- **未確認**: 公開規約に記載がなく、アカウント登録や問い合わせをしないと確定できない事項。

---

## Part 1 — 既存分析の批判的評価

### 1. `Expected rate` と `Platform-suggested rate` のどちらが請求額か

結論は、**どちらも請求額ではない**。

| 表示・段階 | 確認できた意味 | 支払への拘束性 |
|---|---|---|
| `Expected rate` / starting rate | クリエイターがプロフィールへ登録する開始価格。公式はクリエイターが `starting rates` を追加できると説明している。[TikTok 公式](https://ads.tiktok.com/help/article/how-creators-can-sign-up-for-tiktok-one?lang=en) | なし。発見・絞り込み用の自己申告値 |
| `Platform-suggested rate` | **現行の公開公式ヘルプでは定義・算定式を確認できなかった**。旧 Creator Marketplace を実運用した代理店は、TikTok が類似クリエイターから価格帯を提案すると報告しているが、2023年情報である。[Bronco](https://www.bronco.co.uk/our-ideas/an-agencys-guide-to-tiktok-creator-marketplace-for-brands/) | 少なくとも自動請求額ではない。参考ベンチマークとみるのが安全 |
| ブランドの offer | プロジェクト招待に記載する具体的な金額。creator は `Accept` または `Negotiate` を選べる。[TikTok 公式](https://ads.tiktok.com/help/article/how-creators-can-find-and-join-tiktok-one-projects?lang=en) | 相手が承諾すれば案件条件になる |
| counteroffer と最終承認 | 価格交渉後、ブランドが新価格を承認または拒否する。[プロジェクト作成フロー](https://ads.tiktok.com/help/article/how-to-create-a-new-creator-marketing-project-in-tiktok-one?lang=en) | ブランドが新価格と支払を確認した時点の金額が支払根拠 |
| 決済 | クリエイター承諾後にブランドが `Pay now`。TikTok は、ブランドが新価格と支払を承認するまで課金しないと明記する。[支払ヘルプ](https://ads.tiktok.com/help/article/about-payments-on-tiktok-one?lang=en) | ここで実際の請求。税・決済事業者手数料が追加され得る |

TikTok One のオンライン決済自体に TikTok のサービス手数料はない。ただし、税、決済事業者手数料、為替換算は別である。また、クロスボーダー決済は「対応する一部地域」に限定され、非対応なら決済入力時に表示される。[TikTok 支払ヘルプ](https://ads.tiktok.com/help/article/about-payments-on-tiktok-one?lang=en) **日本の個人ブランドから米国クリエイターへのオンライン決済可否は、公開文書だけでは未確認**である。

実利用者の報告も、一覧レートを見積書として扱うべきでないことを裏付ける。旧 Marketplace のブランド代理店では、掲載 $250 に対して実際の要求が $15,000–$25,000 だった事例があり、Sway Group は掲載額より実要求が高いケースを約75%で経験したと報告した。ただし、これは2022年の旧UIに関する補助証拠である。[Marketing Brew](https://www.marketingbrew.com/stories/2022/10/27/the-tiktok-creator-marketplace-is-experiencing-some-growing-pains)

したがって、依頼文で観測された $55 対 $3,463、$100 対 $15,590 の乖離は「プロフィール側が請求額」という意味ではない。分かるのは、**一覧の開始価格が価格予測として弱い**ことまでである。

### 2. Invite は無料か。低予算で大量に送れるか

**送信だけで課金はされない**。TikTok はプラットフォーム閲覧・クリエイター検索を無料とし、選んだ相手との合意レートだけを支払うとしている。[TikTok One overview](https://getstarted.tiktok.com/phase3/tiktok-one?lang=en&phase=3) クリエイターは direct invitation の受領後に支払条件を見て承諾または交渉できる。公式が7日の失効期限を明示しているのは invite link フローであり、direct invitation の期限は公開文書では確認できなかった。[TikTok 公式](https://ads.tiktok.com/help/article/how-creators-can-find-and-join-tiktok-one-projects?lang=en)

ただし、「無料だから無差別に大量送信できる」までは言えない。

- TikTok は、上限制約を回避する複数アカウント作成を spam として明示的に禁止している。つまり検索・注文等に上限が存在し得る。[Brand Code](https://ads.tiktok.com/help/article/tiktok-one-brand-code-of-conduct?lang=en)
- 誠実な交渉を繰り返し怠る、合意案件を払わない、不適切なキャンセルを反復する行為も禁止され、検索・outreach・新規キャンペーン作成の制限や停止対象になり得る。[Brand Code](https://ads.tiktok.com/help/article/tiktok-one-brand-code-of-conduct?lang=en)
- ブランド側の公開公式文書では、Creator Marketing の招待上限件数を確認できなかった。2026年4月のブランド利用者は「以前は約100件送り約15%が承諾、現在は週50件に制限」と報告しているが、これは一アカウントの自己申告で、地域・時期・アカウント状態に依存する。[ブランド利用者の報告](https://www.reddit.com/r/TikTokMarketing/comments/1sy5lfe/working_around_limit_on_number_of_collab_requests/)

Sky Grid 向けの安全な価格発見は次の形である。

1. 直近の投稿、起床・night routine・habit 系の実演、米国視聴者、過去 branded content をプロフィールで確認する。
2. 一度に3件程度へ、全員が成立しても払える $50–$75 の**本気の offer**を提示する。金額は本稿の予算管理上の提案であり、相場保証ではない。
3. direct invitation は7日を運用上の回答目安とし、承諾案件を履行してから次の小ロットへ進む。この7日は本稿の目安で、公式の direct invitation 期限ではない。価格だけを調べる目的の虚偽案件にはしない。
4. 二次利用、Spark Ads、独占などを初回から広く要求しない。追加権利は通常、価格を上げる。

「低予算で応じた相手だけ拾う」は、**少量・誠実・全成立時も履行可能**という条件なら成立する。一方、受諾後に選別して大半を切る設計は、課金前でも規約・信用上のリスクがある。

### 3. Creator 一覧の読み方で見落とされている点

- TikTok の median views と engagement rate は「直近30日」ではなく、**直近30本の動画**から計算される。9か月投稿していなくても古い30本が残り得るため、一覧の数値だけでは再現可能性を示さない。[TikTok 公式](https://ads.tiktok.com/help/article/how-to-find-creators-in-tiktok-one?lang=en)
- Creator score は inactivity で失効・減衰しない。したがって高スコアでも休眠リスクは別途見る必要がある。[Creator score 公式](https://ads.tiktok.com/help/article/about-the-tiktok-one-creator-score?lang=en)
- 依頼文の「視聴者のうち実フォロワーは1.22%」という表現は注意が必要である。公開ヘルプではこのフィールドの厳密な定義を確認できなかった。もし「視聴者のうち当該アカウントをフォローしている割合」なら、低値は FYP で非フォロワーへ広く届いたことも意味し、偽視聴者率ではない。暖かい既存オーディエンスの弱さを示す可能性はあるが、bot 判定には使えない。**厳密定義は未確認**。
- `Response rate 8.33%` は、TikTok が invitation、accepted order、login 等から作る engagement metric の一種だが、公開ポリシーに計算期間・分母はない。[Creator Program Privacy Policy](https://ads.tiktok.com/help/article/tiktok-one-creator-program-privacy-policy-us?lang=en) よって「今後も必ず12件に1件」と解釈するのは強すぎる。低応答の警告信号としては有用である。

### 4. 「CPM が安い＝良い」ではないか

既存分析の方向性は妥当だが、「ミーム転載系は絶対に売れない」と断定する根拠まではない。正確には次のとおりである。

- 研究上、influencer–product–consumer の congruence は、商品態度、購入・推奨意図と正の関係を持つ。[Journal of Business Research, 2021](https://www.sciencedirect.com/science/article/pii/S0148296321002307) 7,500人超を対象にした別研究でも influencer–follower congruence と購買行動の関係が検証されている。[Journal of Retailing and Consumer Services, 2023](https://www.sciencedirect.com/science/article/pii/S0969698923002539)
- Sky Grid は「視聴→App Store→iOS 26 対応端末→初回設定→翌朝撮影→課金」という摩擦の多いファネルである。一般ミームの大量視聴は awareness には使えても、課題認識と実演がないと後段で落ちやすい、というのが本稿の**推論**である。
- 個人開発者 Michael Rode の実測では、TikTok Promote に $200 を投じ「大量 views、conversion 0」。一方、ニッチな fitness subreddit では約150人がリスト登録、約100人が TestFlight、約30人がフィードバックし、最初の約200ユーザー獲得に Reddit が役立った。[GainFrame の公開実績](https://gainframe.app/blog/two-months-launching-second-app/)

したがって、クリエイター評価の主指標は仮想 CPM ではなく、最終的には次である。

> paid CPA = クリエイターへの確定支払総額 ÷ そのクリエイターに帰属できた有料ユーザー数

TikTok One の App download anchor は動画内に App Store 導線を置けるが、公式には third-party tracking と download metrics 非対応で、取得できるのは Anchor CTR / CTA CTR までである。[App download anchor 公式](https://ads.tiktok.com/help/article/how-to-create-a-tiktok-one-app-download-anchor?lang=en) Apple の campaign link は、リンクごとに impression、download、sales、subscription を追跡できるが、5件以上の first-time download が出るまで個別キャンペーンは表示されない。[Apple Campaign Links](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links) TikTok anchor が Apple の `ct` / `pt` パラメータを保持するかは**未確認**なので、実施前にプレビューと小額テストが必要である。

---

## Part 2 — 安く install と paid conversion を得る方法

### 1. まず採算ラインを置く

2026年4–6月の米国 Apple Ads 検索結果広告について、SplitMetrics は Health & Fitness の CPA（install）を $2.38、Lifestyle を $2.90 と報告している。これは広告運用会社の集計であり、Apple公式保証ではない。[SplitMetrics 2026 benchmark](https://splitmetrics.com/blog/apple-search-ads/)

Small Business Program の15%手数料に加入済みと仮定すると、税を無視した初回手取りは月額 $3.39、年額 $25.49、Lifetime $33.99 である。15%適用は自動ではなく加入が必要である。[Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/)

| install CPA | 月額の初月だけで回収する install→paid 率 | 年額の初回決済で回収 | Lifetime で回収 |
|---:|---:|---:|---:|
| $2.38 | 70.2% | 9.3% | 7.0% |
| $2.90 | 85.5% | 11.4% | 8.5% |

これは本稿の**計算値**で、税・返金・継続率を含まない。install→paid が5%なら有料ユーザー1人あたり獲得費は $47.60–$58.00。月額ユーザーで回収するには約14–17か月の有料継続、年額なら約1.9–2.3回分の決済が必要で、Lifetime は初回売上だけでは回収不能である。依頼文の一般 iOS CPI $5.84 を使えばさらに悪化する。

従って、$300 は利益を買う予算ではなく、**どの検索意図・訴求が paid conversion を生むかを学ぶ予算**と位置づけるべきである。

### 2. チャネル別の再評価

#### Apple Ads — 最優先の有料テスト

Apple の検索結果広告はダウンロードを探している瞬間に出て、上部枠の平均 conversion は60%超。関連性がなければ入札額にかかわらず auction に入らない。[Apple Ads 公式](https://ads.apple.com/app-store/help/ad-placements/0082-search-results) 検索意図があるため、今回調べた有料チャネルの中では install に最も近い。

日本居住の広告主も Apple Ads を利用でき、JPY、USD 等の請求通貨と Visa / Mastercard / American Express に対応する。[利用可能地域](https://ads.apple.com/app-store/countries-and-regions)、[支払方法](https://ads.apple.com/app-store/help/get-started/0030-set-your-payment-method) 新規アカウントで条件を満たせば、一度限り $100 のプロモーションクレジットが自動付与される。**Sky Grid のアカウントが未使用かは未確認**。[Apple 公式プロモーションクレジット](https://ads.apple.com/jp/app-store/help/billing/0032-apple-ads-promo-credit)

レビュー0件のまま全額投入は勧めない。Apple 自身が「rating が少ないと download をためらわせ得る」と説明している。[Apple Ratings and Reviews](https://developer.apple.com/app-store/ratings-and-reviews/) ただしレビューが自然に増えるまで完全停止する必要もなく、次の段階テストが妥当である。

- v1.0.1 承認後、まず $30 相当（新規 $100 credit があればそれを優先）を米国の search results に限定する。
- `Manage Bids` で、`morning routine`、`wake up alarm`、`habit alarm`、`photo journal` 等の少数の exact intent 群と、少額の Search Match discovery を分ける。ブランド語 `Sky Grid` は需要発見用の別枠にし、主予算を割かない。ブランド検索が無ければ安くても増分獲得にならない。
- Apple は generic、competitor、brand、discovery を分離し、discovery では Search Match を使うことを推奨している。[Apple keyword guidance](https://ads.apple.com/app-store/help/keywords/0014-add-and-manage-keywords)
- 最初の $30 で relevant search term、tap→install、実起動・初回設定を確認する。CPI が概ね $3.50 以下、tap→install が35%以上、かつ起床設定まで進むユーザーが確認できた場合だけ、累計 $120 まで拡張する。これらの閾値はレビュー0件と小標本を考慮した本稿の**運用仮説**であり、公式基準ではない。
- 累計約40 installs で paid 0、または Day 7 paid conversion が10%未満なら、利益目的の追加出稿は止める。10%でもプラン構成と継続率次第でようやく採算境界付近であり、即スケール条件ではない。

Apple の「suggested CPI」は上限や請求確定額ではない。個人開発者 Ben Dodson は提示 £5.61 に対し、数週間で22 installs、実績 £0.89/install だった。2023年・有料アプリの古い一例で再現保証はないが、推奨値と実績が一致しないことを示す。[本人の postmortem](https://bendodson.com/weblog/2023/03/14/postmortem-of-a-top-10-paid-ios-app/)

#### Whop Content Rewards — $300 では不採用

現行ブランド規約は CPM campaign の最低予算を $500、verified brand の platform fee を8%、それ以外を10%としている。[Content Rewards Brand Terms](https://contentrewards.com/terms-of-service/brands) 一方、FAQ の7%は clipper payout から引く**クリエイター側手数料**であり、ブランド手数料ではない。[Content Rewards FAQ](https://contentrewards.com/faqs)

Whop 全体は195か国、135以上の通貨、100以上の支払方法を掲げ、日本は payout 対応国に含まれる。[Whop fees](https://docs.whop.com/payments-and-billing/fees/fees)、[supported countries](https://docs.whop.com/manage-your-business/manage-payouts/set-up-payouts) しかし、これは日本在住の個人が Content Rewards の**ブランド審査**を通り、日本発行カードで fund できることの明示確認ではない。ブランド登録可否は未確認である。いずれにせよ最低 $500 の時点で今回の予算外となる。

#### Noise — Shipaton 用なら条件付き、conversion 購入としては弱い

Noise の新しい dynamic campaign は最低 $50/日で、日予算は hard cap ではなく学習中に超過し得る。公式は7–10日の学習を推奨し、全体平均 CPM は約 $1.25 としている。[Noise brand guide](https://getnoise.com/welcome/) 通常なら最低7日で $350 となり予算外である。

ただし Shipaton 2026 の Ship Kit は、Noise で支出した $1 ごとに $1 を追加する matching credit を上限 $1,000 まで提供する。従って規約どおり適用されるなら、現金 $175 で creator spend $350 相当、最低7日を構成できる。[Shipaton Resources / Ship Kit](https://revenuecat-shipaton-2026.devpost.com/resources) **マッチングが手数料・税より前か後か、付与時期、未消化 credit の扱いは未確認**である。

重大な欠点は測定である。Noise は App Store Connect の first-party installs を日別・組織全体で表示できるが、「store はどの campaign が install を生んだか知らないため、campaign / playbook 別には分割できない」と明記する。[Noise Metrics](https://getnoise.com/docs/understanding-your-metrics) また terms は18歳以上という一般条件しか示さず、サービス手数料率と日本の個人ブランド決済可否を公開していない。[Noise Terms](https://getnoise.com/terms-of-service)

結論: Apple Ads とは目的が違う。Most Viral App 賞、UGC hook の量産、時系列の増分 install を見る目的なら現金上限 $175 の実験候補。**有料転換 CPA を測って買う方法としては推奨しない**。

#### TikTok One Creator Marketing — 価格発見は実施価値あり、発注は条件付き

検索・invite は無料なので、休眠を除外した small creator に小ロット offer を送り、実際の quote を集める価値はある。発注条件は次のすべてを満たす場合に限定する。

- 直近7日以内に投稿し、過去30日で継続投稿がある。
- morning routine、night routine、alarm、accountability の実体験コンテンツがある。
- US audience が明確で、過去の median だけでなく直近動画の下振れも予算計算に入れる。
- $75 以下の合意、動画1本、organic post、App download anchor、明確な「明日の朝から使う」デモが成立する。
- 可能なら Apple campaign link を割り当て、TikTok がパラメータを保持することを事前確認する。できなければ CTA click と出稿期間の増分 install しか測れない。

この条件を満たさなければ支出しない。$75 は相場ではなく、Sky Grid の総予算から逆算した stop price である。

#### Reddit・ニッチコミュニティ — 最も安い初期 install、ただし spam は逆効果

有償広告より、問題を抱えるコミュニティで「アプリの宣伝」ではなく「朝に起きられない／継続できない問題と、その設計」を共有する方が初期 CPA は低くなり得る。Sky Grid は buddy の相互ロックと毎朝の空という、スクリーンショットで説明しやすい固有フックがある。

ただし大手 productivity subreddit への無断宣伝は避ける。`r/productivity` は広告・自己宣伝を禁止し、`r/getdisciplined` も self-post の外部リンクを制限している。[r/productivity removal notice](https://www.reddit.com/r/productivity/comments/17tsx50/removed/)、[r/getdisciplined posting rules](https://www.reddit.com/r/getdisciplined/comments/dmydjp/) 現在 `r/iOSApps` は developer 投稿に ABC（Answer / Better / Cost）形式を求め、通常投稿の資格がなければ月次 App Shelf を使える。[2026-08 App Shelf](https://www.reddit.com/r/iosapps/comments/1vcqiq9/megathread_the_app_shelf_august_2026/)

実施案は以下である。

- App Store Connect で `reddit_iosapps`、`shipaton`、`creator_x` の campaign link を分ける。Apple は download、usage、sales、subscription を token ごとに追跡し、5 first-time downloads で表示する。[Apple Campaign Links](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links)
- `r/iOSApps` の規則どおり、問題、主要代替との差、月額・年額・Lifetime を明示する。
- 起床・習慣 subreddit では、リンク投稿が許可された dedicated thread または moderator 許可がある場合だけ出す。隠れた宣伝、架空の体験談、組織的 upvote は行わない。
- 「7-day Sky Grid morning challenge」のように buddy 2人で参加できる形式を提示し、download 数より、翌朝撮影率、buddy 招待率、Day 7 retention、paid conversion を見る。これは本稿の施策仮説である。

Discord について、米国の起床習慣ユーザーが集まり、自己宣伝を許可する公開サーバーは今回の検索では確認できなかった。無関係なサーバーへの投稿は推奨しない。Shipaton Discord はフィードバック獲得先として使えるが、参加者は主に開発者であり、購入者母集団とは限らない。

### 3. $300 以下で初速を作った具体例

以下はすべて本人・当事者の自己申告で、監査済み広告実験ではない。

| 事例 | 費用・結果 | Sky Grid への含意 | 限界 |
|---|---|---|---|
| GainFrame / Michael Rode（2026） | ニッチ Reddit から約150 list signup、約100 TestFlight、約30 feedback、5–10 power users。公開20日で305 first-time downloads、59 IAP、proceeds $99、Day 7 download→paid 3.13%。Reddit ads は $115.69 で149 clicks、install 未計測。Apple Ads は $20.69、CPA $6.86。TikTok Promote $200 は conversion 0。[本人記事](https://gainframe.app/blog/two-months-launching-second-app/) | ニッチな実使用画像と会話は、一般広告より質の高い初期ユーザーを作り得る。paid は小額でも必ずしも安くない | 単一事例。paid conversion のプラン内容が Sky Grid と異なる |
| CashLens / Rushiraj Jadeja（2026） | marketing $0、3,000+ downloads、4.8★・6 ratings、conversion 14.78%、73.6% が App Store Search。起点は約200 upvotes の Reddit 投稿。ただし revenue は約 $0、Day 7 retention 5.56%。[本人記事](https://www.rushiraj.me/blog/3000-downloads-zero-marketing-budget) | Reddit→初期 rating→検索流入の flywheel は可能 | install 成功であって paid conversion 成功ではない |
| Trackit / Mukesh Khatri（2026） | 公開3日で約200 downloads、$22 MRR、全ユーザーが Reddit 由来と本人が申告。[Reddit 投稿](https://www.reddit.com/r/AppBusiness/comments/1re7wj2/3_days_after_launch_22_mrr_200_downloads_heres/) App Store 上の開発者名と IAP は確認できる。[App Store](https://apps.apple.com/us/app/subscription-tracker-trackit/id6758032496) | story、screenshots、privacy を先に出す型で実課金まで到達した近年例 | 投稿内の「170k users」は文脈上 views の誤記らしく、数値品質に疑義。現在のアプリ仕様も公開時から変化 |
| Music Library Tracker / Ben Dodson（2023） | Apple Ads 提示 CPI £5.61 に対し22 installs・実績 £0.89。関連性の高い 9to5Mac 掲載後、28日 profit $5,351、米国 paid app 8位。[本人 postmortem](https://bendodson.com/weblog/2023/03/14/postmortem-of-a-top-10-paid-ios-app/) | 推奨 CPI は実績ではなく、狭い課題に合う媒体1件が広い露出より強いことがある | 2023年、既存有料アプリ、過去メディア関係あり。新規 freemium へ直接移植不可 |

共通点は、低価格の大量露出ではなく、**問題と媒体の適合、具体的なストーリー、初期ユーザーとの会話**である。

### 4. Shipaton 2026 の無料成長支援の実効性

確認できた公式事実は次のとおり。

- Discord は discussion、feedback、help、team formation を提供し、`#post-engagement-boost` では参加者同士が BuildInPublic 投稿を支援する。[RevenueCat announcement](https://www.revenuecat.com/blog/company/announcing-shipaton-2026/)
- 公式 resources は同チャンネルと Ship Kit を案内し、2026-08-10 時点の Devpost 画面には14,882 participants と表示された。[Shipaton Resources](https://revenuecat-shipaton-2026.devpost.com/resources)
- Ship Kit には Noise の最大 $1,000 matching credits と、Tenjin All-Inclusive Plan S の3か月無料枠（表示価値 $600）が含まれる。[Shipaton Resources](https://revenuecat-shipaton-2026.devpost.com/resources)
- 2025年は812 projects が提出されたが、公式 winner recap は `#post-engagement-boost` が各アプリの install・revenue をどれだけ増やしたかを公開していない。[2025 winners](https://revenuecat-shipaton-2025.devpost.com/updates/39047-shipaton-2025-winners-announced)

**確認できなかったこと**: `#post-engagement-boost` の平均 impression 増、App Store click、install、paid conversion、または BuildInPublic 投稿と受賞・売上の因果効果。2026年イベントは開始直後でもあり、公開一次情報に定量効果は見つからなかった。

評価としては、利用コストが $0 なので使う価値はあるが、主目的は peer feedback、投稿の初速、審査向け活動記録である。米国の「朝起きたい人」への配信ではないため、ユーザー獲得チャネルとしては campaign link で実測し、install が出なければ時間を使いすぎない。

---

## 推奨する $300 の段階配分

予算は上限であり、使い切る目標にしない。

| Gate | 現金上限 | 実施内容 | 次へ進む条件 |
|---|---:|---|---|
| 0. 計測と初期証拠 | $0 | Apple campaign links をチャネル別に作る。v1.0.1 後、r/iOSApps App Shelf、規則を満たすニッチ投稿、Shipaton Discord で20–50人の実利用を目標にする | 複数人が翌朝撮影まで到達し、少数でも genuine US ratings が付く。3–5 ratings は本稿の運用目安で公式閾値ではない |
| 1. Apple Ads 診断 | $30 | 米国 search results の exact high-intent + 小額 Search Match。新規 $100 credit が使えるなら現金より先に使う | relevant search term、CPI概ね $3.50以下、tap→install 35%以上、起床設定までの activation を確認 |
| 2. Apple Ads 拡張 | 追加 $90、累計 $120 | 勝った検索語だけへ寄せる。brand keyword は増分需要が確認できない限り拡大しない | 約40 installs 時点で paid が発生し、Day 7 paid conversion とプラン構成から継続検証の価値がある |
| 3. 残額 | 最大 $180 | 勝ち検索語があれば拡張。なければ**保留**。代替として、条件を満たす TikTok creator 1本を $75以下、または Shipaton目的の Noise を現金 $175まで | 一度に両方は行わず、単一仮説を測定できること |

Stop rules:

- 約40 paid-source installs で paid 0なら、追加の有料獲得を止め、onboarding、paywall、翌朝 retention の改善へ戻る。
- creator 発注は、合意額だけでなく税・為替を含む総額が残予算内であることを決済確認画面で確認する。
- views、likes、CPM は補助指標。主要指標は channel-attributed first-time downloads、翌朝撮影、Day 7 retention、paid conversion、paid CAC とする。
- レビューを報酬条件にしない。Apple は満足が生じた適切なタイミングでの依頼を推奨し、標準 prompt は365日で最大3回に制限する。[Apple Ratings and Reviews](https://developer.apple.com/app-store/ratings-and-reviews/)

## 最終判断

- **今すぐ大量 invite**: 不採用。送信課金はないが、掲載レートの精度、履行義務、休眠、測定の問題がある。
- **小ロット invite による価格発見**: 採用。3件程度、全成立時も払える範囲、アクティブで課題適合する creator に限定する。
- **Apple Ads**: 条件付き採用。レビュー0のまま $300 全投入はしない。新規 $100 credit の有無を確認し、$30→累計 $120 の gate 方式にする。
- **Whop Content Rewards**: 不採用。最低 $500。
- **Noise**: conversion 獲得としては不採用。Shipaton matching credit を使う UGC・virality 実験としてのみ条件付き採用。
- **Reddit / Shipaton**: 採用。ただし「無料広告枠」ではなく、規則に従う problem-first の投稿、計測リンク、ユーザー会話に限定する。

この予算規模では、最も安い conversion は「安い views を買う」ことではなく、**無料で得た最初の実需要から有料転換率を確認し、その証拠が出た検索意図だけを Apple Ads で買う**ことである。

## 未確認事項

1. TikTok One の `Platform-suggested rate` の現行公式な算定式と更新頻度。
2. TikTok Creator Marketing のブランド側 invite 上限。週50件は利用者1名の報告にとどまる。
3. 日本の個人ブランドから米国 creator への TikTok One online cross-border payment 可否。
4. TikTok App download anchor が Apple campaign link の `pt` / `ct` を保持するか。
5. Content Rewards の日本の個人ブランド審査・日本発行カード funding 可否。最低 $500 のため今回の結論には影響しない。
6. Noise のブランド手数料率、日本の個人ブランド決済、Shipaton matching credit の税・手数料・付与時期の詳細。
7. `#post-engagement-boost` の install / paid conversion に対する定量効果。公開一次データは見つからなかった。
