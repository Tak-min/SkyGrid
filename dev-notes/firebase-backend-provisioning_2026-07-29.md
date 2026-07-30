# Firebase実プロジェクト構築(2026-07-29)

## 前提: このセッション開始時に判明した事実

「UI改善をお願いした」つもりが、並行して動いていた別のCodexセッションが**Phase 2バックエンドの設計・実装を丸ごと完了させていた**(本人未把握)。具体的には:
- `Sources/Data/Firebase/`にFirestore/Storage/Auth本番実装8ファイルが完成
- `ios/firestore.rules` / `ios/storage.rules`(ハンドル一意性・バディ相互承認・投稿不変性を網羅したかなり作り込まれたルール)
- `ios/functions/src/index.ts`に`deleteAccount` Cloud Function
- `ServiceFactory`はローカルモック(`Data/Local/`)を完全削除し、Firebase必須設計に変更済み

このため、本セッションの実質的な作業は「ゼロから設計」ではなく「**既に書かれたコードを実際のFirebaseプロジェクトに接続する**」だった。並行編集の詳細は`~/.claude/projects/-Users-taku8/memory/concurrent-claude-session-detection-via-ps-2026-07-29.md`の2件目の実例として記録済み。

## やったこと(順番に効いた)

1. `npm install -g firebase-tools`(v15.24.0)、`brew install --cask google-cloud-sdk` — どちらも未インストールだった
2. `firebase login` / `gcloud auth login --update-adc` — 両方ユーザー本人による対話認証が必須(代行不可)
3. `firebase projects:create sky-grid-app --display-name "Sky Grid"`
   - **ハマった点**: `addFirebase`のポーリング中に`ECONNRESET`でクライアント側がタイムアウトしCLIはエラー終了したが、**サーバー側では実際には成功していた**。`firebase projects:list`で実際の状態を確認してから再実行を判断すること(闇雲な再実行は「同名プロジェクトが既に存在」エラーを生むだけ)
4. 課金アカウント紐付け: `gcloud billing accounts list`でOPEN=Trueのアカウントを確認 → `gcloud billing projects link sky-grid-app --billing-account=<ID>`
5. 予算アラート$5相当: `gcloud billing budgets create`
   - **ハマった点1**: `billingbudgets.googleapis.com`はADCのquota projectが必要。`gcloud auth application-default set-quota-project sky-grid-app` + `gcloud services enable billingbudgets.googleapis.com --project=sky-grid-app`が必要
   - **ハマった点2(本命)**: `--budget-amount=5USD`が`INVALID_ARGUMENT`で終始失敗。原因は`gcloud billing accounts describe <ID>`で判明した**課金アカウントの通貨がJPY**だったこと(`--budget-amount`で明示した通貨は課金アカウントの通貨と一致必須、とヘルプに書いてある注意書きの通り)。`--budget-amount=750JPY`に変更して解決。**今後同じマシンで予算アラートを作る時は先に`gcloud billing accounts describe`で通貨を確認すること**
   - 副産物: 予算一覧に見覚えのない`Firebase Project sky-grid-52e3d`(¥25)という予算が存在。調査の結果、同名で似た別プロジェクト`sky-grid-52e3d`が本セッション開始**より前**(2026-07-29T11:53、`DELETE_REQUESTED`状態=30日間のソフト削除猶予中)に存在したと判明。おそらく並行Codexセッションが試行錯誤で作って削除した跡。実害なし、対応不要
6. iOSアプリ登録: `firebase apps:create ios --project sky-grid-app --bundle-id com.takmin.skygrid "Sky Grid iOS"` → `firebase apps:sdkconfig IOS <appId> --out .../GoogleService-Info.plist`
   - **ハマった点**: `project.yml`の`sources:`に`SkyGrid/GoogleService-Info.plist`のエントリがなく、plistを配置しただけではXcodeプロジェクトに取り込まれない。明示的に`sources:`へ追加して`xcodegen generate`が必要
