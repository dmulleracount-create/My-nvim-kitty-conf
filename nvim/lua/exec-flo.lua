local json_path = vim.fn.stdpath("data") .. "/custom_commands_final.json"

-- ==========================================================================
-- 1. COLORES TOKYONIGHT
-- ==========================================================================
local colors = {
  bg = "#1a1b26", fg = "#c0caf5", border = "#292e42",
  blue = "#7aa2f7", purple = "#bb9af7", dim_fg = "#565f89"
}

vim.api.nvim_set_hl(0, "CmdNormal", { bg = colors.bg, fg = colors.fg })
vim.api.nvim_set_hl(0, "CmdBorder", { fg = colors.border, bg = colors.bg })
vim.api.nvim_set_hl(0, "CmdName", { fg = colors.blue, bold = true })
vim.api.nvim_set_hl(0, "CmdDefaultMark", { fg = colors.purple, bold = true })
vim.api.nvim_set_hl(0, "CmdSeparator", { fg = colors.border })
vim.api.nvim_set_hl(0, "CmdStats", { fg = colors.border, bold = true })
vim.api.nvim_set_hl(0, "CmdTitle", { fg = colors.blue, bg = colors.bg, bold = true })
vim.api.nvim_set_hl(0, "CmdSidebarSel", { fg = colors.blue, bold = true })
vim.api.nvim_set_hl(0, "CmdActive", { fg = colors.fg, bold = true })
vim.api.nvim_set_hl(0, "CmdDesc", { fg = colors.dim_fg, italic = true })

-- ==========================================================================
-- 2. PERSISTENCIA JSON
-- ==========================================================================
local function save_data(cmds, idx)
  local f = io.open(json_path, "w")
  if f then
    f:write(vim.fn.json_encode({ commands = cmds, default_idx = idx }))
    f:close()
  end
end

local function load_data()
  local f = io.open(json_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, decoded = pcall(vim.fn.json_decode, content)
    if ok then return decoded.commands, (decoded.default_idx or 1) end
  end
  return {
    { name = "Listar Archivos", cmd = "ls -la", icon = " " },
    { name = "Estado Git", cmd = "git status", icon = "󰊢 " }
  }, 1
end

local user_commands, default_cmd_idx = load_data()
_G.user_commands = user_commands

-- ==========================================================================
-- 3. TERMINAL FLOTANTE
-- ==========================================================================
local function run_terminal(cmd_str, title)
  local is_expanded = false
  local tw, th = math.floor(vim.o.columns * 0.3), math.floor(vim.o.lines * 0.4)
  local t_buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(t_buf, true, {
    relative = "editor", width = tw, height = th,
    row = vim.o.lines - th - 5, col = vim.o.columns - tw - 2,
    style = "minimal", border = "single",
    title = { { "   " .. title .. " ", "CmdTitle" } }
  })
  _G.exec_float_win = win
  _G.last_float_win = win
  vim.api.nvim_set_option_value("winhl", "Normal:CmdNormal,FloatBorder:CmdBorder", { win = win })
  vim.fn.termopen(cmd_str)
  vim.cmd("startinsert")

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = t_buf, once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end
  })

  vim.keymap.set({"n", "i", "t"}, "<C-b>", function()
    is_expanded = not is_expanded
    local new_w = math.floor(vim.o.columns * (is_expanded and 0.5 or 0.3))
    local new_h = math.floor(vim.o.lines * (is_expanded and 0.6 or 0.4))
    vim.api.nvim_win_set_config(win, {
      relative = "editor", width = new_w, height = new_h,
      row = vim.o.lines - new_h - 5, col = vim.o.columns - new_w - 2,
    })
  end, { buffer = t_buf, silent = true })
end

