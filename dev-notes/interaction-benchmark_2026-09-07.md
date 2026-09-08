# Interaction benchmark — onboarding / character / paywall / morning habit

調査日: 2026-09-07  
対象: iOS / モバイル 45アプリ  
目的: SkyGrid の複数アラーム、日付更新、会話型オンボーディング、質問パーソナライズ、体験後ペイウォールに転用できる具体パターンを抽出する。

## 結論

SkyGrid に最も相性がよい組み合わせは、**Finch の「世話したくなる相棒」＋ Duolingo の短い会話と祝福＋ RISE の曜日別複数アラーム＋ Pokémon Sleep の「翌朝に開ける発見」＋ Balance の回答即時反映**である。課金前に長い疑似診断や映像を見せるより、最初の空を撮る、またはサンプルの空で1セルが埋まる体験を30〜45秒で終え、その成果をキャラクターが解説してから Pro を提示する方が、SkyGrid 固有の価値を伝えやすい。

避けるべきなのは、結果が変わらない質問、閉じる場所が分かりにくいペイウォール、アラーム解除を遅らせる長い演出、撮影前の重いアニメーション、キャラクターが罪悪感を煽る通知である。特に起床直後は待ち時間への耐性が低い。装飾は 300〜700ms の状態遷移、課金前の価値演出だけ 2〜4秒を上限にする。

## 判断の前提

- 目標指標: **Install→初回撮影完了率**。現在値は **未測定**（`PRODUCT-MODEL.md` の既存イベントは到着確認済みだが、母数7で判断不能）。この変更をしない場合、説明と質問が増えて初回撮影までの距離だけが伸びる可能性がある。
- 現実の主張: キャラクター、連続記録、成長する収集物、短い祝福は多くの継続型アプリで反復採用されている。複数アラームは RISE で曜日別の追加アラームとして公式に確認できる。
- 製品ベット: 「空の相棒が質問し、初回の1セルを一緒に作る」ことで初回撮影完了率が上がる。前提は、説明文より相棒との短い往復の方が価値を理解しやすいこと。最安テストは `onboarding_variant=companion` を50/50配信し、`first_open` を分母に初回撮影完了を比較する。7日成熟コホートで改善せず、オンボーディング完了率が悪化したら撤回する。
- 課金ベット: 「個別プランを作った」と言うだけでなく、回答がアラーム曜日・声かけ・朝の目標に実際に反映されたプレビューを見せれば paywall→trial が上がる。最安テストは結果プレビュー有無のA/B。`paywall_presented` 分母の trial start が上がらない、または refund/cancel が悪化したら撤回する。

## 証拠ラベル

- **P**: 開発元の公式サイト、公式ヘルプ、公式発表、または開発元自身の App Store 商品ページ本文で確認。
- **E**: Apple の編集記事・カテゴリ本文で存在や位置づけを確認。具体的な演出は公開スクリーンショット等からの推論を含む。
- **I**: パターンとして有望だが、今回取得した本文だけでは画面遷移の全工程を確定できない。実機で再確認してから模倣する。

## 45アプリの比較

