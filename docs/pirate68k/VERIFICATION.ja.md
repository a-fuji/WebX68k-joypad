# 海賊王ゲーム 開発・検証記録

## 2026-10-24: 初版

`codex/x68k-original-game`で、独立した68000ソースから開発・配布XDFを生成し、WebX68k上のHuman68kでアセンブル・リンク・実行を確認した。MaidLandは技術文書の参照だけに使い、ソース・素材・音源をコピーしていない。生成イメージとツールのバイナリは`_local/pirate68k/`に置き、Gitへ追加していない。

作業開始時はクリーンなmaster、HEAD `1a9cb9ea4a1deb7c659a3eb9df7a0b7554b9513e`で、origin/masterより2コミット遅れていた。origin/masterの`81646ee`を基点に専用ブランチを作成した。既存master、WebX68kの`src/`、MCPサーバー、既存テストは変更していない。

検証環境はmacOS arm64、隔離Chrome 155.0.8059.85、WebX68kの既定16MHz/2MB構成。Node.js 26.0.0、Python 3.12.14、Pillow 12.3.0を使用した。ツールと入力の正確なバイト列は[入力一覧](evidence/source-inputs.json)、[外部XDF](evidence/external-inputs.json)、[HDS](evidence/hds-input.json)、[タイトル変換](evidence/TITLE.devtools.json)で識別する。

## 結果

| 確認項目 | 結果・証拠 |
| --- | --- |
| `npm test` | 35ファイル・558テスト成功。[実行出力](evidence/npm-test.txt) |
| `npm run build` | TypeScript/Vite成功。[実行出力](evidence/npm-build.txt) |
| XDF処理 | 8テスト成功。多クラスタ、サブディレクトリ、FAT複製、容量不足、循環、同一性。[出力](evidence/xdf-tests.txt) |
| MCPサーバー起動 | stdio初期化・18ツール取得。[ハンドシェイク](evidence/mcp-handshake.json)。単一バンドルのスモークテストも成功 |
| WebX68k接続 | MCP `status`のrunning=true、FDD0/FDD1装填。[接続記録](evidence/connected.json) |
| Human68k起動 | 実ファイル`HUMAN.SYS`内と起動画面の両方にversion 3.02。[外部入力](evidence/external-inputs.json)、[画面](evidence/human68k.png) |
| 開発用XDF一覧 | BIN/SRC/OUTとビルドバッチを確認。[MCP一覧](evidence/development-listing.json)、[全ファイル・容量・ハッシュ](evidence/dev.manifest.json) |
| 独自ソースのビルド | HAS060とHLKをHuman68k上で実行、BUILD OK。[ビルド画面](evidence/guest-build.png)、[テキスト](evidence/guest-build.json) |
| `.X`生成 | 135,114バイト。text=2,604、data=132,396、bss=272、再配置=50バイト。[ヘッダー](evidence/executable-header.json) |
| ゲーム起動 | 256×256の提供画像タイトル。[タイトル](evidence/title.png) |
| 入力 | MCPで開始・右移動・ショット・ボンバー、ブラウザキーで斜めを含む8方向。[状態の前後比較](evidence/game-checks.json) |
| ボンバー | 敵3体を消去、300点、残数2→1。[画面](evidence/bomb.png)。HUDの文字ピクセルを状態と照合して一致 |
| ボス・次ステージ | 第1ボス16HP、第2ボス24HPを実際のキー操作で撃破。[攻略記録](evidence/stages.json)、[第1ボス](evidence/boss-stage-1.png)、[第2ボス](evidence/boss-stage-2.png) |
| ALL CLEAR | 第2ステージ、3,200点、残機2、ボンバー0。[画面](evidence/all-clear.png)、[状態](evidence/all-clear-state.json)、[HUD照合](evidence/hud-clear.txt) |
| ゲームオーバー・再開 | 無操作で残機0、Zで残機3・スコア0へ再開。[ゲームオーバー](evidence/game-over.png)、[状態比較](evidence/game-checks.json) |
| 配布用XDF起動 | 開発ツール無しのディスクからGOで起動、プレイ開始。[記録](evidence/release-checks.json)、[画面](evidence/release-title.png) |
| 終了処理 | ESCで768×512のDOSへ復帰し、ECHOコマンド実行可能。[終了画面](evidence/release-exit.png) |
| 再現性 | ゲストで2回ビルドした`.X`がバイト一致。開発・配布XDFの再生成もバイト一致。[再ビルド](evidence/rebuild.json)、[同一性記録](evidence/determinism.json) |