7. Firestore Native DB: `gcloud firestore databases create --location=asia-northeast1 --type=firestore-native`(東京リージョン、ユーザーが日本在住のため)。事前に`gcloud services enable firestore.googleapis.com`等一式が必要
8. **Cloud Storageのデフォルトバケットのみ、CLI/REST APIでの自動化に失敗。** `firebase deploy --only storage`が明示的に「`https://console.firebase.google.com/project/sky-grid-app/storage`で"Get Started"をクリックしてください」とエラーを返す。REST APIで`defaultBucket:addFirebase`のようなエンドポイントを試したが404で存在しなかった。**これはFirebase CLI公式が認める既知の制約で、代替APIは調査した限り存在しない。** 次回このステップが必要な時は詫びずにユーザーへ直接依頼してよい
9. Firestoreルールのみ先にデプロイ成功: `firebase deploy --only firestore:rules`。Storageルールはバケット未作成のため保留
10. 匿名認証の有効化はFirebase CLIに対応コマンドがないため、Identity Toolkit Admin APIを直接叩いた:
    - まず`GET https://identitytoolkit.googleapis.com/v2/projects/{project}/config`が`404 CONFIGURATION_NOT_FOUND`
    - `POST .../identityPlatform:initializeAuth`(body `{}`)で初期化してから`PATCH .../config?updateMask=signIn.anonymous.enabled`で有効化。**新規プロジェクトでAuthを触る時はinitializeAuthが先という順序を覚えておく**
    - どちらのAPI呼び出しも`X-Goog-User-Project: <project>`ヘッダが必須(ないと403 SERVICE_DISABLED、しかもエラーメッセージの`consumer`が無関係なプロジェクト番号を指してくるので原因が分かりにくい)
11. Cloud Functionsデプロイ: `cd functions && npm run build && firebase deploy --only functions`。1回目は関数自体は成功したが末尾に「Artifact Registryのクリーンアップポリシー未設定」エラー(コンテナイメージ蓄積で課金が地味に増える) → `firebase functions:artifacts:setpolicy`で1日で自動削除するポリシーを追加
12. 疎通確認で`testMissingFirebaseConfigurationIsExplained`(UIテスト)が失敗。**これは想定内の設計上の緊張**: このテストは「GoogleService-Info.plistが物理的に存在しない」ことを利用して「Firebase未設定→エラー画面」を検証していたが、実プロジェクト構築後はplistが常在するため前提が崩れる。既存の`-SkyGridSkipOnboarding`等と同じ「起動引数によるテストフック」パターンを踏襲し、`AppDelegate.swift`に`-SkyGridForceFirebaseUnconfigured`起動引数を追加(plistが存在してもこの引数があれば`FirebaseApp.configure()`をスキップ)、UIテスト側でその引数を渡すよう変更。47テスト全パス
13. 最終確認として実際にシミュレータでアプリを起動し(`-SkyGridForceFirebaseUnconfigured`なしの通常起動)、Identity Toolkit `accounts:query` APIで新規匿名ユーザーが実際に作成されたことを確認 → 検証用ユーザーは`accounts:delete`で削除

## 現在の状態(2026-07-29時点)

**完了:**
- Firebaseプロジェクト`sky-grid-app`(プロジェクト番号777493020244)、Blazeプラン、予算アラート¥750
- iOSアプリ登録・`GoogleService-Info.plist`配置・project.yml/xcodegen反映済み
- Firestore Native DB(asia-northeast1)、Firestoreセキュリティルールデプロイ済み
- 匿名認証有効化
- Cloud Functions `deleteAccount`(v2, us-central1)デプロイ済み、Artifact Registryクリーンアップポリシー設定済み
- build_sim/test_sim 47件全パス、実機相当の匿名サインイン疎通を確認済み

**追記(2026-07-30): Cloud Storageバケット作成完了。** ユーザー本人が`https://console.firebase.google.com/project/sky-grid-app/storage`で"Get Started"をクリック → `gsutil ls -p sky-grid-app`で`gs://sky-grid-app.firebasestorage.app/`の存在を確認 → `firebase deploy --only storage`でStorage Security Rulesもデプロイ完了。build_sim/test_sim 47件全パス再確認済み。これでFirebase本番構築(Auth匿名/Firestore/Storage/Cloud Functions)は全項目完了。

**未完了・次回:**
1. **Sign in with Apple**: Apple Developer Portal側でServices ID・秘密鍵の発行が必要(Bundle ID `com.takmin.skygrid`のCapability登録も未着手、VISION.md §7のチェックリスト参照)。それをFirebase ConsoleのAuthプロバイダ設定に登録する必要あり
2. **App Check enforcement**: 現状App Check APIは有効化しただけで、Firestore/Storage/Functionsへの「強制」モードは未設定(`deleteAccount`関数自体は`enforceAppCheck: true`をコードで指定済みなのでfail-closed)。iOS側は`AppAttestProviderFactory`(Release)/`AppCheckDebugProviderFactory`(Debug)を実装済みだが、Firebase Console側でのApp Attestプロバイダ登録は未確認
3. **RevenueCat**: 未着手(VISION.md §7に記載の通り、APIキー未設定)

## 次回セッションへの申し送り

VISION.mdの「実装前チェックリスト」節は本ドキュメントの内容で更新が必要(Firebase関連項目の多くが完了に変わった)。