| # | アプリ | 確認したインタラクション / 演出 | SkyGrid への適用判断 | 根拠 |
|---:|---|---|---|---|
| 1 | Duolingo | Duo が短く話しかけ、目標時間を選ばせ、1レッスン後に祝福と streak の意味を示す。小さな行動→即時報酬→翌日予告が一続き。 | **採用**: 空の相棒が「質問は6つ、1分だよ」と宣言。回答ごとに表情変化。初回セル完成後に streak ではなく「明日の空で2枚目」と予告。罪悪感コピーは不採用。 | P: [公式 habit 解説](https://blog.duolingo.com/putting-in-work-the-habit-of-language-learning/), [公式製品](https://www.duolingo.com/learn) |
| 2 | Finch | 自分の行動が birb のエネルギー、冒険、会話、衣装に変換される。撫でる操作でハートが出る。初日に既定ゴールが入り、空状態を避ける。 | **強く採用**: 相棒を1日1回タップ/撫でる軽い反応、撮影で相棒が色づく。相棒の健康を人質にする表現は不採用。 | P: [New User Guide](https://help.finchcare.com/hc/en-us/articles/42149821015693-New-User-Guide), [Home](https://help.finchcare.com/hc/en-us/articles/37780000231309-Exploring-the-Finch-Home-Page), [方針](https://help.finchcare.com/hc/en-us/articles/37935669335309-Our-Approach-to-Self-Care) |
| 3 | Headspace / Ebb | 「Hi, I’m Ebb」から会話型にニーズを聞き、回答を care plan に接続する。案内役を機能説明の外枠にする。 | **採用**: 1画面1発話＋1回答。自由入力は起床用途には重いので選択肢中心。医療的な擬人化はしない。 | P: [Headspace buyer guide](https://get.headspace.com/hubfs/Headspace_Investing_In_Workplace_Mental_Health_A_Buyer%E2%80%99s_Guide_Whitepaper_1-16-24.pdf?hsLang=en) |
| 4 | Noom | 短い質問→目標に沿うプラン→日々の短い教材。回答した「ultimate why」を後続のコーチングに使う。日次コンテンツは現地時刻の深夜に更新。 | **一部採用**: 質問の回答を実際のアラーム提案と通知口調に反映。日付更新を local day boundary で明示処理。長い診断・疑似精密スコアは不採用。 | P: [無料機能/深夜更新](https://www.noom.com/support/private/2025/07/free-features-in-the-noom-app-h/), [Big Picture](https://www.noom.com/support/faqs/using-the-app/daily-features/2025/10/understanding-your-big-picture-ybp/) |
| 5 | Flo | 目的・年齢・初期データ・質問を段階化し、目的によって後続UIと情報を変える。進捗と同意を別の画面として扱う。 | **採用**: 「写真習慣」「バディ」「起床」の目的で説明順を変える。質問前に写真/通知の権限を求めない。 | P: [公式 onboarding 解説](https://help.flo.health/hc/de/articles/4406826484500-Das-Einrichten-deines-Flo-Nutzerkontos) |
| 6 | Balance | 毎回、経験・目標・障害を短く尋ね、回答から内容を組み立て、利用に伴って再調整する。 | **強く採用**: 初回6問を固定プロフィールで終わらせず、朝の「起きやすさ」1タップで提案時刻/声かけを更新。 | P: [personalization](https://support.balanceapp.com/hc/en-us/articles/4407704821531-How-does-personalization-work), [公式製品](https://balanceapp.com/) |
| 7 | Calm | 視覚・音・呼吸など、説明より先に落ち着く短い体験を置き、Premium はライブラリ拡張として提示。 | **限定採用**: paywall 前に2〜4秒の空グラデーション＋触れるパララックス。起床直後の呼吸セッションは主動線に置かない。 | P: [製品群](https://support.calm.com/hc/en-us/articles/35795753391003-Available-Calm-Apps), [価格/無料体験](https://support.calm.com/hc/en-us/articles/360008240934-How-to-Check-Calm-Premium-Subscription-Pricing) |
| 8 | Liven | 短い初期 assessment→個別 Journey。章を順に開放し、読解だけでなく練習・振り返り・進捗を入れる。Livie が感情の相棒になる。 | **一部採用**: 回答→「あなたの朝プラン」生成演出→その場で編集可能。結果を見る前の課金要求は不採用。 | P: [personalized plan](https://support.theliven.com/hc/en-us/articles/31383165038994-Personalized-Plan-How-to-follow), [quiz](https://theliven.com/blog/wellbeing/dopamine-management/what-is-the-liven-quiz) |
| 9 | BetterMe | 質問から wellness program を作り、日課・challenge・進捗へ接続。価値を機能束で見せる。 | **限定採用**: 質問後に「平日7:00、休日8:30、やさしい声」など具体結果を見せる。機能羅列と強い自動更新誘導は不採用。 | P: [公式 features](https://bettermesupport.zendesk.com/hc/en-us/articles/360019398237-Which-features-are-included) |
| 10 | Fabulous | 朝・昼・夜の routine、短い coaching、journey を物語調に並べる。1つずつ習慣を積む。 | **採用**: アラームを「朝の儀式」の開始点にし、撮影後に水/ストレッチ等を任意で1つだけ提案。複雑なルーティン編集は後回し。 | P: [公式製品](https://www.thefabulous.co/), [App Store](https://apps.apple.com/us/app/fabulous-daily-habit-tracker/id1203637303) |
| 11 | Elevate | 初回評価と日々の成績から、難易度と daily workout を自動調整。ゲームごとに即時フィードバック。 | **採用**: 選択結果の直後に「ここが変わった」を表示。精密さを装う総合スコアは不要。 | P: [公式説明](https://support.elevateapp.com/hc/en-us/articles/4402922583067-What-is-Elevate), [公式製品](https://elevateapp.com/) |
| 12 | Impulse | 短いゲーム、認知プロフィール、日次プラン、streak、進捗レポートを連結。 | **限定採用**: 質問の間に1回だけ視覚的なミニ選択を入れて単調さを壊す。IQ風ラベルや不安を煽る比較は不採用。 | P: [App Store](https://apps.apple.com/us/app/impulse-brain-training/id1451295827) |
| 13 | Wysa | ペンギンとの会話を入口にし、匿名性と非評価的な口調を強調。会話から呼吸・セルフケアへ分岐。 | **採用**: キャラクターは短く、選択を否定しない。「今日は遅く起きた」でも連続記録を責めない。 | P: [App Store](https://apps.apple.com/us/app/wysa-mental-wellbeing-ai/id1166585565) |
| 14 | Earkick | Panda の表情、即時チェックイン、口調選択、統計、Watch の短い操作。登録なしですぐ使える。 | **採用**: 相棒の口調を「静か/元気/最小限」から選ばせる。朝の通知文と祝福に反映。会話ログ収集は不要。 | P: [App Store](https://apps.apple.com/us/app/earkick-self-care-ai-coach/id1584854531) |
| 15 | Amaru | セルフケアでペットとの bond が育つ。撫でる・餌・ミニゲーム・手描きアニメ・物語解放。基本セルフケアは無料。 | **強く採用**: 撮影回数で相棒の小さな外見/空模様が変わる。物語・装飾をProにし、撮影/アラームを人質にしない。 | P: [App Store](https://apps.apple.com/us/app/amaru-self-care-virtual-pet/id1503075227) |
| 16 | Kinder World | 2分の感情活動で植物を育て、部屋を飾り、動物キャストと出会う。植物は死なず、非線形な回復を許す。 | **採用**: 欠席で相棒を傷つけない。過去の空は残し、今日の空欄だけを穏やかに示す。 | P: [公式製品](https://www.playkinderworld.com/game), [press kit](https://www.playkinderworld.com/press-kit) |
| 17 | Habitica | 実タスクを経験値・装備・pet・quest に変換し、仲間との戦闘に接続。 | **非採用寄り**: 多層通貨/装備/罰は SkyGrid の静かな朝と競合。マイルストーン祝福と収集だけ借りる。 | P: [公式製品](https://habitica.com/static/home), [App Store](https://apps.apple.com/us/app/habitica-gamified-taskmanager/id994882113) |
| 18 | Waterllama | 飲むたびにキャラクターが満ち、140種を収集。日次 recap、challenge、sticker、widget まで同じキャラ言語で統一。 | **強く採用**: 写真の空色で相棒/カードが満ちる。年間モザイクを「集める理由」にする。大量キャラは初期スコープ外。 | P: [App Store](https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585) |
| 19 | Pokémon Sleep | 眠ること自体が翌朝の Pokémon 発見、図鑑、Snorlax 成長になる。「朝に見る理由」を作る。 | **最重要採用**: 撮影後にその日の「空のかけら/天気の表情」が開く。朝の撮影前に報酬を見せず、行動後の発見にする。 | P: [公式発表](https://www.pokemon.com/us/news/pokemon-sleep-is-now-available-on-the-app-store-and-google-play), [開発背景](https://corporate.pokemon.co.jp/en/topics/detail/t-9/) |
| 20 | Forest | 集中時間と同時に木が育ち、完了物が森として残る。途中離脱は枯れ木という可視的コスト。 | **一部採用**: 365セルを努力の景色にする発想は合う。撮り逃しを枯れ/失敗にする罰表現は不採用。 | P: [公式製品](https://www.forestapp.cc/en/), [Apple編集](https://apps.apple.com/us/iphone/story/id1451032333) |
| 21 | Focus Plant | 集中で雨粒を得て植物を育て、荒地を回復し、collection を開く。 | **限定採用**: 撮影→色/粒子→相棒の小世界が少し回復。追加ゲーム画面を増やさず Today 上で完結。 | P: [App Store](https://apps.apple.com/us/app/focus-plant-forest-app-blocker/id1459096306) |
| 22 | Study Bunny | timer→coin→部屋/音楽を購入。休止時に motivational advice。 | **限定採用**: 撮影後のcoinではなく、空の色から毎日1個の装飾が生成される方がSkyGrid固有。常設ショップは不採用。 | P: [App Store](https://apps.apple.com/us/app/study-bunny-focus-timer/id1478345385) |
| 23 | SleepTown | 就寝/起床目標を守ると寝ている間に建物が完成し、町として蓄積。家族・友人と同じ目標で建てられる。 | **採用**: バディ双方の当日投稿で shared cell が鮮明になる既存ループを、完成アニメで祝う。未投稿者への共同罰は避ける。 | P: [App Store](https://apps.apple.com/us/app/sleeptown/id1210251567) |
| 24 | Alarmy | 計算・shake等の解除 mission、複数 mission、無反応時の強い音など、起床を能動行動に変える。 | **一部採用**: 「写真を撮る」を任意の起床missionにできる。ただしカメラ権限/暗所/体調時に解除不能にしない。必ず通常停止を残す。 | P: [missions](https://alarmy-android.zendesk.com/hc/en-us/articles/360004242254--Mission-How-can-I-set-the-missions-math-shake-etc), [Premium](https://alarmy-android.zendesk.com/hc/en-us/articles/900001614846-Let-me-introduce-to-you-Alarmy-Premium-features) |
| 25 | RISE | 曜日を選ぶ反復アラーム、週末用の追加アラーム、gentle wake、時刻変更に連動する energy schedule。 | **そのまま採用**: 複数アラームを `time + active weekdays + label + enabled` のカード列で管理。曜日重複は警告し、次回発火を常に表示。 | P: [Smart Alarm](https://help.risescience.com/hc/en-us/articles/10960396186903-How-does-the-RISE-Smart-Alarm-work) |
| 26 | Sleep Cycle | 起床window内の浅い睡眠で鳴動、穏やかな音、睡眠レポート。アラームが単一操作に集約される。 | **限定採用**: wake window のUI、音の試聴、次回時刻の明示。睡眠段階推定はスコープ/信頼性が別製品になるため不採用。 | P: [Smart Alarm](https://sleepcycle.com/the-app/smart-alarm) |
| 27 | BetterSleep | tracker開始画面の中で wake window を設定し、音/物語/瞑想をmix。起床後は Insights へ続く。 | **一部採用**: アラーム作成中の音プレビューと、起床後に即カメラへつなぐ遷移。音コンテンツ群は不要。 | P: [Smart Alarm](https://www.bettersleep.com/support/en/articles/9391545-what-is-smart-alarm), [getting started](https://www.bettersleep.com/support/en/articles/11101160-bettersleep-getting-started-guide) |
| 28 | Routinery | routineを計画するだけでなく、音声とtimerで1ステップずつ進行。遅延しても柔軟に続ける。 | **採用**: 起床→カーテン→撮影のうち、SkyGridは撮影だけを主とする。任意の短い準備カウントダウンは可能。長い手順強制は不採用。 | P: [App Store](https://apps.apple.com/us/app/routine-planner-habit-tracker/id1450486923) |
| 29 | Structured | 1日の予定を1本の視覚timelineにし、drag、icon、色、Live Activity で現在位置を分かりやすくする。 | **採用**: アラーム一覧を「次に鳴る順」で視覚化し、Today に次回発火を1行表示。高密度timeline全体は不要。 | P: [公式製品](https://structured.app/), [App Store](https://apps.apple.com/us/app/structured-daily-planner-todo/id1499198946) |
| 30 | Me+ | MBTI等の質問からroutine提案、アイコン/色のカスタマイズ、朝/日次routine、mood/progressを統合。 | **限定採用**: 質問は実用的な起床時刻・曜日・声かけだけ。性格診断から因果のない推薦を作る方式は不採用。 | P: [App Store](https://apps.apple.com/us/app/me-lifestyle-routine/id1596403446) |
| 31 | Opal | 初回にscreen habitを質問し権限へつなぐ。focus中のblock、解除前speed bump、score、gem、milestone、友人招待。 | **採用**: 権限は価値説明→必要な瞬間→許可の順。撮影ボタン前のspeed bumpはUXを損なうので使わない。 | P: [公式FAQ](https://opalapp.com/help/what-is-opal), [機能比較](https://opalapp.com/screentime) |
| 32 | Imprint | 視覚カードを短い単位で進める micro learning。情報を図とタップの連続で見せる。 | **採用**: アラーム/モザイク/バディの3概念を、文章スライドではなく1つずつ触れるデモにする。 | E/I: [Apple Essential Education Apps](https://apps.apple.com/us/iphone/room/1441665140) |
| 33 | Headway | 要約を短い日次単位、challenge、進捗、視覚的な key insight に変える。 | **限定採用**: 「6問中2問」の進捗と、回答後の1行要約。連続アップセルや煽るカウントダウンは不採用。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |
| 34 | Blinkist | 短い Blink 単位と音声/読書の切替で、長い価値を小さく試せる。 | **採用**: オンボーディングの説明は1発話ずつ。後からスキップした説明を再確認できるようにする。 | E/I: [Apple Essential Education Apps](https://apps.apple.com/us/iphone/room/1441665140) |
| 35 | Brilliant | 説明の前に問題を触らせ、図形・数値が操作に追随し、正解時に視覚フィードバック。 | **強く採用**: サンプル空を撮影枠へdrag/tapしてモザイクの1セルが埋まる体験を先に置く。 | E/I: [Apple Education](https://apps.apple.com/us/iphone/grouping/25156) |
| 36 | Mimo | コードを短い選択/入力で完成させ、即時採点、streak、段階的unlockを行う。 | **採用**: 6問すべてを同じカード形式にせず、曜日選択や時刻ホイールを混ぜる。ただし正誤扱いはしない。 | E/I: [Apple Education](https://apps.apple.com/us/iphone/grouping/25156) |
| 37 | Lumosity | baseline game→daily training→score推移という「測ってから提案」の流れ。 | **非採用寄り**: 起床能力スコアは根拠と継続データが不足。実用設定だけを質問し、診断結果を装わない。 | E/I: [Apple Essential Education Apps](https://apps.apple.com/us/iphone/room/1441665140) |
| 38 | Simply Piano | 最初から音を出させ、1音でも成功を祝う。進行中に必要な権限/セットアップを文脈化。 | **採用**: 初回撮影の成功をオンボーディング内で完了し、紙吹雪は控えめに空の粒子で祝う。 | E/I: [Apple Essential Education Apps](https://apps.apple.com/us/iphone/room/1441665140) |
| 39 | stoic. | mood check-in、journal prompt、呼吸などを落ち着いた視覚で日次化。 | **限定採用**: 「今朝どう起きたい？」を通知口調選択として使う。感情質問を課金心理に利用しない。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |
| 40 | How We Feel | 感情を色/位置で選び、語彙を探索しながら記録する。 | **採用**: 空色と気分を任意で結ぶインタラクションはshare cardを語りやすくする。ただし必須質問にしない。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |
| 41 | Ahead | 会話的な emotional companion と短い練習で、怒り/不安を小さな行動に分ける。 | **採用**: キャラクターの発話は「説明→質問→応答」の3拍。長文チャット画面にしない。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |
| 42 | Paired | 相手に質問を送り、双方が答えることで会話が開く。関係性を単独行動ではなく往復にする。 | **強く採用**: 既存の「双方投稿で相手の空が開く」を、片側投稿時に明確な待ち状態と柔らかい招待/通知にする。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |
| 43 | Coral | quiz、conversation、shared activity を使って二者体験を段階化。 | **限定採用**: バディとの共有目標を「連続日数」より「今週そろった空」にする。親密さを煽るコピーは避ける。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |
| 44 | Evergreen | カップル向けquiz/game/adviceを日次に配り、答えを会話のきっかけにする。 | **採用**: 朝の空に任意の一言を添える軽いpromptは相互公開後の意味を増す。返信義務は作らない。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |
| 45 | Bird Alone | 1羽の鳥と毎日話し、時間経過・天候・短い創作活動で関係を育てる。静けさと有限性が体験の中心。 | **強く採用**: 相棒は常時しゃべらず、朝とマイルストーンだけ話す。背景の空と季節で存在感を出し、通知乱発を避ける。 | E/I: [Apple Personal Growth](https://apps.apple.com/us/iphone/story/id1649518102) |

## SkyGrid に落とす具体仕様

### 1. 複数アラーム

- `AlarmSchedule`: id / time / activeWeekdays / label / enabled / sound / companionTone。
- 一覧は次回発火順。各カードに時刻、曜日pill、ラベル、ON/OFF、`次回 月 7:00` を表示。
- 追加は右下 `+`。平日/週末プリセットを最上段に置く。曜日が完全重複する同時刻は保存前に警告する。
- 起床missionとして撮影を選べるが、アラーム停止自体は必ず可能にする。停止後に撮影CTAを full-screen で出す。
- 価値訴求は「複数個」ではなく「平日と週末を一度決めれば、毎晩触らなくてよい」。

### 2. 日付変更と前日の写真

- Today の表示対象を `Calendar.current.startOfDay(for:)` に束縛し、scene active、significant time change、timezone change、深夜timerの4契機で再評価する。
- 日付が変わったら前日の大写真を残さず、今日の空セルを空状態に戻す。前日は `Yesterday` の小さなカードまたは年間gridから見られる。
- 画面復帰時に `displayedDay != currentDay` なら state を即座に切り替え、古い画像を非同期refresh完了まで表示し続けない。
- 切替アニメは古い写真を 180ms fade、今日の空枠を 240ms rise。撮影可能になるまでの待ち演出は入れない。

### 3. キャラクター・6問オンボーディング

1. 相棒が登場: 「こんにちは。朝の空を集める相棒だよ」
2. 約束: 「6つだけ聞いて、あなたの朝を整えていい？」＋ `1分で完了`
3. 目的: 自分の記録 / バディと交換 / 起きるきっかけ
4. 曜日: 平日 / 毎日 / カスタム
5. 時刻: wheel。平日・休日を分ける提案をその場で表示
6. 声かけ: 静か / 元気 / 最小限（キャラの表情と文面が即変わる）
7. 写真経験: 毎朝できそう / ときどき / まず試す（頻度で責めない文面へ）
8. 通知: 価値を説明してからOS許可
9. 30〜45秒の初回体験: 実写撮影、難しければサンプル空で1セルを完成
10. 「あなたの朝」結果カードを表示し、編集可能にしてから paywall へ

固定の6問を増やさない。相棒の発話は各画面2文以内、スキップ可能。全回答は後で設定から変更できる。

### 4. 体験→ペイウォール

1. 完成した1セルを中央に置く。
2. そのセルが 7日→30日→365日のgridへ広がる 2〜4秒の seek-safe animation。
3. バディのぼかしセルが双方投稿で晴れる短いデモ。
4. 回答から作った具体値を表示: `平日 7:00 / 週末 8:30 / 静かな声かけ`。
5. Pro の増分価値だけを3項目: 複数アラーム、相棒の季節/装飾、長期モザイク/共有表現（実際のSKUに合わせる）。
6. 価格、期間、trial終了日、復元、閉じるを同時に読める状態で提示。

アニメーションは価値の因果（撮る→セル→年の景色、双方撮る→公開）を説明するために使う。紙吹雪・sparkle・hapticを各画面に重ねない。Reduce Motion では crossfade と数値更新に置き換える。

## 優先順位

| 優先度 | 変更 | 理由 | 最小計測 |
|---|---|---|---|
| P0 | 日付境界で Today の画像/state を同期更新 | 現在の誤表示は価値訴求以前の信頼問題 | stale image exposure / app foreground、日付変更後capture率 |
| P0 | 複数アラーム＋曜日 | 明示された機能欠損。既存習慣に直結 | alarm count distribution、alarm-fired→capture |
| P1 | 6問会話型オンボーディング＋実回答反映 | 初回撮影までの理解と設定を同時に終える | first_open→onboarding complete→first capture |
| P1 | 初回セル体験後の paywall | 課金前に製品固有価値を証明 | paywall presented→trial/purchase、refund/cancel |
| P2 | 相棒の朝/マイルストーン反応 | 継続に効く可能性はあるが、P0/P1の土台が必要 | D1/D7 capture、companion interaction |
| P3 | 収集/季節装飾 | 制作コストが高く、初期ボトルネック未確定 | D30、装飾利用率、課金寄与 |

## 成長ループへの接続

`アラーム/朝の相棒が起動` → `ユーザーが空を撮影` → `年間gridまたはバディ向け空カードが外部/相手に見える` → `受信者がリンクを開き参加` → `双方の空が公開され、翌朝も撮る`。

単独のshareボタンではループにならない。先に activation（初回撮影）と retention（翌日撮影）を改善し、共有物には日付・2人の空・次に開く条件が分かる見た目を持たせる。分母は `first_open`、`capture_completed`、`share_started`、`invite_claimed`、`mutual_reveal_unlocked` を段階ごとに保存する。

## 取得済み本文ソース一覧

取得本文は **35ページ**。うち開発元/Apple/App Storeの一次情報は **33ページ（94%）**。Apple編集記事は一次配布面だが、各アプリ内部の細部については実機の代替にならないため表では E/I とした。

1. [Duolingo — habit of language learning](https://blog.duolingo.com/putting-in-work-the-habit-of-language-learning/) — P
2. [Duolingo product](https://www.duolingo.com/learn) — P
3. [Finch New User Guide](https://help.finchcare.com/hc/en-us/articles/42149821015693-New-User-Guide) — P
4. [Finch Home Page](https://help.finchcare.com/hc/en-us/articles/37780000231309-Exploring-the-Finch-Home-Page) — P
5. [Finch approach](https://help.finchcare.com/hc/en-us/articles/37935669335309-Our-Approach-to-Self-Care) — P
6. [Headspace buyer guide](https://get.headspace.com/hubfs/Headspace_Investing_In_Workplace_Mental_Health_A_Buyer%E2%80%99s_Guide_Whitepaper_1-16-24.pdf?hsLang=en) — P
7. [RISE Smart Alarm](https://help.risescience.com/hc/en-us/articles/10960396186903-How-does-the-RISE-Smart-Alarm-work) — P
8. [Sleep Cycle Smart Alarm](https://sleepcycle.com/the-app/smart-alarm) — P
9. [Fabulous App Store](https://apps.apple.com/us/app/fabulous-daily-habit-tracker/id1203637303) — P
10. [Balance personalization](https://support.balanceapp.com/hc/en-us/articles/4407704821531-How-does-personalization-work) — P
11. [Balance product](https://balanceapp.com/) — P
12. [Noom free features](https://www.noom.com/support/private/2025/07/free-features-in-the-noom-app-h/) — P
13. [Noom Big Picture](https://www.noom.com/support/faqs/using-the-app/daily-features/2025/10/understanding-your-big-picture-ybp/) — P
14. [Flo onboarding](https://help.flo.health/hc/de/articles/4406826484500-Das-Einrichten-deines-Flo-Nutzerkontos) — P
15. [Liven personalized plan](https://support.theliven.com/hc/en-us/articles/31383165038994-Personalized-Plan-How-to-follow) — P
16. [Liven quiz](https://theliven.com/blog/wellbeing/dopamine-management/what-is-the-liven-quiz) — P
17. [BetterMe features](https://bettermesupport.zendesk.com/hc/en-us/articles/360019398237-Which-features-are-included) — P
18. [Elevate overview](https://support.elevateapp.com/hc/en-us/articles/4402922583067-What-is-Elevate) — P
19. [Impulse App Store](https://apps.apple.com/us/app/impulse-brain-training/id1451295827) — P
20. [Habitica product](https://habitica.com/static/home) — P
21. [Pokémon Sleep launch](https://www.pokemon.com/us/news/pokemon-sleep-is-now-available-on-the-app-store-and-google-play) — P
22. [Why Pokémon Sleep was created](https://corporate.pokemon.co.jp/en/topics/detail/t-9/) — P
23. [Waterllama App Store](https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585) — P
24. [Kinder World game](https://www.playkinderworld.com/game) — P
25. [Forest product](https://www.forestapp.cc/en/) — P
26. [Focus Plant App Store](https://apps.apple.com/us/app/focus-plant-forest-app-blocker/id1459096306) — P
27. [Study Bunny App Store](https://apps.apple.com/us/app/study-bunny-focus-timer/id1478345385) — P
28. [Amaru App Store](https://apps.apple.com/us/app/amaru-self-care-virtual-pet/id1503075227) — P
29. [Earkick App Store](https://apps.apple.com/us/app/earkick-self-care-ai-coach/id1584854531) — P
30. [Wysa App Store](https://apps.apple.com/us/app/wysa-mental-wellbeing-ai/id1166585565) — P
31. [Routinery App Store](https://apps.apple.com/us/app/routine-planner-habit-tracker/id1450486923) — P
32. [Structured product](https://structured.app/) — P
33. [Opal FAQ](https://opalapp.com/help/what-is-opal) — P
34. [Apple Personal Growth collection](https://apps.apple.com/us/iphone/story/id1649518102) — E
35. [Apple Essential Education Apps](https://apps.apple.com/us/iphone/room/1441665140) — E

## 制約

- 調査は取得できた公開本文と公開スクリーンショット記述に基づく。A/B配信、地域、OS版によって実際の onboarding / paywall は変わりうる。
- E/I 行の具体遷移は、実装前に対象アプリの現行iOS版を同一地域・同一日で画面収録して再確認する。
- 競合の採用数は効果の証明ではない。SkyGridでは `first_open→first capture` と翌日撮影を基準に判断する。

## コード・トレーサビリティ監査（2026-09-07 現在）

この節は上表で判断を **採用 / 強く採用 / そのまま採用** とした27項目を、現在のworktreeへ照合した結果である。並行作業中の未コミット変更も「現在のコード」に含む。状態は、ユーザーが通る経路と状態保存までつながるものを実装済み、主要部はあるが調査パターンの一部が欠けるものを部分実装とした。

優先度は次の順で決めた。

1. SkyGrid固有の核である `起床 → 空を撮る → 実写真が1セルになる → 年/バディの景色が育つ` を壊しているか。
2. 対象指標 `first_open → first capture` の分子・分母へ直接効くか。
3. 既存コンポーネントを再利用できるか。残作業コストは **S**（1ファイル中心）、**M**（複数画面/状態接続）、**L**（ルートや永続契約をまたぐ）で示す。

| 元アプリ / 採用項目 | 現状 | 現在の証拠 | 足りない点 | 優先度 | 残コスト |
|---|---|---|---|---|---|
| Duolingo: 短い会話、回答反応、行動後の祝福 | **実装済み** | `WelcomeView.swift:9-20,47-132` のMoku挨拶、`OnboardingCoordinatorView.swift:230-297` の回答連動発話、`RewardOverlayView.swift:4-11,96-143` の撮影成功後祝福 | 「明日の2枚目」の明示は薄いが、核を阻害しない | P1 | S |
| Finch: 世話したくなる相棒、撫でる、初日空状態回避 | **部分実装** | `TodayView.swift:178-204` でMokuをタップでき、`MokuView.swift:142-164` でjump/haptic。撮影後は実空色を受け取る | 成長/装飾の永続状態はない。空状態を相棒が埋める仕組みはない | P2 | L |
| Headspace/Ebb: 1発話1回答の会話型案内 | **実装済み** | 6問が1ページ1問に分割され、固定のcompanion railが反応する（`PersonalizationQuestionsView.swift:72-103`, `OnboardingCoordinatorView.swift:118-211`） | 吹き出し型ではなくrailだが、機能上の会話リズムは満たす | P1 | S |
| Flo: 目的で後続説明を変え、権限を文脈化 | **実装済み** | `PersonalizationProfile.swift:194-250` が目的/pace/frequency/privacyをplan文面へ反映。`WakeGoalPickerView.swift:125-147` は明示操作時だけ許可要求 | 目的によるページ順変更はないが不要 | P1 | S |
| Balance: 回答を即時反映し後から調整 | **部分実装** | 選択のたびMoku発話とhapticが変わり、planへ反映（`OnboardingCoordinatorView.swift:203-210,276-297`, `PersonalizedPlanView.swift:10-45`） | 初回後の「起きやすさ」再評価、通知口調の実設定はない | P2 | M |
| Fabulous: アラームを朝の儀式の開始点にする | **実装済み** | AlarmKit stop→cameraを永続フラグで接続（`LocalDefaults.swift:230-233`）。Rootがactive時に消費し、撮影後rewardへ続く（`RootView.swift:94-107` とcamera route） | 撮影後の追加ルーティンはSkyGridの核外 | P0 | S |
| Elevate: 回答直後に何が変わったか示す | **実装済み** | companion lineが選択値を言い換え、planが時刻/目的/pace/frequency/privacyを具体文にする（`OnboardingCoordinatorView.swift:276-297`, `PersonalizationProfile.swift:203-249`） | 曜日別アラームの具体結果はplanに未表示 | P1 | S |
| Wysa: 非評価的な相棒、欠席を責めない | **実装済み** | `PersonalizationProfile.swift:215-232` に「missed morning is simply an empty square」「Most mornings are plenty」。Mokuのerrorは状態エラー専用 | 通知本文のtoneまではprofileに接続されない | P1 | M |
| Earkick: 相棒の口調を選択し通知へ反映 | **部分実装** | `MorningPace` の gentle/structured/flexible と会話反映はある（`PersonalizationProfile.swift:30-48`, `OnboardingCoordinatorView.swift:282-284`） | 選択値がアラーム/通知本文へ届かず、実効的なtone設定になっていない | P2 | M |
| Amaru: 撮影でbond/外見が育ち、基本機能は無料 | **部分実装** | 保存成功だけでMokuが実空色の delight/settled へ変化し、Free撮影導線も残る（`RewardOverlayView.swift:4-11,132-143`, `PaywallFeaturesStepView.swift:68-75`） | bond、装飾、物語の永続進行はない | P2 | L |
| Kinder World: 欠席で相棒を傷つけない | **実装済み** | 欠席は空セルとして扱い、非叱責コピー。Mokuの真実状態はcapture成功までsuccess色を使わない（`MokuView.swift:3-18,28-31`） | 追加なし | P1 | S |
| Waterllama: 行動でキャラが満ち、記録が収集になる | **部分実装** | Mokuが撮影した空色を受け取り、実写真が24×24タイルになって日付slotへ着地（`RewardOverlayView.swift:9-11,53-60,104-133`） | キャラ/装飾collection自体はない | P2 | L |
| Pokémon Sleep: 行動後に翌朝の発見を開ける | **部分実装** | 撮影後だけrewardと、検証済みの場合はbuddy reveal stripを表示（`RewardOverlayView.swift:81-92,136-143`） | 新しい発見物の永続collectionはない。既存の実写真/相互公開が十分SkyGrid固有 | P2 | L |
| SleepTown: 双方の行動でshared結果を完成 | **実装済み** | `BuddyTile.swift:19-31,45-97` がsealed→実写真へ変化。Rewardも検証済みunlock数だけ相手を出す | 共同罰はない。望ましい状態 | P1 | S |
| RISE: 曜日別の複数アラーム | **実装済み** | `MorningAlarmSchedule.swift:3-24` の複数model、`MorningAlarmSettingsView.swift:159-226,306-355` の追加/編集/曜日、`MorningAlarmScheduler.swift` のAlarmKit/通知reconcile。上限5件 | label、sound、各行の「次回発火」、時刻重複警告はない | P0 | M |
| Structured: 次回順と現在位置を視覚化 | **部分実装** | 複数アラームのカード一覧、時刻/曜日/ON/OFFはある（`MorningAlarmSettingsView.swift:148-226`） | 保存順のままで次回発火順ではなく、`次回 月 7:00` もない | P1 | S |
| Opal: 価値説明後に必要な権限を要求 | **実装済み** | onboardingはreminder種別→時刻→明示ボタンで初めて許可を要求（`WakeGoalPickerView.swift:54-68,76-143`）。カメラもCapture時だけ | 追加なし | P1 | S |
| Imprint: 説明を視覚カード/操作へ分解 | **部分実装** | 1画面1問、Moku、RitualGridMark、短いtransitionあり（`OnboardingCoordinatorView.swift:118-199`, `PersonalizedPlanView.swift:29-45`） | 最初の「サンプル空を1セルへ入れる」操作デモはない | P1 | M |
| Blinkist: 説明を短い単位にし再確認可能 | **実装済み** | 9 step、戻る、skip、回答編集を実装（`OnboardingCoordinatorView.swift:60-92,318-333`, `PersonalizedPlanView.swift:17-27`） | 設定後にオンボーディング説明全体を再生する入口はないが低価値 | P2 | M |
| Brilliant: 先に触らせて成功を見せる | **未実装** | 実撮影後のセル着地自体は完成しているが、onboarding中にはカメラ/サンプル操作がなく、plan→任意paywall→invite→完了の順（`OnboardingCoordinatorView.swift:175-225`） | **初回paywallより前の製品固有体験がない** | P1 | M |
| Mimo: 質問形式を変え、即時反応 | **実装済み** | 選択リスト5問＋time wheel 1問、numeric transition、選択haptic（`PersonalizationQuestionsView.swift`, `WakeGoalPickerView.swift:29-52`, `OnboardingCoordinatorView.swift:203-205`） | 正誤/scoreを作らないのは意図どおり | P1 | S |
| Simply Piano: 最初の小さな成功を祝う | **部分実装** | 実撮影成功後のMoku、confetti、実写真→tile着地は完成（`RewardOverlayView.swift:4-11,104-143`） | 祝福がオンボーディング完了後で、オンボーディングpaywallより後 | P1 | M |
| How We Feel: 空色と気分を任意で結ぶ | **未実装** | postは写真/skyColorを持つがmood入力はない | 初回撮影率へ直接効かず、投稿摩擦を増やす可能性 | P2 | M |
| Ahead: 説明→質問→応答の3拍 | **実装済み** | Welcome、単一質問、companion応答の構造（`WelcomeView.swift`, `PersonalizationQuestionsView.swift`, `OnboardingCoordinatorView.swift:276-297`） | 追加なし | P1 | S |
| Paired: 双方が行動して初めて公開 | **実装済み** | Firestore権限と `BuddyTile` のsealed/posted表示で成立。通知とrefresh経路もある（`BuddyTile.swift:19-31`, `RootView.swift:101-130`） | paywall内の相互公開デモはない | P1 | M |
| Evergreen: 空に任意の一言を添える | **未実装** | post schema/UIにcaption promptなし | 投稿contractと共有表示をまたぎ、初回撮影を重くする | P2 | L |
| Bird Alone: 朝/節目だけ話す静かな相棒 | **実装済み** | Mokuはonboarding rail、Todayの明示tap、撮影reward、milestoneに限定。常時会話timerなし（`MokuView.swift:131-170`, `TodayView.swift:178-204`） | 追加なし | P1 | S |

### 横断的に確認できた基盤

| 基盤 | 状態 | コード上の根拠 | 判断 |
|---|---|---|---|
| 前日の写真を今日として残さない | **実装済み** | `RootView.swift:15,87-125,168-186` がforeground、`NSCalendarDayChanged`、timezone、significant time changeで `observedLocalDate` を更新。`TodayView.swift:85` が日付IDで再startし、`TodayViewModel.swift:132-150` が旧listener停止、`todayPost=nil`、全状態初期化 | **P0。今回必須** |
| 日付変更中の旧写真リーク防止 | **実装済み** | `TodayViewModel.start(for:)` は新しいobserver接続前に `todayPost=nil` と `postState=.checking` を同期設定 | **P0。今回必須** |
| 複数アラームの保存/移行/再調停 | **実装済み** | `LocalDefaults.swift:184-217`、`MorningAlarmSchedule.swift`、`MorningAlarmScheduler.swift`、関連tests | **P0。今回必須** |
| 初回体験の分母と所要時間 | **実装済み** | `OnboardingAnalytics.swift:17-27` で開始、`CaptureAnalytics.swift:19-29` で初回保存成功時の秒数 | **P1。今回必須** |
| 6問の離脱計測 | **実装済み** | `OnboardingAnalytics.swift:9-27` がview/advance/back/skip/completeをstep付きで記録。回答値は送らない | **P1。今回必須** |
| paywall段階計測 | **実装済み** | `PaywallAnalytics.swift:8-46` がpresented、step、preview、plan、purchase、restore、dismissを記録 | **P1。今回必須** |
| Reduce Motion | **実装済み** | Moku、reward、paywall preview、page transitionが環境値で停止/最終状態へ短縮 | **P1。今回必須** |

## 今回取り込む最小の一貫した P0 / P1 セット

### P0 — 信頼と起床導線

1. **日付再束縛を現在の形で確定する。** foregroundだけでなく、calendar day、timezone、significant time changeを含める。新しい日を観測する前に旧 `todayPost` を消す。
2. **曜日別複数アラームを現在の形で確定する。** 既存単一アラームを毎日1件へ移行し、追加/削除/ON/OFF/曜日をAlarmKitと通知fallbackの両方へreconcileする。
3. P0では label/sound/重複警告まで広げない。現在の欠損を直すのに必須ではなく、残る最大5件なら時刻＋曜日で識別できる。

この3点は現在のworktreeに実装がある。必要なのは対象testsとiOS buildで確定することであり、新しい製品面を足すことではない。

### P1 — 相棒が価値を説明し、実体験後に課金を提示する

1. **Moku＋6問＋即時応答＋個別planを採用する。** 現在の1画面1問、skip、回答編集、端末内保存を維持する。
2. **最初の価値体験を実撮影にする。** 現在はplanからpaywallを開けるため、オンボーディングpaywallが初回撮影より前に来る。`See my complete archive` は初回には出さず、`Start my first sky` としてonboardingを完了し、既存camera→publish→`RewardOverlayView` を使う。
3. **初回paywallはrewardの後へ移す。** 実写真がセルへ着地しMokuが喜ぶ既存animationが、最も安くて正直なSkyGrid固有体験である。その終了後に既存の `value → animated archive growth → plan` を出す。Free導線、Close、restore、期間/更新条件は維持する。
4. **相互公開デモは今回の必須セットから外す。** 実buddyデータなしで相手の写真を捏造できず、説明用fixtureを追加すると範囲が広がる。初回撮影率を測った後のP2候補とする。
5. **Mokuの永続育成、気分、一言、装飾ショップも外す。** いずれも新しい永続状態や投稿contractを増やす一方、現在の分母7では初回撮影への寄与を判断できない。

このP1のうち 1 とpaywall本体は実装済み、2〜3の**順序接続だけが未実装**である。新しいcameraやrewardを作らず既存経路を再利用すれば残コストは **M**。最安の因果検証は、`experience_variant` を `paywall_before_capture` / `paywall_after_reward` で分け、`first_open` を分母に `first_capture_duration` と初回撮影完了率を比較すること。7日成熟コホートで撮影完了が改善せず、paywall到達またはpurchaseが悪化する場合は元の順序へ戻す。

### 今回の完了条件

- 日付変更直後、旧日の写真が1 frameでもToday's photoとして再表示されない。
- 旧単一アラーム利用者は移行後も同じ時刻で毎日1件が有効。新規は最大5件を曜日別に作成、変更、無効化、削除できる。
- 初回ユーザーはMokuとの6問をskip可能で完了し、課金を選ばなくても最初の空を撮れる。
- オンボーディング由来の初回paywallは、保存成功とreward完了より前には表示されない。
- `first_experience_started → onboarding_completed → first_capture_duration → paywall_presented → purchase_started/confirmed` を回答値・写真・UIDなしで追える。
