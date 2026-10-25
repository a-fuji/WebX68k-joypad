# Z-MUSIC音声データの生成と差し替え

ゲームはZ-MUSIC v2常駐ドライバを使用する。`GO.BAT`が`ZMSC.X -m -b AUDIO\SFX.ZPD`を実行し、ゲーム起動前に効果音バンクを登録する。ゲーム終了後は`ZMSC.X -r`で解除する。BGMはTRAP #3の`$11`、FM効果音は`$12`、登録済みZPD効果音は`$14`で再生する。MaidLandの`src/SOUND.S`と起動バッチに合わせた構成である。

## 暫定データの準備

MaidLandのXDFとソースは読み取り専用で扱う。必要な音声だけをローカル生成先へ抽出する。以下はリポジトリのルートで実行する。Pythonは3.10以上を使用する。

```sh
PYTHON=python3
MAID=/Users/m1prime/Projects/MaidLand
"$PYTHON" tools/pirate68k/audio.py \
  --maid-disk "$MAID/メイドランド.XDF" \
  --maid-source "$MAID/src/SOUND.S" \
  --output _local/pirate68k/audio
```

抽出対象とPCM番号は`games/pirate68k/audio.json`が定める。生成される`audio.manifest.json`に、元データの場所・サイズ・SHA-256を記録する。音声バイナリとドライバはGitに含めない。

| 実行時ファイル | 用途 | 暫定データ |
| --- | --- | --- |
| `AUDIO/TONE.ZMD` | 起動時のFM効果音音色定義 | BTSND.ZMD |
| `AUDIO/TITLE.ZMD` | タイトル | MLDEMO.ZMD |
| `AUDIO/STAGE1.ZMD` | ステージ1 | MLMAIN.ZMD |
| `AUDIO/STAGE2.ZMD` | ステージ2 | MLMAIN.ZMD |
| `AUDIO/CLEAR.ZMD` | 全ステージクリア | MLCLEAR.ZMD |
| `AUDIO/OVER.ZMD` | ゲームオーバー | MLGO.ZMD |
| `AUDIO/SHOT.SE` | ショット | SOUND.Sのse13 |
| `AUDIO/HIT.SE` | 敵・ボスへの命中 | SOUND.Sのse14 |
| `AUDIO/HURT.SE` | プレイヤー被弾 | SOUND.Sのse12 |
| `AUDIO/BOMB.SE` | 必殺技のFM音 | SOUND.Sのse21 |
| `AUDIO/SFX.ZPD` | 必殺技・ボス撃破のADPCM音 | MDLD.ZPD |
| `ZMSC.X` | 常駐再生ドライバ | MaidLand XDFのZMSC.X |

暫定ZPDの必殺技はノート3、ボス撃破はノート4。再生モードはMaidLandと同じ`$00100403`で、優先度16・周波数設定4・左右出力。ADPCMは単音で後からの同優先度要求が優先される。FM8を効果音に使うため、BGMのFM8と競合させない。

## Astraで制作する楽曲への差し替え

1. Z-MUSIC **v2**でコンパイルしたZMDを用意する。v3用データは使わない。
2. BGMはFM1〜7を使用する。音色番号73・82は暫定FM効果音が参照するので上書きしない。各曲に必要な音色を含め、MIDI機器・外部PCMファイル・追加のディスク読込みに依存させない。
3. `TITLE.ZMD`、`STAGE1.ZMD`、`STAGE2.ZMD`、`CLEAR.ZMD`、`OVER.ZMD`の必要なものを同名で置き換える。1ファイル上限32,768バイト。ステージ曲はループ、クリアとゲームオーバーは終端を持たせる。
4. ZPDを差し替える場合はノート3/4を維持するか、`audio.json`のPCM番号と生成する`AUDIO.INC`を合わせて変更する。周波数設定も素材に合わせる。
5. `--audio`に差し替え先のディレクトリを指定し、新しい名前でXDFを生成する。BGMファイルだけの変更なら`.X`の再ビルドは不要。再起動時にまとめて読み込まれる。

