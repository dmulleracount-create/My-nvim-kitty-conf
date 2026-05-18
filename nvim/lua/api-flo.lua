-- ==========================================================================
-- 0. CONFIGURACIÓN GLOBAL Y ALIAS
-- ==========================================================================
local uv = vim.uv or vim.loop

-- ==========================================================================
-- 1. RUTAS Y COLORES TUI
-- ==========================================================================
local api_config = vim.fn.stdpath("data") .. "/api_manager.json"

local colors = {
    bg = "#1a1b26", fg = "#c0caf5", border = "#292e42",
    blue = "#7aa2f7", purple = "#bb9af7", dim_fg = "#565f89"
}

vim.api.nvim_set_hl(0, "ApiNormal", { bg = colors.bg, fg = colors.fg })
vim.api.nvim_set_hl(0, "ApiBorder", { fg = colors.border, bg = colors.bg })
vim.api.nvim_set_hl(0, "ApiName", { fg = colors.blue, bold = true })
vim.api.nvim_set_hl(0, "ApiDesc", { fg = colors.dim_fg, italic = true })
vim.api.nvim_set_hl(0, "ApiSeparator", { fg = colors.border }) 
vim.api.nvim_set_hl(0, "ApiStats", { fg = colors.border, bold = true }) 
vim.api.nvim_set_hl(0, "ApiTitle", { fg = colors.blue, bg = colors.bg, bold = true })
vim.api.nvim_set_hl(0, "ApiSidebarSel", { fg = colors.blue, bold = true })

-- ==========================================================================
-- 2. PERSISTENCIA
-- ==========================================================================
local function save_data(data)
    local f = io.open(api_config, "w")
    if f then f:write(vim.fn.json_encode(data)) f:close() end
end

