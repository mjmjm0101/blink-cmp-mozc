-- blink-cmp-mozc: mozc_emacs_helper との非同期通信モジュール
-- プロトコル: S式ベースの stdin/stdout 通信
--   送信: (EVENT_ID COMMAND [SESSION_ID] [ARGS...])\n
--   受信: ((emacs-event-id . N)(emacs-session-id . N)(output . (...)))\n

local M = {}

-- デフォルト設定
local config = {
  helper_path = nil, -- nil = 自動検出
  timeout_ms = 3000,
}

-- プロセス状態
local state = {
  proc = nil,
  stdin = nil,
  stdout = nil,
  buffer = "",
  event_id = 0,
  callbacks = {}, -- event_id -> function(response_line)
}

-- このファイルの場所からプラグインルートを算出
-- lua/blink-cmp-mozc/mozc.lua → ../../ = plugin root
local _plugin_root = vim.fn.fnamemodify(
  debug.getinfo(1, "S").source:sub(2), -- "=..." を除去してパスを取得
  ":p:h:h:h"
)

-- mozc_emacs_helper の実行ファイルを自動検出
-- 優先順位: 同梱バイナリ > ユーザー設定 > システムインストール
local function find_helper()
  local candidates = {
    -- 1. プラグイン同梱バイナリ (OS/アーキテクチャ別)
    _plugin_root .. "/bin/mozc_emacs_helper",
    -- 2. システムインストール
    vim.fn.expand("~") .. "/bin/mozc_emacs_helper",
    "/usr/local/bin/mozc_emacs_helper",
    "/opt/homebrew/bin/mozc_emacs_helper",
    "/usr/bin/mozc_emacs_helper",
  }
  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 and vim.fn.executable(path) == 1 then
      return path
    end
  end
  return nil
end

-- 次のイベント ID を発行
local function alloc_eid()
  state.event_id = state.event_id + 1
  return state.event_id
end

-- レスポンス行からイベント ID を抽出
local function parse_event_id(line)
  local eid = line:match("%(emacs%-event%-id %. (%d+)%)")
  return eid and tonumber(eid) or nil
end

-- レスポンス行からセッション ID を抽出
local function parse_session_id(line)
  local sid = line:match("%(emacs%-session%-id %. (%d+)%)")
  return sid and tonumber(sid) or nil
end

-- レスポンス行から変換候補を抽出
-- 戦略:
--   1. candidates セクションの (index . N)(value . "変換後") でインデックス順に値を取得
--   2. all-candidate-words セクションの (key . "よみ")(value . "変換後") で読みを取得
--      ※ 直接変換 ("挨拶" 等) は key フィールドが省略される場合がある
--   3. 両者をマージして { label, detail } リストを構築
local function parse_candidates(line)
  -- Step 1: インデックス順に変換後テキストを収集 (candidates セクション)
  -- 形式: (index . N)(value . "X") が隣接
  local ordered = {} -- index(0-based) -> value
  local max_idx = -1
  for idx_s, value in line:gmatch('%(index %. (%d+)%)%(value %. "([^"]+)"%)') do
    local idx = tonumber(idx_s)
    if not ordered[idx] then -- 最初のマッチ (candidates セクション) を優先
      ordered[idx] = value
      if idx > max_idx then max_idx = idx end
    end
  end

  -- Step 2: 読みの lookup テーブルを構築 (key が存在する候補のみ)
  -- 形式: (key . "よみ")(value . "変換後") が隣接
  local readings = {} -- value -> reading
  for reading, value in line:gmatch('%(key %. "([^"]-)"%)%(value %. "([^"]+)"%)') do
    if reading ~= "" and not readings[value] then
      readings[value] = reading
    end
  end

  -- Step 3: インデックス順にマージ
  local candidates = {}
  for i = 0, max_idx do
    local val = ordered[i]
    if val then
      table.insert(candidates, {
        label = val,
        detail = readings[val] or "",
      })
    end
  end

  return candidates
end

