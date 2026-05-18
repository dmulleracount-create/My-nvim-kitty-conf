-- =============================================================================
-- 1. CONFIGURACIONES BÁSICAS
-- =============================================================================
vim.g.mapleader = " "
vim.g.localleader = " "
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.relativenumber = false
vim.opt.tabstop = 3
vim.opt.shiftwidth = 3
vim.opt.softtabstop = 3
vim.opt.expandtab = true

-- Cursor por defecto para el editor
vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"

-- Configuraciones de Neovide (UI)
vim.g.neovide_opacity = 1.0
vim.g.neovide_window_blurred = false
vim.g.neovide_floating_shadow = false
vim.g.neovide_floating_blur_amount_x = 0
vim.g.neovide_floating_blur_amount_y = 0

if vim.g.neovide then
  vim.o.guifont = "JetBrainsMono Nerd Font:h12"
  vim.g.neovide_padding_top = 5
  vim.g.neovide_padding_bottom = 5
  vim.g.neovide_padding_right = 5
  vim.g.neovide_padding_left = 5
end

-- =============================================================================
-- 2. ESTILOS Y COLORES (HIGHLIGHTS)
-- =============================================================================
-- Azul para categorías de tareas y carpetas del sidebar
vim.api.nvim_set_hl(0, 'SidebarBlue', { fg = '#7aa2f7', bold = true })
vim.api.nvim_set_hl(0, 'SidebarNvimDirectory', { fg = '#7aa2f7', bold = true })
vim.api.nvim_set_hl(0, 'SidebarNvimFile', { fg = '#c0caf5' })

-- Diagnósticos: número de línea coloreado, sin letras, texto virtual al final
local diag_colors = {
   error = '#f7768e',
   warn  = '#e0af68',
   info  = '#7dcfff',
   hint  = '#565f89',
}

vim.diagnostic.config({
   signs = {
      text = {
         [vim.diagnostic.severity.ERROR] = ' ',
         [vim.diagnostic.severity.WARN]  = ' ',
         [vim.diagnostic.severity.INFO]  = ' ',
         [vim.diagnostic.severity.HINT]  = ' ',
      },
      numhl = {
         [vim.diagnostic.severity.ERROR] = 'DiagNumhlError',
         [vim.diagnostic.severity.WARN]  = 'DiagNumhlWarn',
         [vim.diagnostic.severity.INFO]  = 'DiagNumhlInfo',
         [vim.diagnostic.severity.HINT]  = 'DiagNumhlHint',
      },
   },
   virtual_text = false,
   underline = false,
   update_in_insert = false,
   severity_sort = true,
})

local function filter_unused(diagnostics)
   local unused_words = { "unused", "no utilizado", "no usado", "never used", "is not used" }
   local r = {}
   for _, d in ipairs(diagnostics) do
      local skip = false
      for _, w in ipairs(unused_words) do
         if d.message:lower():find(w, 1, true) then skip = true; break end
      end
      if not skip then table.insert(r, d) end
   end
   return r
end

if vim.diagnostic.handlers then
   local handler_names = { "signs", "virtual_text", "underline" }
   for _, name in ipairs(handler_names) do
      local h = vim.diagnostic.handlers[name]
      if h and h.show then
         local orig = h.show
         h.show = function(namespace, bufnr, diagnostics, opts)
            orig(namespace, bufnr, filter_unused(diagnostics), opts)
         end
      end
   end
end

local diag_group = vim.api.nvim_create_augroup('DiagInsert', { clear = true })
vim.api.nvim_create_autocmd('InsertLeave', {
   group = diag_group,
   callback = function()
      vim.diagnostic.config({ virtual_text = true, underline = true })
   end,
})

