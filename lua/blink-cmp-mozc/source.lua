-- blink-cmp-mozc: blink.cmp ソースモジュール
-- blink.cmp の sources.providers.{name}.module に "blink-cmp-mozc.source" を指定して使用

local mozc = require("blink-cmp-mozc.mozc")

local source = {}

-- ソースインスタンスを生成 (blink.cmp が呼び出す)
function source.new(opts)
  return setmetatable({ opts = opts or {} }, { __index = source })
end

-- blink.cmp のコンテキストから行テキストとカーソル列 (0-indexed) を取得
local function extract_ctx_info(ctx)
  local line = ctx.line or ctx.cursor_line or ""
  -- cursor は {row, col} 配列か {row=r, col=c} 名前付きテーブル
  local col
  if ctx.cursor then
    col = ctx.cursor[2] or ctx.cursor.col or 0
  else
    col = ctx.cursor_col or 0
  end
  local row
  if ctx.cursor then
    row = ctx.cursor[1] or ctx.cursor.row or 0
  else
    row = ctx.cursor_row or 0
  end
  return line, col, row
end

-- カーソル前のローマ字単語を取得
-- @return word string|nil  ローマ字単語
-- @return word_start number  単語の開始カラム (0-indexed)
-- @return cursor_row number  カーソル行 (0-indexed)
-- @return cursor_col number  カーソル列 (0-indexed)
local function get_romaji_before_cursor(ctx)
  local line, col, row = extract_ctx_info(ctx)

  -- カーソル前のテキストから末尾の小文字 ASCII を抽出
  local before = line:sub(1, col)
  local word = before:match("([a-z]+)$")
  if not word then
    return nil, col, row, col
  end
  local word_start = col - #word
  return word, word_start, row, col
end

-- このソースを有効にするかどうか (任意)
function source:enabled()
  return true
end

-- blink.cmp がソースに補完を要求する際に呼び出す
function source:get_completions(ctx, callback)
  local word, word_start, cursor_line, cursor_col = get_romaji_before_cursor(ctx)

  -- 最低文字数チェック (2文字未満はスキップ)
  if not word or #word < 2 then
    callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = {},
    })
    return
  end

  -- mozc に変換候補を問い合わせ
  mozc.get_candidates(word, function(candidates)
    local items = {}
    for i, cand in ipairs(candidates) do
      -- blink.cmp に渡すアイテム (LSP CompletionItem 形式)
      table.insert(items, {
        label = cand.label,
        -- kind 1 = Text
        kind = 1,
        -- detail にひらがな読みを表示
        detail = cand.detail or "",
        -- filterText にローマ字を指定して絞り込みを有効化
        filterText = word,
        -- sortText で順序を保持
        sortText = string.format("%04d", i),
        -- textEdit でローマ字範囲をそのまま変換後テキストで置換
        textEdit = {
          newText = cand.label,
          range = {
            start = { line = cursor_line, character = word_start },
            ["end"] = { line = cursor_line, character = cursor_col },
          },
        },
      })
    end

    callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = items,
    })
  end)
end

return source
