# 海賊王ゲームの生成・実行ランブック

この手順は、[独立したゲームソース](../games/pirate68k/README.ja.md)から、Human68k上で`.X`をビルドし、開発・配布XDFを検証するためのものである。[仕様の理由](pirate68k/DESIGN.ja.md)と[実測記録](pirate68k/VERIFICATION.ja.md)は別文書で管理する。

## 前提

リポジトリのルートで実行する。Node.jsとnpm、Python 3.10以上、Pillow、Google Chrome、ローカルのDev68KToolsを用意する。Chromeは`tools/pirate68k/session.mjs`の`CHROME_BIN`環境変数でも指定できる。一般のWebX68kセットアップは[X68000実行確認ランブック](X68K_CHECK.ja.md)に従う。

```sh
npm ci
npm --prefix mcp ci
python3 -m pip install Pillow
```

必要な入力ファイルは次のとおり。パスは環境に合わせる。

```sh
PYTHON=python3
DEVTOOLS=/Volumes/AITuberRetroMacDev/Projects/Dev68kTools
HDS="$DEVTOOLS/X68000DEV/SCSIHDD.HDS"
SYSTEM="$DEVTOOLS/X68000DEV/XDF/HUMAN302.XDF"
TITLE=/absolute/path/to/title.jpg
mkdir -p _local/pirate68k
```

HDSは`X68SCSI1`形式の最初のHuman68k FAT16パーティションから`/BIN/HAS060.X`と`/BIN/HLK.X`だけを読み出す。対象パーティションのジオメトリが違う場合は停止する。HDSの直接起動や全体コピーは行わない。Human68kと画像は利用者が用意し、元ファイルは更新しない。

## タイトルと開発用XDF

```sh
"$PYTHON" tools/pirate68k/art.py
"$PYTHON" tools/pirate68k/assets.py "$TITLE" --output _local/pirate68k/TITLE.RAW
node tools/pirate68k/devtools-title.mjs "$DEVTOOLS" \
  _local/pirate68k/TITLE.indexed.png _local/pirate68k/TITLE
"$PYTHON" tools/pirate68k/xdf.py dev --hds "$HDS" \
  --title _local/pirate68k/TITLE.RAW --output _local/pirate68k/dev.xdf
"$PYTHON" tools/pirate68k/xdf.py list _local/pirate68k/dev.xdf
```

`assets.py`は日本語見出し用フォントにmacOSのヒラギノ角ゴシックを使う。他OSでは`--font`に日本語フォントを指定する。Pillowの版・フォント・DevToolsの版によって変換結果が変わるので、生成される`TITLE.json`と`TITLE.devtools.json`で入力と変換器のSHA-256を確認する。DevToolsのコードは外部パスから実行し、ソースを取り込まない。

開発用XDFの構成:

```text
/BIN/HAS060.X, HLK.X
/SRC/PIRATE.S, STATE.INC, ART.INC, SOUND.INC, TITLE.RAW
/OUT/                      ← Human68k側の出力先
/BUILD.BAT
/GO.BAT
/README.TXT
```

## Human68k上でビルド

通常のブラウザ検証はWebX68kへFDD0=HUMAN302.XDF、FDD1=dev.xdfを装填し、起動後に次を入力する。

```text
A>B:\BUILD
B>B:\OUT\PIRATE
```

`BUILD.BAT`はB:\SRCでHAS060を実行し、HLKでB:\OUT\PIRATE.Xを生成する。エラー時はBUILD FAILED、成功時はBUILD OKを表示する。HAS060のVRAM絶対アドレス・ADDA.Wに関する警告は、直接描画する箇所に対応する。ビルド成功表示と`.X`の存在・サイズを併せて判定する。

## MCPを使う自動検証

別々のターミナルで、次の2プロセスを起動する。検証用セッションはMCPのstdioクライアントとしてサーバーを起動し、専用の隔離Chromeを開く。既存のユーザーブラウザやその保存データを変更しない。

```sh
npm run dev -- --host 127.0.0.1 --port 5299
```

```sh
node tools/pirate68k/session.mjs
```

自動検証のCPU/RAMはURLで16MHz/2MBに指定する。検証用ブリッジは3199、ローカル操作エンドポイントは5399を使う。ここで起動したMCPサーバーと同じポートのサーバーを重複して起動しない。

さらに別ターミナルで順に実行する。

```sh
node tools/pirate68k/verify-build.mjs "$SYSTEM"
node tools/pirate68k/verify-game.mjs
node tools/pirate68k/verify-stages.mjs
```

`verify-build`は外部Human68kの起動、MCP接続、開発ディスク一覧、ゲストでのビルド、`.X`回収、タイトルを検証する。`verify-game`はMCPの`key_sequence`で開始・移動・攻撃を、通常のブラウザキーイベントで斜めを含む8方向を検査し、ゲームオーバーと再開まで待つ。`verify-stages`はゲスト状態をMCPで読みながら実際のキーを操作して2体のボスを倒す。メモリの書き換えやテスト専用の無敵設定は使わない。

画面PNG、JSONの状態記録、回収された`.X`は`_local/pirate68k/`に保存する。検証スクリプトが途中で失敗した場合は、操作キーを解放してセッションを終了し、新しい`session.mjs`から再開する。複数回アプリを起動したゲストでは、解放済みヒープに古い`P68KSTAT`が残ることがあるため、正式な検証は新しいブラウザセッションで一巡させる。

手動MCP操作には`status`→`disk_list_files`→`type_text`→`screen_text`/`screenshot`→`disk_read_file`を使う。ゲームはGVRAM描画なので、`screen_text`の空結果で失敗と判定しない。任意コマンドの例:

```sh
node tools/pirate68k/control.mjs call '{"name":"status"}'
node tools/pirate68k/control.mjs shot '{"name":"manual-check"}'
```

## 配布用データディスク

```sh
"$PYTHON" tools/pirate68k/xdf.py release \
  --executable _local/pirate68k/PIRATE.X --output _local/pirate68k/release.xdf
"$PYTHON" tools/pirate68k/xdf.py list _local/pirate68k/release.xdf
node tools/pirate68k/verify-release.mjs
node tools/pirate68k/verify-rebuild.mjs
"$PYTHON" tools/pirate68k/verify-hud.py _local/pirate68k/bomb.png _local/pirate68k/bomb-state.json
"$PYTHON" tools/pirate68k/verify-hud.py _local/pirate68k/all-clear.png _local/pirate68k/all-clear-state.json
shasum -a 256 _local/pirate68k/release.xdf
```

`.X`にタイトル・自作絵・FM曲が埋め込まれているため、配布用XDFには`PIRATE.X`、`GO.BAT`、`README.TXT`だけが必要。FDD0からHuman68kを起動し、FDD1の配布ディスクで`B:`、`GO`を実行する。同じベース名の`release.manifest.json`と`release.sha256`が自動生成される。XDF内の各ファイルのサイズ・SHA-256、空き容量、ディスク全体のSHA-256を含む。

## ホスト側の検査

```sh
npm test
npm run build
"$PYTHON" -m unittest discover -s tools/pirate68k -p 'test_*.py' -v
npm --prefix mcp run bundle
node scripts/smoke-test-mcp-bundle.mjs mcp/dist/webx68k-mcp.mjs
node tools/pirate68k/verify-mcp.mjs
```

終了時は`session.mjs`とViteのターミナルでCtrl-Cを押す。生成したXDFと外部バイナリは`_local/`に置いたままGitへ追加しない。公開する場合は提供画像とツールの再配布条件、配布先リポジトリと公開範囲を確認してからRelease等に置く。
