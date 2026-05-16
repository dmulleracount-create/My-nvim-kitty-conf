-- ==========================================================================
-- 0. CONFIGURACIÓN GLOBAL Y ALIAS
-- ==========================================================================
vim.treesitter.language.register("markdown", "notanv")

_G.notes_float_win = nil

-- ==========================================================================
-- 1. RUTAS Y COLORES (TOKYONIGHT)
-- ==========================================================================
local notes_dir = vim.fn.stdpath("data") .. "/notes_files"
local notes_config = vim.fn.stdpath("data") .. "/notes_manager.json"

if vim.fn.isdirectory(notes_dir) == 0 then vim.fn.mkdir(notes_dir, "p") end

local colors = {
    bg = "#1a1b26", fg = "#c0caf5", border = "#414868",
    sel_bg = "#2f334d", purple = "#7499ea", blue = "#7aa2f7"
}

vim.api.nvim_set_hl(0, "NoteNormal", { bg = colors.bg, fg = colors.fg })
vim.api.nvim_set_hl(0, "NoteBorder", { fg = colors.border, bg = colors.bg })
vim.api.nvim_set_hl(0, "NoteSel", { bg = colors.sel_bg, bold = true })
vim.api.nvim_set_hl(0, "NoteTitle", { fg = colors.purple, bg = colors.bg, bold = true })
vim.api.nvim_set_hl(0, "NoteProject", { fg = colors.purple, bold = true })
-- Cursor "pending": barra horizontal fina color púrpura
vim.api.nvim_set_hl(0, "NoteFloatingCursor", { fg = colors.purple, blend = 0 })

-- ==========================================================================
-- 2. PERSISTENCIA
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
    return { default_file = "", projects = { { name = "General", notes = {} } } }
end

local notes_data = load_data()

-- ==========================================================================
-- 3. VENTANA DE NOTA (REDIMENSIÓN + ICONO 󰎚)
-- ==========================================================================
local function open_note_buffer(entry)
    if _G.notes_float_win and vim.api.nvim_win_is_valid(_G.notes_float_win) then
        vim.api.nvim_win_close(_G.notes_float_win, true)
    end

    local path = notes_dir .. "/" .. entry.file
    local bnr = vim.fn.bufadd(path)
    vim.fn.bufload(bnr)
    
    vim.api.nvim_set_option_value("syntax", "markdown", { buf = bnr })
    vim.api.nvim_set_option_value("filetype", "notanv", { buf = bnr })

    local is_expanded = false
    local tw, th = math.floor(vim.o.columns * 0.3), math.floor(vim.o.lines * 0.4)
    
    local win = vim.api.nvim_open_win(bnr, true, {
        relative = "editor", width = tw, height = th,
        row = vim.o.lines - th - 5, col = vim.o.columns - tw - 2,
        style = "minimal", border = "single",
        title = { { "   " .. entry.name .. " ", "NoteTitle" } },
        title_pos = "center" 
    })

    _G.notes_float_win = win
    _G.last_float_win = win
    vim.api.nvim_set_option_value("winhl", "Normal:NoteNormal,FloatBorder:NoteBorder", { win = win })
    vim.api.nvim_set_option_value("wrap", true, { win = win })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win })

    vim.schedule(function() vim.cmd("Markview attach") end)
    vim.cmd("normal! $")

    local opts = { buffer = bnr, silent = true }
    vim.keymap.set("n", "q", "<cmd>w | q<CR>", opts)
    vim.keymap.set("n", "<Esc>", "<cmd>w | q<CR>", opts)
    
    -- Ctrl+b: Redimensionar (Fix E5108)
    vim.keymap.set({"n", "i"}, "<C-b>", function()
        is_expanded = not is_expanded
        local new_w = math.floor(vim.o.columns * (is_expanded and 0.5 or 0.3))
        local new_h = math.floor(vim.o.lines * (is_expanded and 0.6 or 0.4))
        vim.api.nvim_win_set_config(win, {
            relative = "editor",
            width = new_w, height = new_h,
            row = vim.o.lines - new_h - 5, col = vim.o.columns - new_w - 2,
        })
    end, opts)
end

-- ==========================================================================
-- 4. SALTO INTELIGENTE GLOBAL (Ctrl+b)
-- ==========================================================================
vim.keymap.set({"n", "i", "t"}, "<C-b>", function()
    if _G.last_float_win and vim.api.nvim_win_is_valid(_G.last_float_win) then
        if vim.api.nvim_get_current_win() ~= _G.last_float_win then
            vim.api.nvim_set_current_win(_G.last_float_win)
        end
    end
end)

