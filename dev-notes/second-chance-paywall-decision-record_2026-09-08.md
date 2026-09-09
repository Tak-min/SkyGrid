# Second-chance paywall 意思決定記録

最終更新: 2026-09-09

状態: **コード実装済み（提示履歴は端末内）・ASC / RevenueCat設定待ち・実商品未検証**

対象: 通常ペイウォールを閉じた利用者へ提示する「初月だけ低価格」オファーと、紹介導線との関係

## 1. この文書の役割

Codex と依頼者の会議で決まった内容を、将来の実装へ正確に渡すための記録である。

- `決定` の項目だけを実装してよい。
- `提案` と `未決` はコードへ取り込まない。
- 決定時は、日付、決定者、対象コード、反証・撤回条件を「決定ログ」に追記する。
- 実装前に本書と `PRODUCT-MODEL.md` を読み、価格・商品・紹介成立条件を推測で補わない。

## 2. 狙う指標

**対象指標:** second-chance paywall 対象者の購入確定率

**定義:** `skygrid_paywall_purchase_confirmed`（`entry_point=onboarding`, `step=second_chance`）/ `skygrid_paywall_step_viewed`（同条件）

**現在値:** 未測定。既存 GA4 は `skygrid_paywall_presented` が12件・5ユーザーであり、判断できる標本ではない。

**変更しない場合:** 通常ペイウォールを明示的に閉じた利用者に再提案する機会はなく、その離脱を回収できない。

紹介を組み合わせる場合は、購入率とは別に次のループを測る。

```text
オファーまたは購入後の誘因
  → 招待者が紹介する
  → 招待リンクが外部へ届く
  → 受信者がアプリ内で招待を受諾する
  → 受信者が最初の空を保存する
  → Buddy体験が生まれ、次の紹介につながる
```

共有シートを開いた回数だけを紹介成立とは扱わない。

## 3. 現在確認できている実装

- `PaywallView` は終了理由を `.close`、`.continueWithFree`、`.interactiveDismissal` に分けて記録できる。
- 通常商品の表示価格と購入は `PurchasesServicing` / RevenueCat の offering と package を使用する。
- `PaywallAnalytics` は通常ペイウォールの表示、ステップ、購入開始、購入確定、終了理由を記録する。
- 専用offeringから初月割引商品を取得し、利用資格、導入価格、更新価格を表すアプリ内契約を実装した。
- 「紹介した」「相手が受諾した」「相手が初回撮影した」を割引資格へ結び付ける契約はまだない。議題6〜8が未決のため、今回も実装していない。
- 過去の `ExitOffer` は、実在を保証できない `SKYGRID20` をハードコードし、価格を見る前にも表示できたため削除された。今回の案は同じ方式を復活させてはならない。

## 4. 決定済み

| 項目 | 決定 | 根拠 | 実装への影響 |
|---|---|---|---|
| 表現方針 | 「静かな朝」を制約として扱わず、Mokuの感情表現、アニメーション、華やかな演出を利用できる | 依頼者判断 | second-chance体験は既存の遊び心ある表現に合わせる |
| 商品情報 | `$1` 等の文字列をアプリへ固定せず、StoreKit / RevenueCat が返すローカライズ済み価格と更新条件を表示する | 現行購入契約と過去のExitOffer失敗 | 商品が取得できない場合は架空の割引を表示しない |
| 実装手順 | 会議で決まった範囲を実装・検証し、未決の紹介ゲートは実装しない | 依頼者判断 | 議題1〜5・9・10を実装対象とする |
| 商品分離 | 通常月額とは別の月額SKUを同じsubscription groupへ置き、RevenueCatの`second_chance` offeringだけから取得する | 通常月額SKUへintroを付けると通常paywall購入にも自動適用されるため | 通常3プランにsecond-chance商品を混ぜない |

## 5. 現在の提案

以下は設計案であり、まだ決定ではない。

