local function open_deleter(initial_text)
  initial_text = initial_text or ""

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

  local prefix = " - "
  local prefix_len = #prefix
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_hl(0, "MiniCreatorBorder", { fg = "#414868" })

  local original_eventignore = vim.o.eventignore
  vim.o.eventignore = "WinEnter"

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = win_relative, win = win_ref, width = width, height = height,
    row = row, col = col, style = "minimal", border = "single"
  })

  vim.o.eventignore = original_eventignore

  vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = win })

  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix .. initial_text })

  local function close_safe()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      vim.cmd("stopinsert")
    end
  end

  vim.api.nvim_create_autocmd("CursorMovedI", {
    buffer = bufnr,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[2] < prefix_len then vim.api.nvim_win_set_cursor(win, { 1, prefix_len }) end
    end
  })

  local function protect_prefix(buf, win_id, len)
    vim.api.nvim_create_autocmd("CursorMovedI", {
      buffer = buf,
      group = vim.api.nvim_create_augroup("PrefixProtect_" .. win_id, { clear = true }),
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

  local function confirm()
    local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
    local input = line:sub(prefix_len + 1):gsub("^%s*(.-)%s*$", "%1")
    if input ~= "" then

      if input:sub(1, 2) == "-n" then
        local note_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if note_name ~= "" then
          local notes_config = vim.fn.stdpath("data") .. "/notes_manager.json"
          local notes_data = { projects = {} }
          local f = io.open(notes_config, "r")
          if f then
            local content = f:read("*a")
            f:close()
            local decoded = vim.fn.json_decode(content)
            if decoded and decoded.projects then notes_data = decoded end
          end
          for _, p in ipairs(notes_data.projects) do
            for ni = #p.notes, 1, -1 do
              if p.notes[ni].name == note_name then table.remove(p.notes, ni) end
            end
          end
          local wf = io.open(notes_config, "w")
          if wf then wf:write(vim.fn.json_encode(notes_data)) wf:close() end
        end
        close_safe()
        pcall(function() if _G.trigger_notes_render then _G.trigger_notes_render() end end)
        return

      elseif input:sub(1, 2) == "-w" then
        local widget_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if widget_name ~= "" then
          local api_config = vim.fn.stdpath("data") .. "/api_manager.json"
          local api_data = { items = {} }
          local f = io.open(api_config, "r")
          if f then
            local content = f:read("*a")
            f:close()
            local decoded = vim.fn.json_decode(content)
            if decoded and decoded.items then api_data = decoded end
          end
          for i = #api_data.items, 1, -1 do
            if api_data.items[i].name == widget_name then table.remove(api_data.items, i) end
          end
          local wf = io.open(api_config, "w")
          if wf then wf:write(vim.fn.json_encode(api_data)) wf:close() end
        end
        close_safe()
        pcall(function() if _G.trigger_api_render then _G.trigger_api_render() end end)
        return

      elseif input:sub(1, 2) == "-P" then
        local p_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if p_name ~= "" then
          local notes_config = vim.fn.stdpath("data") .. "/notes_manager.json"
          local notes_data = { projects = {} }
          local f = io.open(notes_config, "r")
          if f then
            local content = f:read("*a")
            f:close()
            local decoded = vim.fn.json_decode(content)
            if decoded and decoded.projects then notes_data = decoded end
          end
          for i = #notes_data.projects, 1, -1 do
            if notes_data.projects[i].name == p_name then table.remove(notes_data.projects, i) end
          end
          local wf = io.open(notes_config, "w")
          if wf then wf:write(vim.fn.json_encode(notes_data)) wf:close() end
        end
        close_safe()
        pcall(function() if _G.trigger_notes_render then _G.trigger_notes_render() end end)
        return

      elseif input:sub(1, 2) == "-p" then
        local t_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if t_name ~= "" then
          local tpl_config = vim.fn.stdpath("data") .. "/templates.json"
          local tpl_data = { templates = {} }
          local f = io.open(tpl_config, "r")
          if f then
            local content = f:read("*a")
            f:close()
            local decoded = vim.fn.json_decode(content)
            if decoded and decoded.templates then tpl_data = decoded end
          end
          for i = #tpl_data.templates, 1, -1 do
            if tpl_data.templates[i].name == t_name then table.remove(tpl_data.templates, i) end
          end
          local wf = io.open(tpl_config, "w")
          if wf then wf:write(vim.fn.json_encode(tpl_data)) wf:close() end
        end
        close_safe()
        pcall(function() if _G.trigger_templates_render then _G.trigger_templates_render() end end)
        return

      elseif input:sub(1, 2) == "-x" then
        local cmd_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if cmd_name ~= "" then
          local json_path = vim.fn.stdpath("data") .. "/custom_commands_final.json"
          local cmds = _G.user_commands or {}
          for i = #cmds, 1, -1 do
            if cmds[i].name == cmd_name then table.remove(cmds, i) end
          end
          local f = io.open(json_path, "w")
          if f then f:write(vim.fn.json_encode({ commands = cmds, default_idx = 1 })) f:close() end
        end
        close_safe()
        pcall(function() if _G.trigger_commands_render then _G.trigger_commands_render() end end)
        return

      elseif input:sub(1, 2) == "-t" then
        local task_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if task_name ~= "" and _G.todos then
          for i = #_G.todos, 1, -1 do
            if _G.todos[i].task == task_name then table.remove(_G.todos, i) end
          end
          if _G.save_todos then _G.save_todos(_G.todos) end
          pcall(function() require("sidebar-nvim").update() end)
        end
        close_safe()
        return
      end

      local expanded_path = vim.fn.expand(input)
      if vim.fn.empty(vim.fn.glob(expanded_path)) == 0 then
        vim.fn.delete(expanded_path, "rf")
        vim.schedule(function() vim.cmd("checktime") end)
      end
      close_safe()
      return
    end
    close_safe()
  end

  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("i", "<CR>", confirm, opts)

  local function close_main()
    close_safe()
    pcall(function() if _G.trigger_api_render then _G.trigger_api_render() end end)
    pcall(function() if _G.trigger_notes_render then _G.trigger_notes_render() end end)
    pcall(function() if _G.trigger_commands_render then _G.trigger_commands_render() end end)
  end

  vim.keymap.set("i", "<Esc>", close_main, opts)
  vim.keymap.set("i", "<C-s>", close_main, opts)

  vim.keymap.set("i", "<BS>", function()
    return vim.api.nvim_win_get_cursor(win)[2] > prefix_len and "<BS>" or ""
  end, { buffer = bufnr, expr = true })

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, prefix_len + #initial_text })
end

    vim.keymap.set("n", "<leader>y", open_deleter)
_G.open_input_remove_global = open_deleter

local M = {}

function M.confirm_delete(opts)
  local name = opts.name or ""
  local label = opts.label or ""
  local on_confirm = opts.on_confirm
  local on_cancel = opts.on_cancel

  local width, height = 35, 1
  local row_off = 1
  local pw = vim.api.nvim_get_current_win()
  local is_floating = vim.api.nvim_win_get_config(pw).relative ~= ""
  local win_relative, win_ref, col
  if is_floating then
    win_relative = "editor"; win_ref = nil
    col = vim.o.columns - width - 3
  else
    win_relative = "win"; win_ref = pw
    col = vim.api.nvim_win_get_width(pw) - width - 3
  end

  local pfx = " - "
  local pfx_len = #pfx
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_set_hl(0, "MiniCreatorBorder", { fg = "#414868" })

  local ei = vim.o.eventignore
  vim.o.eventignore = "WinEnter"

  local w = vim.api.nvim_open_win(buf, true, {
    relative = win_relative, win = win_ref, width = width, height = height,
    row = row_off, col = col, style = "minimal", border = "single"
  })

  vim.o.eventignore = ei

  vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = w })

  local text
  if label ~= "" then text = "-" .. label .. "  " .. name else text = name end
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { pfx .. text })

  local function cs()
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
      vim.cmd("stopinsert")
    end
  end

  vim.api.nvim_create_autocmd("CursorMovedI", {
    buffer = buf,
    callback = function()
      local c = vim.api.nvim_win_get_cursor(w)
      if c[2] < pfx_len then vim.api.nvim_win_set_cursor(w, { 1, pfx_len }) end
    end
  })

  local ob = { buffer = buf, silent = true }

  vim.keymap.set("i", "<CR>", function()
    cs()
    if on_confirm then pcall(on_confirm) end
  end, ob)

  vim.keymap.set("i", "<Esc>", function()
    cs()
    if on_cancel then pcall(on_cancel) end
  end, ob)

  vim.keymap.set("i", "<C-s>", function()
    cs()
    if on_cancel then pcall(on_cancel) end
  end, ob)

  vim.keymap.set("i", "<BS>", function()
    return vim.api.nvim_win_get_cursor(w)[2] > pfx_len and "<BS>" or ""
  end, { buffer = buf, expr = true })

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(w, { 1, pfx_len + #text })
end

return M
