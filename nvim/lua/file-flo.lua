-- 1. Colores Tokyonight
local bg = "#1a1b26"
local fg = "#c0caf5"
local border_col = "#292e42"
local sel_bg = "#2f334d"

vim.api.nvim_set_hl(0, "MiniExplNormal", { bg = bg, fg = fg })
vim.api.nvim_set_hl(0, "MiniExplBorder", { fg = border_col, bg = bg })
vim.api.nvim_set_hl(0, "MiniExplSeparator", { fg = border_col })
vim.api.nvim_set_hl(0, "MiniExplSel", { bg = sel_bg, bold = true })
vim.api.nvim_set_hl(0, "MiniExplBold", { fg = "#7aa2f7", bold = true })

local icons = {
  lua = "󰢱 ", py = " ", js = " ", ts = " ", html = " ",
  css = " ", md = " ", json = " ", cpp = " ", rs = " ", default = "󰈔 "
}

local function open_explorer()
  local show_dotfiles = false
  local is_expanded = false
  local width = math.floor(vim.o.columns * 0.4)
  local height = math.floor(vim.o.lines * 0.5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local start = vim.loop.hrtime()
  local files = vim.fn.globpath(vim.fn.getcwd(), "**/*", true, true)
  local elapsed = (vim.loop.hrtime() - start) / 1e9
  if elapsed > 1 then
     vim.api.nvim_echo({{"Demasiados archivos", "WarningMsg"}}, false, {})
  end
  files = vim.tbl_filter(function(f) return vim.fn.isdirectory(f) == 0 end, files)
  for i, f in ipairs(files) do files[i] = vim.fn.fnamemodify(f, ":.") end

  local prefix = " ~f~ > "
  local prefix_len = #prefix
  local bufnr = vim.api.nvim_create_buf(false, true)
  local ns_id = vim.api.nvim_create_namespace("mini_explorer")
  
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor", width = width, height = height,
    row = row, col = col, style = "minimal", border = "single"
  })
  _G.file_float_win = win
  _G.last_float_win = win

  vim.keymap.set({"n", "i"}, "<C-b>", function()
    is_expanded = not is_expanded
    local new_w = math.floor(vim.o.columns * (is_expanded and 0.6 or 0.4))
    local new_h = math.floor(vim.o.lines * (is_expanded and 0.7 or 0.5))
    local new_r = math.floor((vim.o.lines - new_h) / 2)
    local new_c = math.floor((vim.o.columns - new_w) / 2)
    vim.api.nvim_win_set_config(win, {
      relative = "editor", width = new_w, height = new_h,
      row = new_r, col = new_c,
    })
  end, { buffer = bufnr, silent = true })

  local function close_safe()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      vim.cmd("stopinsert")
    end
  end

  vim.api.nvim_set_option_value("winhl", "Normal:MiniExplNormal,FloatBorder:MiniExplBorder", { win = win })
  
  local current_matches = {}
  local selected_idx = 1
  local window_start = 1
  local max_items = height - 2

  local function filter_files(input)
    local result = {}
    for _, f in ipairs(files) do
      if show_dotfiles or not vim.fn.fnamemodify(f, ":t"):match("^%.") then
        if input == "" or f:lower():find(input, 1, true) then
          table.insert(result, f)
        end
      end
    end
    return result
  end

  local function render()
    local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or prefix
    local input = first_line:sub(prefix_len + 1):lower()
    
    current_matches = filter_files(input)
    local open_buffers = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      open_buffers[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":.")] = true
    end

    if #current_matches == 0 then
      selected_idx = 1
    else
      if selected_idx > #current_matches then selected_idx = #current_matches end
      if selected_idx < 1 then selected_idx = 1 end
      if selected_idx < window_start then window_start = selected_idx
      elseif selected_idx > window_start + max_items - 1 then window_start = selected_idx - max_items + 1 end
    end

    local separator = string.rep("─", width)
    local display_lines = { first_line, separator }
    
    for i = window_start, math.min(#current_matches, window_start + max_items - 1) do
      local f = current_matches[i]
      local ext = f:match("^.+(%..+)$")
      local icon = icons[ext and ext:sub(2)] or icons.default
      local text = " " .. icon .. f
      
      -- RELLENO: Añadir espacios para que el highlight ocupe toda la línea
      local padding = string.rep(" ", math.max(0, width - #text))
      table.insert(display_lines, text .. padding)
    end

    vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { unpack(display_lines, 2) })
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, "MiniExplSeparator", 1, 0, -1)

    if #current_matches > 0 then
      for i = window_start, math.min(#current_matches, window_start + max_items - 1) do
        local line_idx = (i - window_start) + 2 
        if open_buffers[current_matches[i]] then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, "MiniExplBold", line_idx, 0, -1)
        end
        if i == selected_idx then
          -- Ahora que hay padding, -1 garantiza que pinte todo el fondo
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, "MiniExplSel", line_idx, 0, -1)
        end
      end
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix })
  render()

  -- Autocomandos de seguridad
  vim.api.nvim_create_autocmd("WinLeave", { buffer = bufnr, once = true, callback = close_safe })
  vim.api.nvim_create_autocmd("TextChangedI", { buffer = bufnr, callback = render })
  vim.api.nvim_create_autocmd("CursorMovedI", {
    buffer = bufnr,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[1] ~= 1 or cursor[2] < prefix_len then
        vim.api.nvim_win_set_cursor(win, { 1, math.max(cursor[2], prefix_len) })
      end
    end
  })

  local function open_file(close)
    local target = current_matches[selected_idx]
    if not target then return end
    if close then
      close_safe()
      vim.cmd("edit " .. vim.fn.fnameescape(target))
      vim.cmd("stopinsert")
    else
      vim.fn.bufadd(target)
      render()
    end
  end

  local opts = { buffer = bufnr, silent = true }
  local expr_opts = { buffer = bufnr, silent = true, expr = true }

  -- Mapeos de teclado
  vim.keymap.set({ "i", "n" }, "<CR>", function() open_file(true) end, opts)
  vim.keymap.set("i", "<C-a>", function() open_file(false) end, opts)
  vim.keymap.set({ "i", "n" }, "<C-h>", function()
    show_dotfiles = not show_dotfiles
    render()
  end, opts)
  vim.keymap.set("i", "<Esc>", close_safe, opts)
  
  -- Movimiento con Flechas (Cursorline)
  vim.keymap.set("i", "<Down>", function() selected_idx = math.min(selected_idx + 1, #current_matches); render() end, opts)
  vim.keymap.set("i", "<Up>", function() selected_idx = math.max(selected_idx - 1, 1); render() end, opts)
  vim.keymap.set("i", "<C-j>", function() selected_idx = math.min(selected_idx + 1, #current_matches); render() end, opts)
  vim.keymap.set("i", "<C-k>", function() selected_idx = math.max(selected_idx - 1, 1); render() end, opts)

  -- Protecciones de escritura
  vim.keymap.set("i", "<BS>", function()
    return vim.api.nvim_win_get_cursor(win)[2] > prefix_len and "<BS>" or ""
  end, expr_opts)

  vim.keymap.set("i", "<Left>", function()
    return vim.api.nvim_win_get_cursor(win)[2] > prefix_len and "<Left>" or ""
  end, expr_opts)

  vim.keymap.set("i", "<C-u>", function()
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix })
    vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
    return ""
  end, expr_opts)

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
end

vim.keymap.set("n", "<leader>f", open_explorer)