local function load_data()
    local f = io.open(api_config, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local ok, decoded = pcall(vim.fn.json_decode, content)
        if ok and decoded.items then return decoded end
    end
    return { items = {} }
end

local api_data = load_data()

-- ==========================================================================
-- 3. EXPLORADOR TUI COMPACTO (LISTA PLANA)
-- ==========================================================================
local function open_api_manager()
    local parent_editor_win = vim.api.nvim_get_current_win()
    local width = math.floor(vim.o.columns * 0.4) 
    local height = math.floor(vim.o.lines * 0.5)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local bufnr = vim.api.nvim_create_buf(false, true)
    local ns_id = vim.api.nvim_create_namespace("api_tui_selector")
    local sel_ns_id = vim.api.nvim_create_namespace("api_tui_overlays")

    local win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor", width = width, height = height,
        row = row, col = col, style = "minimal", border = "single",
        title = { { " 󰋽  API ", "ApiTitle" } }, title_pos = "center"
    })
    vim.api.nvim_set_option_value("winhl", "Normal:ApiNormal,FloatBorder:ApiBorder", { win = win })
    
    -- MODIFICADO: shift:0 fuerza a que las líneas clonadas hereden exactamente los espacios del buffer
    vim.api.nvim_set_option_value("wrap", true, { win = win })
    vim.api.nvim_set_option_value("breakindent", true, { win = win })
    vim.api.nvim_set_option_value("breakindentopt", "shift:0", { win = win })

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
        pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "ApiTUIBehavior" })
        vim.api.nvim_create_autocmd({ "InsertLeave", "WinLeave" }, {
            buffer = bufnr, group = "ApiTUIBehavior",
            callback = function() vim.schedule(close_safe) end
        })
        local bv = string.char(22)
        vim.api.nvim_create_autocmd("ModeChanged", {
            buffer = bufnr, group = "ApiTUIBehavior",
            callback = function()
                local m = vim.v.event.new_mode
                if m == "n" or m == "v" or m == "V" or m == bv then vim.schedule(close_safe) end
            end
        })
    end
    vim.api.nvim_create_augroup("ApiTUIBehavior", { clear = true })
    attach_behavior_hooks()

    local function render()
        api_data = load_data() 
        vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

        local first_line = prefix .. current_search_text
        local separator = string.rep("─", width)
        
        filtered_items = {}
        local raw_tui_lines = {}
        local raw_line_maps = {}

        local filter = current_search_text:gsub("^%s*(.-)%s*$", "%1"):lower()

        for i, item in ipairs(api_data.items) do
            if filter == "" or item.name:lower():find(filter, 1, true) or item.desc:lower():find(filter, 1, true) then
                table.insert(filtered_items, { idx = i, data = item })
            end
        end

        table.sort(filtered_items, function(a, b) return a.data.name:lower() < b.data.name:lower() end)

        if #filtered_items == 0 then
            selected_idx = 0
            window_start = 1
        else
            if selected_idx > #filtered_items then selected_idx = #filtered_items end
            if selected_idx < 1 then selected_idx = 1 end
        end

        for i, item in ipairs(filtered_items) do
            local is_sel = (i == selected_idx)
            
            -- MODIFICADO: Espacios puros al inicio para asegurar cálculos matemáticos exactos en el Wrap
            table.insert(raw_tui_lines, string.format("    %s", item.data.name))
            raw_line_maps[#raw_tui_lines] = { item_idx = i, part = "main", is_sel = is_sel }
            
            table.insert(raw_tui_lines, string.format("    · %s", item.data.desc))
            raw_line_maps[#raw_tui_lines] = { item_idx = i, part = "sub", is_sel = is_sel }
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
        vim.api.nvim_buf_clear_namespace(bufnr, sel_ns_id, 0, -1)
        
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "ApiTitle", 0, 0, 1)
        vim.api.nvim_buf_add_highlight(bufnr, ns_id, "ApiSeparator", 1, 0, -1)

        for buf_line_idx, mapping in pairs(line_map) do
            -- Barra lateral selectiva flotante (columna 0)
            if mapping.is_sel then
                vim.api.nvim_buf_set_extmark(bufnr, sel_ns_id, buf_line_idx - 1, 0, {
                    virt_text = { { "│", "ApiSidebarSel" } },
                    virt_text_pos = "overlay"
                })
            end

            if mapping.part == "main" then
                vim.api.nvim_buf_add_highlight(bufnr, ns_id, "ApiName", buf_line_idx - 1, 4, -1)
            elseif mapping.part == "sub" then
                vim.api.nvim_buf_add_highlight(bufnr, ns_id, "ApiDesc", buf_line_idx - 1, 6, -1)
            end
        end

        local total = #filtered_items
        local current = selected_idx
        local stats_str = string.format(" %d/%d ", current, total)
        
        vim.api.nvim_win_set_config(win, { footer = { { stats_str, "ApiStats" } }, footer_pos = "right" })
        pcall(vim.api.nvim_win_set_cursor, win, { 1, prefix_len + #current_search_text })
    end

    _G.trigger_api_render = function()
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

    vim.keymap.set("i", "<Down>", function() if selected_idx < #filtered_items then selected_idx = selected_idx + 1 render() end end, opt_i)
    vim.keymap.set("i", "<C-j>", function() if selected_idx < #filtered_items then selected_idx = selected_idx + 1 render() end end, opt_i)
    vim.keymap.set("i", "<Up>", function() if selected_idx > 1 then selected_idx = selected_idx - 1 render() end end, opt_i)
    vim.keymap.set("i", "<C-k>", function() if selected_idx > 1 then selected_idx = selected_idx - 1 render() end end, opt_i)
    vim.keymap.set("i", "<Esc>", close_safe, opt_i)

    vim.keymap.set("i", "<CR>", function()
        if selected_idx == 0 or #filtered_items == 0 then return end
        local item = filtered_items[selected_idx]
        
        pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "ApiTUIBehavior" })
        close_safe()
        
        if vim.api.nvim_win_is_valid(parent_editor_win) then
            vim.api.nvim_set_current_win(parent_editor_win)
            vim.api.nvim_put({item.data.name}, "c", true, true)
            vim.cmd("startinsert") 
        end
    end, opt_i)

    local function spawn_input_create(args)
        if _G.open_input_creator_global then
            pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "ApiTUIBehavior" }) 
            if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end
            _G.open_input_creator_global()
            vim.api.nvim_feedkeys(args, "n", false)
        end
    end

    vim.keymap.set("i", "<C-a>", function() spawn_input_create("-w ") end, opt_i)
    
    vim.keymap.set("i", "<C-r>", function()
        if selected_idx == 0 or #filtered_items == 0 then return end
        local item = filtered_items[selected_idx]

        pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "ApiTUIBehavior" })
        if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end

        require("input-rename").open_rename({
            direct = true,
            current_name = item.data.name,
            label = "API",
            on_rename = function(new_name)
                item.data.name = new_name
                save_data(api_data)
                _G.trigger_api_render()
            end,
            on_cancel = function()
                _G.trigger_api_render()
            end,
        })
    end, opt_i)

    vim.keymap.set("i", "<C-d>", function()
        if selected_idx == 0 or #filtered_items == 0 then return end
        local item = filtered_items[selected_idx]

        pcall(vim.api.nvim_clear_autocmds, { buffer = bufnr, group = "ApiTUIBehavior" })
        if vim.api.nvim_win_is_valid(parent_editor_win) then vim.api.nvim_set_current_win(parent_editor_win) end

        require("input-remove").confirm_delete({
            name = item.data.name,
            label = "API",
            on_confirm = function()
                table.remove(api_data.items, item.idx)
                save_data(api_data)
                _G.trigger_api_render()
            end,
            on_cancel = function()
                _G.trigger_api_render()
            end,
        })
    end, opt_i)

    vim.keymap.set("i", "<BS>", function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        return cursor[2] > prefix_len and "<BS>" or ""
    end, { buffer = bufnr, expr = true, silent = true })

    vim.cmd("startinsert!")
end

vim.keymap.set("n", "<leader>w", open_api_manager)