`.X`のSHA-256は`8d1c1a09d2d8ee7c854601781fe3fa006ea78da891e5b1a573ecd0a5a3346a9b`。

配布用XDFは1,261,568バイト、ファイル合計135,354バイト、クラスタ割当137,216バイト、空き1,113,088バイト。収録ファイルは`PIRATE.X`、`GO.BAT`、`README.TXT`だけで、個別ハッシュは[マニフェスト](evidence/release.manifest.json)を参照する。ディスク全体のSHA-256は次のとおり。

```text
470dfb695a935b1621d7a08bcfccb5301d7380b6fa1d6dc67f03a5d3a604be9b  release.xdf
```

## 開発中の修正

- HAS060の画像埋め込み命令は`.insert`を使用。未対応の命令表記を修正し、再アセンブルで確認した。
- 埋め込み画像の前を`.even`で揃え、68000の奇数アドレス参照によるアドレスエラーを解消した。
- 表示ページを直接塗り直す際のちらつきを、16色GVRAMの非表示ページへの描画とVPAGE切替で解消した。
- IOCSでキーの押下状態だけを読むとDOSキーバッファに操作文字が残ったため、フレームごと・終了時にバッファを消費するようにした。
- HUDのボンバー座標に符号付き8bitのMOVEQを使っていた箇所をMOVE.Wへ変更。スコアは桁ごとに描画する方式へ変更した。300点と3,200点の画面をフォントの実ピクセルで照合した。
- 更新中にGAME OVER/ALL CLEARが決まった後の追加当たり判定を止め、終端状態が同フレームの後続処理で変わらないようにした。
- タイトル描画完了を状態に反映し、撮影がモード切替直後の黒画面を拾う問題を修正した。ゲームのモード切替後にもDOSカーソルを非表示にする。
- 自動検証は画面初期化の完了を待つようにした。再実行前の古いメモリ状態を拾わないよう、正式検証では新しい隔離ブラウザで一巡する。
- 最初の自動プレイヤーはボスの正面弾を受けて敗北した。ボスの進行方向側へ移動し、最後のボンバーを温存する通常操作へ変更して2ステージ通過を確認した。ゲームの残機・敵HPは検証中に緩和していない。

WebX68k本体の機能破壊は認めていない。上記のアドレスエラーは新規ゲームの初期版で発生したもので、ゲストをリセットし開発XDFを再装填して復旧した。外部原本のXDF/HDSは読み取り専用で扱った。

## 既知の制限・未検証

- 配布用XDFはデータディスク。FDD0に別途Human68kを装填して起動し、FDD1のB:でGOを実行する。単体の自動ブートは提供しない。
- キーボード経路で全機能を検証した。JOYGETによる2ボタン入力は実装済みだが、このゲームでの物理パッドE2Eと実機X68000/X68000Zでの動作は未検証。
- FM曲のステップ進行とゲーム終了処理は確認した。録音による音声出力検証・聴感確認は未実施。
- タイトルは添付画像からの変換。自作キャラクターは16×16の簡単な絵で、アニメの公式素材を取り込んでいない。公開配布の権利条件は未確認であり、生成XDFやツールをGit・Releaseへ公開していない。
- DevToolsのコードは外部パスから利用する。画像の再生成には元画像、日本語フォント、Pillow、記録したDevTools版が必要。元画像・フォントは同梱しない。
- HDS読取器は今回確認した最初のHuman68k FAT16パーティションとジオメトリに限定する。WebX68kへのHDS直接対応は行っていない。
- MCPの大容量ファイル書き込み問題は未修正。今回の経路はホスト側で作ったXDF全体を装填し、ゲストの生成物を読み戻す方式。
- 処理が遅い環境ではゲーム更新が遅くなる。難易度調整、敵の種類・演出の拡充、長時間の耐久試験は初版の範囲外。

