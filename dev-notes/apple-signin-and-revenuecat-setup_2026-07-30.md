# Sign in with Apple + RevenueCat 外部セットアップ(2026-07-30)

## やったこと(順番に効いた)

### 1. Apple Developer Portal
- Bundle ID `com.takmin.skygrid` の Sign In with Apple / Push Notifications capability は**既に有効化済み**だった(2026-07-29の実機デプロイ時、Xcode自動署名が自動登録していたと推測)。VISION.mdの仮説が正しかった。手動設定は不要。

### 2. Firebase Console
- Authentication → Sign-in method → Apple provider を有効化。
- **実機フローでは Services ID / Team ID / 秘密鍵は不要**(Console上のフォームに「Services ID (not required for Apple)」「OAuth code flow configuration (optional)」と明記されている)。トグルONにしてSaveのみで完了。
- **ハマった点**: Save後の確認ダイアログのSaveボタンが画面下部に隠れてスクロールが効かず(computer toolのscroll actionが効かない現象、原因不明)、`javascript_tool`で`saveBtn.scrollIntoView()` + `saveBtn.click()`を直接実行して回避。以降、同種のモーダルではまずJS直接操作を試す方が早い。

### 3. App Store Connect: アプリ名衝突
- 「Sky Grid」という名前は**既に他社に使用されており登録不可**(App Store全体でアプリ名は一意)。競合調査では見落としていた盲点。
- 依頼者確認の上、ASC登録名を「Sky Grid: Morning & Wake」に変更して作成(アプリ内表示名は別途「Sky Grid」のまま運用可能)。
- App ID: 6796222704 / Bundle ID: com.takmin.skygrid

### 4. App Store Connect: サブスクリプション/IAP商品作成
価格はドル建て(依頼者指示、世界展開目標のため。円建てドラフト月額¥600/年額¥2,900/ライフタイム¥5,800から換算):
| 商品 | Product ID | 種別 | 価格(USD基準) |
|---|---|---|---|
| Sky Grid Pro Monthly | `com.takmin.skygrid.pro.monthly` | 自動更新サブスクリプション(1ヶ月) | $3.99 |
| Sky Grid Pro Annual | `com.takmin.skygrid.pro.annual` | 自動更新サブスクリプション(1年) | $19.99 |
| Sky Grid Pro Lifetime | `com.takmin.skygrid.pro.lifetime` | 非消耗型App内課金 | $39.99 |

サブスクリプショングループ名: `Sky Grid Premium`。全175地域に配信設定済み(米国基準額から自動計算、個別調整なし)。

**ハマった点**: App Store ConnectのUIで複数の「選択する」プルダウンが**ネイティブ`<select>`要素だがscreenshot上にOSネイティブポップアップが映らず、クリック→キー操作の通常フローが機能しない**箇所が複数あった(バンドルID選択、サブスクリプション期間選択など)。`javascript_tool`で`Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,'value').set`を使ったネイティブセッター経由の値設定+`input`/`change`イベントdispatchで確実に回避可能。一方、価格選択欄は別実装(検索付きカスタムコンボボックス)で通常のクリック操作で問題なく動いた。同じ画面内でもコンポーネント実装が混在している点に注意。

### 5. App Store Connect: RevenueCat連携用認証情報
- **共有シークレット(App-Specific Shared Secret)**: `ユーザとアクセス→統合→App Store Connect API→共有シークレット`ではなく、**アプリ詳細ページの「アプリ情報」を下までスクロールした先の「アプリ用共有シークレット→管理」**から生成(アカウント全体用の「主要共有シークレット」とは別物なので注意)。生成: `c3131c3c8fc24e3fb573fe8a20340205`。**ただしRevenueCat 5.x(StoreKit 2)構成ではこの値は不要と判明**(後述)、結果的に未使用。
- **In-App Purchaseキー(本命)**: `ユーザとアクセス→統合→アプリ内購入`(Team API Keyとは別の専用セクション、ファイル名`SubscriptionKey_XXXXXXXXXX.p8`)から新規生成。名前: `revenuecat-skygrid`、Key ID: `WNLQ253D6D`、Issuer ID: `58c05121-f8df-456e-bff8-00455e0fbc79`。p8ファイルは**生成時に1回しかダウンロードできない**ため、ダウンロード前に依頼者へ確認を取った。

## RevenueCatダッシュボード設定