-- 受信データを処理 (行単位でコールバックを呼び出す)
local function on_stdout_data(err, data)
  if err or not data then return end
  state.buffer = state.buffer .. data

  while true do
    local nl = state.buffer:find("\n", 1, true)
    if not nl then break end
    local line = state.buffer:sub(1, nl - 1)
    state.buffer = state.buffer:sub(nl + 1)

    -- emacs-event-id が含まれる行だけ処理
    local eid = parse_event_id(line)
    if eid then
      local cb = state.callbacks[eid]
      if cb then
        state.callbacks[eid] = nil
        -- メインスレッドでコールバックを実行
        vim.schedule(function()
          cb(line)
        end)
      end
    end
  end
end

-- stdin にコマンドを送信
local function send(cmd)
  if state.stdin and not state.stdin:is_closing() then
    state.stdin:write(cmd .. "\n")
  end
end

-- プロセスが起動済みか確認し、必要なら起動
local function ensure_started()
  if state.proc and not state.proc:is_closing() then return true end

  -- バイナリパスを決定
  local helper = config.helper_path or find_helper()
  if not helper then
    vim.notify(
      "blink-cmp-mozc: mozc_emacs_helper が見つかりません。\n"
        .. "config.helper_path を設定するか、~/bin/mozc_emacs_helper を配置してください。",
      vim.log.levels.ERROR
    )
    return false
  end

  -- パイプを作成
  state.stdin = vim.uv.new_pipe(false)
  state.stdout = vim.uv.new_pipe(false)
  state.buffer = ""
  state.event_id = 0
  state.callbacks = {}

  local err
  state.proc, err = vim.uv.spawn(helper, {
    stdio = { state.stdin, state.stdout, nil },
  }, function(code, signal)
    -- プロセス終了時にリセット
    state.proc = nil
    state.stdin = nil
    state.stdout = nil
  end)

  if not state.proc then
    vim.notify("blink-cmp-mozc: プロセス起動失敗: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  -- stdout の読み取りを開始 (初回グリーティングも含め処理される)
  state.stdout:read_start(on_stdout_data)
  return true
end

-- ローマ字文字列の変換候補を非同期で取得
-- @param romaji string  ASCII ローマ字 (例: "kanji", "nihongo")
-- @param callback function(candidates)
--   candidates: { {label=string, detail=string}, ... }
function M.get_candidates(romaji, callback)
  if not ensure_started() then
    callback({})
    return
  end

  -- タイムアウト処理
  local done = false
  local timer = vim.uv.new_timer()
  timer:start(config.timeout_ms, 0, function()
    if not done then
      done = true
      vim.schedule(function()
        callback({})
      end)
    end
  end)

  local function finish(candidates)
    if done then return end
    done = true
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    callback(candidates)
  end

  -- Step 1: セッションを作成
  local create_eid = alloc_eid()
  state.callbacks[create_eid] = function(resp)
    local session_id = parse_session_id(resp)
    if not session_id then
      finish({})
      return
    end

    -- Step 2: ローマ字の各文字を SendKey で送信
    for i = 1, #romaji do
      local code = romaji:byte(i)
      send(string.format("(%d SendKey %d %d)", alloc_eid(), session_id, code))
    end

    -- Step 3: スペースキー (32) を送信して変換候補を取得
    local space_eid = alloc_eid()
    state.callbacks[space_eid] = function(resp2)
      local candidates = parse_candidates(resp2)

      -- Step 4: セッションを削除 (クリーンアップ)
      send(string.format("(%d DeleteSession %d)", alloc_eid(), session_id))

      finish(candidates)
    end
    send(string.format("(%d SendKey %d 32)", space_eid, session_id))
  end

  send(string.format("(%d CreateSession)", create_eid))
end

-- プラグイン設定を反映
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

-- プロセスを明示的に終了 (プラグイン終了時などに使用)
function M.stop()
  if state.stdin and not state.stdin:is_closing() then
    state.stdin:close()
  end
  if state.stdout and not state.stdout:is_closing() then
    state.stdout:close()
  end
  if state.proc and not state.proc:is_closing() then
    state.proc:kill("sigterm")
  end
end

return M