local function update_diagnostic_hl()
   local err = vim.api.nvim_get_hl(0, { name = 'DiagnosticSignError' })
   local warn = vim.api.nvim_get_hl(0, { name = 'DiagnosticSignWarn' })
   vim.api.nvim_set_hl(0, 'DiagNumhlError', { fg = err.fg or diag_colors.error })
   vim.api.nvim_set_hl(0, 'DiagNumhlWarn',  { fg = warn.fg or diag_colors.warn })
   vim.api.nvim_set_hl(0, 'DiagNumhlInfo',  { fg = diag_colors.info })
   vim.api.nvim_set_hl(0, 'DiagNumhlHint',  { fg = diag_colors.hint })
end
update_diagnostic_hl()

-- Bold solo en línea actual si tiene diagnóstico
local default_clnr_fg = '#c0caf5'
local function update_cursorline_diag()
   local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
   local diagnostics = vim.diagnostic.get(0, { lnum = lnum })
   local severity = nil
   for _, d in ipairs(diagnostics) do
      if severity == nil or d.severity < severity then
         severity = d.severity
      end
   end
   local fg = default_clnr_fg
   if severity == vim.diagnostic.severity.ERROR then
      fg = diag_colors.error
   elseif severity == vim.diagnostic.severity.WARN then
      fg = diag_colors.warn
   elseif severity == vim.diagnostic.severity.INFO then
      fg = diag_colors.info
   end
   vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = fg, bold = true })
end

-- Separadores y WinBar
vim.api.nvim_set_hl(0, 'WinSeparator', { fg = '#1a1b26', bg = '#1a1b26'})
vim.cmd('highlight ErrorMsg guifg=#565f89 ctermfg=0')

