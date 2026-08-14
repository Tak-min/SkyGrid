# ASC 1.0.4(build 7)提出完了(2026-08-14) — 実機ワイヤレスデプロイと並行実施

依頼から「実機にデプロイ(ワイヤレス)」+「通常通り審査提出」の2件を並行して実施。競合を
避けるため、審査提出側は`git worktree`で隔離した別ディレクトリ(`/tmp/skygrid-1.0.4-submit`)
で作業した(完了後に`git worktree remove`で削除済み)。

## 結果

- **実機デプロイ**: 依頼者本人の端末(「俺のGALAXY Pro Max」— 名前から友人の端末と誤認した後、
  依頼者本人から訂正あり。実体はiPhone 15 Pro、devicectl識別子
  `FF649B7E-F19F-5E73-9AA2-797C297B8916`)へワイヤレス経由でDebugビルドをインストール・起動
  成功。友人の端末は今回接続確認できず、対応は見送り(友人側の接続設定待ち)。
- **審査提出**: build 7(1.0.4)が`WAITING_FOR_REVIEW`で審査キューに入った
  (reviewSubmission `2f2ffcc3-6bc7-4ab8-bddd-af7f5f8a37e5`、
  `submittedDate: 2026-08-14T07:42:18.419Z`)。`releaseType: MANUAL`(承認後の公開は別途承認要)。

## 今回発生した新規のGotcha(2件、いずれも過去記録に無い初出)

### 1. ASC APIキー経由の自動プロビジョニングは、実機Debugビルド用のDevelopment証明書を新規発行できない

`xcodebuild build`(実機向けDebug、archiveではない)で`-allowProvisioningUpdates`単体でも、
`-authenticationKeyID/-authenticationKeyIssuerID/-authenticationKeyPath`(ASC APIキー)を
明示追加しても、**ローカルkeychainに存在する無関係な個人Apple ID(`32ZRVW6HP8`)のDevelopment
証明書がそのまま使われ続けた**(`DerivedData`の完全削除・クリーンビルドでも再現)。
`codesign -dvvv`で確認すると`Authority`は個人チームの証明書のまま、`TeamIdentifier`だけが
正しい`NVZB82UK53`という食い違った状態でビルドが成功する。

**この状態のまま`xcrun devicectl device install app`を実行したところ、実際にはエラーなく
インストール・起動に成功した。** 表示上の証明書ミスマッチが実害を伴わなかった実例
(Team Provisioning Profileの`application-identifier`が正しく`NVZB82UK53.com.takmin.skygrid`
になっていたことが効いたと推測されるが、根本原因は未特定)。**今後同種の状況に遭遇した場合、
理論上の食い違いだけで諦めず、実際に`devicectl device install app`を試すこと** —
署名ログの理論的な不整合と、実機が実際に受理するかどうかは別問題だと判明した。

なお、Archive→Export(App Store配布用)の方は既知の通り正しく`NVZB82UK53`のDistribution
証明書で署名された(`ExportOptions.plist`の`teamID`明示指定が効いている、
[[skygrid-asc-api-submission-2026-08-08]]の既知パターン通り)。**Debug実機ビルドと
Archive/Exportで署名解決の挙動が異なる**、という新しい知見。

### 2. 前バージョンが`WAITING_FOR_REVIEW`のままだと新規`appStoreVersions`を作成できない

1.0.3(build 6)が審査待ちのまま1.0.4を作ろうとすると
`HTTP 409 ENTITY_ERROR.RELATIONSHIP.INVALID: "You cannot create a new version of the App
in the current state."`で拒否される。Appleは「審査未完了のバージョンが1つ存在する間は
次のバージョンを新規作成できない」という制約を持つ(READY_FOR_SALE/公開済みの旧バージョンは
無関係、あくまで審査パイプライン中の1件のみが対象)。

**解決手順(今回確立):**
1. `PATCH /reviewSubmissions/{id}` に`{"attributes": {"canceled": true}}` →
   `state`が`CANCELING`→`COMPLETE`に遷移(15秒間隔のポーリングで確認、今回は2回目のpollで
   `COMPLETE`)。
2. 該当の`appStoreVersions`は`DEVELOPER_REJECTED`状態になるが、**これもまだバージョン枠を
   占有しており、新規`POST /appStoreVersions`は依然として同じ409エラーで拒否される**
   (キャンセル後も再度試したが同一エラー、想定外の挙動だった)。
3. 正しい対処は「新規作成」ではなく**既存の`DEVELOPER_REJECTED`バージョンを編集して
   再利用**すること: `PATCH /appStoreVersions/{id}`で`versionString`を新バージョン番号に
   書き換えると、`appStoreState`が自動的に`PREPARE_FOR_SUBMISSION`(編集可能)に戻る。
   続けて`releaseType`(勝手に`AFTER_APPROVAL`に変わっていたので`MANUAL`に戻す必要あり)と
   `relationships.build`(新しいビルド番号に差し替え)を同じPATCHで更新。
4. 以降は通常の提出手順(`appStoreVersionLocalizations`のWhat's New更新→
   `reviewSubmissions`新規作成→`reviewSubmissionItems`で紐付け→`submitted: true`)。

**教訓: 「審査待ちバージョンを取り下げて新バージョンに差し替える」場合、`appStoreVersions`は
新規POSTせず、キャンセル後に残る既存レコードをPATCHで作り変える。** 新規POSTを繰り返しても
同じ409で失敗し続けるため、無駄なリトライをしないこと。

## 実施した手順(概要、詳細な確立済み手順は[[skygrid-asc-api-submission-2026-08-08]]参照)

1. `project.yml`のバージョンを1.0.3(build 6)→1.0.4(build 7)に変更、`xcodegen generate`。
2. `xcodebuild archive` → `-exportArchive` → `codesign -dvvv`で実地検証
   (`Authority=Apple Distribution: Takumi Eto (NVZB82UK53)`確認済み)。
3. `altool --validate-app` → `altool --upload-app`(Delivery UUID `d1f82537-...`)。
4. build 7が`VALID`になるまでポーリング(約2〜3分)。
5. 上記Gotcha #2の手順で1.0.3の審査提出をキャンセル→既存バージョンレコードを1.0.4に
   作り変え→build 7を紐付け→What's New更新→新規審査提出。

## 未対応・引き継ぎ

- 承認後のリリース操作は依頼者の承認待ち(push/deployと同じ扱い)。
- 友人の端末への実機デプロイは未実施(接続未確認、友人側の対応待ち)。
- 実機2台でのバディフローE2E検証はまだ実施できていない(友人端末が繋がり次第)。
