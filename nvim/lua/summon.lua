local colors = {
  bg = "#16161e", fg = "#a9b1d6", border = "#3b4252",
  title = "#7aa2f7", accent = "#4c566a", stats = "#6b737d",
  green = "#9ece6a", orange = "#ff9e64", red = "#f7768e",
  blue = "#7aa2f7",
}

vim.api.nvim_set_hl(0, "SummonNormal",  { bg = colors.bg, fg = colors.fg })
vim.api.nvim_set_hl(0, "SummonBorder",  { fg = colors.border, bg = colors.bg })
vim.api.nvim_set_hl(0, "SummonStats",   { fg = colors.stats })
vim.api.nvim_set_hl(0, "SummonTitle",   { fg = colors.title, bg = colors.bg, bold = true })
vim.api.nvim_set_hl(0, "SummonSep",     { fg = colors.accent })
vim.api.nvim_set_hl(0, "SummonHead",    { fg = colors.blue, bold = true })
vim.api.nvim_set_hl(0, "SummonWeekend", { fg = colors.red })
vim.api.nvim_set_hl(0, "SummonToday",   { fg = colors.fg, bold = true, reverse = true })
vim.api.nvim_set_hl(0, "SummonSel",     { fg = colors.title, bold = true, reverse = true })
vim.api.nvim_set_hl(0, "SummonMark",    { fg = colors.green })
vim.api.nvim_set_hl(0, "SummonTask",    { fg = colors.fg })
vim.api.nvim_set_hl(0, "SummonDoneTask",{ fg = colors.stats })

local ns = vim.api.nvim_create_namespace("summon_cal")

local function get_todos_for_date(date_str)
  local todos = _G.todos or {}
  local r = {}
  for _, t in ipairs(todos) do if t.date == date_str then table.insert(r, t) end end
  return r
end

local function has_todos_on_date(date_str)
  local todos = _G.todos or {}
  for _, t in ipairs(todos) do if t.date == date_str then return true end end
  return false
end

local function build_grid(year, month)
  local dim = tonumber(os.date("%d", os.time({ year = year, month = month + 1, day = 0 })))
  local fdow = (tonumber(os.date("%w", os.time({ year = year, month = month, day = 1 }))) + 6) % 7
  local grid, week = {}, {}
  for _ = 1, fdow do table.insert(week, nil) end
  for d = 1, dim do
    table.insert(week, d)
    if #week == 7 then table.insert(grid, week); week = {} end
  end
  if #week > 0 then while #week < 7 do table.insert(week, nil) end; table.insert(grid, week) end
  return grid, dim
end

