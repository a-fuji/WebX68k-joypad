# Dev68K.XDF と WebX68k MCP を使った開発・実行確認

このドキュメントは、X68000アセンブラ系のゲーム開発プロジェクトから、WebX68k上の
開発環境を再現し、ビルド結果をブラウザで確認するための共有手順です。

対象となる役割は次の3つです。

- `Dev68K.XDF`: WebX68k専用の開発・起動ディスク
- `GDISK.XDF`: ゲーム配布用の基本構成ディスク
- `BLANK.XDF`: FAT12フォーマット済みの空ディスク

これらのイメージは現在、`/Users/ofuji/EXD/Pyxel/X68000/SOZAI/` に置かれています。
XDF本体を共有リポジトリへ含めるかどうかは、収録ソフトウェアの配布条件を確認してから
決めてください。このリポジトリでは、URLで取得できる無料配布用イメージを使う構成を
想定します。

## Dev68K のドライブ構成

WebX68kではURLパラメータとゲスト側ドライブの対応は次のとおりです。

| WebX68kスロット | X68000ドライブ | URLパラメータ | 用途 |
|---|---|---|---|
| FDD0 | `A:` | `fd1` | 開発環境・起動ディスク |
| FDD1 | `B:` | `fd2` | ビルド対象・成果物ディスク |

基本構成は、FDD0に `Dev68K.XDF`、FDD1に `BLANK.XDF` または作業用の別XDFをセットします。
`fd1` はFDD0、`fd2` はFDD1を意味するため、名前の数字とゲスト側のA/Bドライブが
1つずれている点に注意してください。

### Aドライブ (`Dev68K.XDF`)

`A:` は開発環境と起動環境です。現状のイメージにはHuman68k、HAS/HLK、Z-MUSIC、
インクルードファイル、各種コマンド・バッチが入っています。

- XSPライブラリのオブジェクトファイルは `A:` 直下に置く
- 基本的なアセンブラ/C用インクルードは `A:\INCLUDE` に置く
- ゲーム固有のインクルードは、ソース共有時に `A:\INCLUDE` へ追加するか、ビルドバッチの
 参照先を明示的に変更する
- `AUTOEXEC.BAT`、`CONFIG.SYS`、`STARTUP.ENV` はWebX68k上のパス構成に合わせて調整する

特に、ホスト側のWindows/DOS環境を前提にした相対パスやドライブ名はそのままでは動かない
可能性があります。WebX68k上では、開発ツール・ライブラリ・インクルードの位置を `A:`
基準で記述してください。

### Bドライブ (`BLANK.XDF` / 作業用XDF)

`B:` はビルド対象のソース、生成物、実行用データを置く作業ディスクです。

- WebX68kのFDD1へ挿入するとゲストから `B:` として見える
- `BLANK.XDF` はフォーマット済みですが空なので、必要なディレクトリやファイルを配置する
- WebX68kの画面からFDD1用のブランクディスクを作成することもできる
- 反復ビルドでは、MCPの `disk_write_file` でBドライブへソースや成果物だけを転送できる
- 配布確認では、完成したBドライブ用XDFを固定URLから読み込むほうが再現しやすい

## 代表的なURL

ローカルHTTPサーバーでXDFを配信する場合の例です。

```text
http://localhost:5173/?fd1=./xdf/Dev68K.XDF&fd2=./xdf/BLANK.XDF&run=1&bridge=1&vpad=panel&lang=ja
```

GitHub Pagesなど別オリジンから取得する場合は、XDFのURLを指定します。

```text
https://a-fuji.github.io/WebX68k-joypad/?fd1=./game/Dev68K.XDF&fd2=./game/BLANK.XDF&run=1&bridge=1&vpad=panel&lang=ja
```

URLのXDFはHTTP(S)で取得でき、配信元がCORSを許可している必要があります。開発中は、
WebX68kとXDFを同じローカルHTTPサーバーから配信すると切り分けが容易です。

## MCPサーバーの登録

Codexでは、単一ファイル版MCPサーバーを一度登録します。

```sh
codex mcp add webx68k -- node /absolute/path/to/webx68k-mcp.mjs
codex mcp list
```

登録後は新しいCodexセッションを開始してください。すでに別のターミナルで
`node webx68k-mcp.mjs` を起動している場合、Codex側の自動起動とWebSocketポート
(`3099`)が競合するため、どちらか一方だけを起動します。

ブラウザ側は必ず `bridge=1` を付けてください。MCPサーバーは標準入出力でMCPコマンドを
受け、同じプロセスのWebSocketブリッジを通じてブラウザ内のエミュレータを操作します。

## 他プロジェクトでのビルド確認フロー

1. `Dev68K.XDF` をFDD0 (`A:`) に、`BLANK.XDF` または作業用XDFをFDD1 (`B:`) にセットする。
2. ソース、ゲーム固有インクルード、XSPオブジェクトの配置を確認する。
3. WebX68kを `run=1&bridge=1` 付きで起動する。
4. MCPの `status` で、エミュレータの起動状態とFDD0/FDD1のディスク名を確認する。
5. `disk_list_files` でBドライブの初期状態を確認する。
6. `disk_write_file` でソース・インクルード・設定・ビルド対象をBドライブへ転送する。
7. `type_text` と `key_sequence` で、Aドライブ上のビルドバッチまたはコマンドを実行する。
8. `wait_screen_change` で処理完了を待ち、`screen_text` または `screenshot` でエラーと
   生成物の起動結果を確認する。
9. 必要に応じて `disk_read_file` でBドライブから生成物やログを取り出す。

`screen_text` はTVRAM上の文字が対象で、GVRAM・背景・スプライトに描かれたゲーム画面の
文字は取得できません。ビルドログやDOSプロンプトは `screen_text`、ゲーム画面やZ-MUSICの
再生状態は `screenshot` を優先してください。

## Z-MUSICの確認

Z-MUSICのコマンドやバッチを `type_text` で実行し、次の順で確認します。

```text
type_text("A:\\BIN\\ZMSC.X ...\\n")
wait_screen_change()
screen_text()
screenshot()
```

ASCII入力のみが対象なので、全角文字や日本語ファイル名は避けてください。エラー表示が
グラフィック画面に出る場合は `screen_text` ではなく `screenshot` で確認します。

## XDFの使い分け

- 開発環境を再現したい場合: `Dev68K.XDF` + 作業用Bドライブ
- 無料体験版などの配布確認: `GDISK.XDF` をベースにゲーム固有ファイルを追加
- 一時的なビルド対象ディスク: `BLANK.XDF` またはWebX68kから作成したブランクディスク

HDDを使う構成では、HDDへのファイル書き込みはエミュレータ起動前に行う必要があります。
FDD0/FDD1は起動中でも差し替えとファイル転送が可能です。

