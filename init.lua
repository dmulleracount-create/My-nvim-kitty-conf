vim.g.mapleader = " "
vim.g.localleader = " "
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true

vim.cmd([[
  au TermOpen * setlocal norelativenumber nonumber
  au TermOpen * silent! execute '!stty -ixon' 
]])

require("configs")
require("mappings")
require("special")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")

vim.wo.number = true

vim.opt.tabstop = 3
vim.opt.shiftwidth = 3
vim.opt.softtabstop = 3
vim.opt.expandtab = true

