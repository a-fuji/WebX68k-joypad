# 海賊王ゲーム

X68000 / Human68k用の固定画面シューティングです。非公式ファンゲームとして、後ろ向きのルフィ風ドット絵、百獣海賊団の手下風の敵、ビッグ・マムとカイドウの2ステージを扱います。タイトルはユーザー提供画像を変換して使用します。

矢印キーまたはジョイスティックの8方向で移動し、Z / TRG1でショット、X / TRG2で全体攻撃を出します。全体攻撃ではゾロ・サンジ風の援護が交互に登場します。Rで最初から再開、ESCでHuman68kへ終了します。ゲームオーバーと全ステージクリア後もZ / TRG1で再開できます。

| ファイル | 役割 |
| --- | --- |
| `PIRATE.S` | ゲームループ、入力、当たり判定、ステージ進行、タイトル表示 |
| `STATE.INC` | MCPで読み取る`P68KSTAT`構造体のフィールド位置 |
| `ART.INC` | 自作5×7フォント |
| `VIDEO.INC` | XSPスプライト、背景、文字レイヤー、援護演出 |
| `assets/` | 変換元PNGと素材記録 |
| `SOUND.INC` | Z-MUSIC v2のBGM・FM効果音・ZPD効果音、外部データ読込み |
| `audio.json` | 暫定音声の抽出元とPCM番号 |
| `BUILD.BAT` | Human68k上でのHAS060・HLK実行 |

実行環境のWebX68kとは別のソースツリーです。XSP2libをビルド時にリンクします。音声は差し替え可能な外部ファイルで、当面はユーザーの指定によりMaidLandのZMD・FM効果音・ZPDを流用します。音声バイナリとZMSCは外部資料からローカルに抽出し、Gitには含めません。

- [音声の生成・差し替え・音楽版の検証](../../docs/pirate68k/AUDIO.ja.md)
- [生成・ビルド・MCP検証の手順](../../docs/X68K_ORIGINAL_GAME.ja.md)
- [最小仕様と設計理由](../../docs/pirate68k/DESIGN.ja.md)
- [開発・検証記録と制限](../../docs/pirate68k/VERIFICATION.ja.md)
- [次版作業の引き継ぎ](../../docs/pirate68k/NEXT_VERSION_HANDOFF.ja.md)
