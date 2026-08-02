# 「今日はもう投稿済み」なのに写真が存在しない問題 — 根本原因特定・自己修復機構の実装(2026-08-02)

## 依頼内容

依頼者から: 今日の写真をまだ送信していないのに、カメラで撮影しようとすると「もう記録済み」
という趣旨のメッセージが出る。サーバー側のFirestoreには今日投稿済みの状態として保存されて
いるが、実際には写真データが存在しない(表示もされない)。新しく撮り直しても送信できず、
過去のアカウント情報から画像を復元することもできない。この根本原因調査・恒久対策を、実機を
使わず自律的に行うよう指示された。

## 根本原因(コード上の事実で特定、証拠付き)

設計上意図的に(`PostDraft.swift`のコメント「blueprint §3.2」参照)、1回の撮影は
**2つの独立したストアに非同期・非協調で書き込まれる**:

1. `FirebasePostRepository.createPost()` — Firestore `users/{uid}/posts/{localDate}`
   ドキュメントを**即座に**作成。この時点でStorage側の画像はまだ存在しなくてよい。
2. `UploadQueue`(SwiftData裏付けのactor) — 実際のJPEGバイトをFirebase Storageへ
   **バックグラウンドで非同期に**アップロード。1.の完了とは完全に切り離されている。

`PostPublisher.publish()`は`uploadQueue.enqueue(draft)` → `postRepository.createPost(draft)`
の順で呼ぶ — Firestoreドキュメントの作成は、Storageアップロードの成功確認より**前**に起きる。

**問題のギャップ:** バックグラウンドのStorageアップロードが**永久に完了しない**場合
(`UploadQueue.isTerminal()`が拾う`.notAuthenticated`/`.permissionDenied`
[App Check・Storage Rules拒否]、`localFileMissing`エラー、または実機固有の問題として
以前から記録されている「ローカルSwiftData行・保留中JPEGファイル自体が丸ごと消失する」
ケース[アプリ再インストール・コンテナUUID再割り当て、`camera-capture-crash-and-upload-
investigation_2026-07-31.md`参照])、Firestoreの投稿ドキュメントは**恒久的に修復不能な
「幽霊」**になる:

- `firestore.rules`の`posts/{localDate}`は`allow update: if false`(更新は絶対に不可)。
- その日の新規撮影は無条件に拒否される(`FirebasePostRepository.swift`が結果の
  Firestore `permission-denied`を`RepositoryError.alreadyPostedToday`にマップ — この
  マッピング自体は前回セッション[`app-check-resolution-and-recapture-bug_2026-08-01.md`]
  で追加された正しい修正だが、「検知」しかせず「治療」しない)。
- `PostPublisher.swift`は`.alreadyPostedToday`を受けるたびに、ユーザーが**今まさに
  撮り直した新しい写真のローカルファイルを削除**する(前の投稿がこの日のスロットを
  正当に所有している、という前提のロールバック処理 — 幽霊状態ではこの前提が崩れる)。
- `TodayPhotoCard.loadImage()`は存在しないStorageオブジェクトを指数バックオフで
  永遠にリトライし続ける。
- `PostStatusBanner`はローカルの`PendingUploadSummary`行が残っている場合のみ何かを
  表示する — その行自体が消失していれば、**失敗を示すUIすら一切出ない**まま永久に
  ブロックされる。

`PostRepository.deletePost(uid:localDate:)`は既に存在し(`FirebasePostRepository.swift`)、
`firestore.rules`も所有者による削除を明示的に許可している
(`allow delete: if signedIn() && request.auth.uid == uid`)——**しかし本番コードのどこからも
一度も呼ばれていなかった**(grep で確認)。自己修復に必要な権限・APIは揃っていたが、
どこにも配線されていなかった、というのが本質。

## 依頼者アカウントの現在の状態について(重要な限界)

本セッションでは`gcloud auth print-access-token`・`firebase login:list`による本番
Firestore/Storageへの直接調査を試みたが、**権限クラシファイアにブロックされ実行できなかった**
(認証情報アクセスに分類されたため)。無理な迂回はせず、コードベースの分析のみで原因を
特定した。したがって、依頼者の実際のアカウントで「幽霊」となっているドキュメントを
本セッション内で直接削除することはできていない。**この後デプロイされたビルドを開いて
Todayタブを見れば、下記の自己修復バナーが自動的に幽霊状態を検知し、そこから
「Clear and retake」で自力復旧できるはず**(実機での最終確認は依頼者の指示により本セッション
では未実施)。

## 設計判断(code-architect [Opus] による方針設計 + 実装)

このタスクはDBの整合性・状態遷移設計に関わる根本修正のため、CLAUDE.mdのエスカレーション
方針に従い`code-architect`(Opus)に実装ブループリントの設計を委譲し、その設計に基づいて
実装した。

- **`ImageUploading.imageExists(path:)`は削除の根拠にできない**: そのdocコメントに
  「`false`は判定不能な読み取りも含む」と明記されており、`FirebaseImageStore.imageExists`は
  `(try? ...getMetadata()) != nil`という実装 — **App Check拒否(幽霊を生む原因そのもの)も
  `false`を返す**。これをそのまま削除条件に使うと、単にオフラインだったりApp Checkに
  ブロックされているだけの正常なユーザーの投稿を誤って消してしまう回帰バグになる。
  → `RemoteImagePresence { present, absent, indeterminate }`という3値を新設し、
  `.absent`(Storageの`objectNotFound`で確定)の場合のみ削除を許可。読み取り不能は
  常に`.indeterminate`とし、何もしない。