-- ==========================================================================
-- 5. GESTOR (SIN MARGEN + CURSOR PENDING + ICONO 󰎚)
-- ==========================================================================
local function open_note_manager()
    local width, height = math.floor(vim.o.columns * 0.25), math.floor(vim.o.lines * 0.3)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local current_p_idx = nil 

    local win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor", width = width, height = height,
        row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2),
        style = "minimal", border = "single",
        title = { { " Notas ", "NoteTitle" } }, title_pos = "center"
    })

    -- FORZAR MODO NORMAL Y CURSOR PENDING
    vim.schedule(function() vim.cmd("stopinsert") end)
    
    vim.api.nvim_set_option_value("winhl", "Normal:NoteNormal,FloatBorder:NoteBorder,CursorLine:NoteSel", { win = win })
    vim.api.nvim_set_option_value("cursorline", true, { win = win })
    
    local original_guicursor = vim.go.guicursor
    vim.go.guicursor = "n:hor20-NoteFloatingCursor-blinkon0"

    local line_map = {}

    local function render()
        local lines = {}
        line_map = {}
        
        if current_p_idx == nil then
            local active_p_idx = nil
            for i, p in ipairs(notes_data.projects) do
                for _, n in ipairs(p.notes) do
                    if n.file == notes_data.default_file then active_p_idx = i break end
                end
            end

            for i, p in ipairs(notes_data.projects) do
                -- Sin margen izquierdo
                table.insert(lines, "  " .. p.name)
                line_map[#lines] = { type = "project", idx = i }
                if i == active_p_idx then
                    for j, n in ipairs(p.notes) do
                        local ind = (n.file == notes_data.default_file) and "· " or "  "
                        -- Icono 󰎚 forzado
                        table.insert(lines, string.format("  %s  %s", ind, n.name))
                        line_map[#lines] = { type = "note", p_idx = i, n_idx = j }
                    end
                end
            end
        else
            local p = notes_data.projects[current_p_idx]
            table.insert(lines, "  Atrás")
            line_map[#lines] = { type = "back" }
            for j, n in ipairs(p.notes) do
                local ind = (n.file == notes_data.default_file) and "· " or "  "
                -- Icono 󰎚 forzado y sin margen extra
                table.insert(lines, string.format("%s  %s", ind, n.name))
                line_map[#lines] = { type = "note", p_idx = current_p_idx, n_idx = j }
            end
        end

        vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

        vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
        for i, m in pairs(line_map) do
            if m.type == "project" then
                vim.api.nvim_buf_add_highlight(bufnr, -1, "NoteProject", i - 1, 0, -1)
            end
        end
    end

    local function close_ui()
        vim.go.guicursor = original_guicursor
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end

    local opts = { buffer = bufnr, silent = true }

    vim.keymap.set("n", "<CR>", function()
        local idx = vim.api.nvim_win_get_cursor(win)[1]
        local m = line_map[idx]
        if not m then return end
        if m.type == "project" then
            current_p_idx = m.idx
            render()
            vim.api.nvim_win_set_cursor(win, {1, 0})
        elseif m.type == "back" then
            current_p_idx = nil
            render()
        elseif m.type == "note" then
            close_ui()
            open_note_buffer(notes_data.projects[m.p_idx].notes[m.n_idx])
        end
    end, opts)

    vim.keymap.set("n", "<BS>", function() if current_p_idx then current_p_idx = nil render() end end, opts)
    vim.keymap.set("n", "u", function() if current_p_idx then current_p_idx = nil render() end end, opts)

    vim.keymap.set("n", "<C-p>", function()
        vim.go.guicursor = original_guicursor
        vim.ui.input({ prompt = "Nuevo Proyecto: " }, function(name)
            if name and name ~= "" then
                table.insert(notes_data.projects, { name = name, notes = {} })
                save_data(notes_data)
            end
            vim.go.guicursor = "n:hor20-NoteFloatingCursor-blinkon0"
            render()
        end)
    end, opts)

    vim.keymap.set("n", "<C-a>", function()
        local idx = vim.api.nvim_win_get_cursor(win)[1]
        local m = line_map[idx]
        local t_idx = (m and m.type ~= "back") and (m.p_idx or m.idx) or current_p_idx
        if not t_idx then return end
        vim.go.guicursor = original_guicursor
        vim.ui.input({ prompt = "Nueva Nota: " }, function(name)
            if name and name ~= "" then
                local p = notes_data.projects[t_idx]
                local fname = p.name:gsub("%s+", "_") .. "/" .. name:gsub("%s+", "_"):lower() .. ".md"
                -- ICONO FORZADO 󰎚 AL GUARDAR
                table.insert(p.notes, { name = name, file = fname, icon = " " })
                save_data(notes_data)
            end
            vim.go.guicursor = "n:hor20-NoteFloatingCursor-blinkon0"
            render()
        end)
    end, opts)

    vim.keymap.set("n", "<C-d>", function()
        local idx = vim.api.nvim_win_get_cursor(win)[1]
        local m = line_map[idx]
        if not m or m.type == "back" then return end
        if m.type == "project" then table.remove(notes_data.projects, m.idx)
        else table.remove(notes_data.projects[m.p_idx].notes, m.n_idx) end
        save_data(notes_data)
        render()
    end, opts)

    vim.keymap.set("n", "b", function()
        local idx = vim.api.nvim_win_get_cursor(win)[1]
        local m = line_map[idx]
        if m and m.type == "note" then
            notes_data.default_file = notes_data.projects[m.p_idx].notes[m.n_idx].file
            save_data(notes_data)
            render()
        end
    end, opts)

    vim.keymap.set("n", "q", close_ui, opts)
    vim.keymap.set("n", "<Esc>", close_ui, opts)
    render()
end

-- ==========================================================================
-- 6. MAPPINGS
-- ==========================================================================
vim.keymap.set("n", "<leader>m", open_note_manager)
vim.keymap.set("n", "<leader>n", function()
    for _, p in ipairs(notes_data.projects) do
        for _, n in ipairs(p.notes) do
            if n.file == notes_data.default_file then open_note_buffer(n) return end
        end
    end
end)