```mermaid
flowchart TD
    A[通常ペイウォールのプラン・価格を表示] --> B{明示的に閉じた}
    B -->|対象外| F[元の画面へ戻る]
    B -->|対象| C[Mokuのsecond-chance体験]
    C --> D[ローカライズ済みの初月オファーと更新条件]
    D -->|購入| E[購入確定]
    D -->|閉じる| F
    E --> G[最初の空を完成]
    G --> H[任意のBuddy Passを提案]
    H --> I[受信者が受諾して最初の空を保存]
    I --> J[双方へMoku装飾等の非金銭報酬]
```

画面案:

- 目を潤ませたMokuが短く登場し、「ちょっと待って！ 最初の1か月を試してみない？」と呼びかける。
- 値引き額、対象期間、その後の更新価格、解約可能時期を同じ画面で読めるようにする。
- Reduce Motion 設定では表情の静止状態へ縮退する。
- 同じ利用者へ繰り返し割り込まないよう、提示回数または再提示間隔を持つ。

紹介条件についての作業仮説:

- **Bet:** 購入前の割引を「紹介必須」にすると、紹介の質と購入完了率が下がる可能性がある。
- **仮定:** 利用者は価値体験前の義務的共有を避け、自己送信などで条件だけを満たそうとする。
- **確認方法:** A/B割付は追加せず、依頼者が既存paywallイベントの`step=second_chance`における離脱率と購入確定を確認する。
- **継続判断:** 自動停止ロジックは持たず、依頼者が実測を見て判断する。

## 6. 会議で決める事項

| # | 議題 | 選択肢・決める内容 | 状態 |
|---|---|---|---|
| 1 | 提示トリガー | オンボーディング完了後の最初のペイウォール表示での `.close` のみを対象とする | 決定（決定ログ参照） |
| 2 | 提示頻度 | アカウント生涯で1回のみ（上記の最初のペイウォール表示に限定） | 決定（決定ログ参照） |
| 3 | 商品契約 | 専用月額SKUの初月を米国`$0.99`相当、1か月後は通常月額へ自動更新。Appleの等価価格を各地域へ適用する | 決定・外部設定待ち |
| 4 | オファー資格 | RevenueCat / Appleのintro eligibilityが`eligible`で、1か月pay-as-you-goの実商品が取得できた場合だけ表示する | 決定・コード実装済み |
| 5 | 画面 | 承認文言、涙目のMoku、動きと触覚を使用。Reduce Motionでは静止。音は追加しない | 決定・コード実装済み |
| 6 | 紹介との関係 | 購入前の必須条件、購入後の任意Buddy Pass、紹介を分離 | 未決 |
| 7 | 紹介成立 | 共有、インストール、招待受諾、初回撮影のどれを成立とするか | 未決 |
| 8 | 報酬 | 招待者・受信者への価格特典、Moku装飾、共有カード等 | 未決 |
| 9 | 実験 | A/B・holdout・自動停止を実装せず、対象者全員へ提示して既存イベントを依頼者が読む | 決定・コード実装済み |
| 10 | 障害時 | 取得中はspinner、named constantの7秒後は未接続表示。購入中はspinner、保留・失敗は明示する | 決定・コード実装済み |

## 7. 実装開始条件

次の項目が決定ログで `決定` になってから、該当範囲を実装する。

| 実装範囲 | 開始条件 | 主な対象 |
|---|---|---|
| second-chance表示制御 | 議題1・2の決定 | `PaywallView`、`RootView`、`LocalDefaults` |
| 価格・購入 | 議題3・4の決定とASC/RevenueCatの商品準備 | `PurchasesServicing`、`RevenueCatService`、購入UI |
| Moku画面 | 議題5の決定 | Paywall UI、アクセシビリティ、ローカライズ |
| 紹介連携 | 議題6〜8の決定 | Invite/Buddy、Functions、資格状態 |
| 計測・実験 | 議題9・10の決定 | `PaywallAnalytics`、実験割付、失敗時処理 |

現在の外部設定ブロッカー:

