# 海賊王ゲームの生成・実行ランブック

音楽版の抽出・起動・検証・差し替えは[Z-MUSIC音声手順](pirate68k/AUDIO.ja.md)を併せて使用する。

この手順は、[独立したゲームソース](../games/pirate68k/README.ja.md)から、Human68k上で`.X`をビルドし、開発・配布XDFを検証するためのものである。[仕様の理由](pirate68k/DESIGN.ja.md)と[実測記録](pirate68k/VERIFICATION.ja.md)は別文書で管理する。

## 前提

リポジトリのルートで実行する。Node.jsとnpm、Python 3.10以上、Pillow 12.3以上、Google Chrome、ローカルのDev68KToolsを用意する。Chromeは`tools/pirate68k/session.mjs`の`CHROME_BIN`環境変数でも指定できる。一般のWebX68kセットアップは[X68000実行確認ランブック](X68K_CHECK.ja.md)に従う。

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
TOOLDISK=/Users/m1prime/Projects/MaidLand/Dev68K.XDF
TITLE=/absolute/path/to/title.jpg
mkdir -p _local/pirate68k
```

HDSは`X68SCSI1`形式の最初のHuman68k FAT16パーティションから`/BIN/HAS060.X`と`/BIN/HLK.X`だけを読み出す。対象パーティションのジオメトリが違う場合は停止する。HDSの直接起動や全体コピーは行わない。Human68kと画像は利用者が用意し、元ファイルは更新しない。

## タイトルと開発用XDF

```sh
"$PYTHON" tools/pirate68k/art.py
"$PYTHON" tools/pirate68k/graphics.py
"$PYTHON" tools/pirate68k/assets.py "$TITLE" --output _local/pirate68k/TITLE.RAW
node tools/pirate68k/devtools-title.mjs "$DEVTOOLS" \
  _local/pirate68k/TITLE.indexed.png _local/pirate68k/TITLE
"$PYTHON" tools/pirate68k/xdf.py dev --hds "$HDS" \
  --tool-disk "$TOOLDISK" --title _local/pirate68k/TITLE.RAW \
  --audio _local/pirate68k/audio --output _local/pirate68k/audio-dev.xdf
"$PYTHON" tools/pirate68k/xdf.py list _local/pirate68k/audio-dev.xdf
```

XDF生成前に、[暫定音声の準備](pirate68k/AUDIO.ja.md#暫定データの準備)を実行して`audio/`を作る。正常な既存開発XDFを上書きしない。

`assets.py`は日本語見出し用フォントにmacOSのヒラギノ角ゴシックを使う。他OSでは`--font`に日本語フォントを指定する。Pillowの版・フォント・DevToolsの版によって変換結果が変わるので、生成される`TITLE.json`と`TITLE.devtools.json`で入力と変換器のSHA-256を確認する。DevToolsのコードは外部パスから実行し、ソースを取り込まない。

開発用XDFの構成:

```text
/BIN/HAS060.X, HLK.X, XSP2LIB.O
/SRC/PIRATE.S, STATE.INC, ART.INC, SOUND.INC, VIDEO.INC, TITLE.RAW
/SRC/GRAPHICS.INC, SPRITES.SP, SPRITES.PAL, BG1.BIN, BG1.PAL, BG2.BIN, BG2.PAL
/SRC/AUDIO.INC
/AUDIO/                    ← 外部ZMD、FM効果音、ZPD
/ZMSC.X
/OUT/                      ← Human68k側の出力先
/BUILD.BAT
/GO.BAT
/README.TXT
```

## Human68k上でビルド

ビルド時はWebX68kを16MHz・8MBに設定する。通常のブラウザ検証はWebX68kへFDD0=HUMAN302.XDF、FDD1=audio-dev.xdfを装填し、起動後に次を入力する。

```text
A>B:\BUILD
B>B:\GO
```

`BUILD.BAT`はB:\SRCでHAS060を実行し、B:\OUTにオブジェクトと一時ファイルを作り、HLKでXSP2LIB.OをリンクしてB:\OUT\PIRATE.Xを生成する。エラー時はBUILD FAILED、成功時はBUILD OKを表示する。HAS060のVRAM絶対アドレス・ADDA.Wに関する警告は、直接描画する箇所に対応する。ビルド成功表示と`.X`の存在・サイズを併せて判定する。

## MCPと配布用XDFの検証

音楽版は[音声手順のビルド・XDF生成](pirate68k/AUDIO.ja.md#ビルドxdf生成)に従う。`verify-audio.mjs`がMCPと隔離Chromeを起動し、8MBでのビルド、2MBでのプレイ、音声録音を行う。FDD0はHuman68k、FDD1は音楽版XDFを使用する。`GO.BAT`が音声ドライバを登録し、終了後に解除する。

`xdf.py release`には`--audio`で外部音声ディレクトリを指定する。生成先は`_local/pirate68k/release-audio.xdf`とし、既存の`release.xdf`は保持する。配布ディスクの収録ファイル・容量・SHA-256は自動生成される同名のマニフェストで確認する。音声は実行ファイルとは別に収録する。

従来の`session.mjs`は手動MCP観測に使用できる。背景はGVRAM、キャラクターはハードウェアスプライト、HUDは独自のTVRAMフォントなので、`screen_text`の空結果で失敗と判定しない。ゲームの起動と終了は`GO.BAT`を通して検証する。

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

## グラフィック変換

`graphics.py`は`games/pirate68k/assets/`のPNGを読み、32×32の通常キャラ、96×96のボス、64×64の援護キャラを作る。キャラは各15色＋透明色、背景は256色に量子化する。XSP用16×16 PCGは8×8区画の左上・左下・右上・右下順で格納する。生成物は`_local/pirate68k/graphics/`。`native-preview.png`で実寸を拡大表示し、`graphics.json`で素材ハッシュ・タイル数を確認する。PNGの生成経緯は[素材記録](../games/pirate68k/assets/README.md)を参照する。

音楽版の検証は`verify-audio.mjs`を使う。初版用の`verify-build`、`verify-release`、`verify-rebuild`は旧ファイル名・旧収録構成を対象にするため、音楽版へそのまま使用しない。
