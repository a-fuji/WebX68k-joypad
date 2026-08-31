# Joypad / XDF 起動環境の現状とロードマップ

## 結論

現行の `master` には、当初の主要要件だったブラウザ Joypad 入力と URL 指定 XDF 起動が
すでに実装されている。新規に入力経路を作る段階ではなく、今後の中心は実機パッドでの互換性確認、
AI エージェントからの Joypad 入力注入、再現可能な XDF 配布規約、X68000 アセンブラ開発側との
E2E 統合になる。

## 現在成立している機能

### Joypad

- `navigator.getGamepads()` を毎フレーム読み、`assignPorts()` で X68000 のポート 0/1 に割り当てる。
- `GamepadManager` がボタン・軸・デッドゾーン・軸較正・機種別プリセットを扱う。
- `LibretroHost.onPoll` で RetroPad ビット列を更新し、`inputStateCb` が
  `RETRO_DEVICE_JOYPAD` として px68k-libretro へ返す。
- 2 ボタン、CPSF-MD、CPSF-SFC のパッド種別と TRG1〜TRG8 に対応する。
- Gamepad の物理入力を X68000 キーボード入力へ割り当てる経路もある。
- 割当、ポート、パッド種別は `localStorage` に保存される。
- `test/core-joystick-integration.test.ts` がコンパイル済み WASM を通してポート 0/1 の
  負論理 JoyState まで結合テストしている。

px68k-libretro は元から毎フレーム `Joystick_Update()` を呼ぶため、コアの Joypad 機能を
有効化する C 側の変更は不要だった。ホストの `input_state` 実装が必要な主要部分だったが、
これはすでに配線済みである。

#### 対象パッドと互換方針

当面の実機確認対象は次の3系統とする。

- ZUIKI X68000 Z PRODUCT EDITION JOYPAD: Chrome系ブラウザでの実機値は
  `X68000 Z JOYCARD(BLACK) (Vendor: 33dd Product: 0013)`、`mapping: ""`、12ボタン/2軸。
  方向はaxis 0/1、TRG1はbutton 2、TRG2はbutton 1（いずれも内部0始まり）と確認し、
  既知プリセットへ登録済み。
- Nintendo Switch Pro Controller（無線接続）: ブラウザが `mapping: "standard"` として
  公開する場合は XInput標準相当の既定割当を使い、そうでなければ押下検出へフォールバックする。
- Logicool F310: Xモードは標準マッピング、Dモードは non-standard の両方を確認する。

既知機種プリセットは製品名の曖昧な部分一致ではなく、実機から採取した `Gamepad.id` の
Vendor/Product IDを優先して選ぶ。ブラウザやOSによって `id`、`mapping`、ボタンindex、軸indexが
変わりうるため、次の診断値を Chrome/Edge/Firefox ごとに記録してからプリセットへ追加する。

- `id`、`mapping`、`buttons.length`、`axes.length`
- 無操作時と各ボタン押下時の `buttons[].pressed`
- 無操作時、十字キー、スティック、トリガ操作時の `axes[]`
- USB/無線、F310のX/Dモードによる差

未知の non-standard パッドを全未割当で始める現仕様は、誤ったindexを推測して入力が固着するのを
避ける安全側の設計である。初回設定を簡単にするには、将来的に「方向→TRG1→TRG2の順に押す」
セットアップウィザードを追加し、完了したプロファイルを現在と同様に `Gamepad.id` ごとに保存する。

### XDF の URL 起動

- `fd1` / `fd2` に XDF などの FD イメージ URL を指定できる。
- `hdd` に HDD イメージ URL を指定できる。
- `run=1` で起動オーバーレイを待たずに自動起動できる。
- `system=1` で同梱 `human302.xdf` を FDD1 に設定できる。
- ZIP / LZH を URL に指定でき、単一ディスクなら対象スロットへ、複数ディスクなら
  ライブラリへ登録する。
- 取得したイメージは IndexedDB に保存され、ゲストの変更もオートセーブされる。

代表例:

```text
http://localhost:5173/?fd1=./system/human302.xdf&run=1
```

URL が別オリジンの場合、配信元に CORS ヘッダーが必要である。

### AI / ブラウザ操作

- `?bridge=1` の MCP ブリッジは画面、TVRAM テキスト、キー、マウス、リセット、ステート、
  ディスク挿抜、FAT ファイル操作、メモリ読み取りを提供する。
- URL 起動と MCP を組み合わせれば、アセンブラ側で作った XDF を配信し、起動後の画面・
  テキスト・メモリを Codex から検査できる。
- ブラウザ操作だけでも URL 遷移、起動状態、canvas、エラーの有無は検証できる。

## 残っている課題

### 1. 自動化用 Joypad 注入経路