local function open_calendar()
  local tw = math.floor(vim.o.columns * 0.7)
  local th = math.floor(vim.o.lines * 0.7)
  local r0 = math.floor((vim.o.lines - th) / 2)
  local c0 = math.floor((vim.o.columns - tw) / 2)

  local cal_w = 28
  local sep_col = cal_w + 2
  local task_w = tw - sep_col - 2
  if task_w < 20 then task_w = 20; tw = sep_col + 2 + task_w end

  local bufnr = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor", width = tw, height = th,
    row = r0, col = c0, style = "minimal", border = "single",
    title = { { "   Calendario ", "SummonTitle" } }, title_pos = "center"
  })
  vim.api.nvim_set_option_value("winhl", "Normal:SummonNormal,FloatBorder:SummonBorder", { win = win })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  local today = os.date("*t")
  local cy, cm, sd = today.year, today.month, today.day
  local day_names = { "L", "M", "M", "J", "V", "S", "D" }
  local month_names = { "enero","febrero","marzo","abril","mayo","junio",
                        "julio","agosto","septiembre","octubre","noviembre","diciembre" }

  local function render()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local grid, days_in_month = build_grid(cy, cm)

    local lines = {}
    local sep = " │"

    -- Month header
    local hdr_text = "  " .. month_names[cm] .. " " .. cy
    table.insert(lines, hdr_text)

    -- Day-of-week header
    local dow_text = " "
    for _, n in ipairs(day_names) do dow_text = dow_text .. " " .. n end
    table.insert(lines, dow_text)

    -- Calendar rows
    for _, week in ipairs(grid) do
      local row_str = ""
      for di, d in ipairs(week) do
        if d then
          local ds = string.format("%d-%d-%d", cy, cm, d)
          local mark = has_todos_on_date(ds) and "●" or " "
          row_str = row_str .. string.format(" %s%2d%s", "", d, mark)
        else
          row_str = row_str .. "    "
        end
      end
      table.insert(lines, row_str)
    end

    -- Append separator and right-side content to each line
    local ds = string.format("%d-%d-%d", cy, cm, sd)
    local items = get_todos_for_date(ds)

    for li = 1, #lines do
      local cal_part = lines[li] or ""
      if #cal_part < cal_w then cal_part = cal_part .. (" "):rep(cal_w - #cal_part) end
      local right = ""
      if li == 1 then
        right = ""
      elseif li == 2 then
        right = "  " .. sd
      elseif li - 2 <= #items then
        local t = items[li - 2]
        local icon = t.done and "󰄵" or "󰄱"
        right = "  " .. icon .. "  " .. t.task
      end
      if right ~= "" then
        lines[li] = cal_part .. sep .. right
      else
        lines[li] = cal_part .. sep
      end
    end

    -- Write buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

    -- Highlights
    vim.api.nvim_buf_add_highlight(bufnr, ns, "SummonHead", 0, 0, #hdr_text)
    for li = 1, #lines do
      vim.api.nvim_buf_add_highlight(bufnr, ns, "SummonSep", li - 1, cal_w, cal_w + 2)
    end

    -- Per-day cell highlights
    for wi, week in ipairs(grid) do
      local li = wi + 2
      for di, d in ipairs(week) do
        if d then
          local col = 1 + di * 4
          if d == today.day and cm == today.month and cy == today.year then
            vim.api.nvim_buf_add_highlight(bufnr, ns, "SummonToday", li, col - 1, col + 2)
          end
          if d == sd then
            vim.api.nvim_buf_add_highlight(bufnr, ns, "SummonSel", li, col - 1, col + 2)
          end
          if di == 6 or di == 7 then
            vim.api.nvim_buf_add_highlight(bufnr, ns, "SummonWeekend", li, col - 1, col + 2)
          end
        end
      end
    end

    -- Green markers for days with todos
    for wi, week in ipairs(grid) do
      local li = wi + 2
      for di, d in ipairs(week) do
        if d then
          local ds = string.format("%d-%d-%d", cy, cm, d)
          if has_todos_on_date(ds) then
            local col = 1 + di * 4 + 2
            vim.api.nvim_buf_add_highlight(bufnr, ns, "SummonMark", li, col, col + 1)
          end
        end
      end
    end

    local stats = string.format(" %s %d  |  dia %d  (%d tareas)", month_names[cm], cy, sd, #items)
    vim.api.nvim_win_set_config(win, { footer = { { stats, "SummonStats" } }, footer_pos = "right" })
  end

  render()

  local opt = { buffer = bufnr, silent = true, nowait = true }

  vim.keymap.set("n", "h", function()
    cm = cm - 1
    if cm < 1 then cm = 12; cy = cy - 1 end
    sd = 1; render()
  end, opt)

  vim.keymap.set("n", "l", function()
    cm = cm + 1
    if cm > 12 then cm = 1; cy = cy + 1 end
    sd = 1; render()
  end, opt)

  vim.keymap.set("n", "j", function()
    local _, dim = build_grid(cy, cm)
    sd = sd + 1
    if sd > dim then sd = 1; cm = cm + 1
      if cm > 12 then cm = 1; cy = cy + 1 end
    end
    render()
  end, opt)

  vim.keymap.set("n", "k", function()
    sd = sd - 1
    if sd < 1 then
      cm = cm - 1
      if cm < 1 then cm = 12; cy = cy - 1 end
      local _, dim = build_grid(cy, cm)
      sd = dim
    end
    render()
  end, opt)

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, opt)

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, opt)
end

vim.keymap.set("n", "<leader>sum", open_calendar, { desc = "Abrir Calendario" })
vim.api.nvim_create_user_command("Summon", open_calendar, {})
