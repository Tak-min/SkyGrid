# 実写真の一貫使用 + 正方形サムネイルへの統一（2026-07-31）

## 依頼内容

依頼者から3点の指摘：
1. 画像が使われる箇所は全て実写真を使う。空色の平均値カラー表示ではなく。
2. 撮影した画像が要求サイズに合わず、枠を少しはみ出す。
3. 複数の画像で幅（サイズ）にばらつきがある。ピクセルアート化するなら幅は統一されているべき。

## 調査で判明した実態（当初の想定との差）

依頼文だけでは「シェアカード」「アプリ内グリッド」「実機での見た目」のどこを指しているか曖昧だったため、
`screenshots/ui-audit-grid-final.png` の実画像を確認し、コードを読み、Opus(code-architect)に実装ブループリントを
委譲して以下を確定させた（プロンプトの実測プローブで検証済み — 推測ではない）。

### 問題1（平均色カラー）の実体
`Sources/Grid/GridCanvas.swift` の `GridCanvas`（年間365マスの`Canvas`）は既に実写真サムネイルを描画していた
（未読込セルはニュートラルfill、平均色ではない）。**唯一の例外がシェアカード書き出し経路**：
`ColorGridCanvas` → `SkyGridExportView` → `ShareCardRenderer.render(year:colors:)` → `GridArchiveView.shareGrid()`
の一本道だけが `SkyColor`（平均色）を描いていた。2026-07-30の同日メモ
(`dev-notes/ui-photo-archive-review_2026-07-30.md`)には「共有カードは意図的に軽量な色の記録として残す」と
明記されており、これは**意図的な過去の設計判断**だった。依頼者の今回の指示はこの判断を明示的に上書きするもの。

**単純にcolorsをthumbnailsに置き換えるだけでは壊れる**、という点が最大の落とし穴だった：
`GridArchiveViewModel.thumbnails` は選択中の月のサムネイルしか読み込まない設計（年間画面を開いた瞬間に
365枚をフェッチしない、というコスト制御が目的）。素朴に置き換えると、共有画像は年の1/12だけ写真が入り、
残り11ヶ月が空白になる回帰を起こしていた。

### 問題2・3（枠のはみ出し・幅のばらつき）の実体
根本原因は2箇所の複合：

**(a) データ層**: `ImageProcessor.processedPair` はサムネイルを「長辺320px」にリサイズするだけで、
アスペクト比は撮影時のまま（機種・向きにより毎回変わる）保持していた。365日分の写真が全部違う形のまま
グリッドセルに描かれていた。

**(b) 表示層のSwiftUIレイアウトの罠**: `Sources/Grid/SkyGridView.swift` の `ArchivePhotoTile`
（月別カレンダーグリッドの1マス）は
```swift
ZStack { Image(...).scaledToFill(); Text(...) }
    .frame(maxWidth: .infinity)
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(...))
```
という構造だった。`.aspectRatio(1, contentMode: .fit)` は「子に正方形を提案する」だけで、**子が提案を無視して
太った場合、親はその太ったサイズをそのまま自分の報告サイズとして採用する**（SwiftUIのレイアウトプロトコルの
仕様）。`scaledToFill` は意図的に提案サイズを超えて描画するので、`ZStack`全体が最大33%膨張し、
`.clipShape`は「既に膨張した後の矩形」に対してクリップするため、はみ出しを一切防げない
（Opusの実測プローブ: 350pt幅・7列グリッドで、正方形ソースは47.43×47.43で正常だが、3:4縦長ソースは
47.43×63.24、4:3横長ソースは63.24×47.43——隣のセルへ食い込む）。`.clipped()`を足しても直らない
（同じく実測確認済み）。`Sources/Today/TodayPhotoCard.swift` も同型の潜在バグを持っていた
（現状は縦長撮影のみなので症状が出ていなかっただけ）。

## 実装した修正

1. **`ImageProcessor`**: サムネイル生成を「長辺320px」から「320×320中央クロップ」に変更（`squareJPEG`）。
   本体画像（main、1440px長辺）はクロップしない——`TodayPhotoCard`等はfill+clipで任意アスペクト比を
   正しく処理できているため、クロップすると写真の一部を無意味に失うだけ。
   - **副産物で見つけたバグ**: `UIGraphicsImageRendererFormat.default()` はデバイスの表示スケール
     （iPhone 15 Proなら3倍）をそのまま継承する。「320px」のつもりが実際は960pxで書き出されており、
     アップロード画像の実ピクセル数は常に意図の約9倍だった。`format.scale = 1` で修正
     （`VISION.md`が自己記録している「画像サイズがStorage/帯域コストの支配的要因」という課題の一部が
     これで説明できる）。
