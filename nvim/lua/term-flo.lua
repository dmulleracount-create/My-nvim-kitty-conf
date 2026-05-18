local function run_terminal()
  local is_expanded = false
  local tw, th = math.floor(vim.o.columns * 0.3), math.floor(vim.o.lines * 0.4)

  local t_buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(t_buf, true, {
    relative = "editor", width = tw, height = th,
    row = vim.o.lines - th - 5, col = vim.o.columns - tw - 2,
    style = "minimal", border = "single",
  })
  _G.term_float_win = win
  _G.last_float_win = win

  vim.api.nvim_set_option_value("winhl", "Normal:MiniDirNormal,FloatBorder:MiniDirBorder", { win = win })
  vim.fn.termopen(vim.o.shell)
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

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = t_buf,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    buffer = t_buf,
    callback = function()
      vim.cmd("startinsert")
    end,
  })
end

vim.keymap.set("n", "<leader>t", run_terminal)
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>:q<CR>", { noremap = true, silent = true})

