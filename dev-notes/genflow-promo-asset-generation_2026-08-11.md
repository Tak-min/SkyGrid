# GenflowAI で Sky Grid 広報素材を作る — 実地調査と初回生成ログ

日付: 2026-08-11
対象サービス: https://www.genflowai.io/ (Studio: /studio)
アカウント: 江藤拓海 でログイン済み（Google SSO と思われる。ブラウザセッションで既に認証済みだった）

---

## 結論（先に）

- **無料プランのクレジット10では動画は1本も作れない。** 最安構成（Seedance 2.0 Mini / 9:16 / 8s / 480p）でも **32クレジット**必要。
- 画像は作れる。**medium 品質 = 6クレジット / low = 3クレジット**（9:16・1K）。
- 今回、10クレジットを使って **9:16 画像2枚** を生成済み（medium 1 + low 1）。残クレジット **1**。
- 継続するには課金が必要。**Starter $9.90/月（500クレジット/月）が、$10単発クレジットパック（500クレジット）と同額でウォーターマーク無しDL等の特典が付くため厳密に上位互換。**

---

## 実測データ（すべて 2026-08-11 に UI 上で確認）

### モード
入力欄下のセレクタで切替: `Agentモード` / `画像生成` / `動画生成` / `音声生成`

### 画像生成（GPT Image 2）
- アスペクト比: 1:1 / 2:3 / 3:2 / 4:3 / 3:4 / 16:9 / **9:16**
- 解像度: 1K / 2K
- 品質: low / medium / high
- **コスト実測（9:16・1K）: low ≈ 3、medium ≈ 6**（送信ボタン横に `~N` と表示される）
- medium での実消費は **ちょうど6**（10 → 4 に減少）を確認。表示の `~` は付くが実際は表示通りだった。

### 動画生成
モデル3種。すべて 9:16 対応。
| モデル | 構成 | コスト |
|---|---|---:|
| Seedance 2.0 **Pro** | 9:16 / 8s / 480p | ~56 |
| Seedance 2.0 **Mini** | 9:16 / 8s / 480p | **~32（最安）** |
| HappyHorse 1.0 | 9:16 / 8s / 720p | ~104 |

Seedance の生成タイプ: `最初と最後のフレーム` / `リファレンスモード` / `テキストからビデオへ`。
解像度は 480p / 720p / 1080p / 4k、音声は ミュート / サウンドオン。

→ **静止画で先にキーフレームを作り、`最初と最後のフレーム` か `リファレンスモード` に食わせるのが、クレジット効率の良い作り方**（テキストから直接動画を回すとガチャで溶ける）。

### 課金
- クレジットパック（単発）: **500クレジット = $10.00**（$0.020/クレジット）。スライダーで 500〜2M。「毎月の補充や会員特典は含まれません」と明記。
- メンバーシップ: Starter $9.90/月（500cr）/ Basic $19（1,000cr）/ Advanced $42.50（2,500cr）/ Professional $140（10,000cr）。年払いで -50%。
- **Starter の特典に「ウォーターマークなしでダウンロード」「7日間の資産保管」が含まれる** → 無料プランのダウンロードにはウォーターマークが入る可能性が高い（未検証。DLボタンは押していない）。

---

## 今回生成した素材（プロジェクト: `prj_01kzqan0fbp53t99v28es8g5bm`）

いずれも 9:16 / 1K / GPT Image 2。**文字は意図的に一切入れていない**（AI生成の文字は崩れやすく、後からCapCut等で載せた方が使い回しが効くため）。

### 1. フック用カット（medium, 6cr）— 出来は良い
プロンプト:
> Vertical 9:16 lifestyle photograph, shot on 35mm film, soft natural morning light. First-person POV: a young adult's hand holds up a smartphone toward a quiet dawn sky seen through an open bedroom window. The real sky behind is a gentle gradient of pale blue fading into peach and warm cream with a few soft clouds. The phone screen shows a minimal app interface: clean off-white background with one large rounded rectangle filled with the same pale-blue-to-peach sky gradient. Absolutely no text, no letters, no numbers, no icons, no logos anywhere in the image or on the screen. Calm, intimate, unhurried early-morning mood. Muted pastel palette, fine film grain, shallow depth of field, slightly imperfect handheld framing like a real phone photo. No watermark.

