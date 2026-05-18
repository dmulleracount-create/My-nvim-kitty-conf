-- ==========================================================================
-- 0. CONFIGURACIÓN GLOBAL Y ALIAS
-- ==========================================================================
vim.treesitter.language.register("markdown", "notanv")

_G.notes_float_win = nil
local uv = vim.uv or vim.loop

-- ==========================================================================
-- 1. RUTAS Y COLORES TUI SINCRONIZADOS
-- ==========================================================================
local notes_dir = vim.fn.stdpath("data") .. "/notes_files"
local notes_config = vim.fn.stdpath("data") .. "/notes_manager.json"

if vim.fn.isdirectory(notes_dir) == 0 then vim.fn.mkdir(notes_dir, "p") end

local colors = {
    bg = "#1a1b26", fg = "#c0caf5", border = "#292e42",
    blue = "#7aa2f7", purple = "#bb9af7", dim_fg = "#565f89"
}

vim.api.nvim_set_hl(0, "NoteNormal", { bg = colors.bg, fg = colors.fg })
vim.api.nvim_set_hl(0, "NoteBorder", { fg = colors.border, bg = colors.bg })
vim.api.nvim_set_hl(0, "NoteProject", { fg = colors.blue })
vim.api.nvim_set_hl(0, "NoteText", { fg = colors.purple })
vim.api.nvim_set_hl(0, "NoteDate", { fg = colors.dim_fg, italic = true })
vim.api.nvim_set_hl(0, "NoteSeparator", { fg = colors.border }) 
vim.api.nvim_set_hl(0, "NoteStats", { fg = colors.border, bold = true }) 
vim.api.nvim_set_hl(0, "NoteTitle", { fg = colors.blue, bg = colors.bg, bold = true })

vim.api.nvim_set_hl(0, "NoteProjectSel", { fg = colors.blue, bold = true })
vim.api.nvim_set_hl(0, "NoteTextSel", { fg = colors.purple, bold = true })
vim.api.nvim_set_hl(0, "NoteSidebarSel", { fg = colors.blue, bold = true })

-- ==========================================================================
-- 2. PERSISTENCIA Y UTILS DE FECHAS
-- ==========================================================================
local function save_data(data)
    local f = io.open(notes_config, "w")
    if f then f:write(vim.fn.json_encode(data)) f:close() end
end