- App Store Connectの`Sky Grid Premium` groupには、承認済みの月額`$3.99`と年額`$19.99`があるが、2026-09-08時点でintroductory offerは両方とも0件。
- 実装が参照する専用SKUは`com.takmin.skygrid.pro.monthly.secondchance`、RevenueCat offeringは`second_chance`。ASCで同じgroupへ専用月額商品を作成し、通常月額と同じ更新価格、米国`$0.99`を基準に1か月の`PAY_AS_YOU_GO` introを設定する必要がある。
- 米国`$0.99`のprice pointは実在し、Apple equalizationは米国を除く174地域へ解決できた。日本の等価価格は`¥150`。ASCの変更はまだ行っていない。
- Appleの現行仕様では月額商品のpay-as-you-go introを1〜12か月で設定でき、利用者は同じsubscription groupで1回だけintroを受けられる。今回の1か月設定を禁じる地域別規約は確認されず、販売地域ごとの実価格はASCのprice pointとequalizationを正とする。
- RevenueCatでは専用商品を`premium` entitlementへattachし、`second_chance` offeringのmonthly packageへだけ配置する必要がある。通常current offeringへは追加しない。
- FunctionsのWebhook商品マッピングはコード更新済みだが、未デプロイ。
- 提示済み履歴は現在、アカウントIDごとに端末内へ保存する。アプリ再インストールや別端末をまたぐ厳密な「アカウント生涯1回」は保証できない。Apple / RevenueCatの購入資格とは混同せず、サーバー側の提示予約を追加するかは別途決定が必要。

確認に使用したApple一次資料:

- [Set up introductory offers for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/)
- [Manage pricing for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions)
- [Subscriptions](https://developer.apple.com/app-store/subscriptions/)

受け入れ条件:

- 表示価格と更新条件が StoreKit / RevenueCat の実商品と一致する。
- 明示的な終了経路があり、同じセッションで画面が循環しない。
- 購入、復元、保留、キャンセル、オフラインを区別して処理する。
- VoiceOver、Dynamic Type、Reduce Motion で主要操作が完了できる。
- 紹介を採用する場合、分母から受信者の初回撮影まで計測できる。
- second-chanceと紹介施策の効果を別々に判定できる。

## 8. 決定ログ

| 日付 | 決定者 | 区分 | 内容 | 対象 | 状態 |
|---|---|---|---|---|---|
| 2026-09-08 | 依頼者 | 表現方針 | 「静かな朝」を破棄し、より派手で感情的な体験を許容する | 全ユーザー向け画面 | 決定 |
| 2026-09-08 | 依頼者・Codex | 進め方 | 本書を会議記録とし、会議で確定した決定に従って段階的にコーディングする | second-chance paywall | 決定 |
| 2026-09-08 | Codex提案 | 紹介 | 購入前の紹介必須化を避け、購入・初回撮影後の任意Buddy Passとして別検証する | 紹介ループ | 提案 |
| 2026-09-08 | 依頼者 | 提示トリガー | オンボーディング完了後の最初のペイウォール表示で明示的に閉じた場合のみ対象とし、以降のペイウォール表示では出さない | second-chance表示制御 | 決定 |
| 2026-09-08 | 依頼者 | 提示頻度 | アカウント生涯で1回のみ（上記の最初のペイウォール表示に限定） | second-chance表示制御 | 決定 |
| 2026-09-08 | 依頼者 | 商品 | 初月のみ`$1`相当、翌月から通常月額へ自動更新し、価格はStoreKit / RevenueCatの実値だけを表示する | 専用月額SKU | 決定 |
| 2026-09-08 | 依頼者 | 資格 | Apple / RevenueCatのintro eligibilityを使い、過去の有料利用を独自フラグで判定しない | 購入サービス | 決定 |
| 2026-09-08 | 依頼者 | 表現 | 承認文言、涙目のMoku、アニメーション、触覚を使用し、Reduce Motionでは静止する。音は追加しない | second-chance step | 決定 |
| 2026-09-08 | 依頼者 | 計測 | 既存paywallの追加stepとして既存イベントを使い、専用イベント、A/B割付、自動停止を追加しない | PaywallFlow / Analytics | 決定 |
| 2026-09-08 | 依頼者 | 障害時 | 取得・購入中はspinner、7秒後の未接続、購入保留、購入失敗を明示する | second-chance step | 決定 |

## 9. バックログ

- アプリ全体の効果音設計。second-chance専用の音は追加せず、全画面の音響方針を決める別タスクとして扱う。
- 議題6〜8の紹介条件、成立点、双方の報酬。今回の割引資格には結合しない。
