# 広報用モザイクを実写の空から作る — 経緯・失敗・再現手順

日付: 2026-08-11
成果物: `branding/promo/`（スクリプト一式）、`branding/promo/out/`（書き出し）、`branding/promo/ATTRIBUTION.md`

---

## 一番大事な失敗: 平均色はグリッドの「フォールバック」であって製品ではない

最初、実写の空から `SkyColorExtractor` の平均色を算出し、**単色タイルのモザイク**を作った。
依頼者に却下された。理由は正しく、コードを読めば分かることだった。

- `Grid/SkyGridView.swift` の `ArchivePhotoTile` は `Image(uiImage: thumbnail)` を描画する。**セルは写真そのもの。**
- `SkyGridExportView` も `thumbnails: photos` を渡し、`GridLayoutMath.aspectFillRect` で**画像をセルにアスペクトフィルして描く**。
- 単色は `SGExport.cellPostedNoThumb`（サムネイル未取得時）と `cellEmpty`（未投稿）**だけ**に使われる。

**症状:** 広報素材が「色の四角形の集合」になり、製品の見た目と一致しない。
**原因:** `SkyColorExtractor` の存在から「グリッド＝平均色の集合」と早合点し、描画側（`ArchivePhotoTile`）を確認しなかった。
**対策:** モデル層のアルゴリズムを見たら、**必ず View 側でそれが何に使われているか**を確認する。抽出した値が表示に使われているとは限らない。

## 副産物として得られた検証（捨てなくてよい）

平均色の再現実装自体は正しく、**`SkyColorExtractorTests.swift` に記録されていた Pillow クロスチェック値4件と 4/4 完全一致**した（`branding/promo/sky_color.py`）。

- 最初は1階調ずれた。原因は**オラクル側が切り捨て（truncate）で、こちらが四捨五入していた**こと。
  `String(format:"%02X", pixel[0])` に渡る `UInt8` は `CIAreaAverage` の bitmap render 由来で切り捨てになる。
- この関数はタイル描画には使っていないが、**「その写真は本当に空か」を判定する安価な指標**として残してある。

## 実写の空の集め方（Commons）

`fetch_skies.py`。API キー不要、ライセンスが機械可読なので出典を報告できる。

### Gotcha

1. **`list=categorymembers` はほぼ空を返す。** Commons のカテゴリは実体を下位カテゴリに持つため、`Category:Blue skies` 直下にファイルは1件しかなかった。**`list=search` + `srnamespace=6`（Fileネームスペース）を使う。**
2. **1検索ページは50件上限。** `sroffset` でページングしないと数が全く足りない。
3. **`https://www.genflowai.io/ja/pricing` と同様、雑な連打は 429 を返す。**
   `HTTP Error 429: Your bot is making too many requests` を実際に踏んだ。sleep を 0.15→0.4 秒に緩め、**マニフェストを追記式にして再ダウンロードを避ける**ようにした。
4. ライセンスは `extmetadata.LicenseShortName` で判定。**`-nc` / `-nd` を明示的に除外**（商用不可・改変不可のため広報素材に使えない）。

## タイル選別 — ここが手間の本体

Commons の検索結果をそのまま並べると、**パラシュート・塔・トウモロコシ畑・白黒写真・地平線の入った風景・絵画**が混ざる。
平均色にしていた頃はこれが全部隠れていたが、写真そのものをタイルにすると一目で「スマホで空を撮った1枚」に見えなくなる。

`render_grid.py` の `tile_is_clean_sky()` で、**実際に表示される正方形クロップに対して**判定する:

| 条件 | 目的 | 実測での却下数（241枚中） |
|---|---|---:|
| チャンネル差 < 6 | 白黒写真 | 13 |
| 空ピクセル率 < 0.93 | 地面・建物・木 | 146 |
| 上端と下端の輝度差 > 45 | 地平線 | 9 |
| 硬いエッジ密度 > 0.02 | 人工物・枝 | 7 |
| タイトルに painting/museum 等 | 絵画・図版 | 5 |

**検証したこと:** クロップ位置（`ImageOps.fit` の `centering` y=0.25/0.15/0.08/0.0）を振っても通過数は 61/61/60/60 とほぼ不変。
→ **却下されている146枚は「クロップの失敗」ではなく本当に空以外が写っている。** 閾値を下げるのは品質を落とすだけなので、代わりに検索語を増やして母数を稼ぐ方針にした。

## レイアウト（すべて実コードから取得、推測なし）

| 用途 | 値 | 出所 |
|---|---|---|
| 年グリッド | 31列 × 12行、セル30px、間隔2px | `SkyGridExportView` |
| 月アーカイブ | 7列、隙間ゼロ、角丸なし、1日目が左上 | `GridLayoutMath.sequentialDates` / `SkyGridView` |
| エクスポート地色 | `#0B0E14` | `SGExport.ground` |
| 未投稿セル | white @ 0.09 | `SGExport.cellEmpty` |
| アプリ内背景 | `#FAF7F2` | `SGT.background` |

**9:16 のGotcha:** 最初、年グリッド（990×382 の横長）を 1080×1920 に置いた。**細い帯が暗闇に浮くだけの絵**になった。
縦フレームは縦に伸びる形でしか埋まらないので、**7列アーカイブ形をフルブリードで**使う。
セル = ceil(1080/7) = 155px、行 = ceil(1920/155) = 13 → **91枚必要**。

## 2巡目で分かったこと — 検索語が混入源だった

