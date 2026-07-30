# Firestore/Storage Rules のバディ相互参照を実際に検証(2026-07-30)

## 背景

VISION.md §4「実装前に潰しておくべき落とし穴」#5で「要検証: Storage Security Rulesから友達関係を参照できるか(クロスサービス`firestore.get()`)」と明記されていた事項。前回セッションでコードは書かれ実プロジェクトにデプロイ済みだったが、実際に2アカウント間で意図通り動くかは未検証のままだった。

## やったこと

1. `brew install openjdk`(このマシンには元々JRE未インストール — Firebase Firestore/Storageエミュレータの実行に必須。`/usr/bin/java`はmacOS標準のスタブで実体を持たない)。keg-onlyのためPATHへのシンボリックリンクは行わず、実行時に`export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"`で都度解決する方式にした(システム全体のJava設定は変更していない)。
2. `ios/firebase.json`に`emulators`セクション(firestore: 8180, storage: 9299, `singleProjectMode: true`)を追加。
3. `ios/rules-tests/`に`@firebase/rules-unit-testing` + mochaのテストプロジェクトを新設。`firestore.rules`/`storage.rules`を実ファイルから読み込んでエミュレータにロードし、以下をテスト:
   - 承認済みバディ→投稿画像を閲覧できる(cross-service参照の本丸)
   - 本人は常に閲覧できる
   - 友達関係なし/pending中/ブロック済み/未認証 → いずれも閲覧不可
   - Firestore側`users/{uid}`のバディ経由読み取りも同様に検証

## ハマった点(重要)

**症状**: 初回実行時、「承認済みバディが投稿を読める」の1件だけが`storage/unauthorized`で失敗し、他の「読めないはず」のテストは全部パスするという奇妙なパターンになった。

**原因**: テストコードの`initializeTestEnvironment({projectId: "sky-grid-rules-test", ...})`が、CLIが`.firebaserc`の`default`(`sky-grid-app`)で起動したエミュレータとは**別のプロジェクト名前空間**でFirestoreにデータを書き込んでいた。Storage Rules Runtime(`firestore.get()`/`exists()`)は、CLIが起動した側のプロジェクト(`sky-grid-app`)のFirestoreデータを見にいくため、テストが書いた`sky-grid-rules-test`名前空間のデータが見つからず、`activeBuddy()`が常に`false`を返していた。「読めないはず」のケースは偶然にも期待通りの結果(false)と一致していたため、一見全部通っているように見えて実は**クロスサービス参照そのものが機能していなかった**。

**教訓**: `initializeTestEnvironment`のFirestore/Storage両方を使うテストでは、`projectId`を`.firebaserc`の`default`プロジェクトIDと**必ず一致させる**こと。一致していないと、クロスサービス参照だけが静かに壊れ、単体のFirestore-onlyテストやStorage-onlyテストでは検出できない。

**修正後**: `PROJECT_ID`を`"sky-grid-app"`に変更 → 8件全てパス。ローカルエミュレータの名前空間分離のみに影響する変更であり、実際の本番Firebaseプロジェクトには一切アクセスしていない(host: 127.0.0.1固定)。

## 実行方法(次回セッション用)

```bash
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
cd ~/Desktop/SkyGrid/ios
npm --prefix rules-tests run test:emulator
```

## 結論

Storage RulesからFirestoreを参照するクロスサービス設計(`activeBuddy()`)は、承認済み/pending/ブロック済み/無関係/未認証の全パターンで**意図通り動作することを実証済み**。VISION.mdの「要検証」マークは解消してよい。