結果: ベッドから起き上がって窓の外の朝焼けにスマホを向けている一人称カット。画面には空のグラデーションだけが映る。Sky Grid の Today 画面の「THIS MORNING」カード（実物も空グラデーションのカード）と矛盾しない表現になっている。

### 2. ペイオフ用カット（low, 3cr）— 及第点だが色が土っぽい
プロンプト:
> Vertical 9:16 minimal editorial poster, photographed flat-lay style. A large dense grid of small rounded squares fills most of the frame like a calendar mosaic, roughly 12 columns by 20 rows... (略、空の色のモザイク)

結果: 365マス風のカラーモザイク。ただし **low 品質のせいか色がベージュ/グレー寄りに寄り、「空の色」感が薄い**。medium で作り直す価値あり。

---

## Gotcha（ハマりどころ）

1. **`https://www.genflowai.io/ja/pricing` は 404。** 価格はトップページ内のアンカー（フッターの「価格設定」リンク）。ナビの「価格設定」ボタンはクリックしてもスクロールしないことがある。
2. **ダッシュボードの `get_page_text` はほぼ空を返す**（`<article>` だけ拾う）。スクリーンショット + `find` で見るしかない。
3. **設定ドロップダウンが入力欄に覆いかぶさる。** ドロップダウンを開いたまま `type` すると文字がどこにも入らない（エラーも出ない）。必ず一度キャンバス空白をクリックして閉じてから入力欄をクリックすること。
4. **キャンバス上で画像をクリックすると選択＋編集ツールバーが出て、下部に「その画像を参照素材として使う」プロンプトバーが開く。** 次の独立した生成をしたいときは右パネル（Generate タブ）の入力欄を使う。キャンバス下部のバーに書くと i2i になる。
5. **キャンバスでドラッグすると画像が動く**（ハンドツールを選んでいても選択中の要素は動く）。レイアウトが崩れたら cmd+Z。
6. 生成後、右パネルの設定は **1:1・low にリセットされる**。9:16 を毎回設定し直す必要がある。
7. 生成時間: 9:16・1K・medium で **約40秒**（99% で長く止まる。「バックグラウンドの生成には通常30秒かかります」と表示）。

---

## 次にやること（未着手）

1. **クレジット購入の判断が要る**（依頼者の権限）。Starter $9.90/月 を推奨。500cr で Mini 8s 動画が約15本、または medium 画像が約83枚。
2. 買った後の推奨手順:
   - キーフレームを medium 画像で数枚作る（6cr/枚）
   - `Seedance 2.0 Mini` + `最初と最後のフレーム` で 8s 動画化（32cr/本）
   - 3〜5本回して当たりを探す（約 150〜200cr）
3. **未検証**: 無料プランでのダウンロードにウォーターマークが入るか（DLボタン未押下）。
4. **未検証**: 実アプリのスクリーンショット（`branding/mockups/app-store/*.png`）を参照素材としてアップロードできるか。Claude 側の `file_upload` はセッション共有ファイルに制限されるため、依頼者本人のドラッグ&ドロップが必要な可能性。

## 方針上の注意（2026-08-10 の持ち越し論点）

[[skygrid-paid-acquisition-pivot-2026-08-10]] の「決定3」で、依頼者の希望「同じ日に撮った空を別々の日の写真であるかのように見せかけて動画量産」に対し、エージェント側が3点の懸念（TikTok の AIGC 表示義務違反 → ブランドアカウント凍結、Locket の着火要因が実在の人間関係だったという調査結果との矛盾、景表法/FTC の優良誤認）を提起したまま**未決着**。

今回生成した2枚は、いずれも **「アプリの実績・ユーザー数・連続記録を偽って提示するもの」ではない**（ブランドイメージ用のコンセプトカット）ため、この論点には抵触しない。動画化フェーズで「これは実際の利用者の365日の記録です」といった提示をする場合に、上記の懸念が再び効いてくる。
