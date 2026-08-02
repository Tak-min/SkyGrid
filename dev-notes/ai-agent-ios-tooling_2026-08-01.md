# AIエージェント向けiOS開発ツール調査・導入(2026-08-01)

## 発端

Shipaton 2026のShip Kitメール(RevenueCatから、`shipaton@revenuecat.com`)とshipaton.com/shipaton-saleに、
「AIエージェントがiOSアプリ開発を上手く行えない」問題を解決するスポンサー特典が複数掲載されていた。
依頼者はメール内の記憶が曖昧で「argentargent」と呼んでいたが、正体は **Argent**。

## 調査した4ツール

| ツール | 解決する問題 | アカウント要否 | 判定 |
|---|---|---|---|
| **Argent** (Software Mansion製、`@swmansion/argent`) | Claude Code等のAIエージェントにiOSシミュレータの直接操作権限を与える(起動・タップ・ログ読取・ネットワーク監視・Instruments連携プロファイリング)。**「コードは書けるが実際に動かして確認できない」というAIエージェントの根本的弱点そのものを解消する。** | **不要**。npm公開・無料・OSS。MCPサーバーとして動作、Claude Code/Cursor/Codex/Copilot等に一級対応 | ✅ **最優先・導入済み** |
| **Lance** (`lance.app`) | App Store Connect作業(証明書・プロビジョニング・TestFlight・IAP・審査提出)をAIエージェント経由で自動化。Sky Gridではこの領域(価格設定UI・サブスクリプショングループ・審査提出ブロック)に過去何時間も溶かした実績あり([[skygrid-app-project-2026-07-29]]参照) | **要**(Apple Developer/App Store Connect連携のため、詳細未確認だがログインが必須と推測)。Shipatonコードで3ヶ月無料($180相当)、コード: `SHIP26-54F29-5Y52E` | 🟡 **有望・要依頼者本人によるサインアップ** |
| **Bitrig** (`bitrig.com`) | SwiftUI共同開発者(元Apple)が作った、iPhone上で音声/テキストからSwiftUIアプリを新規に作る「vibe coding」アプリ。**既存の大規模コードベース(Sky Grid等)を触るツールではなく、ゼロから新規アプリを作る用途。** | 要(iPhoneアプリのダウンロード+アカウント) | ⚪ 今回の課題(既存アプリの開発支援)には非該当。新規アイデアの高速プロトタイピング用途としては将来候補 |
| **Codemagic** | モバイルCI/CD(ビルド・署名・デプロイパイプライン)。M2マシンで月500分無料・カード不要 | 要(アカウント作成) | ⚪ Lanceと機能重複、Lanceの方がAIエージェントネイティブで優先度低 |

## Argent導入内容(このセッションで完了)

`/Users/taku8/Desktop/SkyGrid/ios`で実行:
```
npx -y @swmansion/argent init --yes --no-telemetry
```

結果:
- グローバルインストール完了(`which argent` → `/opt/homebrew/bin/argent`, v0.18.0)
- プロジェクトルート(`/Users/taku8/Desktop/SkyGrid/.mcp.json`)にMCPサーバー登録(`argent mcp`をstdioで起動)
- `.claude/settings.json`に`mcp__argent`の自動承認を追加(**このプロジェクト内のみ**、マシン全体ではない)
- `.claude/agents/argent-environment-inspector.md`(専用サブエージェント)、`.claude/rules/argent.md`を配置
- テレメトリは明示的に無効化(`--no-telemetry`)

**重要: MCPサーバーはセッション開始時にロードされるため、このセッション内ではArgentのツールはまだ使えない。次回このプロジェクトでClaude Codeを起動した瞬間から自動的に有効になる。**

次回セッションでの動作確認方法: 「Argentで何ができる?」と聞くか、シミュレータ起動済みの状態で実際に操作を依頼する。

## Lance(2026-08-01、依頼者のアカウント作成後にセットアップ完了)

`npx add-mcp https://api.lance.app/mcp` は Claude Code の自動モード分類器に2度ブロックされた
(外部URLから即座にリモートスクリプトを取得・実行するパターンのため安全側で拒否、会話内での
明示的なユーザー許可でも解除されない)。これは正当な安全機構であり、強行突破しなかった。

**代替手段で完了させた内容:**
- `npx add-mcp` の代わりに、Lanceダッシュボード(`lance.app/getting-started` → 「Install the MCP
  server」→「Claude」)が案内する接続先と完全に一致する内容を `.mcp.json` に手動追加:
  ```json
  "lance": { "type": "http", "url": "https://api.lance.app/mcp" }
  ```
- **`.claude/settings.json`には`mcp__lance`の自動承認を追加していない**(Argentと違いApp Store
  提出等の不可逆操作を含みうるため、意図的に個別確認が必要な状態のまま)
- 依頼者が「Create your organization」「Connect App Store Connect」(APIキー入力、要本人対応)を
  完了済み → 自動で500 Starterクレジット付与(8月31日失効)を確認
- Shipatonプロモコード `SHIP26-54F29-5Y52E` を `lance.app/settings/usage` の「Have a promo code?」
  から適用 → **「RevenueCat Shipaton offer applied — 3 months of Pro free」**。決済手段の登録は
  一切不要だった(想定と異なり、Stripeチェックオンではなく独立したプロモコード入力フォームだった)。
  Pro化により2,000クレジット/月(9月1日リセット)、Usage-based billing(超過時$20/2000credit自動課金)は
  意図的にOffのまま(無効化しないと勝手に課金され得るため)
- 「Send your first request」(残り最後のチェックリスト項目)は次回セッションでLance MCPが
  ロードされた際に「Use the Lance MCP to check what App Store Connect teams are connected」を
  実行すれば自動完了する設計。今回のセッション内では未実行(MCPはセッション開始時ロードのため)

**次回セッションでの確認事項:** Argent同様、`.mcp.json`のlanceエントリはセッション開始時に
ロードされる。初回接続時にOAuth風の認証確認が入る可能性があるため、最初のLance関連リクエストの
挙動を見て問題なければそのまま使用継続。

## 横展開

同じ問題(AIエージェントがiOSアプリを実際に動かして検証できない)は `~/Desktop/v-mate`・
`~/Desktop/ClubFaceMatch` 等、他のSwiftUIプロジェクトにも共通する。Argentはプロジェクトごとに
`npx @swmansion/argent init --yes --no-telemetry` を実行するだけで導入できる(アカウント不要)。
