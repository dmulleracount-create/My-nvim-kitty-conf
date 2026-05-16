local json_path = vim.fn.stdpath("data") .. "/custom_commands_final.json"

-- ==========================================================================
-- 1. COLORES TOKYONIGHT
-- ==========================================================================
local colors = {
  bg = "#1a1b26",
  fg = "#c0caf5",
  border = "#414868",
  sel_bg = "#2f334d",
  purple = "#414868",
  blue = "#7aa2f7",
}

vim.api.nvim_set_hl(0, "CmdNormal", { bg = colors.bg, fg = colors.fg })
vim.api.nvim_set_hl(0, "CmdBorder", { fg = colors.border, bg = colors.bg })
vim.api.nvim_set_hl(0, "CmdSel", { bg = colors.sel_bg, bold = true })
vim.api.nvim_set_hl(0, "CmdTitle", { fg = colors.purple, bg = colors.bg, bold = true })
vim.api.nvim_set_hl(0, "CmdDefault", { fg = colors.blue, bold = true })
-- Highlight del cursor: Barra horizontal color púrpura
vim.api.nvim_set_hl(0, "CmdFloatingCursor", { fg = colors.purple, blend = 0 })

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
-- 4. GESTOR DE COMANDOS (UI)
-- ==========================================================================
local function open_command_manager()
  local width, height = math.floor(vim.o.columns * 0.35), math.floor(vim.o.lines * 0.4)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor", width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal", border = "single",
    title = { { "   Comandos ", "CmdTitle" } }, title_pos = "center"
  })

  -- EVITAR MODO INSERTAR AL ENTRAR
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)

  vim.api.nvim_set_option_value("winhl", "Normal:CmdNormal,FloatBorder:CmdBorder,CursorLine:CmdSel", { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  
  local original_guicursor = vim.go.guicursor
  -- Cursor "pending" (barra horizontal fina que no parpadea)
  vim.go.guicursor = "n:hor20-CmdFloatingCursor-blinkon0"

  local function render()
    local lines = {}
    for i, entry in ipairs(user_commands) do
      -- QUITADO EL MARGEN IZQUIERDO: El string empieza directamente con el punto
      local dot = (i == default_cmd_idx) and "· " or "  "
      local icon = string.format("%-3s", entry.icon or ">_")
      table.insert(lines, string.format("%s%s %s", dot, icon, entry.name))
    end
    
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
    for i = 1, #user_commands do
      if i == default_cmd_idx then
        -- Ajustado el highlight al nuevo índice sin margen (columna 0)
        vim.api.nvim_buf_add_highlight(bufnr, -1, "CmdDefault", i-1, 0, 2)
      end
    end
  end

  local function close_ui()
    vim.go.guicursor = original_guicursor
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end

  -- Autocomando para limpiar cursor si se sale de la ventana inesperadamente
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = bufnr,
    once = true,
    callback = close_ui
  })

  local opts = { buffer = bufnr, silent = true }
  local keys_to_block = { "h", "l", "<Left>", "<Right>" }
  for _, key in ipairs(keys_to_block) do vim.keymap.set("n", key, "<Nop>", opts) end

  vim.keymap.set("n", "<CR>", function()
    local idx = vim.api.nvim_win_get_cursor(win)[1]
    local entry = user_commands[idx]
    close_ui()
    if entry then run_terminal(entry.cmd, entry.name) end
  end, opts)

  vim.keymap.set("n", "<space>", function()
    default_cmd_idx = vim.api.nvim_win_get_cursor(win)[1]
    save_data(user_commands, default_cmd_idx)
    render()
  end, opts)

  vim.keymap.set("n", "<C-a>", function()
    vim.go.guicursor = original_guicursor
    vim.ui.input({ prompt = "Nombre: " }, function(name)
      if not name or name == "" then 
        vim.go.guicursor = "n:hor20-CmdFloatingCursor-blinkon0"
        return 
      end
      vim.ui.input({ prompt = "Icono/Prefijo: " }, function(icon)
        icon = (icon == "" or not icon) and ">_" or icon
        vim.ui.input({ prompt = "Comando: " }, function(cmd)
          if cmd and cmd ~= "" then 
            table.insert(user_commands, {name = name, cmd = cmd, icon = icon})
            save_data(user_commands, default_cmd_idx)
          end
          vim.go.guicursor = "n:hor20-CmdFloatingCursor-blinkon0"
          render() 
        end)
      end)
    end)
  end, opts)

  vim.keymap.set("n", "<C-d>", function()
    local idx = vim.api.nvim_win_get_cursor(win)[1]
    if #user_commands > 0 then
      table.remove(user_commands, idx)
      if default_cmd_idx > #user_commands then default_cmd_idx = math.max(1, #user_commands) end
      save_data(user_commands, default_cmd_idx)
      render()
    end
  end, opts)

  vim.keymap.set("n", "q", close_ui, opts)
  vim.keymap.set("n", "<Esc>", close_ui, opts)
  render()
end

-- ==========================================================================
-- 5. MAPPINGS FINALES
-- ==========================================================================
vim.keymap.set("n", "<leader>x", open_command_manager, { desc = "Gestor de Comandos" })
vim.keymap.set("n", "<leader>r", function()
  local entry = user_commands[default_cmd_idx]
  if entry then run_terminal(entry.cmd, entry.name) end
end, { desc = "Ejecutar Comando Predeterminado" })