再現の操作手順は[ランブック](../X68K_ORIGINAL_GAME.ja.md)を参照する。

## 2026-10-24: ユーザー確認と次版の相談

初版コミット`76634771cfef5a302c663c326a418cd7bbdf1bb7`のリリースXDFをユーザーが確認し、1ドライブでは起動できないこと、プレイヤーと敵の表示が小さく見えることを報告した。音の実装方式とキャラクターのドットサイズについて、ソースを確認して次の内容を回答した。

- リリースXDFにはHuman68kが無く、Human68k起動ディスクと組み合わせる2ドライブ構成である。1枚で起動して遊べる配布形態は未実装。単体起動版には、起動可能なHuman68k環境とゲーム自動実行の構成が必要になる。
- 音は動作確認用の単音BGMだけ。ショット・命中・撃破・ボンバーの効果音、クリアのジングルは未実装。
- BGMは`SOUND.INC`の16音フレーズを、IOCS `_OPMSET`でFMチャンネル7（0始まり、8番目）へ送る。ゲーム更新8回ごとに次の音へ進み、目標20更新/秒なら約0.4秒間隔・約6.4秒ループ。処理が遅くなるとテンポも遅くなる。Z-MUSIC、ZMD、ADPCM、独立した音楽タイマーは使っていない。ユーザーの「EGM」は会話の文脈からBGMと解釈して回答した。

初版のキャラクター寸法は次のとおり。描画はハードウェアスプライト登録ではなく、`PIRATE.S`の`sprite` / `bosssprite`からGVRAMへ描く方式である。

| 対象 | 元データ | 画面上の描画枠 | 透明余白を除く絵の実寸 |
| --- | --- | --- | --- |
| プレイヤー | 16×16 | 16×16 | 13×16 |
| ザコ敵 | 16×16 | 16×16 | 13×16 |
| ゾロ・サンジ風の援護 | 16×16 | 16×16 | 13×16 |
| ビッグ・マム風／カイドウ風のボス | 16×16 | 48×32 | 36×32 |

ボスは元データを横3倍・縦2倍に拡大している。プレイヤーとザコの高さは画面の1/16であり、小さく見えるという指摘に対応する。改善案として24×24程度の新規ドット絵と、当たり判定・配置間隔の調整を提示したが、24×24への変更はユーザーが決定した仕様ではない。

ユーザーはこの後、アストラへ画像制作とZ-MUSICの組み込みを含むパワーアップ版を依頼する予定とした。この時点の依頼は記録の保存であり、次版の実装・画像生成・モデル変更・別タスクへの送信は行っていない。引き継ぎの入口は[次版作業の引き継ぎ](NEXT_VERSION_HANDOFF.ja.md)にまとめた。


## 2026-10-25: 背景・XSPスプライト版とユーザー通しプレイ

初版から描画を更新し、港・要塞の背景、後ろ姿のプレイヤー、ザコ、ボス、ゾロ・サンジ風の援護を組み込んだ。通常キャラ32×32、ボス96×96、援護64×64の枠を使い、キャラクターはXSPのハードウェアスプライトで表示する。画像・ゲーム仕様は[設計](DESIGN.ja.md)、素材の生成経緯は[素材記録](../../games/pirate68k/assets/README.md)を参照する。XSP2lib.oは外部Dev68K.XDFからビルド時に読み取り、外部ディスク原本は変更していない。

### 確認した結果