-- ==========================================================================
-- 4. GESTOR DE COMANDOS (TUI)
-- ==========================================================================
local function open_command_manager()
  local parent_editor_win = vim.api.nvim_get_current_win()
  local width = math.floor(vim.o.columns * 0.35)
  local height = math.floor(vim.o.lines * 0.4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local ns_id = vim.api.nvim_create_namespace("cmd_tui_selector")
  local sel_ns_id = vim.api.nvim_create_namespace("cmd_tui_overlays")

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor", width = width, height = height,
    row = row, col = col, style = "minimal", border = "single",
    title = { { "   Comandos ", "CmdTitle" } }, title_pos = "center"
  })
  vim.api.nvim_set_option_value("winhl", "Normal:CmdNormal,FloatBorder:CmdBorder", { win = win })
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("breakindent", true, { win = win })
  vim.api.nvim_set_option_value("breakindentopt", "shift:0", { win = win })

  local selected_idx = 1
  local filtered_items = {}
  local line_map = {}
  local current_search_text = ""
  local prefix = " > "
  local prefix_len = #prefix
  local window_start = 1
  local max_lines_for_list = height - 2

  local function close_safe()
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
    vim.cmd("stopinsert")
  end

  local function attach_behavior_hooks()
    pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "CmdTUIBehavior" })
    vim.api.nvim_create_autocmd({ "InsertLeave", "WinLeave" }, {
      buffer = bufnr, group = "CmdTUIBehavior",
      callback = function() vim.schedule(close_safe) end
    })
    local bv = string.char(22)
    vim.api.nvim_create_autocmd("ModeChanged", {
      buffer = bufnr, group = "CmdTUIBehavior",
      callback = function()
        local m = vim.v.event.new_mode
        if m == "n" or m == "v" or m == "V" or m == bv then vim.schedule(close_safe) end
      end
    })
  end
  vim.api.nvim_create_augroup("CmdTUIBehavior", { clear = true })
  attach_behavior_hooks()

  local function render()
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

    local first_line = prefix .. current_search_text
    local separator = string.rep("─", width)

    filtered_items = {}
    local raw_tui_lines = {}

    local filter = current_search_text:gsub("^%s*(.-)%s*$", "%1"):lower()

    for i, entry in ipairs(_G.user_commands or user_commands) do
      if filter == "" or entry.name:lower():find(filter, 1, true) or entry.cmd:lower():find(filter, 1, true) or (entry.desc or ""):lower():find(filter, 1, true) then
        table.insert(filtered_items, { idx = i, data = entry })
      end
    end

    if #filtered_items == 0 then
      selected_idx = 0
      window_start = 1
    else
      if selected_idx > #filtered_items then selected_idx = #filtered_items end
      if selected_idx < 1 then selected_idx = 1 end
    end

    for i, item in ipairs(filtered_items) do
      local is_sel = (i == selected_idx)
      local icon = string.format("%-3s", item.data.icon or ">_")
      table.insert(raw_tui_lines, string.format("    %s %s", icon, item.data.name))
      line_map[#raw_tui_lines] = { item_idx = i, part = "main", is_sel = is_sel }
      local desc = item.data.desc or ""
      table.insert(raw_tui_lines, string.format("    · %s", desc))
      line_map[#raw_tui_lines] = { item_idx = i, part = "sub", is_sel = is_sel }
    end

    local target_raw_line = 1
    for l_idx, m in ipairs(line_map) do
      if m.item_idx == selected_idx then target_raw_line = l_idx; break end
    end

    if selected_idx > 0 and #raw_tui_lines > 0 then
      if target_raw_line < window_start then
        window_start = target_raw_line
      elseif target_raw_line > window_start + max_lines_for_list - 1 then
        window_start = target_raw_line - max_lines_for_list + 1
      end
    end
    if window_start < 1 then window_start = 1 end

    local display_lines = { first_line, separator }
    local new_line_map = {}

    for i = window_start, math.min(#raw_tui_lines, window_start + max_lines_for_list - 1) do
      table.insert(display_lines, raw_tui_lines[i])
      new_line_map[#display_lines] = line_map[i]
    end
    line_map = new_line_map

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_lines)
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_clear_namespace(bufnr, sel_ns_id, 0, -1)

    vim.api.nvim_buf_add_highlight(bufnr, ns_id, "CmdTitle", 0, 0, 1)
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, "CmdSeparator", 1, 0, -1)

    for buf_line_idx, mapping in pairs(line_map) do
      if mapping.is_sel then
        vim.api.nvim_buf_set_extmark(bufnr, sel_ns_id, buf_line_idx - 1, 0, {
          virt_text = { { "│", "CmdSidebarSel" } },
          virt_text_pos = "overlay"
        })
      end
      local item = filtered_items[mapping.item_idx]
      if mapping.part == "main" then
        if item and item.idx == default_cmd_idx then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, "CmdName", buf_line_idx - 1, 4, -1)
        end
      elseif mapping.part == "sub" then
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "CmdDesc", buf_line_idx - 1, 6, -1)
      end
    end

    local total = #filtered_items
    local current = selected_idx
    local stats_str = string.format(" %d/%d ", current, total)
    vim.api.nvim_win_set_config(win, { footer = { { stats_str, "CmdStats" } }, footer_pos = "right" })
    pcall(vim.api.nvim_win_set_cursor, win, { 1, prefix_len + #current_search_text })
  end

  render()

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    buffer = bufnr, callback = function()
      local line_content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
      current_search_text = line_content:sub(prefix_len + 1)
      render()
    end
  })

  vim.api.nvim_create_autocmd("CursorMovedI", {
    buffer = bufnr, callback = function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[1] ~= 1 then pcall(vim.api.nvim_win_set_cursor, win, { 1, prefix_len + #current_search_text })
      elseif cursor[2] < prefix_len then pcall(vim.api.nvim_win_set_cursor, win, { 1, prefix_len }) end
    end
  })

  -- ==========================================================================
  -- MAPEOS EN MODO INSERTAR
  -- ==========================================================================
  local opt_i = { buffer = bufnr, silent = true }

  vim.keymap.set("i", "<Down>", function()
    if selected_idx < #filtered_items then selected_idx = selected_idx + 1 render() end
  end, opt_i)
  vim.keymap.set("i", "<C-j>", function()
    if selected_idx < #filtered_items then selected_idx = selected_idx + 1 render() end
  end, opt_i)
  vim.keymap.set("i", "<Up>", function()
    if selected_idx > 1 then selected_idx = selected_idx - 1 render() end
  end, opt_i)
  vim.keymap.set("i", "<C-k>", function()
    if selected_idx > 1 then selected_idx = selected_idx - 1 render() end
  end, opt_i)
  vim.keymap.set("i", "<Esc>", close_safe, opt_i)
  vim.keymap.set("i", "q", close_safe, opt_i)

  vim.keymap.set("i", "<CR>", function()
    if selected_idx == 0 or #filtered_items == 0 then return end
    local item = filtered_items[selected_idx]

    pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "CmdTUIBehavior" })
    close_safe()

    if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end
    if item then run_terminal(item.data.cmd, item.data.name) end
  end, opt_i)

  vim.keymap.set("i", "b", function()
    if selected_idx == 0 or #filtered_items == 0 then return end
    default_cmd_idx = filtered_items[selected_idx].idx
    save_data(_G.user_commands or user_commands, default_cmd_idx)
    render()
  end, opt_i)

  vim.keymap.set("i", "<C-a>", function()
    pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "CmdTUIBehavior" })
    if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end
    if _G.open_input_creator_global then
      _G.open_input_creator_global()
      vim.api.nvim_feedkeys("-x ", "n", false)
    end
  end, opt_i)

  vim.keymap.set("i", "<C-d>", function()
    if selected_idx == 0 or #filtered_items == 0 then return end
    local item = filtered_items[selected_idx]

    pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "CmdTUIBehavior" })
    if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end

    require("input-remove").confirm_delete({
      name = item.data.name,
      label = "Comando",
      on_confirm = function()
        local current_cmds = _G.user_commands or user_commands
        table.remove(current_cmds, item.idx)
        if default_cmd_idx > #current_cmds then default_cmd_idx = math.max(1, #current_cmds) end
        save_data(current_cmds, default_cmd_idx)
        render()
        attach_behavior_hooks()
        vim.cmd("startinsert!")
      end,
      on_cancel = function()
        render()
        attach_behavior_hooks()
        vim.cmd("startinsert!")
      end,
    })
  end, opt_i)

  vim.keymap.set("i", "<C-r>", function()
    if selected_idx == 0 or #filtered_items == 0 then return end
    local item = filtered_items[selected_idx]

    pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "CmdTUIBehavior" })
    if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end

    require("input-rename").open_rename({
      current_name = item.data.name,
      label = "Comando",
      direct = true,
      on_rename = function(new_name)
        local current_cmds = _G.user_commands or user_commands
        current_cmds[item.idx].name = new_name
        save_data(current_cmds, default_cmd_idx)
        render()
        attach_behavior_hooks()
        vim.cmd("startinsert!")
      end,
      on_cancel = function()
        render()
        attach_behavior_hooks()
        vim.cmd("startinsert!")
      end,
    })
  end, opt_i)

  vim.cmd("startinsert!")
end

-- ==========================================================================
-- 5. MAPPINGS FINALES
-- ==========================================================================
vim.keymap.set("n", "<leader>x", open_command_manager, { desc = "Gestor de Comandos" })
vim.keymap.set("n", "<leader>r", function()
  local entry = (_G.user_commands or user_commands)[default_cmd_idx]
  if entry then run_terminal(entry.cmd, entry.name) end
end, { desc = "Ejecutar Comando Predeterminado" })
