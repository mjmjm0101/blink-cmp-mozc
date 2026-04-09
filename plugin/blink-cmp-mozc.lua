-- blink-cmp-mozc: 自動ロード用プラグインエントリ

if vim.g.loaded_blink_cmp_mozc then return end
vim.g.loaded_blink_cmp_mozc = true

-- :BlinkMozcInstall — バイナリをダウンロードしてインストール
vim.api.nvim_create_user_command("BlinkMozcInstall", function()
  require("blink-cmp-mozc.install").install()
end, { desc = "blink-cmp-mozc: mozc_emacs_helper をダウンロードしてインストール" })

-- :BlinkMozcStatus — インストール状態を確認
vim.api.nvim_create_user_command("BlinkMozcStatus", function()
  require("blink-cmp-mozc.install").status()
end, { desc = "blink-cmp-mozc: インストール状態を確認" })

-- Neovim 終了時にプロセスをクリーンアップ
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("blink_cmp_mozc_cleanup", { clear = true }),
  callback = function()
    local ok, mozc = pcall(require, "blink-cmp-mozc.mozc")
    if ok then mozc.stop() end
  end,
})
