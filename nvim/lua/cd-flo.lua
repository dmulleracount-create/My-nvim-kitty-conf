-- 1. Colores Tokyonight y Personalizados
local bg = "#1a1b26"
local fg = "#c0caf5"
local border_col = "#292e42" -- Color más tenue para bordes y línea
local sel_bg = "#2f334d"

vim.api.nvim_set_hl(0, "MiniDirNormal", { bg = bg, fg = fg })
vim.api.nvim_set_hl(0, "MiniDirBorder", { fg = border_col, bg = bg })
vim.api.nvim_set_hl(0, "MiniDirSeparator", { fg = border_col }) -- Línea divisoria tenue
vim.api.nvim_set_hl(0, "MiniDirSel", { bg = sel_bg, bold = true })
vim.api.nvim_set_hl(0, "MiniDirBold", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "MiniDirTitle", { fg = fg, bg = bg, bold = true })

local function shorten_path(path)
  local home = os.getenv("HOME")
  if home then
    path = path:gsub("^" .. home, "~")
  end
  return path
end

local function open_dir_selector()
  local width = math.floor(vim.o.columns * 0.4)
  local height = math.floor(vim.o.lines * 0.5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local browse_dir = vim.fn.getcwd()
  local dirs = {}
  local current_matches = {}

  local prefix = " ~cd~ > "
  local prefix_len = #prefix
  local bufnr = vim.api.nvim_create_buf(false, true)
  local ns_id = vim.api.nvim_create_namespace("mini_dir_selector")

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor", 
    width = width, 
    height = height,
    row = row, 
    col = col, 
    style = "minimal", 
    border = "single",
    title = { { " " .. shorten_path(browse_dir) .. " ", "MiniDirTitle" } }, 
    title_pos = "center"
  })

  -- Lógica de cierre seguro
  local function close_safe()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      vim.cmd("stopinsert")
    end
  end

  -- Autocomandos para cerrar al salir de modo insertar o cambiar de ventana
  vim.api.nvim_create_autocmd("InsertLeave", { buffer = bufnr, once = true, callback = close_safe })
  vim.api.nvim_create_autocmd("WinLeave", { buffer = bufnr, once = true, callback = close_safe })

  vim.api.nvim_set_option_value("winhl", "Normal:MiniDirNormal,FloatBorder:MiniDirBorder", { win = win })

  local window_start = 1
  local max_items = height - 2
  local selected_idx = 1

  local function fetch_dirs()
    local all_paths = vim.fn.globpath(browse_dir, "*", true, true)
    local hidden_paths = vim.fn.globpath(browse_dir, ".*", true, true)
    
    for _, h in ipairs(hidden_paths) do
      local tail = vim.fn.fnamemodify(h, ":t")
      if tail ~= "." and tail ~= ".." then table.insert(all_paths, h) end
    end

    dirs = { ".", ".." }
    for _, d in ipairs(all_paths) do
      if vim.fn.isdirectory(d) == 1 then
        table.insert(dirs, vim.fn.fnamemodify(d, ":t"))
      end
    end
    vim.api.nvim_win_set_config(win, { title = { { " " .. shorten_path(browse_dir) .. " ", "MiniDirTitle" } } })
  end

  local function render()
    local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or prefix
    local input = first_line:sub(prefix_len + 1):lower()
    
    current_matches = {}
    for _, d in ipairs(dirs) do
      if input == "" or d:lower():find(input, 1, true) then
        table.insert(current_matches, d)
      end
    end

    if #current_matches == 0 then
      selected_idx = 1
      window_start = 1
    else
      if selected_idx > #current_matches then selected_idx = #current_matches end
      if selected_idx < 1 then selected_idx = 1 end
      if selected_idx < window_start then
        window_start = selected_idx
      elseif selected_idx > window_start + max_items - 1 then
        window_start = selected_idx - max_items + 1
      end
    end

    -- Separador fino
    local separator = string.rep("─", width)
    local display_lines = { first_line, separator }
    for i = window_start, math.min(#current_matches, window_start + max_items - 1) do
      local d = current_matches[i]
      local icon = (d == "." or d == "..") and " " or " "
      local text = " " .. icon .. " " .. d
      local pad = math.max(0, width - #text)
      table.insert(display_lines, text .. string.rep(" ", pad))
    end

    vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { unpack(display_lines, 2) })
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

    -- Highlight tenue al separador
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, "MiniDirSeparator", 1, 0, -1)

    if #current_matches > 0 then
      for i = window_start, math.min(#current_matches, window_start + max_items - 1) do
        local line_idx = (i - window_start) + 2 
        if i == selected_idx then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, "MiniDirSel", line_idx, 0, -1)
        elseif current_matches[i] == "." or current_matches[i] == ".." then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, "MiniDirBold", line_idx, 0, -1)
        end
      end
    end
  end

  fetch_dirs()
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix })
  render()

  -- Refresco limpio al escribir
  vim.api.nvim_create_autocmd("TextChangedI", { buffer = bufnr, callback = render })

  -- Bloquear el cursor para que no baje de línea ni entre en el prefijo
  vim.api.nvim_create_autocmd("CursorMovedI", {
    buffer = bufnr,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[1] ~= 1 or cursor[2] < prefix_len then
        vim.api.nvim_win_set_cursor(win, { 1, math.max(cursor[2], prefix_len) })
      end
    end
  })

  local function confirm()
    local target = current_matches[selected_idx]
    if not target then return end
    local final_dir = browse_dir
    if target == ".." then final_dir = vim.fn.fnamemodify(browse_dir, ":h")
    elseif target ~= "." then final_dir = browse_dir .. "/" .. target end
    
    -- Evitar colisión de autocomandos al cerrar
    vim.api.nvim_clear_autocmds({ buffer = bufnr, event = { "InsertLeave", "WinLeave" } })
    close_safe()
    
    vim.cmd("cd " .. vim.fn.fnameescape(final_dir))
    vim.cmd("stopinsert")
    vim.api.nvim_echo({{ "  CD a: " .. shorten_path(final_dir), "MiniDirTitle" }}, false, {})
  end

  local function navigate_in()
    local target = current_matches[selected_idx]
    if not target or target == "." then return end
    if target == ".." then browse_dir = vim.fn.fnamemodify(browse_dir, ":h")
    else browse_dir = browse_dir .. "/" .. target end
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix })
    vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
    selected_idx = 1
    window_start = 1
    fetch_dirs()
    render()
  end

  local opts = { buffer = bufnr, silent = true }
  local expr_opts = { buffer = bufnr, silent = true, expr = true }

  -- Ejecución y navegación de carpetas
  vim.keymap.set("i", "<CR>", confirm, opts)
  vim.keymap.set("i", "<C-CR>", navigate_in, opts)
  vim.keymap.set("i", "<C-a>", navigate_in, opts)
  vim.keymap.set("i", "<Esc>", close_safe, opts)
  
  -- Movimiento de selección visual
  local function move_down()
    selected_idx = math.min(selected_idx + 1, #current_matches)
    render()
  end
  local function move_up()
    selected_idx = math.max(selected_idx - 1, 1)
    render()
  end

  vim.keymap.set("i", "<Down>", move_down, opts)
  vim.keymap.set("i", "<Up>", move_up, opts)
  vim.keymap.set("i", "<C-j>", move_down, opts)
  vim.keymap.set("i", "<C-k>", move_up, opts)

  -- Protecciones del prefijo
  vim.keymap.set("i", "<BS>", function()
    local col = vim.api.nvim_win_get_cursor(win)[2]
    return col > prefix_len and "<BS>" or ""
  end, expr_opts)

  vim.keymap.set("i", "<Left>", function()
    local col = vim.api.nvim_win_get_cursor(win)[2]
    return col > prefix_len and "<Left>" or ""
  end, expr_opts)

  vim.keymap.set("i", "<C-u>", function()
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix })
    vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
    return ""
  end, expr_opts)

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
end

vim.keymap.set("n", "<leader>c", open_dir_selector)
