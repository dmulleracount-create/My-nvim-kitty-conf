local function open_creator(initial_text)
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

  local prefix = " + "
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

  local function make_multiline(buf, win_id, max_height, indent)
    max_height = max_height or 5
    indent = indent or 0
    vim.api.nvim_set_option_value("wrap", true, { win = win_id })
    vim.keymap.set("i", "<Tab>", function()
      local cursor = vim.api.nvim_win_get_cursor(win_id)
      local line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1]
      local before = line:sub(1, cursor[2])
      local after = line:sub(cursor[2] + 1)
      local indent_str = (" "):rep(indent)
      vim.api.nvim_buf_set_lines(buf, cursor[1] - 1, cursor[1], false, { before, indent_str .. after })
      vim.api.nvim_win_set_cursor(win_id, { cursor[1] + 1, indent })
    end, { buffer = buf })
    vim.api.nvim_create_augroup("PrefixProtect_" .. win_id, { clear = true })
    local ml_group = vim.api.nvim_create_augroup("MLProtect_" .. win_id, { clear = true })
    vim.api.nvim_create_autocmd("CursorMovedI", {
      buffer = buf,
      group = ml_group,
      callback = function()
        if not vim.api.nvim_win_is_valid(win_id) then return end
        local cursor = vim.api.nvim_win_get_cursor(win_id)
        if cursor[2] < indent then vim.api.nvim_win_set_cursor(win_id, { cursor[1], indent }) end
      end
    })
    local busy = false
    vim.api.nvim_create_autocmd("TextChangedI", {
      buffer = buf,
      callback = function()
        if not vim.api.nvim_win_is_valid(win_id) or busy then return end
        busy = true
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local win_w = vim.api.nvim_win_get_width(win_id)
        local wrap_col = math.max(win_w, 1)
        local total = #lines
        for _, l in ipairs(lines) do
          if #l > 0 then total = total + math.floor((#l - 1) / wrap_col) end
        end
        local needed = math.max(1, math.min(total, max_height))
        local cur = vim.api.nvim_win_get_config(win_id)
        vim.api.nvim_win_set_config(win_id, {
          relative = cur.relative,
          win = cur.win,
          width = cur.width,
          height = needed,
          row = cur.row,
          col = cur.col,
          style = cur.style,
          border = cur.border,
        })
        busy = false
      end
    })
  end

  local function confirm()
    local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
    local input = line:sub(prefix_len + 1):gsub("^%s*(.-)%s*$", "%1")
    if input ~= "" then
      
      -- ====================================================================
      -- FLAGS DE NOTAS: -n [Nombre]
      -- ====================================================================
      if input:sub(1, 2) == "-n" then
        local note_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if note_name == "" then note_name = "Nueva Nota" end

        local pro_prefix = "   "
        local pro_buf = vim.api.nvim_create_buf(false, true)
        local pro_win = vim.api.nvim_open_win(pro_buf, true, {
          relative = win_relative, win = win_ref, width = width, height = height,
          row = row + 3, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = pro_win })
        vim.api.nvim_buf_set_lines(pro_buf, 0, 1, false, { pro_prefix })
        protect_prefix(pro_buf, pro_win, #pro_prefix)
        set_bs_mapping(pro_buf, pro_win, #pro_prefix)

        local sec_prefix = " 󱏒  " 
        local sec_buf = vim.api.nvim_create_buf(false, true)
        local sec_win = vim.api.nvim_open_win(sec_buf, false, { 
          relative = win_relative, win = win_ref, width = width, height = height,
          row = row + 6, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = sec_win })
        vim.api.nvim_buf_set_lines(sec_buf, 0, 1, false, { sec_prefix })
        protect_prefix(sec_buf, sec_win, #sec_prefix)
        set_bs_mapping(sec_buf, sec_win, #sec_prefix)

        local function close_all_notes_windows()
          pcall(vim.api.nvim_win_close, pro_win, true)
          pcall(vim.api.nvim_win_close, sec_win, true)
          close_safe()
          pcall(function() if _G.trigger_notes_render then _G.trigger_notes_render() end end)
        end

        vim.keymap.set("i", "<CR>", function()
          vim.api.nvim_set_current_win(sec_win)
          vim.cmd("startinsert!")
          vim.api.nvim_win_set_cursor(sec_win, {1, #sec_prefix}) 
        end, { buffer = pro_buf, nowait = true })

        vim.keymap.set("i", "<CR>", function()
          local pro_line = vim.api.nvim_buf_get_lines(pro_buf, 0, 1, false)[1] or ""
          local target_pro = vim.trim(pro_line:sub(#pro_prefix + 1))

          local sec_line = vim.api.nvim_buf_get_lines(sec_buf, 0, 1, false)[1] or ""
          local sec_name = vim.trim(sec_line:sub(#sec_prefix + 1))
          if sec_name == "" then sec_name = "General" end

          local notes_config = vim.fn.stdpath("data") .. "/notes_manager.json"
          local notes_dir = vim.fn.stdpath("data") .. "/notes_files"
          local notes_data = { projects = {} }

          local f = io.open(notes_config, "r")
          if f then
            local content = f:read("*a")
            f:close()
            local decoded = vim.fn.json_decode(content)
            if decoded and decoded.projects then notes_data = decoded end
          end

          local found_project = nil
          for _, p in ipairs(notes_data.projects) do
            if p.name:lower() == target_pro:lower() then found_project = p break end
          end

          if not found_project then
            pcall(vim.api.nvim_win_close, pro_win, true)
            pcall(vim.api.nvim_win_close, sec_win, true)
            close_safe()
            vim.api.nvim_err_writeln("Proyecto no existente")
            pcall(function() if _G.trigger_notes_render then _G.trigger_notes_render() end end)
            return
          end

          local p_dir = found_project.name:gsub("%s+", "_")
          local fname = p_dir .. "/" .. note_name:gsub("%s+", "_"):lower() .. ".md"
          table.insert(found_project.notes, { name = note_name, file = fname, section = sec_name, icon = " " })
          
          local wf = io.open(notes_config, "w")
          if wf then wf:write(vim.fn.json_encode(notes_data)) wf:close() end

          local full_p = notes_dir .. "/" .. fname
          local dir = vim.fn.fnamemodify(full_p, ":h")
          if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end
          vim.fn.writefile({}, full_p)

          close_all_notes_windows()
        end, { buffer = sec_buf, nowait = true })

        vim.keymap.set("i", "<Esc>", close_all_notes_windows, { buffer = sec_buf, nowait = true })
        vim.keymap.set("i", "<Esc>", close_all_notes_windows, { buffer = pro_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_notes_windows, { buffer = sec_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_notes_windows, { buffer = pro_buf, nowait = true })
        return

      -- ====================================================================
      -- FLAGS DE API/WIDGETS: -w [Nombre] (Crear) y -e [Nombre] (Editar)
      -- ====================================================================
      elseif input:sub(1, 2) == "-w" or input:sub(1, 2) == "-e" then
        local is_edit = (input:sub(1, 2) == "-e")
        local final_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if final_name == "" then final_name = "Nuevo_Widget" end

        local desc_prefix = " 󰋽  " 
        local desc_buf = vim.api.nvim_create_buf(false, true)
        local desc_win = vim.api.nvim_open_win(desc_buf, true, { 
          relative = win_relative, win = win_ref, width = width, height = 1,
          row = row + 3, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = desc_win })
        vim.api.nvim_buf_set_lines(desc_buf, 0, 1, false, { desc_prefix }) 
        protect_prefix(desc_buf, desc_win, #desc_prefix)
        set_bs_mapping(desc_buf, desc_win, #desc_prefix)
        make_multiline(desc_buf, desc_win, 5, #desc_prefix)

        local function close_all_api_windows()
          pcall(vim.api.nvim_win_close, desc_win, true)
          close_safe()
          pcall(function() if _G.trigger_api_render then _G.trigger_api_render() end end)
        end

        vim.keymap.set("i", "<CR>", function()
          local d_line = vim.api.nvim_buf_get_lines(desc_buf, 0, 1, false)[1] or ""
          local final_desc = vim.trim(d_line:sub(#desc_prefix + 1))
          if final_desc == "" then final_desc = "Sin definición" end

          if is_edit and _G.on_tui_api_edit_submit then
            _G.on_tui_api_edit_submit(final_name, final_desc)
          else
            local api_config = vim.fn.stdpath("data") .. "/api_manager.json"
            local api_data = { items = {} }
            local f = io.open(api_config, "r")
            if f then
              local content = f:read("*a")
              f:close()
              local decoded = vim.fn.json_decode(content)
              if decoded and decoded.items then api_data = decoded end
            end

            table.insert(api_data.items, { name = final_name, desc = final_desc })
            local wf = io.open(api_config, "w")
            if wf then wf:write(vim.fn.json_encode(api_data)) wf:close() end
          end

          close_all_api_windows()
        end, { buffer = desc_buf, nowait = true })

        vim.keymap.set("i", "<Esc>", close_all_api_windows, { buffer = desc_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_api_windows, { buffer = desc_buf, nowait = true })
        return

      -- ====================================================================
      -- FLAGS DE PROYECTOS: -P [Nombre]
      -- ====================================================================
      elseif input:sub(1, 2) == "-P" then
        local p_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if p_name and p_name ~= "" then
          local notes_config = vim.fn.stdpath("data") .. "/notes_manager.json"
          local notes_data = {projects = {} }
          local f = io.open(notes_config, "r")
          if f then
            local content = f:read("*a")
            f:close()
            local decoded = vim.fn.json_decode(content)
            if decoded and decoded.projects then notes_data = decoded end
          end

          table.insert(notes_data.projects, { name = p_name, notes = {} })
          local wf = io.open(notes_config, "w")
          if wf then wf:write(vim.fn.json_encode(notes_data)) wf:close() end
        end
        close_safe()
        pcall(function() if _G.trigger_notes_render then _G.trigger_notes_render() end end)
        return

      -- ====================================================================
      -- FLAGS DE PLANTILLAS: -p [Nombre]
      -- ====================================================================
      elseif input:sub(1, 2) == "-p" then
        local tpl_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if tpl_name == "" then tpl_name = "Nueva Plantilla" end

        local d_prefix = " 󰋽  "
        local d_buf = vim.api.nvim_create_buf(false, true)
        local d_win = vim.api.nvim_open_win(d_buf, true, {
          relative = win_relative, win = win_ref, width = width, height = 1,
          row = row + 3, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = d_win })
        vim.api.nvim_buf_set_lines(d_buf, 0, 1, false, { d_prefix })
        protect_prefix(d_buf, d_win, #d_prefix)
        set_bs_mapping(d_buf, d_win, #d_prefix)
        make_multiline(d_buf, d_win, 5, #d_prefix)

        local c_prefix = "    "
        local c_buf = vim.api.nvim_create_buf(false, true)
        local c_win = vim.api.nvim_open_win(c_buf, false, {
          relative = win_relative, win = win_ref, width = width, height = 3,
          row = row + 6, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = c_win })
        vim.api.nvim_buf_set_lines(c_buf, 0, 1, false, { c_prefix })
        protect_prefix(c_buf, c_win, #c_prefix)
        set_bs_mapping(c_buf, c_win, #c_prefix)
        make_multiline(c_buf, c_win, 5, #c_prefix)

        local function close_all_tpl_windows()
          pcall(vim.api.nvim_win_close, d_win, true)
          pcall(vim.api.nvim_win_close, c_win, true)
          close_safe()
          pcall(function() if _G.trigger_templates_render then _G.trigger_templates_render() end end)
        end

        vim.keymap.set("i", "<CR>", function()
          vim.api.nvim_set_current_win(c_win)
          vim.cmd("startinsert!")
          vim.api.nvim_win_set_cursor(c_win, { 1, #c_prefix })
        end, { buffer = d_buf, nowait = true })

        vim.keymap.set("i", "<CR>", function()
          local d_line = vim.api.nvim_buf_get_lines(d_buf, 0, 1, false)[1] or ""
          local desc = vim.trim(d_line:sub(#d_prefix + 1))

          local c_lines = vim.api.nvim_buf_get_lines(c_buf, 0, -1, false)
          local content = {}
          for _, l in ipairs(c_lines) do
            table.insert(content, l:sub(#c_prefix + 1))
          end
          local final_content = table.concat(content, "\n")

          local tpl_config = vim.fn.stdpath("data") .. "/templates.json"
          local tpl_data = { templates = {} }
          local f = io.open(tpl_config, "r")
          if f then
            local content_r = f:read("*a")
            f:close()
            local decoded = vim.fn.json_decode(content_r)
            if decoded and decoded.templates then tpl_data = decoded end
          end
          table.insert(tpl_data.templates, { name = tpl_name, desc = desc, content = final_content })
          local wf = io.open(tpl_config, "w")
          if wf then wf:write(vim.fn.json_encode(tpl_data)) wf:close() end

          close_all_tpl_windows()
        end, { buffer = c_buf, nowait = true })

        vim.keymap.set("i", "<Esc>", close_all_tpl_windows, { buffer = d_buf, nowait = true })
        vim.keymap.set("i", "<Esc>", close_all_tpl_windows, { buffer = c_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_tpl_windows, { buffer = d_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_tpl_windows, { buffer = c_buf, nowait = true })
        return

      -- ====================================================================
      -- RENOMBRAR ELEMENTOS: -r [Nombre]
      -- ====================================================================
      elseif input:sub(1, 2) == "-r" then
        local new_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if new_name and new_name ~= "" then
          if _G.on_tui_rename_submit then pcall(_G.on_tui_rename_submit, new_name) end
        end
        close_safe()
        pcall(function() if _G.trigger_notes_render then _G.trigger_notes_render() end end)
        return

      -- ====================================================================
      -- FLAGS DE COMANDOS EXEC (-x [Nombre del Comando])
      -- ====================================================================
      elseif input:sub(1, 2) == "-x" then
        local cmd_name = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if cmd_name == "" then cmd_name = "Nuevo Comando" end

        -- 1. Descripción
        local dsc_prefix = " 󰋽  "
        local dsc_buf = vim.api.nvim_create_buf(false, true)
        local dsc_win = vim.api.nvim_open_win(dsc_buf, true, {
          relative = win_relative, win = win_ref, width = width, height = 1,
          row = row + 3, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = dsc_win })
        vim.api.nvim_buf_set_lines(dsc_buf, 0, 1, false, { dsc_prefix })
        protect_prefix(dsc_buf, dsc_win, #dsc_prefix)
        set_bs_mapping(dsc_buf, dsc_win, #dsc_prefix)
        make_multiline(dsc_buf, dsc_win, 5, #dsc_prefix)

        -- 2. Comando ejecutable real
        local exe_prefix = "   "
        local exe_buf = vim.api.nvim_create_buf(false, true)
        local exe_win = vim.api.nvim_open_win(exe_buf, false, {
          relative = win_relative, win = win_ref, width = width, height = 1,
          row = row + 6, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = exe_win })
        vim.api.nvim_buf_set_lines(exe_buf, 0, 1, false, { exe_prefix })
        protect_prefix(exe_buf, exe_win, #exe_prefix)
        set_bs_mapping(exe_buf, exe_win, #exe_prefix)
        make_multiline(exe_buf, exe_win, 5, #exe_prefix)

        -- 3. Icono / Prefijo
        local ico_prefix = " 󰊢  "
        local ico_buf = vim.api.nvim_create_buf(false, true)
        local ico_win = vim.api.nvim_open_win(ico_buf, false, {
          relative = win_relative, win = win_ref, width = width, height = height,
          row = row + 9, col = col, style = "minimal", border = "single"
        })
        vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = ico_win })
        vim.api.nvim_buf_set_lines(ico_buf, 0, 1, false, { ico_prefix })
        protect_prefix(ico_buf, ico_win, #ico_prefix)
        set_bs_mapping(ico_buf, ico_win, #ico_prefix)

        local function close_all_exec_windows()
          pcall(vim.api.nvim_win_close, dsc_win, true)
          pcall(vim.api.nvim_win_close, exe_win, true)
          pcall(vim.api.nvim_win_close, ico_win, true)
          close_safe()
          pcall(function() if _G.trigger_commands_render then _G.trigger_commands_render() end end)
        end

        -- Saltar a la ventana de comando
        vim.keymap.set("i", "<CR>", function()
          vim.api.nvim_set_current_win(exe_win)
          vim.cmd("startinsert!")
          vim.api.nvim_win_set_cursor(exe_win, {1, #exe_prefix})
        end, { buffer = dsc_buf, nowait = true })

        -- Saltar a la ventana de icono
        vim.keymap.set("i", "<CR>", function()
          vim.api.nvim_set_current_win(ico_win)
          vim.cmd("startinsert!")
          vim.api.nvim_win_set_cursor(ico_win, {1, #ico_prefix})
        end, { buffer = exe_buf, nowait = true })

        -- Confirmar Guardado
        vim.keymap.set("i", "<CR>", function()
          local dsc_line = vim.api.nvim_buf_get_lines(dsc_buf, 0, 1, false)[1] or ""
          local final_dsc = vim.trim(dsc_line:sub(#dsc_prefix + 1))

          local exe_lines = vim.api.nvim_buf_get_lines(exe_buf, 0, -1, false)
          local cmd_parts = {}
          for _, l in ipairs(exe_lines) do
            table.insert(cmd_parts, l:sub(#exe_prefix + 1))
          end
          local final_exe = vim.trim(table.concat(cmd_parts, "\n"))

          local ico_line = vim.api.nvim_buf_get_lines(ico_buf, 0, 1, false)[1] or ""
          local final_ico = vim.trim(ico_line:sub(#ico_prefix + 1))

          if final_exe and final_exe ~= "" then
            local json_path = vim.fn.stdpath("data") .. "/custom_commands_final.json"
            if not _G.user_commands then _G.user_commands = {} end
            table.insert(_G.user_commands, { name = cmd_name, cmd = final_exe, icon = final_ico, desc = final_dsc })

            local f = io.open(json_path, "w")
            if f then
              f:write(vim.fn.json_encode({ commands = _G.user_commands, default_idx = 1 }))
              f:close()
            end
          end

          close_all_exec_windows()
        end, { buffer = ico_buf, nowait = true })

        vim.keymap.set("i", "<Esc>", close_all_exec_windows, { buffer = dsc_buf, nowait = true })
        vim.keymap.set("i", "<Esc>", close_all_exec_windows, { buffer = exe_buf, nowait = true })
        vim.keymap.set("i", "<Esc>", close_all_exec_windows, { buffer = ico_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_exec_windows, { buffer = dsc_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_exec_windows, { buffer = exe_buf, nowait = true })
        vim.keymap.set("i", "<C-s>", close_all_exec_windows, { buffer = ico_buf, nowait = true })
        return

      -- ====================================================================
      -- FLAGS DE TAREAS: -t [Nombre]
      -- ====================================================================
      elseif input:sub(1, 2) == "-t" then
        local task = input:sub(3):gsub("^%s*(.-)%s*$", "%1")
        if task ~= "" then
          local cat_prefix = " # "
          local cat_buf = vim.api.nvim_create_buf(false, true)
          local cat_win = vim.api.nvim_open_win(cat_buf, true, {
            relative = win_relative, win = win_ref, width = width, height = height,
            row = row + 3, col = col, style = "minimal", border = "single"
          })
          vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = cat_win })
          vim.api.nvim_buf_set_lines(cat_buf, 0, 1, false, { cat_prefix })
          
          protect_prefix(cat_buf, cat_win, #cat_prefix)
          set_bs_mapping(cat_buf, cat_win, #cat_prefix)

          local date_prefix = "   "
          local date_buf = vim.api.nvim_create_buf(false, true)
          local date_win = vim.api.nvim_open_win(date_buf, false, {
            relative = win_relative, win = win_ref, width = width, height = height,
            row = row + 6, col = col, style = "minimal", border = "single"
          })
          vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = date_win })
          vim.api.nvim_buf_set_lines(date_buf, 0, 1, false, { date_prefix })
          protect_prefix(date_buf, date_win, #date_prefix)
          set_bs_mapping(date_buf, date_win, #date_prefix)

          vim.cmd("startinsert!")
          vim.api.nvim_win_set_cursor(cat_win, { 1, #cat_prefix })

          local function close_all_todo_windows()
            pcall(vim.api.nvim_win_close, cat_win, true)
            pcall(vim.api.nvim_win_close, date_win, true)
            close_safe()
          end

          -- Saltar a la ventana de fecha
          vim.keymap.set("i", "<CR>", function()
            vim.api.nvim_set_current_win(date_win)
            vim.cmd("startinsert!")
            vim.api.nvim_win_set_cursor(date_win, {1, #date_prefix})
          end, { buffer = cat_buf, nowait = true })

          -- Confirmar Guardado
          vim.keymap.set("i", "<CR>", function()
            local cat_line = vim.api.nvim_buf_get_lines(cat_buf, 0, 1, false)[1] or ""
            local cat = vim.trim(cat_line:sub(#cat_prefix + 1))
            if cat == "" then cat = "General" end

            local date_line = vim.api.nvim_buf_get_lines(date_buf, 0, 1, false)[1] or ""
            local date = vim.trim(date_line:sub(#date_prefix + 1))

            if not _G.todos then _G.todos = {} end
            table.insert(_G.todos, { task = task, cat = cat, date = date, done = false, current = false })
            if _G.save_todos then _G.save_todos(_G.todos) end
            pcall(function() require("sidebar-nvim").update() end)
            close_all_todo_windows()
          end, { buffer = date_buf, nowait = true })

          vim.keymap.set("i", "<Esc>", close_all_todo_windows, { buffer = cat_buf, nowait = true })
          vim.keymap.set("i", "<Esc>", close_all_todo_windows, { buffer = date_buf, nowait = true })
          vim.keymap.set("i", "<C-s>", close_all_todo_windows, { buffer = cat_buf, nowait = true })
          vim.keymap.set("i", "<C-s>", close_all_todo_windows, { buffer = date_buf, nowait = true })
          return
        end
      end

      -- ====================================================================
      -- COMPORTAMIENTO INTELIGENTE SIN ETIQUETAS
      -- ====================================================================
      local expanded_path = vim.fn.expand(input)
      
      if input:sub(-1) == "/" then
        if vim.fn.isdirectory(expanded_path) == 0 then
          vim.fn.mkdir(expanded_path, "p")
          close_safe()
          vim.api.nvim_out_write("Carpeta creada: " .. expanded_path .. "\n")
        else
          close_safe()
          vim.api.nvim_out_write("La carpeta ya existe.\n")
        end
        return
      end

      local target_dir = vim.fn.fnamemodify(expanded_path, ":h")
      if vim.fn.isdirectory(target_dir) == 0 and target_dir ~= "." then
        vim.fn.mkdir(target_dir, "p")
      end
      
      close_safe()
      vim.cmd("edit " .. vim.fn.fnameescape(expanded_path))
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

vim.keymap.set("n", "<leader>a", open_creator)
_G.open_input_creator_global = open_creator
