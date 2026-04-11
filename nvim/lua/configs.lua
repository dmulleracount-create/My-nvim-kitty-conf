vim.wo.number = true
vim.wo.relativenumber = true

vim.api.nvim_create_autocmd('InsertLeave', {
  pattern = '*',
  callback = function()
    if vim.bo.modified and vim.bo.buftype == '' and vim.fn.expand('%') ~= '' then
      vim.cmd('write')
    end
  end,
})

local function set_winbar()
  local name = vim.fn.expand('%:t')
  if name == '' then return end
  local is_active = vim.api.nvim_get_current_win() == vim.fn.win_getid()
  local color = is_active and '#f4b866' or '#6c7086'
  vim.opt_local.winbar = ' > ' .. name
  vim.cmd('highlight! WinBar guifg=' .. color)
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'BufNew' }, {
  callback = set_winbar,
})

vim.api.nvim_create_autocmd('WinLeave', {
  callback = function()
    local name = vim.fn.expand('%:t')
    if name ~= '' then
      vim.opt_local.winbar = ' > ' .. name
      vim.cmd('highlight! WinBar guifg=#6c7086')
    end
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, {
  callback = function()
    vim.cmd "highlight WinSeparator guifg=#181616 guibg=#181616"
    vim.cmd "highlight BufferLineSelected guibg=#181616 guifg=#C8C093"
    vim.cmd "highlight BufferLineTabSelected guibg=#181616 guifg=#C8C093"
  end,
})

vim.opt.tabstop = 3
vim.opt.shiftwidth = 3
vim.opt.softtabstop = 3
vim.opt.expandtab = true

vim.api.nvim_set_hl(0, "TelescopeBorder", { fg = "#b9a882" })
vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = "#b9a882" })
vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { fg = "#b9a882" })
vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { fg = "#b9a882" })
vim.api.nvim_set_hl(0, "TelescopeTitle", { link = "TelescopeBorder" })
vim.api.nvim_set_hl(0, "TelescopePromptTitle", { link = "TelescopeBorder" })
vim.api.nvim_set_hl(0, "TelescopeResultsTitle", { link = "TelescopeBorder" })