- 新規プロジェクト「Sky Grid」作成(Category: Health、Platform: Native Apple)。
- **Entitlement IDは`premium`に設定**(RevenueCatConfig.swiftが`static let entitlementID = "premium"`を厳密に期待するため、オンボーディングウィザードの自動提案「Sky Grid Pro」から手動で"Other"→`premium`に変更)。
- App追加: 「Sky Grid (App Store)」、Bundle ID `com.takmin.skygrid`。
- **In-app purchase key configuration は"Required"表示**(RevenueCat 5.x = StoreKit 2構成では共有シークレットではなくこちらが必須、と明記されている)。上記で生成したp8ファイル+Key ID+Issuer IDを設定して保存。
- API keys: Test Store用`test_WWTIDdASrtWxebDIrrEsdqBxWgf`、App Store(本番)用`appl_SMzOfqdncroJOxFDpxBRgaJMxgt`を取得。
- 商品カタログ: 「Import」でApp Store Connectから商品を自動取得しようとしたが**「No new products available to import」**で失敗 → 下記の既知障害が原因と推測、手動で3商品(`com.takmin.skygrid.pro.{monthly,annual,lifetime}`)を作成し、それぞれ`premium` entitlementにattach。
- Offering「default」の既存3パッケージ($rc_monthly/$rc_annual/$rc_lifetime、オンボーディングが自動生成したTest Store商品のみが紐付いていた)に、上記App Store実商品を追加紐付け。

## 既知の外部障害(今回の未解決ブロッカー)

RevenueCat公式ステータスページに**"Newly created apps error with 'The key is not valid or is not compatible with the Bundle ID of your app'"**という進行中インシデントを発見(https://status.revenuecat.com/incidents/mr3l9wqygn3d、2026-07-27報告開始・2026-07-29時点でApple側の修正待ち)。

- 症状: **2026年7月24日以降に新規登録されたBundle IDに対し、AppleのApp Store Server APIが401を返す**(RevenueCat側のロジックに入る前の段階で失敗)。既存の古いBundle IDは影響なし。
- Sky GridのBundle ID `com.takmin.skygrid` は2026-07-29に(実質的に)登録されているため、**ほぼ確実にこの影響を受けている**。実際、RevenueCat商品ページの「Store Status」が全商品で「Could not check」表示、Import機能も新商品を検出できなかった。
- **これは設定ミスではない**(RevenueCat公式が「キーの再生成・Bundle ID再登録・アプリ再作成では解決しない」と明言)。Appleの修正を待つしかない。
- 次回セッションでこの障害が解消しているか要確認: RevenueCatダッシュボードで各商品の「Store Status」が「Could not check」から実際のステータス(Ready to Submit等)に変わっているかを見ればよい。

## ローカル設定

`ios/SkyGrid/Config/Secrets.xcconfig`(gitignore対象、新規作成)に以下を設定:
```
REVENUECAT_API_KEY_TEST = test_WWTIDdASrtWxebDIrrEsdqBxWgf
REVENUECAT_API_KEY_PROD = appl_SMzOfqdncroJOxFDpxBRgaJMxgt
```
SKYGRID_SUPPORT_URL / SKYGRID_PRIVACY_POLICY_URL / SKYGRID_EXIT_OFFER_* はExample値のまま(既知の未着手タスク、別途対応)。

**新規に気づいた点**: `~/Desktop/SkyGrid`配下は**gitリポジトリとして初期化されていない**(`ios/`直下含めどこにも`.git`が存在しない)。過去のdev-notesにコミット云々の記述は無いが、念のため次回操作前に`git status`相当の確認ができない状態である点は認識しておくこと。

build_sim実行、エラー・警告ゼロで成功確認済み(Secrets.xcconfig追加後)。

## 次回セッションへの申し送り

1. **RevenueCat商品の「Store Status: Could not check」が解消しているか確認**(Apple側障害の解消待ち)。解消していればImport機能で自動同期を試してもよい。
2. **App Check enforcement**(Firestore/Storage/Functionsへの強制モード)は依然未設定(前回セッションからの既存タスク)。
3. **APNsキーのFirebase登録**も依然未着手(前回セッションからの既存タスク)。
4. **サポートURL・プライバシーポリシーの実URL投入**も依然未着手。
5. RevenueCatのペイウォール/Offering画面(Paywallタブ)は未着手 — 今回はProduct catalogのみ設定。
