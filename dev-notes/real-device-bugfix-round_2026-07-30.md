# 実機不具合4件の根本原因調査・修正（2026-07-30）

依頼者がiPhone 15 Proの実機スクリーンショット8枚をAirDropで送付、時系列で確認しながら4件を修正した。すべて`build_sim`/`test_sim`(54件)で回帰なしを確認済み。**実機での最終確認は未実施**（下記「次回セッションTODO」参照）。

## 1. 写真アップロード失敗（P0、根本原因特定）

**症状:** 撮影後「Use this one」→「Your post could not be saved.」。Sky Gridアーカイブは0枚のまま。Buddiesのハンドル保存も、ランダムな未使用ハンドルですら常に「That handle is already in use.」。

**根本原因:** [dev-notes/app-check-enforcement_2026-07-30.md](app-check-enforcement_2026-07-30.md)でFirebase App Check enforcementを`ENFORCED`にした際、固定デバッグトークン(`2920ed9c-3a77-4d4d-ad35-85bbfa4eec33`)を`project.yml`のscheme `run`/`test`アクションの`environmentVariables`にのみ配線した。しかし実機デプロイは[dev-notes/ios-phase1-implementation_2026-07-29.md](ios-phase1-implementation_2026-07-29.md)の手順どおり`xcrun devicectl device process launch`を直接使う（Xcodeのscheme run actionを経由しない）。この経路は**schemeのenvironmentVariablesを一切継承しない**ため、実機は未登録のランダムなApp Checkデバッグトークンを使い、enforcement後はFirestore/Storageへの全リクエストが拒否されていた。

**修正:**
- `project.yml`: `SGDebugAppCheckToken`という固定Info.plistキー(Debug configのみ)に同じトークン値を追加で埋め込み。
- `AppDelegate.swift`: `#if DEBUG`分岐内で、`AppCheck.setAppCheckProviderFactory`を呼ぶ前に`Bundle.main`からこのキーを読んで`setenv("FIRAAppCheckDebugToken", ...)`を実行。これによりXcode経由・devicectl経由どちらの起動でも同じ固定トークンが使われる。

**副次バグ（同じ症状の別原因、修正済み）:** `HandleClaimView.swift`の`claim()`が`catch { errorMessage = "That handle is already in use." }`という**キャッチオール**になっており、App Check拒否のような無関係なエラーまで「ハンドル重複」と誤表示していた。`RepositoryError.handleAlreadyTaken`/`.network`/その他で分岐するよう修正。

## 2. オンボーディング未完了（P0、孤立コードの発見）

**症状:** ユーザー報告「オンボーディングが適切に機能していない」。スクリーンショットには含まれず、コードから発見。

**根本原因:** [dev-notes/ui-screen-flow-audit_2026-07-30.md](ui-screen-flow-audit_2026-07-30.md)のmermaid図が示す意図された4段階（Welcome→Morning intent→Wake time→Personalized plan）に対し、`OnboardingCoordinatorView.swift`の`OnboardingStep` enumは`.welcome`/`.questions`の2値しかなく、Questions完了後は`WakeGoalPickerView`(step 3/4)と`PersonalizedPlanView`(step 4/4)を一切経由せず直接Paywallへ遷移していた。両ファイルは実装済み・コンパイルも通る状態で存在するが、どこからも呼ばれない孤立コードだった（`grep`で呼び出し元ゼロを確認）。結果として新規ユーザーは起床目標時刻を一度も聞かれず、`LocalDefaults.wakeGoalMinutes`はデフォルト値のまま——ストリーク・アラームというアプリの中核指標が初回設定されない状態だった。テストにこの2画面への参照は皆無で、削除ではなく配線復元が安全と判断。

**修正:** `OnboardingStep`に`.wakeGoal`/`.plan`を追加し、Questions→WakeGoal→Plan→(Paywall/Free)の4段階を復元。`WelcomeView`/`PersonalizationQuestionsView`の`OnboardingProgress(step:total:)`表示も`total: 2`→`total: 4`に修正（`WakeGoalPickerView`/`PersonalizedPlanView`は元々`total: 4`のままだった=不整合の証拠）。

## 3. UIレイアウト崩れ（2件、スクリーンショットで視覚確認→シミュレータで再現・修正確認）