- **検知は自動・削除はユーザー確認必須**: 削除はサーバーデータの不可逆な破棄であり、
  `.absent`判定は高確信だが証明ではない(未知のバグ・ルール変更等の可能性は残る)。
  検知(読み取りのみ)を自動でバックグラウンド実行し、実際の削除はカメラを開いて
  撮り直す一連の操作の中の1タップ確認に載せる(体感上の追加コストはゼロ)。
- **Compare-and-delete**: 削除直前にサーバーの最新ドキュメントを再取得し、
  判定に使ったものと`imagePath`が一致することを確認してから削除。Firestoreのルールが
  `update`を一切禁止しているためトランザクションのexistsプレコンディションが使えず、
  この再確認は完全な排他制御ではない(別端末での同時撮影という残存リスクは受容)。
- **再入防止**: `OrphanedPostRecovery.recover()`は`@MainActor`上、最初の`await`より前に
  同期的に日付をSetへ挿入するガードを持つ — 2重タップや2エントリーポイントからの
  同時呼び出しでも削除は必ず1回だけ実行される(テストで確認済み)。

## 変更したファイル

- `Sources/Data/ImageStore.swift` — `RemoteImagePresence`、`imagePresence(path:)`追加
  (フェイルセーフなデフォルト実装付き)
- `Sources/Data/Firebase/FirebaseImageStore.swift` — `imagePresence`実装
  (Storageの`objectNotFound`[-13010]のみを`.absent`とする)
- `Sources/Persistence/PendingUpload.swift` — `PendingUploadSummary`に
  `fullImagePath`/`thumbImagePath`/`hasLocalFullImage`追加
- `Sources/Upload/UploadQueue.swift` — `discardOrphanedRow(queueID:fullImagePath:)`新設
- `Sources/Publishing/PostIntegrityPolicy.swift`(新規) — 純粋な決定表
  (`TodayPostIntegrity`: intact/uploadPending/undetermined/orphaned)
- `Sources/Publishing/OrphanedPostRecovery.swift`(新規) — 検知・削除サービス
- `Sources/Today/OrphanedPostBanner.swift`(新規) — 復旧UI(破壊的確認ダイアログ付き)
- `Sources/Today/TodayView.swift` — バナーを`morningRecord`内に組み込み
- `Sources/Today/TodayViewModel.swift` — 状態(`todayIntegrity`等)・15秒間隔の
  ポーリングタスク・`recoverOrphanedPost()`追加
- `Sources/App/AppServices.swift` / `ServiceFactory.swift` — 依存注入配線
  (`FirebaseImageStore`のインスタンスを`UploadQueue`と`OrphanedPostRecovery`で共有するよう修正)
- `Sources/App/RootView.swift` / `SkyGridApp.swift` — `TodayViewModel`呼び出し箇所2箇所を更新
  (UIAudit用スタブ`UIAuditOrphanedPostRecovery`追加)
- `Tests/PostIntegrityPolicyTests.swift`(新規、12件) — 決定表の全分岐
- `Tests/OrphanedPostRecoveryTests.swift`(新規、6件) — 実在する投稿は絶対に消さない、
  indeterminate時は絶対に消さない(App Check回帰ガード)、2パターンの孤児検知、
  compare-and-delete、同時呼び出しの排他
- `Tests/UploadQueueTests.swift`(+3件) — `discardOrphanedRow`のパス不一致no-op、
  uploading/done時no-op、失敗行の削除
- `SkyGrid.xcodeproj/project.pbxproj` — `xcodegen generate`で新規ファイルを再登録
  (手動pbxproj編集は行っていない。`project.yml`はディレクトリglobで
  `SkyGrid/Sources`・`SkyGrid/Tests`を拾うため、新規ファイル自体の`project.yml`変更は不要)

## 検証

- `build_sim`: 成功、警告・エラー0件。
- `test_sim -only-testing:SkyGridTests`: **111件全てpass**(新規21件 + 既存90件、
  regressionなし)。
- 実機ビルド・実機デプロイは依頼者の指示により本セッションでは未実施
  (「別の場所に行くので実機は使わない」との明示指示)。**次回セッションで実機検証を
  推奨** — 特に、実際に幽霊状態のドキュメントが存在するアカウントでバナーが正しく
  表示され、「Clear and retake」が機能することを確認すること。

## 既知の残存リスク・次回への申し送り

1. **本番の幽霊ドキュメントの実地確認は未実施。** 本セッションはgcloud/firebase CLIへの
   アクセスがブロックされたため、依頼者の実際のアカウントに現在どんな状態のドキュメントが
   残っているかをground truthとして確認できていない。今回実装した自己修復バナーが
   次回起動時に正しく発火するかは、実機での確認が必要。
2. **Compare-and-deleteは完全な排他制御ではない**(上記参照)。実運用上、同一アカウントの
   複数端末からの同時撮影という非常に稀なケースでのみ問題になりうる。
3. `TodayPostIntegrity.undetermined`の"grace window"は120秒固定。`publish()`の
   enqueue→createPostの間隔は通常ミリ秒〜数秒のはずだが、極端に遅いネットワークでは
   境界値の妥当性を実地で見直す余地がある。
4. 既存のApp Check debug provider不具合(`exchangeDebugToken`の403)は本修正の範囲外。
   今回のテスト実行中もシミュレータ上で同じ403ログが出ている(無害、既知)。