| 確認項目 | 結果・証拠 |
| --- | --- |
| ホストテスト | 2026-10-24の`npm test`は35ファイル・558件成功、`npm run build`も成功。[テスト](evidence/v2/npm-test.txt)、[ビルド](evidence/v2/npm-build.txt) |
| 画像・XDF処理 | Pythonの13テスト成功。[出力](evidence/v2/python-tests.txt) |
| Human68k・MCP | Human68k 3.02の起動とMCP接続を確認。[起動](evidence/v2/boot.json)、[画面](evidence/v2/human68k.png)、[接続](evidence/v2/connected.json) |
| 8MBゲストビルド | 16MHz・8MB設定でHAS060とHLKによるビルド成功。セッションログの最終成功時刻は2026-10-25 01:13:34 JST。[出力](evidence/v2/guest-build.json)、[画面](evidence/v2/guest-build.png) |
| 実行ファイル | `PIRATE.X`は297,948バイト。配布XDF内のファイルとホストの生成物が一致。[生成物情報](evidence/v2/executable.json)、[ハッシュ](evidence/v2/release.manifest.json) |
| 開発用XDF | HAS060、HLK、XSP2LIB.O、ソース、変換済み画像を収録。[一覧](evidence/v2/development-listing.json)、[マニフェスト](evidence/v2/dev.manifest.json) |
| 素材の組み込み | 背景2枚・パレット・スプライトのバイト列が`.X`に含まれることを読取監査で確認。[寸法・素材ハッシュ](evidence/v2/graphics.json) |
| 2MBでの実行 | タイトル、ゲーム開始、MCPによる右移動を既存ログで確認。港・キャラクター・HUDの[実行画面](evidence/v2/runtime-2mb.png)と[タイトル](evidence/v2/release-title.png)を保存 |
| 通しプレイ | ユーザーが提示した配布XDFを実際に遊び、ステージ2クリアまで確認したと報告。[ユーザー確認記録](evidence/v2/user-playtest.json)。エージェントの自動通し検証成功とは区別する |

配布XDFは1,261,568バイト、収録ファイルは`PIRATE.X`、`GO.BAT`、`README.TXT`のみ。空き950,272バイト。ディスク全体のSHA-256は次のとおりで、監査時に実ファイルと[マニフェスト](evidence/v2/release.manifest.json)の一致を確認した。

```text
b8f70c853d6090c15fdc8391a7e06bf019e467ad79efd37b1b73859bd3558887  release.xdf
```

生成物は`_local/pirate68k/`に保持し、XDF本体と外部ツールをGitへ追加していない。初版開発XDFは`dev-repeat.xdf`に残り、そのハッシュは初版の`evidence/dev.manifest.json`と一致する。初版配布XDFと実行ファイルは`baseline/`に保存されている。これらの既存成果物は変更しない。

### 後続に残す項目

- Z-MUSIC・ZPD効果音は未統合。音は従来の簡易FMフレーズ。
- 配布ディスクはHuman68k起動ディスクと組み合わせる2ドライブ構成。単体ブートは後続対応。
- 新版の再ビルド一致、物理パッド、実機X68000/X68000Zは未確認。
- 初版の`evidence/rebuild.json`、`stages.json`などを新版の成功証拠として流用しない。新版の通しプレイ確認元は上記ユーザー報告。


## 2026-10-25: Z-MUSIC BGM・FM効果音・ZPD効果音

ユーザーの指定により、MaidLandの音声データを暫定流用するZ-MUSIC版を実装した。正常な既存XDFは保持し、開発用は`_local/pirate68k/audio-dev.xdf`、配布用は`_local/pirate68k/release-audio.xdf`へ生成した。音声の抽出元・差し替え契約・実行手順は[音声手順](AUDIO.ja.md)を参照する。WebX68k本体とMCP本体は変更していない。

### 実装と場面別の検証

従来の直接OPM操作を撤去し、BGMは常駐ドライバの割込みで再生する。ZMDとFM効果音は起動時に外部ファイルから先読みする。ZPDは起動バッチで登録し、終了後にドライバを解除する。使用したドライバの常駐識別バージョンは`$2003`。下表は音楽版に対するエージェントの検証であり、前節のユーザーによる背景・XSP版のプレイ報告とは区別する。