- **Buddies画面の見出しテキスト省略:** `BuddiesView.swift`の`BuddyRitualCard`内`Text("Two skies, revealed together.")`が`List`のカスタム行(`.listRowInsets(EdgeInsets())`)内で折り返されず"…"で切れていた。同じカード内の別テキストは正常に折り返していたため、`List`行のサイズ計算に対する典型的な回避策として`.fixedSize(horizontal: false, vertical: true)`を追加。
- **Sky Grid画面の「SKY GRID」年表示がステータスバーに被る:** `build_run_sim`(`-SkyGridSkipOnboarding -SkyGridLaunchGrid`起動引数)で再現を試みたところ、**初期状態(スクロール位置0)では問題なし**だった。実機スクリーンショットでは"SKY GRID"キャプションのみ大きくズレ、"2026"はやや上寄り——という非対称なズレ方から、パディング不足ではなく**ScrollViewのスクロール位置がTabView内で保持されたまま**（Buddiesへpush→pop、またはタブ切替の前に既にGridタブを少しスクロールしていた）と判断。`SkyGridView.swift`に`ScrollViewReader`を追加し、画面が`.onAppear`するたびに先頭(`sky-grid-header`のid)へ強制スクロールするよう修正。

## 4. 通知タップ→カメラ直行が効かない（P0、根本原因特定）

**症状:** 依頼者報告「アラームの通知から写真撮影画面に移動後、青いカメラアイコンでカメラが起動しない」。

**根本原因:** `RootView.swift`は2つの独立した「カメラに直行したい」トリガーを持っていた。
- AlarmKit経由(iOS 26+): `LocalDefaults.openCameraAfterMorningAlarm`という**永続化フラグ**を、`.onAppear`/`.onChange(of: destination)`/`.onChange(of: scenePhase)`のたびに**現在値を直接チェック**する`consumeAlarmCameraRequestIfNeeded()`で消費——堅牢。
- ローカル通知経由(iOS 17–25フォールバック、`NotificationRouter.swift`): `AppRouter.pendingRoute`という**インメモリ値**を`.onChange(of: router.pendingRoute)`で監視——**コールドスタート時に確実に壊れる**。`didFinishLaunchingWithOptions`で通知デリゲートが即座に呼ばれ`pendingRoute = .camera`がセットされるのは、`RootView`が`services.entitlements.refresh()`等のFirebase非同期処理を経て`destination == .today`に到達し`todayFlow`の`.onChange`がアタッチされるより確実に早い。SwiftUIの`.onChange`はアタッチ後の遷移にしか反応しないため、既に`.camera`になっている値への遷移を見逃す。

**修正:** `consumeAlarmCameraRequestIfNeeded()`を`consumePendingCameraRequestIfNeeded()`に統合し、`router.pendingRoute`も同様に**現在値を直接チェック**する方式に変更。冗長になった`.onChange(of: router.pendingRoute)`ブロックは削除。

カメラのライブプレビューが一瞬(スクリーンショット1枚分)黒くなる挙動も観測されたが、直後のフレームでは正常表示、かつ`liveSkyColor`の円は既に色を拾っていた（＝`AVCaptureSession`自体は起動済みでサンプルバッファは流れている）ことから、`AVCaptureVideoPreviewLayer`のウォームアップに伴う正常な一過性挙動と判断し、修正不要とした。

## 次回セッションTODO

- **実機での最終確認が必須。** 今回の4修正はすべてシミュレータの`build_sim`/`test_sim`(54件パス)でしか検証していない。特に#1(App Check)と#4(通知ルーティング)はシミュレータでは原理的に再現できない(実機固有の起動経路・実通知が必要)。iPhone 15 Proへワイヤレスデバイス再デプロイし、(a)撮影→投稿が実際にFirestore/Storageへ届くこと、(b)ハンドル保存が成功すること、(c)朝のローカル通知をコールドスタートからタップしてカメラへ直行すること、を確認する。
- 上記の実機確認時、`xcrun devicectl device process launch`にはSGDebugAppCheckToken経由のsetenvで対応済みだが、**万が一まだ失敗する場合**はFirebase Console側のApp Check debug tokens一覧に`2920ed9c-3a77-4d4d-ad35-85bbfa4eec33`が実際に登録されているか確認すること（[dev-notes/app-check-enforcement_2026-07-30.md](app-check-enforcement_2026-07-30.md)のロールバック手順も参照）。
- オンボーディング4段階復元により、`WakeGoalPickerView`内の「Set a System Alarm」ボタンが初回起動時にAlarmKit/通知権限を要求するようになった。これはVISION.md記載の「permissionは明示的な操作の瞬間にのみ要求」という設計方針に合致するが、初回オンボーディング体験の実機通し確認はまだ行っていない。
- `git status`で確認した限り、`ios/`配下には今回の6ファイル以外にも(Codexによる2026-07-29のGrid/Camera/Onboarding全面再設計を含む)非常に多くの未コミット変更が残っている。依頼者から明示的な指示がないためコミットは行っていない。作業消失リスクがあるため、次回セッション冒頭で依頼者にコミット方針を確認することを推奨する。