枚数を稼ぐために検索語を12個追加して466枚まで増やしたら、**手書き文書・設計図・航空機の3Dモデル・建物・紙テクスチャ**が大量に通過した。
`bright_cloud = (spread < 34) & (brightness > 120)` が「淡くて彩度が低い面」を全部雲とみなすため、紙も壁も通る。

追加した2条件:

1. **寒色/中性の割合 ≥ 0.60**（`b >= r - 8`）。曇天の灰色でも青は赤以上に残るが、紙・漆喰・鉛筆画は暖色。
   ただし本物の朝焼けを落とさないよう、**彩度の高い暖色（`spread > 50`）が25%以上ある場合は通す**。
2. **エッジ検出を64px→160pxで実施**。64pxに落とすと手書き文字や細線が霞と区別できなくなる。

**さらに効いたのは検索語単位の除外。** 通過タイルを `manifest` の `category` で集計したところ、
気象用語（stratocumulus / cumulus / altocumulus / cirrus 等）は実写が返るのに対し、
`contrails blue sky`（航空機3Dモデル）・`sky texture background`（紙・布）・`clouds from below`（屋根・室内）
がゴミの供給源だと**データで特定できた**。→ `NOISY_SOURCE_TERMS` で除外。

## 最後は手作業（自動化を諦めた箇所）

**灰色の建物と灰色の雲、砂浜と霞は、色統計では原理的に分離できない。**
番号付きコンタクトシート（`out/contact-sheet.png`）を出力して目視で18枚を除外し、
`EXCLUDED_FILES` にファイル名で記録した。再取得したらシートを作り直してこのリストを更新する。

## 現状

- 466枚取得 → タイトル除外134 → 画素判定で278却下 → 手動18除外 → **実写54枚が採用**。
- 9:16 は 7×7 = 49タイル（セル155px）。**フルブリードにはならないが、上下の余白は見出しとCTAを置く場所**なので実害はない（文字は焼き込まない方針のため）。
- テキストは一切焼き込んでいない（AI/描画の文字は崩れるうえ、使い回しが効かなくなるため）。CapCut 等で載せる前提。
- ハンドル・実在ユーザーの記録・「N mornings」の断定的な提示はしていない。

## 最終結果（773枚取得後）

773枚取得 → タイトル除外137 → 画素判定で545却下 → **実写91枚が採用**、目視除外は0件（気象用語のみに絞った2回目の取得はゴミがほぼ無かった）。
9:16 モザイク（`mosaic-9x16.png`）は 7×13 = **91タイルでちょうど端数なくフルブリード**。
シェアカード（`year-share-card.png`）はApp Store公開日 **2026-08-06 起点**で埋めている（1月1日からだと誰も持ち得ない年を描くことになるため、`FIRST_POSSIBLE = (8, 6)`）。セル解像度は実機の3倍（`CARD_SCALE`）にして、静止画として見た時に写真だと分かるようにした。

## 他セッションとの統合（2026-08-11 午後）

別のClaude Codeセッションが同じ `branding/promo/` 配下で並行して `video-v1/`（11秒の宣伝動画）を作っていたことが `ps aux` で判明。フック画面が `branding/mockups/backgrounds/overview-year-v1.png` という**イラスト**（`CONCEPT VISUAL` と自己申告）で、依頼者の「実際の空の写真でやり直せ」という指示に反する状態だった。

依頼者確認の上で統合。`render_grid.py` に**動画背景専用のフルブリード版** `render_hook_background()` を追加した:
- `mosaic-9x16.png`（文字を置く余白付き）とは別に、`hook-background-9x16.png` は写真枚数から**列数を総当たりで探索し、余白ゼロかつ同じ写真の重複なしで1080×1920を埋める**構成。
- `video-v1/make_assets.py` は `HOOK_BACKGROUNDS` のタプルでフォールバック方式にした（モザイク未生成時は元のイラストに自動で戻る）。
- 注記文言も「実写だが特定個人の記録ではない」ことを示すよう `CONCEPT VISUAL` → `REAL SKY PHOTOS · SAMPLE GRID` に変更。

## git 整理

- `branding/promo/skies/`（実写ソース、100MB超）、`video-v1/build/`（中間PNG）、`__pycache__`、`out/contact-sheet.png`（目視選別用の作業ファイル）を `.gitignore` に追加。いずれも `fetch_skies.py` / `render_grid.py` / `make_assets.py` から再生成可能なため、リポジトリには追跡しない。
- `skies_manifest.json`（ライセンス情報込み）と `ATTRIBUTION.md` は追跡する — これがあれば再取得なしで出典を再現できる。

## 実行手順

```bash
cd ~/Desktop/SkyGrid/branding/promo
python3 sky_color.py        # アプリとの色一致を検証（4/4 で exit 0）
python3 fetch_skies.py      # 追記式。既取得分は再取得しない
python3 render_grid.py      # out/ に4点書き出し（mosaic-9x16 / hook-background-9x16 / month-archive / year-share-card）
python3 write_attribution.py # ATTRIBUTION.md 再生成（CC BY 系のクレジット義務）
python3 contact_sheet.py    # 目視選別用の番号付きシート。悪い番号を渡すとEXCLUDED_FILES用の行を出力
cd video-v1 && ./render.sh  # 宣伝動画を再生成
```

関連: [[genflowai-credit-costs-and-ui-gotchas-2026-08-11]]（先にGenFlowで試して無料枠が尽きた経緯）、
`genflow-promo-asset-generation_2026-08-11.md`（同日、AI生成側のログ）
