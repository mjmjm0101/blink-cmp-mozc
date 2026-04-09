# blink-cmp-mozc

> [!WARNING]
> このプラグインは現在試験的な開発段階にあります。
> 予告なく破壊的な変更が行われる可能性があります。
> いかなる保証も提供されず、サポートも約束されません。
> 自己責任のもとでご使用ください。

[blink.cmp](https://github.com/Saghen/blink.cmp) の補完ソースとして、macOS / Linux にインストールされた **Mozc** の変換候補を提供するプラグインです。

## 動作の仕組み

1. ユーザーがローマ字 (ASCII 小文字) を入力する
2. blink.cmp がこのソースを呼び出す
3. `mozc_emacs_helper` プロセスに変換を問い合わせる
4. 変換候補を blink.cmp の補完候補として表示する
5. 選択するとローマ字が変換後のテキストに置き換わる

## 前提条件

- macOS または Linux に Mozc がインストール済みであること
- `mozc_emacs_helper` バイナリは `:BlinkMozcInstall` で自動取得できます

## インストール

### lazy.nvim

```lua
{
  'mjmjm/blink-cmp-mozc',
  dependencies = { 'Saghen/blink.cmp' },
  build = function()
    require('blink-cmp-mozc.install').install()
  end,
  config = function()
    require('blink-cmp-mozc').setup()
  end,
}
```

初回インストール時に `mozc_emacs_helper` バイナリが自動でダウンロードされます。
手動で実行する場合は `:BlinkMozcInstall`。

## blink.cmp への組み込み

```lua
require('blink.cmp').setup({
  sources = {
    providers = {
      mozc = {
        name = 'Mozc',
        module = 'blink-cmp-mozc.source',
        score_offset = -3,
      },
    },
    default = { 'lsp', 'path', 'snippets', 'buffer', 'mozc' },
  },
})
```

## 使い方

insert モードでローマ字を入力すると、自動的に変換候補が表示されます。

```
nihongo  →  日本語入力 (にほんごにゅうりょく)
           日本語名 (にほんごめい)
           日本語タイピング (にほんごたいぴんぐ)

nippon   →  日本 (にっぽん)
            日本国 (にっぽんこく)
            日本人 (にっぽんじん)

aisatsu  →  挨拶 (あいさつ)
            あいさつ運動 (あいさつうんどう)
            挨拶文 (あいさつぶん)
```

候補を選択するとローマ字が変換後テキストに置き換わります。

## 設定オプション

```lua
require('blink-cmp-mozc').setup({
  -- mozc_emacs_helper のフルパス (nil = 自動検出)
  helper_path = nil,

  -- 変換タイムアウト (ミリ秒)
  timeout_ms = 3000,
})
```

## コマンド

| コマンド | 説明 |
|---|---|
| `:BlinkMozcInstall` | `mozc_emacs_helper` をダウンロードしてインストール |
| `:BlinkMozcStatus` | インストール状態を確認 |

## 対応環境

| OS | アーキテクチャ |
|---|---|
| macOS | x86_64 / arm64 (ユニバーサルバイナリ) |
| Linux | x86_64 |
| Linux | arm64 |

## トラブルシューティング

**候補が表示されない場合:**

`:BlinkMozcStatus` でバイナリの状態を確認してください。

手動テスト:
```bash
echo "(1 CreateSession)" | ~/.local/share/nvim/lazy/blink-cmp-mozc/bin/mozc_emacs_helper
```

## ライセンス

このプラグインのソースコード (Lua) は [MIT License](./LICENSE) のもとで公開されています。

`:BlinkMozcInstall` でダウンロードされる `mozc_emacs_helper` バイナリは [Mozc](https://github.com/google/mozc) プロジェクトのものであり、BSD 3-Clause License が適用されます。詳細は [NOTICE](./NOTICE) を参照してください。
