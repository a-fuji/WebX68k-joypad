# X68000 検証履歴と別Mac向け再現手順

この文書は、WebX68k と MCP を使って実施した X68000 ディスク、Z-MUSIC、開発環境連携の実験結果を記録する履歴である。現在の操作手順は [X68000 実行確認ランブック](X68K_CHECK.ja.md)、HDS と Z-MUSIC の判断材料は [HDS と Z-MUSIC 開発検証の実現可能性](X68K_HDS_ZMUSIC_FEASIBILITY.ja.md) を正本とする。

ディスクイメージ、ホスト上のプロジェクト、ブラウザの IndexedDB はこのリポジトリに含めない。別のMacで検証するときは、同じコミットのWebX68kを用意し、検証対象のXDFをファイル選択またはCORS対応URLから装填する。

## 検証の範囲

今回の検証では、次の経路を確認した。

```text
XDF/HDSの内容確認
  -> WebX68kへの装填
  -> MCPからの状態・画面・キー操作
  -> Human68k上のZ-MUSICコンパイル
  -> 生成物の読み出し
```

アセンブラ・リンカを含むMaidLandの実ビルドは、現在のMacにツールチェーンと実行用XDFがまだ無いため未実施である。MaidLand側のビルド要件は、ローカルにMaidLandプロジェクトを配置した場合の`src/README.md`と`doc/workflow.md`を参照する。

今回の調査対象は次のローカルパスだった。

```text
/Users/m1prime/Projects/MaidLand
```

## 2026-08-30〜31: ディスクイメージの調査

調査対象は、外部ボリューム上の次のディレクトリに置かれたイメージである。

```text
/Volumes/AITuberRetroMacDev/Projects/Dev68kTools/X68000DEV
```

### XDF

確認したXDFはいずれも、1,261,568バイトのX68000 2HD FAT12イメージとして読み出せた。

| イメージ | 確認結果 |
| --- | --- |
| `HUMAN302.XDF` | Human68k 3.02の起動ディスク |
| `ASM.XDF` | `/ASM`以下にアセンブラソース、PAL、SP等を含む開発用データディスク。単体起動はしない |
| `ZMP7.XDF` | Human68k、`ZMUSIC.X`、MMDSP、ZMS/ZMD/ZPDデータを含むZ-MUSIC確認ディスク |
| `BLANK.XDF` | ファイル・ディレクトリの無い空のFAT12ディスク |
| `GDISK.XDF` | `ZMSC.X`とZMDデータを含む再生用ディスク |

`ZMP7.XDF`には、ルートのHuman68k起動ファイル、`BIN/ZMUSIC.X`、MMDSP関連ファイル、`FCZMS`以下のZMS/ZMDが含まれている。`ZMSC.X`はコンパイラではなく、ZMDを再生するための縮小ドライバである。

### HDS

`SCSIHDD.HDS`は943,718,400バイト（約900MiB）で、先頭に`X68SCSI1`を持つSCSIイメージだった。HDSはWebX68kの現在のraw HDFとは論理ブロック配置が異なり、拡張子変更やヘッダー削除だけでは装填できない。