local function apply_bufferline_hl()
   update_diagnostic_hl()
   vim.api.nvim_set_hl(0, 'WinSeparator',               { fg = '#1a1b26', bg = '#1a1b26' })
   vim.api.nvim_set_hl(0, 'SidebarNvimFile',            { fg = '#c0caf5' })
   vim.api.nvim_set_hl(0, 'SidebarNvimDirectory',       { fg = '#7aa2f7', bold = true })
   vim.api.nvim_set_hl(0, "BufferLineSeparator",         { fg = "#1a1b26", bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "BufferLineSeparatorVisible",  { fg = "#1a1b26", bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "BufferLineSeparatorSelected", { fg = "#1a1b26", bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "BufferLineTab",               { fg = "#565f89", bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "BufferLineBackground",        { fg = "#565f89", bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "BufferLineBufferVisible",     { fg = "#565f89", bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "TabLineFill",                 { bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "TabLine",                     { bg = "#1a1b26" })
   vim.api.nvim_set_hl(0, "CursorLineNr",                { fg = "#c0caf5", bold = true })
end

vim.api.nvim_create_autocmd("ColorScheme", { pattern = "*", callback = apply_bufferline_hl })
vim.api.nvim_create_autocmd("VimEnter",    { callback = apply_bufferline_hl })

vim.api.nvim_create_autocmd("CursorMoved", { callback = update_cursorline_diag })

-- =============================================================================
-- 3. COMPORTAMIENTO DEL SIDEBAR (BLOQUEOS Y CURSOR)
-- =============================================================================
vim.api.nvim_create_autocmd("FileType", {
  pattern = "SidebarNvim",
  callback = function()
    vim.bo.modifiable = false
    vim.bo.readonly = false
    vim.bo.buftype = "nofile"
    vim.bo.buflisted = false -- Evita que <Tab> (:bnext) entre aquí
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
  end,
})

-- Cambiar cursor a subrayado grueso (hor20) solo en Sidebar
local cursor_group = vim.api.nvim_create_augroup("SidebarCursor", { clear = true })
vim.api.nvim_create_autocmd("WinEnter", {
    group = cursor_group,
    callback = function()
        if vim.bo.filetype == "SidebarNvim" then
            vim.opt.guicursor = "n:hor20,v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
        else
            vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
        end
    end
})

-- Timer de actualización automática (cada 500ms)
local sb_timer = vim.uv.new_timer()
sb_timer:start(0, 500, vim.schedule_wrap(function()
    local status, sidebar = pcall(require, "sidebar-nvim")
    if status and sidebar.update then
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_win_get_buf(win)
        local cursor_pos
        if vim.bo[buf].filetype == "SidebarNvim" then
            cursor_pos = vim.api.nvim_win_get_cursor(win)
        end
        sidebar.update()
        if cursor_pos then
            pcall(vim.api.nvim_win_set_cursor, win, cursor_pos)
        end
    end
end))

-- =============================================================================
-- 4. UTILIDADES Y AUTOSAVE
-- =============================================================================
vim.treesitter.language.register("markdown", "notanv")

vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    callback = function()
        local dir = vim.fn.expand("%:p:h")
        if vim.fn.isdirectory(dir) == 0 and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
            vim.fn.mkdir(dir, "p")
        end
        vim.cmd("silent! write")
    end,
})

-- Persistencia de To-Dos
_G.todo_path = vim.fn.stdpath("data") .. "/sidebar_todos.json"
_G.load_todos = function()
    local f = io.open(_G.todo_path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content and content ~= "" then
            local ok, data = pcall(vim.fn.json_decode, content)
            return ok and data or {}
        end
    end
    return {}
end
_G.save_todos = function(data)
    local f = io.open(_G.todo_path, "w")
    if f then f:write(vim.fn.json_encode(data)) f:close() end
end
_G.todos = _G.load_todos()

-- =============================================================================
-- 5. WINBAR DINÁMICA
-- =============================================================================
local ignore_filetypes = {
  ["SidebarNvim"] = true,
  ["sidebar-nvim"] = true,
  ["NvimTree"]     = true,
  ["toggleterm"]   = true,
  ["alpha"]        = true,
  ["notanv"]       = true,
  ["zsh"]          = true,
  ["terminal"]          = true,
}

local function set_winbar()
  if ignore_filetypes[vim.bo.filetype] then
    vim.opt_local.winbar = nil
    return
  end
  local name = vim.fn.expand('%:t')
  if name == '' then return end
  local is_active = vim.api.nvim_get_current_win() == vim.fn.win_getid()
  local color = is_active and '#c0caf5' or '#6c7086'
  vim.opt_local.winbar = ' > ' .. name
  vim.cmd('highlight! WinBar   guifg=' .. color .. ' guibg=#1a1b26')
  vim.cmd('highlight! WinBarNC guifg=#6c7086 guibg=#1a1b26')
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'BufNew' }, {
  callback = set_winbar,
})

-- =============================================================================
-- 6. GESTIÓN DE PLUGINS (LAZY.NVIM)
-- =============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  change_detection = { notify = false },
})

-- =============================================================================
-- 7. KEYMAPPINGS (AL FINAL PARA PRIORIDAD)
-- =============================================================================
require("mappings")
require("file-flo")
require("cd-flo")
require("exec-flo")
require("term-flo")
require("notes-flo")
require("input-create")
require("input-remove")
require("input-rename")
require("api-flo")
require("templates-flo")
require("summon")

-- Navegación de buffers (ignorará el sidebar porque buflisted = false)
vim.keymap.set("n", "<Tab>", "<C-w>w", { silent = true })
vim.keymap.set("n", "<S-Tab>", ":bnext<CR>", { silent = true })

-- Control de Sidebar
vim.keymap.set({ "n", "v" }, "<C-s>", ":SidebarNvimToggle<CR>", { silent = true })
vim.keymap.set("n", "<leader>e", ":SidebarNvimToggle<CR>", { silent = true, noremap = true })

-- Atajos forzados para Secciones (llama a la lógica en sidebar.lua)
vim.keymap.set("n", "<C-e>", function() 
    if _G.focus_sidebar_section then _G.focus_sidebar_section("tree") end 
end, { silent = true })

vim.keymap.set("n", "<C-t>", function() 
    if _G.focus_sidebar_section then _G.focus_sidebar_section("todo") end 
end, { silent = true })

-- Apariencia de bordes
vim.opt.fillchars = {
  vert      = '│',
  horiz     = '─',
  vertleft  = ' ',
  vertright = ' ',
  fold      = '·',
  diff      = '╱',
  msgsep    = '‾',
}

