# HDS と Z-MUSIC 開発検証の実現可能性

この文書は、X68000 SCSI HDD イメージ(HDS)の扱いと、Z-MUSIC の ZMS 開発・コンパイル・再生検証を WebX68k と MCP で行う構成を評価する。実行手順の正本は [X68000 実行確認ランブック](X68K_CHECK.ja.md) とする。

## 結論

現時点では、HDS を WebX68k に直接対応させるより、HDS は変換・ファイル抽出用に保管し、開発検証は XDF を2台構成で行うのが現実的である。

- HDS の直接対応は実現可能だが、拡張子を追加するだけの変更ではない。HDS の SCSI コンテナ、パーティション配置、論理ブロック変換をエミュレータ側まで扱う必要がある。
- `SCSIHDD.HDS` は `X68SCSI1` ヘッダーを持つ約900MiBのイメージで、現在の WebX68k が利用する raw Human68k HDD形式とは異なる。現行コアの raw SASI 経路にも容量上限の制約があるため、最初の対応対象には向かない。
- ZMP7 の単体起動は成立する。ZMP7 は自動起動後に MMDSP のセレクタ画面へ到達し、内蔵 ZMS/ZMD データの閲覧・鑑賞環境として使用できる。
- Z-MUSIC のコンパイルは実機エミュレータ上で自動化できる。コンパイラは `ZMUSIC.X` であり、`ZMSC.X` は ZMD 再生用の縮小ドライバなので役割を混同しない。

## 確認したイメージ

XDF はいずれも X68000 2HD の標準的な 1,261,568 バイトの FAT12 イメージとして読める。

| イメージ | 用途として確認できる内容 |
| --- | --- |
| `ZMP7.XDF` | Human68k、`ZMUSIC.X`、MMDSP、23個の `.ZMS`、22個の `.ZMD`、3個の `.ZPD`。`autoexec.bat` は Z-MUSIC と MMDSP を起動する。 |
| `HUMAN302.XDF` | Human68k 3.02 の起動ディスク。開発用 XDF と組み合わせる起動側の候補。 |
| `ASM.XDF` | `/ASM` 以下にアセンブリソース等を持つ開発用データディスク。単体起動用ではない。 |
| `BLANK.XDF` | ファイル・ディレクトリが無い空の FAT12 ディスク。単体起動用ではない。 |
| `GDISK.XDF` | `GAME/ZMSC.X` と `GAME/ZM/BTSND.ZMD`。ZMSC の再生環境を含む。 |
| `BWR101.XDF` / `MDTK.XDF` / `PACT102.XDF` | 各ディレクトリに `ZMSC.X` を含む再生用イメージ。 |

ユーザーが先に共有した開発用イメージは `ASM.XDF` として確認した。ファイル名が別の XDF を指している場合でも、同じく起動ディスクとデータディスクを分離する2ドライブ構成で評価できる。

今回確認したファイル群と `Projects/ZMConverter` には `.JMD` は無く、コンパイル済み形式は `.ZMD` だった。Z-MUSIC v2 の資料でも `-c` の出力は `.ZMD` と説明されている。ここでいう JMD が別の独自形式を指す場合は、サンプルファイルまたは仕様が別途必要になる。

## ZMP7 と2ドライブ運用

### ZMP7 の単体起動

FDD0 に `ZMP7.XDF` を入れて起動すると、MMDSP のセレクタ画面まで到達する。画面の大部分はグラフィック面に描画されるため、MCP の `screen_text` の認識率が低くても起動失敗とは限らない。判定には `screenshot` を使う。

### 開発・コンパイル用

最も簡単な検証構成は次の通り。

```text
FDD0: HUMAN302.XDF   (Human68k の起動ディスク)
FDD1: ZMP7.XDF       (ZMUSIC.X と ZMS の入った開発・資料ディスク)
```

実際に次のコマンドを実行し、`FC00TST.ZMD` が生成されることを確認した。

```text
A>B:\BIN\ZMUSIC.X -c B:\FCZMS\FC00.ZMS B:\FC00TST.ZMD
```

コンパイル後は、MCP の `disk_read_file` で出力 `.ZMD` を読み出してサイズ・内容を検査できる。生成物を再生確認する場合は、ZMP7 の MMDSP または Z-MUSIC の演奏オプションへ渡す。

`ZMP7.XDF` と `BLANK.XDF` の2台構成も可能だが、BLANK には Human68k と `ZMUSIC.X` が無い。そのままでは開発用のコマンド環境にならないため、次のいずれかにする。

- FDD0 に Human68k、FDD1 に BLANK を置き、あらかじめ `ZMUSIC.X` と作業用ファイルを BLANK へ転送する。
- `HUMAN302.XDF` と `ZMP7.XDF` でコンパイルし、出力だけを MCP で BLANK へ転送する。
- 再現可能な開発ディスクを別途作り、Human68k、`ZMUSIC.X`、ビルド用バッチを同梱する。

