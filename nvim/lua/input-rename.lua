local M = {}

function M.open_rename(opts)
  local current_name = opts.current_name or ""
  local label = opts.label or ""
  local on_rename = opts.on_rename
  local on_cancel = opts.on_cancel
  local direct = opts.direct

  local width, height = 35, 1
  local row = 1
  local parent_win = vim.api.nvim_get_current_win()
  local is_floating = vim.api.nvim_win_get_config(parent_win).relative ~= ""
  local win_relative, win_ref, col
  if is_floating then
    win_relative = "editor"; win_ref = nil
    col = vim.o.columns - width - 3
  else
    win_relative = "win"; win_ref = parent_win
    col = vim.api.nvim_win_get_width(parent_win) - width - 3
  end

  vim.api.nvim_set_hl(0, "MiniCreatorBorder", { fg = "#414868" })

  local original_eventignore = vim.o.eventignore
  vim.o.eventignore = "WinEnter"

  local function protect_prefix(buf, win_id, len)
    vim.api.nvim_create_autocmd("CursorMovedI", {
      buffer = buf,
      group = vim.api.nvim_create_augroup("RenameProtect_" .. win_id, { clear = true }),
      callback = function()
        if vim.api.nvim_win_is_valid(win_id) then
          local cursor = vim.api.nvim_win_get_cursor(win_id)
          if cursor[2] < len then vim.api.nvim_win_set_cursor(win_id, { 1, len }) end
        end
      end
    })
  end

  local function set_bs_mapping(buf, win_id, len)
    vim.keymap.set("i", "<BS>", function()
      return vim.api.nvim_win_get_cursor(win_id)[2] > len and "<BS>" or ""
    end, { buffer = buf, expr = true })
  end

  local function make_cs(win_ids)
    return function()
      for _, w in ipairs(win_ids) do pcall(vim.api.nvim_win_close, w, true) end
      vim.cmd("stopinsert")
    end
  end

  local function make_cancel(cs_fn)
    return function()
      cs_fn()
      if on_cancel then pcall(on_cancel) end
    end
  end

  if direct then
    local prefix = " > "
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = win_relative, win = win_ref, width = width, height = height,
      row = row, col = col, style = "minimal", border = "single"
    })
    vim.o.eventignore = original_eventignore
    vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = win })
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { prefix .. current_name })
    protect_prefix(buf, win, #prefix)
    set_bs_mapping(buf, win, #prefix)

    local cs = make_cs({ win })
    local cancel = make_cancel(cs)

    vim.keymap.set("i", "<CR>", function()
      local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      local new_name = vim.trim(line:sub(#prefix + 1))
      if new_name ~= "" and on_rename then pcall(on_rename, new_name) end
      cs()
    end, { buffer = buf, nowait = true })

    vim.keymap.set("i", "<Esc>", cancel, { buffer = buf, nowait = true })
    vim.keymap.set("i", "<C-s>", cancel, { buffer = buf, nowait = true })

    vim.cmd("startinsert!")
    vim.api.nvim_win_set_cursor(win, { 1, #prefix + #current_name })
    return
  end

  local first_prefix = " ~ "
  local first_buf = vim.api.nvim_create_buf(false, true)
  local first_win = vim.api.nvim_open_win(first_buf, true, {
    relative = win_relative, win = win_ref, width = width, height = height,
    row = row, col = col, style = "minimal", border = "single"
  })
  vim.o.eventignore = original_eventignore
  vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = first_win })
  local first_text
  if label ~= "" then first_text = first_prefix .. "-" .. label .. "  " .. current_name else first_text = first_prefix .. current_name end
  vim.api.nvim_buf_set_lines(first_buf, 0, 1, false, { first_text })
  protect_prefix(first_buf, first_win, #first_prefix)
  set_bs_mapping(first_buf, first_win, #first_prefix)

  local second_prefix = " ~ "
  local second_buf = vim.api.nvim_create_buf(false, true)
  local second_win = vim.api.nvim_open_win(second_buf, false, {
    relative = win_relative, win = win_ref, width = width, height = height,
    row = row + 3, col = col, style = "minimal", border = "single"
  })
  vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = second_win })
  vim.api.nvim_buf_set_lines(second_buf, 0, 1, false, { second_prefix .. current_name })
  protect_prefix(second_buf, second_win, #second_prefix)
  set_bs_mapping(second_buf, second_win, #second_prefix)

  local cs = make_cs({ first_win, second_win })
  local cancel = make_cancel(cs)

  vim.keymap.set("i", "<CR>", function()
    vim.api.nvim_set_current_win(second_win)
    vim.cmd("startinsert!")
    vim.api.nvim_win_set_cursor(second_win, { 1, #second_prefix + #current_name })
  end, { buffer = first_buf, nowait = true })

  vim.keymap.set("i", "<CR>", function()
    local line = vim.api.nvim_buf_get_lines(second_buf, 0, 1, false)[1] or ""
    local new_name = vim.trim(line:sub(#second_prefix + 1))
    if new_name ~= "" and on_rename then pcall(on_rename, new_name) end
    cs()
    if on_cancel then pcall(on_cancel) end
  end, { buffer = second_buf, nowait = true })

  vim.keymap.set("i", "<Esc>", cancel, { buffer = first_buf, nowait = true })
  vim.keymap.set("i", "<Esc>", cancel, { buffer = second_buf, nowait = true })
  vim.keymap.set("i", "<C-s>", cancel, { buffer = first_buf, nowait = true })
  vim.keymap.set("i", "<C-s>", cancel, { buffer = second_buf, nowait = true })

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(first_win, { 1, #first_text })
end

vim.keymap.set("n", "<leader>g", function()
  M.open_rename({
    current_name = "",
    label = "",
    direct = false,
  })
end)

return M