2. **`GridLayoutMath.aspectFillRect`**: 純粋関数として追加。`GraphicsContext.draw(_:in:)`は
   非等方ストレッチでrectを埋めるだけ（アスペクト比保持なし、実際にピクセル検証済み）なので、
   `GridCanvas`側でアスペクトフィルの矩形を計算してから渡すよう変更。今後正方形以外のサムネイルが
   紛れ込んでも歪まない安全網として残す。
3. **`ArchivePhotoTile` / `TodayPhotoCard`**: 「形（Shape/Rectangle）にレイアウトを決めさせ、写真は
   `.overlay`に入れる」パターンに変更。`.overlay`の内容は親のレイアウトサイズに影響しないため、
   ソースのアスペクト比に関わらずセルは常に指定サイズ通りになる。
4. **シェアカード**: `GridArchiveViewModel.loadThumbnailsForSharing()` を新設。オンスクリーンの
   月単位の遅延読み込みとは別に、共有ボタンを押した瞬間だけ「表示可能な全期間」のサムネイルを
   （キャッシュ済みは再利用・未取得分だけフェッチして）読み込む。読み込み中は共有ボタンに
   スピナー表示＋無効化（`isPreparingShare`）。`SkyGridExportView`/`ShareCardRenderer`は
   `colors:` ではなく `postedDates:` + `photos:` を受け取り、オンスクリーンと同じ`GridCanvas`で
   実写真を描画するよう変更。
5. `ColorGridCanvas` は呼び出し元・テストがゼロだったため削除。`SkyColor.color` は他に生きた
   呼び出し元（`TodayView`, `BuddyTile`, `CameraView`のライブシャッター色, `SkyColorDisplay`）が
   あるため維持。

## テスト

`Tests/ImageProcessorTests.swift` を新規作成。合成画像（横長・縦長・正方形）とWikimedia由来の実写真
フィクスチャ(`real_clear_sky.jpg`)の両方で、本体画像の長辺と、サムネイルの正方形（幅=高さ=320px、
JPEGのメタデータから直接ピクセル寸法を読む——`UIImage.size`はスケール1.0を常に返すため検証にならない）を
検証。`Tests/GridLayoutMathTests.swift` に `aspectFillRect` のケース（正方形/縦長/横長/ゼロサイズ）を追加。

## スコープ外にした事項（依頼者判断待ち）

- **`Sources/Today/BuddyTile.swift`**: バディ公開後（`BuddyRevealGate`が開いた後）も平均色の円のまま
  表示している。Storage Rulesは`activeBuddy && hasPostedFor`条件で実写真取得を許可しているため、
  技術的には表示可能。ただし「公開前は色のみ・0.35不透明度でぼかす」は意図的なプロダクト仕掛け
  (`dev-notes`の相互ブラー機能)であり、公開後の表示だけを直す変更はToday画面のフェッチ数を最大12件
  （バディ数分）増やす。プロダクト上の判断が必要なため今回は手を付けていない。
- **色抽出のEXIF向き**: `SkyColorExtractor.extract(from: UIImage)` は `CIImage(image:)` を使うが、
  これは`imageOrientation`を適用しない。実機撮影は`.right`向きで届くため、「上55%が空」という前提が
  実際は表示画像の側面帯を読んでいる可能性がある。既存のテストフィクスチャは全て`.up`向きなので
  この問題を検出できない。未検証・未修正（別issueとして次回検証すべき）。
- **共有時の365枚シーケンシャル読み込みの速度**: 未キャッシュの1年分をシーケンシャルに読むと
  デバイス次第で数十秒かかる可能性がある。実測してから`withTaskGroup`化を検討すべきで、
  今回は計測していないため手を付けていない。

## 検証状況

`build_sim` 成功（既存の警告2件はRevenueCatService.swiftの既知のSwift 6 concurrency警告で無関係）。
`test_sim` 実行中（結果は追記予定）。**実機での見た目確認は未実施** — このメモを読む次のセッションは
まず実機（またはシミュレータのUI Audit画面）で年間グリッド・月別グリッド・シェアカードを目視確認すること。