local function load_data()
    local f = io.open(notes_config, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local ok, decoded = pcall(vim.fn.json_decode, content)
        if ok and decoded.projects then return decoded end
    end
    return { default_file = "", default_project_idx = 1, projects = { { name = "General", notes = {} } } }
end

local notes_data = load_data()

local function get_file_mod_time(fname)
    local stat = uv.fs_stat(notes_dir .. "/" .. fname)
    return stat and stat.mtime and stat.mtime.sec or 0
end

local function get_project_mod_time(project)
    local latest_sec = 0
    for _, note in ipairs(project.notes) do
        local time = get_file_mod_time(note.file)
        if time > latest_sec then latest_sec = time end
    end
    return latest_sec
end

local function format_date(sec)
    return sec > 0 and os.date("%d-%m-%y %H:%M", sec) or "--"
end

-- ==========================================================================
-- 3. VENTANA DE EDICIÓN DE NOTA (CON REDIMENSIÓN CTRL+B RESTAURADA)
-- ==========================================================================
local function open_note_buffer(entry)
    if _G.notes_float_win and vim.api.nvim_win_is_valid(_G.notes_float_win) then
        pcall(vim.api.nvim_win_close, _G.notes_float_win, true)
    end

    local path = notes_dir .. "/" .. entry.file
    local dir = vim.fn.fnamemodify(path, ":h")
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

    local bnr = vim.fn.bufadd(path)
    vim.fn.bufload(bnr)
    
    vim.api.nvim_set_option_value("filetype", "notanv", { buf = bnr })
    vim.api.nvim_set_option_value("syntax", "off", { buf = bnr })
    pcall(vim.treesitter.stop, bnr)

    local is_expanded = false
    local tw, th = math.floor(vim.o.columns * 0.35), math.floor(vim.o.lines * 0.45)
    
    local win = vim.api.nvim_open_win(bnr, true, {
        relative = "editor", width = tw, height = th,
        row = vim.o.lines - th - 5, col = vim.o.columns - tw - 2,
        style = "minimal", border = "single",
        title = { { "   " .. entry.name .. " ", "NoteTitle" } }, title_pos = "center" 
    })

    _G.notes_float_win = win
    _G.last_float_win = win
    vim.api.nvim_set_option_value("winhl", "Normal:NoteNormal,FloatBorder:NoteBorder", { win = win })
    vim.api.nvim_set_option_value("wrap", true, { win = win })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win })

    -- Highlight groups for notanv headings
    vim.api.nvim_set_hl(0, "NotanvH1", { fg = "#7aa2f7", bold = true, underline = false })
    vim.api.nvim_set_hl(0, "NotanvH2", { fg = "#ff9e64", bold = true, underline = false })
    vim.api.nvim_set_hl(0, "NotanvH3", { fg = "#9ece6a", bold = true, underline = false })
    vim.api.nvim_set_hl(0, "NotanvBC", { fg = "#565f89", italic = true })

    local proj_name = entry.file:match("^([^/]+)") or "General"
    for _, p in ipairs(notes_data.projects) do
      local p_dir = p.name:gsub("%s+", "_")
      if entry.file:sub(1, #p_dir) == p_dir then proj_name = p.name; break end
    end
    local sec_name = entry.section or "General"
    local note_name = entry.name or ""

    local ns_h = vim.api.nvim_create_namespace("notanv_h")

    local function render_headers()
        if not vim.api.nvim_buf_is_valid(bnr) then return end
        vim.api.nvim_buf_clear_namespace(bnr, ns_h, 0, -1)

        local lines = vim.api.nvim_buf_get_lines(bnr, 0, -1, false)
        for i = 1, #lines do
            local l = lines[i]
            local icon, hl
            if l:match("^### ") then
                icon, hl = "○ ", "NotanvH3"
            elseif l:match("^## ") then
                icon, hl = "▪ ", "NotanvH2"
            elseif l:match("^# ") then
                icon, hl = "◆ ", "NotanvH1"
            end
            if icon then
                local indent = 2
                vim.api.nvim_buf_set_extmark(bnr, ns_h, i - 1, 0, {
                    virt_text = { { (" "):rep(indent) .. icon, hl } },
                    virt_text_pos = "overlay",
                    hl_mode = "combine",
                })
                local _, _, hlevel = l:find("^(#+) ")
                local text_start = hlevel and (#hlevel + 1) or 3
                if text_start < #l then
                    vim.api.nvim_buf_set_extmark(bnr, ns_h, i - 1, text_start, {
                        hl_group = hl,
                        end_col = -1,
                    })
                end
            end
        end
    end

    render_headers()

    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
        buffer = bnr,
        callback = render_headers,
    })

    -- Breadcrumb as window footer (always at visual bottom)
    local bc = proj_name .. " > " .. sec_name .. " > " .. note_name
    vim.api.nvim_win_set_config(win, {
        footer = { { "  " .. bc, "NotanvBC" } },
        footer_pos = "left",
    })

    vim.cmd("normal! $")

    local opts = { buffer = bnr, silent = true }
    vim.keymap.set("n", "q", "<cmd>w | q<CR>", opts)
    vim.keymap.set("n", "<Esc>", "<cmd>w | q<CR>", opts)

    vim.keymap.set({"n", "i"}, "<C-b>", function()
        is_expanded = not is_expanded
        local new_w = math.floor(vim.o.columns * (is_expanded and 0.55 or 0.35))
        local new_h = math.floor(vim.o.lines * (is_expanded and 0.65 or 0.45))
        vim.api.nvim_win_set_config(win, {
            relative = "editor", width = new_w, height = new_h,
            row = vim.o.lines - new_h - 5, col = vim.o.columns - new_w - 2,
        })
    end, opts)
end