FDD は実行中でも差し替えられるため、コンパイル用ディスクと再生用ディスクを切り替える運用も可能である。MCP の `disk_write_file` で FDD へファイルを送り、`disk_read_file` は生成物をホスト側へ戻す。今回の確認では小さいファイルの書き込みは成功した一方、1KBを超えるソース ZMS の投入は完了しなかった。多クラスタ書き込みまたは実行中 FDD の保存経路を修正・再検証するまで、ホストからの一括投入は正式な自動化工程にしない。入力イメージの原本を保全する場合は、検証用コピーへ書き込み、原本をダウンロードで上書きしない。

## MCP による自動化案

次の工程は現在の MCP ツールで構成できる。

1. ホスト側で `ZMConverter` の `inspect` を実行し、ZMS のトラック数、音源割り当て、変換警告を確認する。
2. 必要なら `ZMConverter` の `convert` で、FM/ADPCM向けの別名 ZMS を生成する。これは ZMS の前処理であり、ZMDそのものは生成しない。
3. `disk_write_file` でソース ZMS、音色データ、ZPD を作業用 XDF へ転送する（現状は小さいファイルのみ確認済み。大きいファイルは多クラスタ書き込みの修正後に再検証する）。
4. `type_text` で `ZMUSIC.X -c ...` を入力し、`key_sequence` で Enter を送る。
5. `wait_screen_change` と `screen_text` でコンパイル結果を確認する。画面がグラフィック主体の再生ソフトへ移った場合は `screenshot` を使う。
6. `disk_read_file` で `.ZMD` を取得し、ファイルサイズ、ヘッダー、既知の再生環境での読み込みを検査する。
7. 必要なら MMDSP で再生し、音声出力と画面状態を確認する。

この流れは、ホスト側の静的検査と X68000 上の正典コンパイルを分離できる。`ZMConverter` の README にも、Z-MUSIC コンパイルと XM6 上の試聴は別の検証工程として記載されているため、最終判定は `ZMUSIC.X` と再生環境で行う。

## HDS を直接対応する場合

HDS は単一の FAT イメージではなく、次のような配置を持つ SCSI イメージである。

```text
0x0000  X68SCSI1 ヘッダー
0x0400  IPL
0x0800  X68K パーティションテーブル
0x0C00  SCSI/SASI ドライバ
0x8000  Human68k パーティション
```

そのため、対応範囲は次の層にまたがる。

- `src/disk-store.ts`: `.hds` を HDD として分類し、容量・形式を検証する。
- `src/api/fat.ts`: HDS のヘッダーとパーティションを理解し、ファイル操作のオフセットを合わせる。
- `src/main.ts`: HDS を読み取り専用または編集可能として扱い、保存・再読込時の変換を定義する。
- `px68k-libretro` の SCSI/SASI 実装: ゲストから見える論理ブロックを HDS の配置へ変換する。コア変更後は Emscripten で WASM を再ビルドする。
- テスト: 複数パーティション、ブート、読み書き、容量境界、原本の再現性を検証する。

従って、直接アダプターは中規模以上の機能追加になる。特に現在の raw SASI 経路は 256バイト固定ブロックのLBAを前提とし、実装コメント上の実用上限は約512MiBである。900MiB級の HDS をそのまま同じ経路へ渡す設計は適切でない。

## 変換・移行の候補

既存ツールでは、[erique/scsitools](https://github.com/erique/scsitools) が X68000 SxSI/SCSI イメージの `info`、整合性検査、ファイル抽出、追加、再パックを提供している。HDS のファイルを安全に抽出して、WebX68k 用に別の raw HDF または XDF へ移す際の候補になる。

ただし、このツールの出力は SCSI 形式のままであり、WebX68k が現在受け付ける raw HDF へ自動変換するものではない。移行時は次のように原本と変換物を分離する。

1. HDS の SHA-256 を記録し、原本を変更しない。
2. `scsitools` 等で必要なファイルを抽出する。
3. WebX68k のブランク HDD、または XDF の作業ディスクへファイルを配置する。
4. Human68k 起動、Z-MUSIC コンパイル、再生を確認する。
5. 変換物のファイル一覧とハッシュを記録する。

HDS をゲストからブート・常用することが必須になった時点で、コア側の SCSI 実装を含む直接アダプターを別作業として着手するのが安全である。

## 参照

- [Z-MUSIC SYSTEM Ver.2 ソースとマニュアル](https://github.com/kg68k/zmusic2)
- [Z-MUSIC v2 オプションスイッチ解説](https://github.com/kg68k/zmusic2/blob/main/manual/zm02.txt)
- [X68000 SxSI Disk Image Tools](https://github.com/erique/scsitools)
