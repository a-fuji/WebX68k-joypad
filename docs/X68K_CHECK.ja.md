# X68000 実行確認ランブック

この文書は、このリポジトリのWebX68k本体をローカルで起動し、ブラウザ上のX68000をMCPクライアントから確認する手順を定める。MCPサーバーのツール一覧と制約は [mcp/README.md](../mcp/README.md)、アプリの設計は [DESIGN.md](DESIGN.md) が正本である。これまでの実験結果と別Macでの再現手順は [X68000 検証履歴と別Mac向け再現手順](X68K_VERIFICATION_HISTORY.ja.md) にまとめている。

## 前提

- Node.js 18以上
- npm
- MCPクライアント（Codexなど）
- ブラウザ

このチェックではエミュレータコアを再ビルドしない。リポジトリにコミット済みの `public/core/px68k_libretro.js` / `.wasm` と `public/system/` のROM・システムディスクを使う。コアを更新する作業は [DESIGN.md のコアのビルド手順](DESIGN.md#コアのビルド手順) を参照する。

## 初回セットアップ

リポジトリのルートで、アプリとMCPサーバーの依存をそれぞれインストールする。

```sh
npm ci
npm --prefix mcp ci
```

MCPクライアントへ登録する場合は、`mcp/server.mjs` を絶対パスで指定する。例えばClaude Codeでは次のように登録する。

```sh
claude mcp add webx68k -- node "/絶対パス/WebX68k-joypad/mcp/server.mjs"
```

単一ファイルの配布版を使う場合は [mcp/README.md](../mcp/README.md) のRelease手順に従う。ローカル確認ではチェックアウト中の `mcp/server.mjs` を使うため、MCPの変更をすぐ検証できる。

## 起動

ルートで次のコマンドを実行する。このコマンドはWebサーバーだけを起動する。MCPサーバーはstdioをMCPクライアントが管理して起動するため、別プロセスとして手動起動しない。

```sh
npm run check:local
```

表示された確認用URLをブラウザで開く。標準ポートなら次のURLになる。

```text
http://127.0.0.1:5299/?bridge=3099&system=1&run=1
```

`bridge=1` は既定の3099番ポートを使う指定でもある。MCPブリッジのポートを変更する場合は、サーバーとページで同じ番号を指定する。

```sh
WEBX68K_WEB_PORT=5300 WEBX68K_BRIDGE_PORT=3199 npm run check:local
```

この場合は `http://127.0.0.1:5300/?bridge=3199&system=1&run=1` を開く。MCPクライアント側でも
`WEBX68K_BRIDGE_PORT=3199` をMCPサーバーの環境変数に設定する。ポートを変更したページでは
`bridge=1` に戻さないこと。

## 確認項目

### 1. ブラウザ側

- ページが表示される。
- FDD0に `human302.xdf` と表示される。
- `run=1` により起動オーバーレイが表示されない。
- エミュレータ画面が表示される。
- ブラウザの開発者コンソールに起動失敗やアセット取得失敗がない。

自動再生制限により、`run=1` の起動直後は音声が無効になることがある。画面をクリックするかキーを入力すれば音声が有効になる。

### 2. MCP側

MCPクライアントからまず `status` を呼ぶ。`running` が `true` で、FDD0に `human302.xdf` が入っていれば、stdioとWebSocketブリッジの接続は成立している。

続けて `screen_text` を呼ぶと、Human68kのテキスト画面を行配列と認識診断で確認できる。文字がGVRAM・BG・スプライトに描かれるソフトでは `screen_text` が空または `coverage` が低くなるため、`screenshot` を使う。

### 3. 独自XDF

同梱の確認用XDFをURLで起動する場合は、次のように `fd1` を指定する。

```text
http://127.0.0.1:5299/?bridge=3099&fd1=./game/MDTK.XDF&run=1
```

MCPの `status` でFDD0の名前が `MDTK.XDF` になり、画面サイズなどの実行状態が返れば、URL取得・XDF装填・コア起動・MCP接続を一続きで確認できる。ゲーム画面は主にグラフィック画面なので、結果判定は `screenshot` を基本とし、`screen_text` の空結果を失敗とみなさない。

外部で公開するXDFを確認する場合は、`fd1` にそのURLを指定する。配布元はCORSに対応している必要があり、同じURLを再訪したときはブラウザのIndexedDBに保存済みのイメージが優先される。配布物の内容を取り直す必要がある場合は、URLのパスまたはクエリに内容を識別する値を含めるか、ブラウザ側の保存済みディスクを整理してから確認する。

開発用のXDFをファイル選択で確認する場合、開発ディスク単体をFDD0に入れても起動用のHuman68kが無いため、起動エラーになることがある。起動確認は、FDD0に同梱の`human302.xdf`を入れて起動した後、FDD1へ開発用XDFを入れる構成で行う。MCPの`status`でFDD0/FDD1の名前を確認し、`disk_list_files`で開発ディスクのルートまたは作業ディレクトリを列挙する。

### 開発確認の標準方針

今後の基本的な開発環境の実行確認は、アセンブラとリンカを含む専用の開発用XDFを正本として行う。開発用XDFには、Human68k上でのビルドに必要なツール、ソース配置、実行確認用のバッチまたは手順をまとめ、XDF単位で再現できる環境にする。

開発用XDFが起動可能な構成ならFDD0から直接起動する。データディスク形式の場合は、FDD0に`human302.xdf`、FDD1に開発用XDFを入れる。現在の`ASM.XDF`はソース確認用、`ZMP7.XDF`はZ-MUSICのコンパイル・再生確認用、`BLANK.XDF`は一時的な転送先として扱い、通常の開発確認の正本にはしない。

### SCSI HDDイメージ（HDS）

現在のHDD処理は、`src/disk-store.ts`の`HDD_EXTENSIONS`で分類される`.hdf`/`.dup`と、`src/api/fat.ts`の`HUMAN68K_PARTITION_TABLE_OFFSET`が示す、先頭`0x400`から始まるヘッダー無しのHuman68kイメージを対象にしている。

X68000 SCSI用の`.HDS`はそのまま投入できない。`SCSIHDD.HDS`のようなイメージは`X68SCSI1`ヘッダーを持ち、`X68K`パーティションテーブルもファイル先頭から`0x800`にあるため、現在のHDF判定位置と一致しない。拡張子を`.hdf`へ変更したり、先頭ヘッダーを単純に削除したりするだけでは変換にならない。HDSをテストに使う場合は、元ファイルを保持したまま、HDS形式とWebX68kのraw HDF形式の論理ブロック配置を理解した変換またはアダプターを別途用意する。

HDS と Z-MUSIC の開発・コンパイル検証、HDSからの移行候補は [HDS と Z-MUSIC 開発検証の実現可能性](X68K_HDS_ZMUSIC_FEASIBILITY.ja.md) にまとめている。

## 自動検証

ローカル起動の前に、コード・本番ビルド・MCPバンドルを確認する。

```sh
npm test
npm run build
npm --prefix mcp run bundle
node scripts/smoke-test-mcp-bundle.mjs mcp/dist/webx68k-mcp.mjs
```

最後のスモークテストは、単一ファイルMCPサーバーを起動し、`initialize`、`tools/list`、WebSocketブリッジの待受を確認する。ローカルTCPポートの待受が環境により制限される場合は、権限付きのターミナルで実行する。

## うまく接続できない場合

- MCPクライアントのエラーが「ブラウザタブが接続されていません」の場合、URLに `bridge=1` または正しい `bridge=<ポート>` が付いているか確認する。
- MCPサーバーの `WEBX68K_BRIDGE_PORT` とブラウザの `bridge` の番号が一致しているか確認する。
- WebSocketポート3099が使用中の場合は、別の `WEBX68K_BRIDGE_PORT` を指定して起動し、同じ番号をURLにも指定する。
- XDFを取得できない場合は、ブラウザからURLへアクセスできること、配布元のCORS、ファイルの拡張子・内容を確認する。
- `screen_text` で文字が読めない場合は、画面がTVRAMを使っているかを確認し、GVRAM描画なら `screenshot` を使う。

終了は `npm run check:local` を実行したターミナルで `Ctrl-C` を押す。MCPクライアントの登録を削除する必要はない。MCPクライアントを終了すれば、そのクライアントが起動したMCPサーバーとブリッジも終了する。