| 確認項目 | 結果・証拠 |
| --- | --- |
| ホスト検査 | `npm test`35ファイル・558件成功、`npm run build`成功、Python17テスト成功。[テスト](evidence/audio/npm-test.txt)、[ビルド](evidence/audio/npm-build.txt)、[Python](evidence/audio/python-tests.txt) |
| Human68k・8MBビルド | MCPを通じて起動・HAS060/HLK実行・生成物回収を確認。[起動](evidence/audio/build-boot.json)、[ビルド](evidence/audio/guest-build.json)、[画面](evidence/audio/guest-build.png) |
| 実行ファイル | 298,730バイト。text=12,016、data=285,052、bss=236,462。[ヘッダーとハッシュ](evidence/audio/executable-header.json) |
| 再現性 | 同じソースを8MBで再ビルドした`.X`がバイト一致。配布XDFの再生成もバイト一致。[再ビルド](evidence/audio/rebuild.json)、[XDF](evidence/audio/determinism.json) |
| 2MB起動 | Human68k起動ディスクと音楽版配布XDFの2台構成で起動。タイトル曲、ゲーム開始、XSP表示を確認。[状態](evidence/audio/title-state.json)、[タイトル](evidence/audio/title.png)、[ステージ画面](evidence/audio/stage1.png) |
| BGM | タイトル・ステージ・ゲームオーバー・クリアの各WAVで変動する音声出力を確認。[録音解析](evidence/audio/recording-analysis.json) |
| FM効果音 | BGMを無音にした検証専用XDFで、無操作の無音とショットのFM音を分離して確認。[状態](evidence/audio/isolated-effects-state.json)、[解析](evidence/audio/recording-analysis.json)。通常ディスクで命中・被弾イベントも発生 |
| ZPD効果音 | 同じ実行ファイルと元のZPDを使い、BGM・必殺技FM音を除いた状態で必殺技のADPCM音を確認。[録音解析](evidence/audio/recording-analysis.json)。通常ディスクで必殺技ノート3、ボス撃破ノート4を要求 |
| ステージ進行・クリア曲 | 実際のキー操作で両ボスを撃破。ステージ2、ALL CLEAR状態、3,200点、残機1、BGM番号4、BGM APIエラー0を確認。[操作時の状態推移](evidence/audio/play-trace.json)、[クリア状態](evidence/audio/clear-state.json)、[クリア曲解析](evidence/audio/recording-analysis.json) |
| 終了 | ESC後にDOSへ復帰し、ECHO実行、ZMSC解除を確認。終了直後のPCMを含むケースでも録音の変動成分RMS=0。[結果](evidence/audio/exit-result.json)、[DOS出力](evidence/audio/exit.json)、[録音](evidence/audio/exit-silence.json) |
| ドライバ未常駐 | 解除後に`.X`を直接起動すると案内を表示して終了。[出力](evidence/audio/missing-driver.json)、[画面](evidence/audio/missing-driver.png) |
| 既存成果物の保持 | 以前の開発用・配布用XDFのSHA-256一致を確認。[保全確認](evidence/audio/protected-artifacts.json) |

WAVはWebX68kのミキサー出力を記録したもので、録音結果の聴感評価・実機確認は別工程。ADPCM終了後に保持される一定のDAC値は、変動する音声信号と分けて判定した。音声バイナリや録音WAVはローカルに保持し、Gitにはサイズ・解析結果・ハッシュだけを保存する。ゲームの残機や敵HPを検証用に変更したり、メモリにゲーム状態を書き込んだりしていない。

配布用XDFは1,261,568バイト、ファイル合計415,183バイト、クラスタ割当425,984バイト、空き824,320バイト。`PIRATE.X`、`ZMSC.X`、`AUDIO/`、`GO.BAT`、`README.TXT`を収録し、開発ツールとソースは含めない。[配布マニフェスト](evidence/audio/release-audio.manifest.json)、[開発マニフェスト](evidence/audio/audio-dev.manifest.json)、[暫定音声の抽出元](evidence/audio/source-audio.manifest.json)、[実装入力](evidence/audio/source-inputs.json)で内容を識別する。

```text
f20e951437d8392591cfd9d24e5e718639b22ecd4c1ee9cd65882f7e43a68a4b  release-audio.xdf
```

制作予定の新曲はまだ使用していない。ステージ1と2は暫定的に同じMaidLand曲で、独立したファイル名を用意している。単体ブート、物理パッド、実機X68000/X68000Zは後続の確認対象。
