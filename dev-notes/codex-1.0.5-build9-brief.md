# Codex 指示（1.0.5 build 9 の調査・改善・再提出）

以下をそのまま Codex に貼り付けてください。

---

Sky Grid（`/Users/taku8/Desktop/SkyGrid`、ブランチ `release/1.0.5-store-assets`）で、1.0.5 を build 9 として作り直し、審査に再提出してください。オーナーはこの一連（調査・コード修正・ビルド・ストア画像差し替え・再提出）を明示的に承認しています。

## トークン運用（最優先で守ること）

あなたが使えるトークンは少ない。**広く探索せず、質の高い推論だけに絞れ。**

- 全ファイルを読むな。証拠のある箇所だけを読め。
- 「念のため」の調査、投機的リファクタ、大規模な書き換えを一切するな。
- 迷ったら、変更しないほうを選べ。
- sol への委譲は本当に判断が割れる1点だけに限れ。ゼロでもよい。

## 前提（確定事項、再調査不要）

- 1.0.5 build 8 の審査提出は**取り下げ済み**。version 1.0.5 は `PREPARE_FOR_SUBMISSION` に戻っている。ASC app id `6796222704`、version id `56034449-fb7b-48f9-816e-fdcec37a650e`、en-US localization id `d5344601-9a0b-4e57-8f13-b65c9cff6c31`。
- releaseType は `AFTER_APPROVAL`。**承認され次第そのまま公開される。**中途半端な状態で提出するな。
- 本番 Functions に `requestBuddy` / `acceptBuddy` はデプロイ済みで、実機でハンドル経由の申請・承認が成功済み。ここは触るな。
- 直近のコミット `781595b` と `d05a0c6` で、バディ画面の修正（丸アバター→角丸タイル、招待カードのSection分離、公開済みの空を開く導線、セリフ体9箇所の一掃）が入っている。これらは build 8 には入っていない。**build 9 の目的はこれらを載せること。**
- ユニットテストは現在 301件／55スイート通過。

## やること

### 1. 調査（ここにトークンを使いすぎるな）

ユーザー体験を壊す実害のある問題だけを探せ。目安は30分程度の調査で十分。

優先して見る場所:
- `ios/SkyGrid/Sources/Friends/`、`Invite/`、`Today/`（今回変更が入った周辺の回帰）
- ライト／ダーク両方でのコントラストとレイアウト破綻
- Dynamic Type 最大時に主要導線が壊れないか

**探すな**: 新機能の提案、アーキテクチャの改善、パフォーマンス最適化、テストカバレッジの拡充。今回は範囲外。

判断基準は `DESIGN.md`（2026-09-05 オーナー承認、これが現行方針）と `AGENTS.md`。

### 2. 修正

見つけた実害のある問題だけを、最小の差分で直せ。1つ直すごとにビルドを通せ。

### 3. バージョン更新

`ios/project.yml` の `CURRENT_PROJECT_VERSION` を **8 → 9**。`MARKETING_VERSION` は 1.0.5 のまま。その後 `xcodegen generate --spec ios/project.yml --project ios`。

### 4. 検証（実際に実行しろ、主張するな）

```sh
xcodebuild -project ios/SkyGrid.xcodeproj -scheme SkyGrid \
  -destination 'platform=iOS Simulator,id=7B20C298-FB04-4588-B748-54011781919F' \
  -derivedDataPath /Users/taku8/.cache/skygrid-b9/DerivedData \
  -only-testing:SkyGridTests test
```

301件を下回ったら原因を潰すまで進むな。

画面の確認は DEBUG 限定の UI 監査ハーネスを使う:

```sh
xcrun simctl launch <udid> com.takmin.skygrid -SkyGridUIAudit \
  -SkyGridUIAuditScenario buddies \
  -SkyGridStorePhotoDirectory /Users/taku8/Desktop/SkyGrid/ios/SkyGrid/Tests/Fixtures
```

シナリオ: `today` / `camera-review` / `grid` / `buddies` / `reward-peak` / `share-morning`。
`xcrun simctl ui <udid> appearance light|dark` で両方見ろ。**画像を実際に開いて目で見ろ。**

### 5. ストア画像 `04-together` の差し替え（必須）

現在ストアに載っている `04-together` は**丸アバター時代の古いUI**で、build 9 とは一致しなくなる。作り直せ。

レンダラは `/Users/taku8/.cache/skygrid-release-20260907/tools/bin/kou`（koubou 0.18.1）に既にある。`/tmp` は消えるので使うな。

```sh
# 素材の再撮影（7枚すべて撮り直す）
python3 branding/app-store/1.0.5/capture.py <udid>

# 5枚レンダリング
/Users/taku8/.cache/skygrid-release-20260907/tools/bin/kou generate branding/app-store/1.0.5/store.yaml

# 差し替え（旧5枚を消して新5枚を上げる）
asc screenshots upload \
  --version-localization d5344601-9a0b-4e57-8f13-b65c9cff6c31 \
  --path branding/app-store/1.0.5/final/iPhone_17_-_Black_-_Portrait \
  --device-type IPHONE_65 --replace
```

`branding/app-store/1.0.5/previous/` にある旧世代のバックアップは**消すな**（ASCから削除済みで再取得できない）。

文言の事実確認: 無料枠は「直近30日分のアーカイブ」であって**無料トライアルではない**。トライアルと読める表現を書くな。バディ人数の上限も主張するな。

### 6. アーカイブ・アップロード・再提出

```sh
asc xcode archive ...   # Release構成
asc xcode export --archive-path <...> --export-options ios/ExportOptions.plist \
  --ipa-path <...> --xcodebuild-flag=-allowProvisioningUpdates
asc builds upload --app 6796222704 --ipa <...> --wait
asc versions attach-build --version-id 56034449-fb7b-48f9-816e-fdcec37a650e --build-id <新build id>
asc review doctor --app 6796222704      # blockingCount 0 を確認してから
asc review submit --app 6796222704 --version 1.0.5 --build <新build id> --confirm
```

**`asc review doctor` が blockingCount 0 でなければ提出するな。**

審査メモ（review detail id `2c876a09-32da-44f8-8c2d-a5ead1ed19bf`）は現状「スクリーンショット用ハーネスはReleaseビルドから除外」と書いてある。これは事実（`SkyGridApp.swift:12-20, 36-853` と `CameraView.swift:363` が `#if DEBUG` 内）。変更を入れてこの記述が嘘になるなら、メモを直せ。

## 触るな

- `.loop/` — 別セッションが所有。stage も revert も clean も一切するな
- `waitlist/` — 公開サイト。今回は無関係
- Firebase（Functions、Firestore、Rules、設定）— デプロイ済みで動作確認済み
- `branding/app-store/1.0.5/previous/`
- 既存コミットの改変、`origin` への push

## 報告

変更したファイル、実際のテスト件数、スクリーンショットで何が見えたか、新しい build id と提出 id、そして**検証できなかったこと**を明示しろ。監査ハーネスは sealed 状態しか出せないので、公開済みバディの空の表示とズーム操作は確認できない。できていないことをできたと書くな。