ブラウザ自動操作は通常、物理 Gamepad API の接続・ボタン状態を生成できない。現状の
`window.__webx68kDebug.joy()` は観測専用であり、MCP にも Joypad 注入ツールが無い。
したがって純粋ロジックと WASM 結合テストは自動化できる一方、実ブラウザの
`navigator.getGamepads()` からゲストまでの E2E は物理パッドに依存する。

次の実装候補:

1. `LibretroHost` にテスト用の仮想 Joypad 状態を重ねる入力源を設ける。
2. MCP に `joypad_set` / `joypad_release_all` を追加する。
3. 開発ビルドでは同じ経路を `window.__webx68kDebug` から呼べるようにする。
4. ゲスト側の Joypad テストプログラムを XDF に入れ、画面またはメモリ上の結果を検査する。

この経路は通常の物理パッド処理と競合しないよう、ポートごとに入力源を OR 合成し、切断時・
リセット時・MCP 切断時に全解放する必要がある。

### 2. 再現可能な URL 公開

同じ URL のディスクは IndexedDB の保存済みイメージを優先し、ゲスト書き込みも残る。
遊ぶ用途には便利だが、ビルド成果物の再現確認では以前の状態が混ざりうる。

開発・CI 用には次を検討する。

- 成果物ごとに内容ハッシュまたはビルド ID を URL パスへ含める。
- URL から取得したバイト列の SHA-256 を任意パラメータで検証する。
- IndexedDB を使わない一時実行モード、または明示的な再取得モードを追加する。
- 公開 XDF は CORS、正しい MIME type、キャッシュ方針を含めて静的ホスティングする。

### 3. アセンブラ開発プロジェクトとの受け渡し

推奨する最小フロー:

1. アセンブラプロジェクトでバイナリをビルドする。
2. テンプレート XDF へ成果物と必要な起動スクリプトを格納する。
3. ローカル HTTP サーバーまたは静的ホスティングで XDF を配信する。
4. WebX68k を `?fd1=<encoded-xdf-url>&run=1&bridge=1` で開く。
5. MCP の `wait_screen_change`、`screen_text`、`screenshot`、`read_memory` で結果を検査する。
6. Joypad を使うプログラムは、追加予定の仮想 Joypad MCP ツールで入力を注入する。

XDF 全体を毎回作り直す方法に加え、既存の `disk_write_file` で起動前の FAT ディスクへ
成果物だけを書き込む方法も使える。ただし大きなソースの多クラスタ転送は未検証であるため、反復開発ではホスト側のXDF生成も併用する。これまでの実測と制限は
[X68000 検証履歴と別Mac向け再現手順](X68K_VERIFICATION_HISTORY.ja.md)に記録している。

## 推奨する作業順

1. 仮想 Joypad 入力源と単体テストを追加する。
2. MCP の Joypad 操作ツールと切断時全解放を追加する。
3. Joypad 入力表示用の小さな X68000 テストプログラム/XDF でブラウザ E2E を作る。
4. URL ディスクの一時実行または強制再取得モードを追加する。
5. アセンブラプロジェクト側に「ビルド→XDF生成/更新→HTTP配信→WebX68k起動→検査」の
   コマンドをまとめる。
6. GitHub Pages 等へ固定 URL で公開し、CORS とキャッシュを本番条件で確認する。

## 2026-08-09 の基準確認

- `npm test`: 15 test files / 220 tests passed。
- `npm run build`: TypeScript と Vite の本番ビルド成功。
- 実ブラウザで `?fd1=./system/human302.xdf&run=1` を開き、FDD1 が `human302.xdf`、
  起動オーバーレイ非表示、リセット操作有効、canvas 768x512、コンソールエラーなしを確認。
- ローカルのゲーム用イメージ `BWR1.XDF`（1,261,568 bytes、SHA-256
  `12443987ccd47cc931899d568d4851694416156208419ba78047f1d25586f956`）を本番ビルドと
  同一オリジンから配信し、`?fd1=./BWR1.XDF&run=1` でFDD1へ挿入、canvas 256x256、
  「BEOWULF」タイトル画面まで到達、コンソールエラーなしを確認。
- 初回のブラウザ検証では物理パッドが公開されておらず、Joypad設定画面は未検出だった。
  Switch Pro/F310のプリセット確定には、実機を接続した通常ブラウザでボタンを一度押し、
  診断値を採取する必要がある。
- その後ZUIKI X68000 Z JOYCARD(BLACK)を接続して再検証し、Vendor/Product、12ボタン/2軸、
  non-standard mappingと全6入力を採取した。BWR1.XDF上でTRG1によりタイトルからゲームを開始し、
  右入力でキャラクター移動・画面スクロール・スコア進行まで確認できたため、
  Gamepad APIから実ゲームまでの実機E2Eが成立している。
