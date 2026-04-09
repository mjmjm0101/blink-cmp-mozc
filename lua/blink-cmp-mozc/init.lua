-- blink-cmp-mozc: エントリポイント
-- 使用例:
--   require('blink-cmp-mozc').setup({ helper_path = '/path/to/mozc_emacs_helper' })
--
-- blink.cmp 設定例:
--   require('blink.cmp').setup({
--     sources = {
--       providers = {
--         mozc = {
--           name = 'Mozc',
--           module = 'blink-cmp-mozc.source',
--         },
--       },
--       default = { 'lsp', 'path', 'snippets', 'buffer', 'mozc' },
--     },
--   })

local M = {}

M.default_config = {
  -- mozc_emacs_helper のパス (nil = 自動検出)
  helper_path = nil,
  -- 変換タイムアウト (ミリ秒)
  timeout_ms = 3000,
  -- blink.cmp ソースを自動登録するか
  auto_register = false,
}

-- プラグインを初期化
-- @param opts table|nil  設定オプション
function M.setup(opts)
  local cfg = vim.tbl_extend("force", M.default_config, opts or {})
  require("blink-cmp-mozc.mozc").setup(cfg)
end

-- blink.cmp ソースクラスを返す (blink.cmp が module として require する際に使用)
-- 通常は source.lua を直接 module に指定するため、このメソッドは補助用
function M.new(opts)
  return require("blink-cmp-mozc.source").new(opts)
end

return M
