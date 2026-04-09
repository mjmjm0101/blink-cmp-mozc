-- blink-cmp-mozc: バイナリのダウンロード・インストール
--
-- lazy.nvim の build フック (同期実行):
--   build = function() require('blink-cmp-mozc.install').install() end
--
-- 手動インストール:
--   :BlinkMozcInstall

local M = {}

local REPO = "mjmjm0101/blink-cmp-mozc"

-- OS/アーキテクチャからバイナリ名を決定
local function get_binary_name()
  local uname = vim.uv.os_uname()
  local sysname = uname.sysname:lower()
  local machine = uname.machine:lower()

  if sysname == "darwin" then
    return "mozc_emacs_helper_macos" -- ユニバーサルバイナリ (x86_64 + arm64)
  elseif sysname == "linux" then
    if machine:match("aarch64") or machine:match("arm64") then
      return "mozc_emacs_helper_linux_arm64"
    else
      return "mozc_emacs_helper_linux_x86_64"
    end
  end
  return nil
end

-- プラグインの bin/ ディレクトリパス
local function get_bin_dir()
  local this_file = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(this_file, ":p:h:h:h") .. "/bin"
end

-- curl が使えるか確認
local function check_curl()
  return vim.fn.executable("curl") == 1
end

-- バイナリをダウンロードしてインストール (同期)
-- lazy.nvim の build フックおよび :BlinkMozcInstall から呼び出す
function M.install()
  if not check_curl() then
    vim.notify("blink-cmp-mozc: curl が必要です", vim.log.levels.ERROR)
    return false
  end

  local binary_name = get_binary_name()
  if not binary_name then
    vim.notify(
      "blink-cmp-mozc: 対応していない OS/アーキテクチャです: " .. vim.uv.os_uname().sysname,
      vim.log.levels.ERROR
    )
    return false
  end

  local bin_dir = get_bin_dir()
  local dest = bin_dir .. "/mozc_emacs_helper"

  -- 既にインストール済みか確認
  if vim.fn.executable(dest) == 1 then
    vim.notify("blink-cmp-mozc: インストール済みです: " .. dest)
    return true
  end

  vim.fn.mkdir(bin_dir, "p")

  -- Step 1: 最新リリース情報を取得 (同期)
  local api_url = string.format("https://api.github.com/repos/%s/releases/latest", REPO)
  vim.notify("blink-cmp-mozc: リリース情報を取得中...")

  local json = vim.fn.system({ "curl", "-fsSL", api_url })
  if vim.v.shell_error ~= 0 then
    vim.notify("blink-cmp-mozc: リリース情報の取得に失敗しました", vim.log.levels.ERROR)
    return false
  end

  -- ダウンロード URL を抽出
  local url = json:match('"browser_download_url":"([^"]+' .. binary_name .. '[^"]*)"')
  if not url then
    vim.notify(
      "blink-cmp-mozc: " .. binary_name .. " のダウンロード URL が見つかりません",
      vim.log.levels.ERROR
    )
    return false
  end

  -- Step 2: バイナリをダウンロード (同期)
  vim.notify("blink-cmp-mozc: ダウンロード中: " .. url)
  vim.fn.system({ "curl", "-fsSL", "-o", dest, url })
  if vim.v.shell_error ~= 0 then
    vim.fn.delete(dest) -- 不完全なファイルを削除
    vim.notify("blink-cmp-mozc: ダウンロードに失敗しました", vim.log.levels.ERROR)
    return false
  end

  -- Step 3: 実行権限を付与
  vim.fn.system({ "chmod", "+x", dest })

  vim.notify("blink-cmp-mozc: インストール完了: " .. dest)
  return true
end

-- インストール状態を表示
function M.status()
  local bin_dir = get_bin_dir()
  local dest = bin_dir .. "/mozc_emacs_helper"
  if vim.fn.executable(dest) == 1 then
    vim.notify("blink-cmp-mozc: インストール済み (" .. dest .. ")")
  else
    vim.notify("blink-cmp-mozc: 未インストール (:BlinkMozcInstall で導入できます)")
  end
end

return M