-- ==========================================================================
-- 4. EXPLORADOR TUI COMPACTO
-- ==========================================================================
local function open_note_manager()
    local parent_editor_win = vim.api.nvim_get_current_win()
    local width = math.floor(vim.o.columns * 0.4) 
    local height = math.floor(vim.o.lines * 0.5)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local bufnr = vim.api.nvim_create_buf(false, true)
    local ns_id = vim.api.nvim_create_namespace("notes_tui_selector")

    local win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor", width = width, height = height,
        row = row, col = col, style = "minimal", border = "single",
        title = { { " 󱏒  Notas ", "NoteTitle" } }, title_pos = "center"
    })
    vim.api.nvim_set_option_value("winhl", "Normal:NoteNormal,FloatBorder:NoteBorder", { win = win })

    local selected_idx = 1
    local filtered_items = {}
    local line_map = {}
    local current_search_text = ""

    local prefix = " > "
    local prefix_len = #prefix
    local window_start = 1
    local max_lines_for_list = height - 2 

    local function close_safe()
        if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
        vim.cmd("stopinsert")
    end

    local function attach_behavior_hooks()
        pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "NotesTUIBehavior" })
        vim.api.nvim_create_autocmd({ "InsertLeave", "WinLeave" }, {
            buffer = bufnr, group = "NotesTUIBehavior",
            callback = function() vim.schedule(close_safe) end
        })
        local bv = string.char(22)
        vim.api.nvim_create_autocmd("ModeChanged", {
            buffer = bufnr, group = "NotesTUIBehavior",
            callback = function()
                local m = vim.v.event.new_mode
                if m == "n" or m == "v" or m == "V" or m == bv then vim.schedule(close_safe) end
            end
        })
    end
    vim.api.nvim_create_augroup("NotesTUIBehavior", { clear = true })
    attach_behavior_hooks()

    local function render()
        notes_data = load_data() 
        vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

        local first_line = prefix .. current_search_text
        local separator = string.rep("─", width)
        
        filtered_items = {}
        local raw_tui_lines = {}
        local raw_line_maps = {}

        local filter = current_search_text:gsub("^%s*(.-)%s*$", "%1"):lower()

        local project_list = {}
        for i, p in ipairs(notes_data.projects) do
            local is_actual = (i == notes_data.default_project_idx)
            local mod_time = get_project_mod_time(p)
            table.insert(project_list, { orig_idx = i, data = p, is_actual = is_actual, mod_time = mod_time })
        end

        table.sort(project_list, function(a, b)
            if a.is_actual then return true end
            if b.is_actual then return false end
            return a.mod_time > b.mod_time
        end)

        for _, p_entry in ipairs(project_list) do
            local p = p_entry.data
            local p_idx = p_entry.orig_idx
            
            if filter == "" or p.name:lower():find(filter, 1, true) then
                table.insert(filtered_items, { type = "project", idx = p_idx, data = p, is_active = p_entry.is_actual })
            end
            
            if p_entry.is_actual then
                local sections_map = {}
                local ordered_sections = {}

                for j, n in ipairs(p.notes) do
                    if filter == "" or n.name:lower():find(filter, 1, true) or (n.section and n.section:lower():find(filter, 1, true)) then
                        local sec_name = n.section or "General"
                        if not sections_map[sec_name] then
                            sections_map[sec_name] = {}
                            table.insert(ordered_sections, sec_name)
                        end
                        table.insert(sections_map[sec_name], { n_idx = j, data = n })
                    end
                end

                for _, sec in ipairs(ordered_sections) do
                    table.insert(filtered_items, { type = "section", name = sec })
                    for _, note_item in ipairs(sections_map[sec]) do
                        local is_n_active = (note_item.data.file == notes_data.default_file)
                        table.insert(filtered_items, { 
                            type = "note", p_idx = p_idx, n_idx = note_item.n_idx, 
                            data = note_item.data, is_active = is_n_active 
                        })
                    end
                end
            end
        end

        if #filtered_items == 0 then
            selected_idx = 0
            window_start = 1
        else
            if selected_idx > #filtered_items then selected_idx = #filtered_items end
            if selected_idx < 1 then selected_idx = 1 end
        end

        for i, item in ipairs(filtered_items) do
            local is_sel = (i == selected_idx)
            local sidebar = is_sel and "│ " or "  "
            local dot_indicator = item.is_active and "· " or "  "
            
            if item.type == "project" then
                local p_date = format_date(get_project_mod_time(item.data))
                table.insert(raw_tui_lines, string.format("%s%s  %s", sidebar, dot_indicator, item.data.name))
                raw_line_maps[#raw_tui_lines] = { item_idx = i, part = "main", type = "project", is_sel = is_sel }
                table.insert(raw_tui_lines, string.format("%s     󰸗 Modificado: %s", sidebar, p_date))
                raw_line_maps[#raw_tui_lines] = { item_idx = i, part = "sub", type = "project", is_sel = is_sel }
                
            elseif item.type == "section" then
                table.insert(raw_tui_lines, string.format("%s    󱏒 %s", sidebar, item.name))
                raw_line_maps[#raw_tui_lines] = { item_idx = i, part = "main", type = "section", is_sel = is_sel }

            elseif item.type == "note" then
                local n_date = format_date(get_file_mod_time(item.data.file))
                table.insert(raw_tui_lines, string.format("%s      %s  %s", sidebar, dot_indicator, item.data.name))
                raw_line_maps[#raw_tui_lines] = { item_idx = i, part = "main", type = "note", is_sel = is_sel }
                table.insert(raw_tui_lines, string.format("%s           󰸗 Edición: %s", sidebar, n_date))
                raw_line_maps[#raw_tui_lines] = { item_idx = i, part = "sub", type = "note", is_sel = is_sel }
            end
        end

        local target_raw_line = 1
        for l_idx, m in ipairs(raw_line_maps) do
            if m.item_idx == selected_idx and m.part == "main" then
                target_raw_line = l_idx
                break
            end
        end

        if selected_idx > 0 and #raw_tui_lines > 0 then
            if target_raw_line < window_start then
                window_start = target_raw_line
            elseif target_raw_line > window_start + max_lines_for_list - 1 then
                window_start = target_raw_line - max_lines_for_list + 1
            end
            if raw_line_maps[target_raw_line + 1] and raw_line_maps[target_raw_line + 1].item_idx == selected_idx then
                if (target_raw_line + 1) > window_start + max_lines_for_list - 1 then
                    window_start = (target_raw_line + 1) - max_lines_for_list + 1
                end
            end
        end
        if window_start < 1 then window_start = 1 end

        local display_lines = { first_line, separator }
        line_map = {}

        for i = window_start, math.min(#raw_tui_lines, window_start + max_lines_for_list - 1) do
            table.insert(display_lines, raw_tui_lines[i])
            line_map[#display_lines] = raw_line_maps[i]
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_lines)
        vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "NoteTitle", 0, 0, 1)
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "NoteSeparator", 1, 0, -1)

        for buf_line_idx, mapping in pairs(line_map) do
            if mapping.is_sel then
                vim.api.nvim_buf_add_highlight(bufnr, ns_id, "NoteSidebarSel", buf_line_idx - 1, 0, 4)
                if mapping.part == "main" then
                    local group = (mapping.type == "project") and "NoteProjectSel" or ((mapping.type == "section") and "NoteTitle" or "NoteTextSel")
                    vim.api.nvim_buf_add_highlight(bufnr, ns_id, group, buf_line_idx - 1, 4, -1)
                end
            else
                if mapping.part == "main" then
                    local group = (mapping.type == "project") and "NoteProject" or ((mapping.type == "section") and "NoteTitle" or "NoteText")
                    vim.api.nvim_buf_add_highlight(bufnr, ns_id, group, buf_line_idx - 1, 4, -1)
                end
            end
            if mapping.part == "sub" then
                vim.api.nvim_buf_add_highlight(bufnr, ns_id, "NoteDate", buf_line_idx - 1, 4, -1)
            end
        end

        local total = #filtered_items
        local current = selected_idx
        local percent = total > 0 and math.floor((current / total) * 100) or 0
        local stats_str = string.format(" %d/%d (%d%%) ", current, total, percent)
        
        vim.api.nvim_win_set_config(win, { footer = { { stats_str, "NoteStats" } }, footer_pos = "right" })
        pcall(vim.api.nvim_win_set_cursor, win, { 1, prefix_len + #current_search_text })
    end

    _G.trigger_notes_render = function()
        vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) then 
                vim.api.nvim_set_current_win(win) 
                render() 
                attach_behavior_hooks()
                vim.cmd("startinsert!") 
            end
        end)
    end

    render()

    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
        buffer = bufnr, callback = function()
            local line_content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
            current_search_text = line_content:sub(prefix_len + 1)
            render()
        end
    })

    vim.api.nvim_create_autocmd("CursorMovedI", {
        buffer = bufnr, callback = function()
            local cursor = vim.api.nvim_win_get_cursor(win)
            if cursor[1] ~= 1 then pcall(vim.api.nvim_win_set_cursor, win, { 1, prefix_len + #current_search_text })
            elseif cursor[2] < prefix_len then pcall(vim.api.nvim_win_set_cursor, win, { 1, prefix_len }) end
        end
    })

    -- ==========================================================================
    -- MAPEOS EN MODO INSERTAR
    -- ==========================================================================
    local opt_i = { buffer = bufnr, silent = true }

    local function move_down()
        if selected_idx < #filtered_items then
            selected_idx = selected_idx + 1
            if filtered_items[selected_idx] and filtered_items[selected_idx].type == "section" then
                selected_idx = selected_idx + 1
            end
            render()
        end
    end

    local function move_up()
        if selected_idx > 1 then
            selected_idx = selected_idx - 1
            if filtered_items[selected_idx] and filtered_items[selected_idx].type == "section" then
                selected_idx = selected_idx - 1
            end
            render()
        end
    end

    vim.keymap.set("i", "<Down>", move_down, opt_i)
    vim.keymap.set("i", "<C-j>", move_down, opt_i)
    vim.keymap.set("i", "<Up>", move_up, opt_i)
    vim.keymap.set("i", "<C-k>", move_up, opt_i)
    vim.keymap.set("i", "<Esc>", close_safe, opt_i)

    local function select_active()
        if selected_idx == 0 or #filtered_items == 0 then return end
        local item = filtered_items[selected_idx]
        if item.type == "project" then
            notes_data.default_project_idx = item.idx
        elseif item.type == "note" then
            notes_data.default_file = item.data.file 
            notes_data.default_project_idx = item.p_idx
        end
        save_data(notes_data)
        render()
    end
    
    vim.keymap.set("i", "<CR>", function()
        if selected_idx == 0 or #filtered_items == 0 then return end
        local active_item = filtered_items[selected_idx]
        if active_item.type == "note" then
            pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "NotesTUIBehavior" })
            close_safe()
            open_note_buffer(active_item.data)
        else
            select_active()
        end
    end, opt_i)
    vim.keymap.set("i", "<C-CR>", select_active, opt_i)

    local function spawn_input_create(args)
        if _G.open_input_creator_global then
            pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "NotesTUIBehavior" }) 
            if vim.api.nvim_win_is_valid(parent_editor_win) then
                vim.api.nvim_set_current_win(parent_editor_win)
            end
            _G.open_input_creator_global()
            vim.api.nvim_feedkeys(args, "n", false)
        end
    end

    vim.keymap.set("i", "<C-a>", function() spawn_input_create("-n ") end, opt_i)
    vim.keymap.set("i", "<C-p>", function() spawn_input_create("-P ") end, opt_i)
    
    vim.keymap.set("i", "<C-r>", function()
        if selected_idx == 0 or #filtered_items == 0 then return end
        local item = filtered_items[selected_idx]
        if item.type == "section" then return end

        pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "NotesTUIBehavior" })
        if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end

        local label = item.type == "project" and "Proyecto" or "Nota"

        require("input-rename").open_rename({
            direct = true,
            current_name = item.data.name,
            label = label,
            on_rename = function(new_name)
                if item.type == "project" then item.data.name = new_name
                elseif item.type == "note" then item.data.name = new_name end
                save_data(notes_data)
                _G.trigger_notes_render()
            end,
            on_cancel = function()
                _G.trigger_notes_render()
            end,
        })
    end, opt_i)

    vim.keymap.set("i", "<C-d>", function()
        if selected_idx == 0 or #filtered_items == 0 then return end
        local item = filtered_items[selected_idx]
        if item.type == "section" then return end

        pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "NotesTUIBehavior" })
        if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end

        local label = item.type == "project" and "Proyecto" or "Nota"

        require("input-remove").confirm_delete({
            name = item.data.name,
            label = label,
            on_confirm = function()
                if item.type == "project" then
                    table.remove(notes_data.projects, item.idx)
                    if notes_data.default_project_idx > #notes_data.projects then
                        notes_data.default_project_idx = math.max(1, #notes_data.projects)
                    end
                else
                    table.remove(notes_data.projects[item.p_idx].notes, item.n_idx)
                end
                save_data(notes_data)
                _G.trigger_notes_render()
            end,
            on_cancel = function()
                _G.trigger_notes_render()
            end,
        })
    end, opt_i)

    vim.keymap.set("i", "<BS>", function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        return cursor[2] > prefix_len and "<BS>" or ""
    end, { buffer = bufnr, expr = true, silent = true })

    vim.cmd("startinsert!")
end

_G.open_note_manager_global = open_note_manager
vim.keymap.set("n", "<leader>m", open_note_manager)
vim.keymap.set("n", "<leader>n", function()
    for _, p in ipairs(notes_data.projects) do
        for _, n in ipairs(p.notes) do
            if n.file == notes_data.default_file then open_note_buffer(n) return end
        end
    end
end)