現時点では、HDSをWebX68kへ直接対応させるより、HDS原本を保管し、必要なファイルを抽出してXDFへ移す方針とする。移行候補として[X68000 SxSI Disk Image Tools](https://github.com/erique/scsitools)を確認したが、WebX68k用raw HDFを直接生成するツールではない。

## 2026-08-30〜31: WebX68kとMCPの確認

ローカルWebX68kとMCPブリッジを起動し、ブラウザとMCPが接続した状態で確認した。別Macでの標準手順は次の通り。

```sh
npm ci
npm --prefix mcp ci
npm run check:local
```

表示されたローカルURLをブラウザで開き、MCPクライアントから `status` を呼ぶ。通常のポートは、Webサーバーが5299、MCPブリッジが3099である。ポートを変更する場合は、MCPサーバーの`WEBX68K_BRIDGE_PORT`とURLの`bridge`を同じ値にする。

確認済みのMCP操作は次の通り。

- `status`: エミュレータの起動状態、画面サイズ、FDD/HDDの装填状態
- `screen_text`: Human68kのテキスト画面と認識診断
- `screenshot`: GVRAM、BG、スプライト主体の画面
- `type_text` / `key_sequence`: コマンド入力と特殊キー入力
- `wait_screen_change`: 起動・画面遷移待ち
- `list_disks` / `insert_disk` / `eject_disk`: ディスク操作
- `disk_list_files` / `disk_read_file`: XDF内のファイル一覧・読み出し
- `disk_write_file`: XDF内へのファイル書き込み

MCPの画面文字認識はTVRAM中心であり、MMDSPなどのグラフィック画面では`coverage`が低くなる。ZMP7の起動判定は`screen_text`だけでなく、`screenshot`で行う。

リポジトリ側の確認では、`npm test`が35テストファイル・558テストすべて成功し、`npm run build`も成功した。MCP接続を伴う実行確認は、別Macでも本書のXDF検証手順を実施する。

## 2026-08-30〜31: ZMP7の起動確認

FDD0へ`ZMP7.XDF`を装填して起動すると、MMDSPのセレクタ画面まで到達した。画面にはMMDSPのバージョン表示、ファイル選択領域、`BIN`、`ZM2022`、`BWLF`、`ZM2023`、`FCZMS`等のディレクトリが表示された。

この結果により、ZMP7は次の用途に利用できる。

- 内蔵ZMS/ZMDデータの一覧確認
- MMDSPによる音楽データの選択・鑑賞
- Z-MUSIC関連環境の起動確認

## 2026-08-30〜31: XDF 2ドライブでのZMSコンパイル

次の構成でHuman68kを起動した。

```text
FDD0: HUMAN302.XDF
FDD1: ZMP7.XDF
```

Human68kの`A>`プロンプトから、次のコマンドを実行した。

```text
B:\BIN\ZMUSIC.X -c B:\FCZMS\FC00.ZMS B:\FC00TST.ZMD
```

`Operations are all set.`の表示後、MCPの`disk_read_file`で`/FC00TST.ZMD`を読み出し、467バイトの生成物を確認した。したがって、X68000上の正典コンパイルをMCPで操作・検査する経路は成立している。

この確認で、既知のコンパイル済み形式は`.ZMD`であることも確認した。調査対象のファイル群とMaidLandプロジェクトには`.JMD`は無かった。別の独自形式をJMDと呼んでいる場合は、サンプルまたは仕様を追加で確認する。

## 2026-08-30〜31: MCPからのファイル転送

実行中のFDDへMCPの`disk_write_file`を使い、短いテキストファイルを書き込めることを確認した。一方、1KBを超えるZMSファイルをFDDへ投入する試行は完了せず、MCP要求が長時間待機した。

このため、現時点の判定は次の通りである。

| 経路 | 判定 |
| --- | --- |
| XDFにあらかじめ入っているZMSのコンパイル | 成立 |
| 小さいファイルのMCP転送 | 成立 |
| 大きいソースをMCPで多クラスタ転送 | 未成立。修正・再検証が必要 |
| XDF全体をホスト側で生成して装填 | 実装候補。大規模転送を避けられる |

本番の自動化では、原本XDFへ直接書き込まず、検証用コピーまたはホスト側で新規生成したXDFを使う。大きなソースを扱う場合は、MCPの多クラスタ書き込み経路を修正するか、ホスト側XDFパッケージャーで一括生成する。

## MaidLandプロジェクトの受け入れ調査

対象プロジェクトは次の場所にある。

```text
/Users/m1prime/Projects/MaidLand
```

この時点で確認できた構成は次の通り。

- アセンブル入口は`src/MAIDLAND.S`
- ビルド手順は`has060 maidland.s`、`hlk maidland.o a:\lib\xsp2lib.o`、`maidland.x`
- `iocscall.mac`、`doscall.mac`、`fdef.h`、`LABEL.S`、`const.h`が外部依存
- `A:\lib\xsp2lib.o`がリンク依存
- リポジトリ内に`.O`、`.X`、`.XDF`の生成物はまだ無い
- このMacのPATHに`has060`と`hlk`は無く、従来のWhisky実行環境パスも存在しない
- `src`ディレクトリ全体は1,162,559バイトで、標準2HD XDFの総容量に近い

従って、MaidLandをこの環境でビルドするには、次の開発用XDFが必要になる。

- Human68k起動環境
- `has060`と`hlk`、または同じ入力形式を処理できるX68000側ツール
- 共通マクロ・ヘッダー・`A:\lib\xsp2lib.o`
- `MAIDLAND.S`から参照される分割ソースと`.insert`素材
- アセンブル・リンク用バッチ
- 実行確認用の起動バッチとZ-MUSIC関連ファイル

ソースと素材を一枚の標準2HD XDFへすべて入れるのは容量が厳しい。1.44MB形式の採用、起動・ツール用とソース・素材用の2ドライブ分割、または複数XDFの切り替えを候補とする。

## 別Macでの再現手順

### WebX68k本体の検証

```sh
git clone <WebX68k-joypadのURL>
cd WebX68k-joypad
npm ci
npm --prefix mcp ci
npm test
npm run build
npm --prefix mcp run bundle
node scripts/smoke-test-mcp-bundle.mjs mcp/dist/webx68k-mcp.mjs
npm run check:local
```

MCPクライアントには、ローカルの`mcp/server.mjs`またはバンドルした`mcp/dist/webx68k-mcp.mjs`を登録する。ブラウザでローカルURLを開いた後、`status`、`screen_text`、`screenshot`の順に確認する。

### XDFの検証

1. FDD0に`HUMAN302.XDF`を入れてHuman68kを起動する。
2. FDD1に`ZMP7.XDF`、`ASM.XDF`、または検証対象の開発用XDFを入れる。
3. `disk_list_files`でルートと作業ディレクトリを確認する。
4. ビルドまたは再生コマンドを`type_text`で入力し、必要なら`key_sequence`でEnterやファンクションキーを送る。
5. `wait_screen_change`、`screen_text`、`screenshot`で結果を確認する。
6. 生成物は`disk_read_file`でホスト側へ戻し、サイズとハッシュを記録する。

### 原本保全

- 外部HDS/XDFをリポジトリへコピーしない。
- 入力イメージのSHA-256を記録する。
- 書き込み試験は検証用コピーで行う。
- 同じURLを再訪した場合、ブラウザのIndexedDBに保存済みのディスクが優先されるため、内容を再取得するときは保存済みディスクとキャッシュを確認する。
- 配布用XDFは、開発用ファイルを除いた明示的なファイル一覧から生成する。

## 今後の実装課題

優先順は次の通り。

1. アセンブラ・リンカ同梱の開発用XDFを準備する。
2. MaidLandの外部依存ファイルとビルドバッチを開発用XDFへ収録する。
3. ホスト側でディレクトリを含むXDFを再現可能に生成するパッケージ処理を用意する。
4. 大きなファイルのMCP転送またはXDF一括生成を検証する。
5. WebX68k MCPでアセンブル・リンク・起動・生成物回収を一連の手順にする。
6. 最終ランタイムだけを配布用XDFへ格納し、ファイル一覧、サイズ、ハッシュ、起動結果を記録する。
7. ソース管理タスクと実行環境タスクの間で、コミットSHA付きの確認依頼と結果報告を運用する。

ソース更新をGitコミット単位で検証する運用は可能だが、ローカルGitコミットを検知して別のCodexタスクを自動起動する機能はこの構成にはまだない。最初はソース管理側から明示的に確認依頼を送り、実行環境側が結果を返す方式とする。


## 2026-10-24〜30: 独立ゲームの開発・表示強化・Z-MUSIC統合

`codex/x68k-original-game`で「海賊王ゲーム」を開発した。初版の独立68000ソースとXDF生成環境から、背景・大型ハードウェアスプライト、Z-MUSICによるBGMとFM/ZPD効果音へ拡張した。Human68k上のHAS060・HLK・XSPによるビルドは8MB、配布版の実行検証は2MBで行った。

ユーザーは背景・XSP版をステージ2クリアまで実プレイ確認した。音楽版はMaidLandの音声を暫定流用し、後から楽曲ファイルを差し替えられる構成とした。正常な既存XDFと外部原本は保持し、新版は別名のXDFへ生成している。

ゲーム固有の結果・確認元・コミット・マニフェストは[開発・検証記録](pirate68k/VERIFICATION.ja.md)に集約する。操作手順は[ゲーム生成ランブック](X68K_ORIGINAL_GAME.ja.md)、音声の生成・差し替えは[音声手順](pirate68k/AUDIO.ja.md)、次の作業は[引き継ぎ](pirate68k/NEXT_VERSION_HANDOFF.ja.md)を参照する。