`TONE.ZMD`はFM効果音用音色を定義する無音の初期化データなので、曲を変更するときも保持する。`.SE`は通常のZMDファイル全体ではなく、共通コマンドを除いた「トラック数」から始まるZ-MUSICの効果音データ。FM8の1トラック、1ファイル上限1,024バイト。新しい効果音へ置き換える場合はこの形式と参照音色を合わせる。

`audio.py`を再実行すると抽出先は暫定データに戻る。制作済み音源は別ディレクトリに保持し、抽出処理と差し替え処理を分ける。

## ビルド・XDF生成

既存の正常なXDFは更新せず、音楽版は別名を使う。`TITLE.RAW`と`graphics/`は[生成ランブック](../X68K_ORIGINAL_GAME.ja.md)に従って準備する。

```sh
DEVTOOLS=/Volumes/AITuberRetroMacDev/Projects/Dev68kTools
SYSTEM="$DEVTOOLS/X68000DEV/XDF/HUMAN302.XDF"
"$PYTHON" tools/pirate68k/xdf.py dev \
  --hds "$DEVTOOLS/X68000DEV/SCSIHDD.HDS" \
  --tool-disk "$MAID/Dev68K.XDF" \
  --title _local/pirate68k/TITLE.RAW \
  --audio _local/pirate68k/audio \
  --output _local/pirate68k/audio-dev.xdf
```

WebX68kを16MHz・8MBにし、FDD0にHuman68k、FDD1に`audio-dev.xdf`を装填する。`B:\BUILD`で`B:\OUT\PIRATE.X`を生成する。起動はルートの`B:\GO`を使う。外部音声を読むので、`OUT`へ移動して実行しない。

```sh
npm run dev -- --host 127.0.0.1 --port 5299
# 別ターミナルで実行（検証中は別のMCPサーバーを3299で起動しない）
HUMAN_XDF="$SYSTEM" node tools/pirate68k/verify-audio.mjs build
"$PYTHON" tools/pirate68k/xdf.py release \
  --executable _local/pirate68k/PIRATE-audio.X \
  --audio _local/pirate68k/audio \
  --output _local/pirate68k/release-audio.xdf
HUMAN_XDF="$SYSTEM" node tools/pirate68k/verify-audio.mjs play
HUMAN_XDF="$SYSTEM" node tools/pirate68k/verify-audio.mjs exit
HUMAN_XDF="$SYSTEM" node tools/pirate68k/verify-audio.mjs rebuild
```

`play`は実際のキーによる自動プレイと各場面の録音、`exit`は終了・無音・ドライバ未常駐時の処理、`rebuild`はゲスト再ビルドのバイト一致を確認する。

配布用は16MHz・2MB、FDD0=Human68k、FDD1=`release-audio.xdf`で`B:`→`GO`。実行ファイル・ZMSC・AUDIO一式・起動バッチだけを収録する。開発ツール・ソースは入れない。マニフェストとSHA-256は同時に生成される。

## 音声出力の検証

`verify-audio.mjs`は専用の隔離ChromeとMCPを起動し、`audio-check/`へ画面・状態・WAVを保存する。WAVはWebX68kのミキサーがAudioWorkletへ送るステレオ44.1kHz音声を記録したもの。録音中のテスト用観測はWebX68k本体・MCP本体を変更しない。ADPCMミキサーは終了後に一定のDAC値を保持する場合があるため、チャンネルごとの直流成分と変動成分のRMS（`acRms`）を分けて記録し、無音は変動成分で判定する。

```sh
"$PYTHON" tools/pirate68k/audio_probe.py
HUMAN_XDF="$SYSTEM" node tools/pirate68k/verify-audio.mjs effects
```

この検証専用XDFは同じ実行ファイルを使い、BGMを無音の音色初期化に、必殺技のFMデータを空のトラックに置き換える。無操作の無音、ショット時のFM音、必殺技時のZPD音をそれぞれ確認する。配布用XDFへはこの置換を適用しない。

参考: [Z-MUSIC v2ファンクションコール](https://github.com/kg68k/zmusic2/blob/main/manual/zm10.txt)、[効果音モード](https://github.com/kg68k/zmusic2/blob/main/manual/zm14.txt)。
