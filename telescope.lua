return {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-tree/nvim-web-devicons',
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
    },
    config = function()
        local telescope    = require('telescope')
        local actions      = require('telescope.actions')
        local action_state = require('telescope.actions.state')
        local pickers      = require('telescope.pickers')
        local finders      = require('telescope.finders')
        local conf         = require('telescope.config').values
        local previewers   = require('telescope.previewers')
        local devicons     = require('nvim-web-devicons')

        local show_dotfiles = false
        local bg_color      = '#b83b3b'
        local prompt_bg     = '#1e1e1e'
        local DASH          = "—" 
        local ICON_FOLDER   = "" -- Icono para carpetas

        local hl_groups = {
            TelescopeNormal         = { bg = bg_color },
            TelescopeBorder         = { fg = bg_color,  bg = bg_color  },
            TelescopePromptNormal   = { bg = prompt_bg },
            TelescopePromptBorder   = { fg = prompt_bg, bg = prompt_bg },
            TelescopePromptTitle    = { fg = '#ffffff',  bg = '#ff5f00', bold = true },
            TelescopeSelection      = { bg = '#2a2a2a',  bold = true },
            TelescopeSelectionCaret = { fg = '#2a2a2a',  bg = '#2a2a2a' },
            TelescopePreviewNormal  = { bg = bg_color },
            TelescopePreviewBorder  = { fg = bg_color,  bg = bg_color  },
        }
        for group, hl in pairs(hl_groups) do
            vim.api.nvim_set_hl(0, group, hl)
        end

        local function make_title(label, win_width)
            local side_dashes = string.rep(DASH, 30)
            local full_label = side_dashes .. " " .. label .. " " .. side_dashes
            local label_w = vim.fn.strdisplaywidth(full_label)
            
            if not win_width or label_w >= win_width then return full_label end
            
            local padding = math.floor((win_width - label_w) / 2)
            return string.rep(" ", padding) .. full_label
        end

        local function get_ivy_opts(extra)
            return require('telescope.themes').get_ivy(vim.tbl_extend('force', {
                hidden          = show_dotfiles,
                prompt_title    = make_title(extra and extra.title or "Files"),
                results_title   = false,
                preview_title   = false,
                layout_strategy = "bottom_pane",
                layout_config   = { height = 0.7, preview_width = 0.5, preview_cutoff = 0 },
                borderchars     = { 
                    prompt  = {" "," "," "," "," "," "," "," "}, 
                    results = {" "," "," "," "," "," "," "," "}, 
                    preview = {" "," "," "," "," "," "," "," "} 
                },
                winblend        = 0,
            }, extra or {}))
        end

        local uv = vim.uv or vim.loop

        local function fill_dir_buf(bufnr, target_dir)
            if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
            local lines, hl_info = {}, {}
            local fd = uv.fs_scandir(target_dir)
            
            if fd then
                local items = {}
                while true do
                    local name, typ = uv.fs_scandir_next(fd)
                    if not name then break end
                    if show_dotfiles or name:sub(1, 1) ~= "." then
                        table.insert(items, { name = name, typ = typ })
                    end
                end
                table.sort(items, function(a, b)
                    local a_d = a.typ == "directory" or vim.fn.isdirectory(target_dir..'/'..a.name) == 1
                    local b_d = b.typ == "directory" or vim.fn.isdirectory(target_dir..'/'..b.name) == 1
                    if a_d ~= b_d then return a_d end
                    return a.name:lower() < b.name:lower()
                end)

                for i, item in ipairs(items) do
                    local is_dir = item.typ == "directory" or vim.fn.isdirectory(target_dir..'/'..item.name) == 1
                    local icon, icon_hl
                    if is_dir then
                        icon, icon_hl = ICON_FOLDER, "Directory"
                    else
                        local ext = item.name:match("^.+%.(.+)$") or ""
                        icon, icon_hl = devicons.get_icon(item.name, ext, { default = true })
                    end
                    table.insert(lines, string.format("%s  %s", icon or "", item.name))
                    table.insert(hl_info, { line = i-1, hl = icon_hl or "Normal", icon_len = #(icon or "") })
                end
            end

            vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            vim.api.nvim_buf_set_option(bufnr, 'number', false)
            vim.api.nvim_buf_set_option(bufnr, 'relativenumber', false)
            for _, info in ipairs(hl_info) do
                pcall(vim.api.nvim_buf_add_highlight, bufnr, -1, info.hl, info.line, 0, info.icon_len)
            end
            vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
        end

        local dir_previewer = previewers.new_buffer_previewer({
            title = false,
            define_preview = function(self, entry)
                local target = entry.value == ".." and vim.fs.dirname(entry.path) or entry.path
                fill_dir_buf(self.state.bufnr, target)
            end
        })

        local function fs_create(base_dir, name, is_folder)
            if not name or name == '' then return false end
            local path = base_dir .. '/' .. name
            if is_folder then
                return vim.fn.mkdir(path, 'p') == 1
            else
                local parent = vim.fs.dirname(path)
                if parent ~= base_dir then vim.fn.mkdir(parent, 'p') end
                local f = io.open(path, 'w')
                if f then f:close(); return true end
                return false
            end
        end

        local function fs_delete(path)
            local stat = uv.fs_stat(path)
            if not stat then return false end
            return vim.fn.delete(path, stat.type == 'directory' and 'rf' or '') == 0
        end

        local function fs_rename(old_path, new_path)
            return vim.loop.fs_rename(old_path, new_path)
        end

        -- ─────────────────────────── Picker CD mejorado ───────────────────────────

        local function open_dir_picker(cwd)
            cwd = (cwd or vim.fn.getcwd()):gsub("/$", "")
            local dirs = {}
            local fd = uv.fs_scandir(cwd)
            if fd then
                while true do
                    local name, typ = uv.fs_scandir_next(fd)
                    if not name then break end
                    if (typ == "directory" or vim.fn.isdirectory(cwd..'/'..name) == 1) and (show_dotfiles or name:sub(1,1) ~= ".") then
                        table.insert(dirs, name)
                    end
                end
            end
            table.sort(dirs)

            local entries = { { value = "..", display = "..", path = vim.fs.dirname(cwd) } }
            for _, d in ipairs(dirs) do 
                table.insert(entries, { value = d, display = ICON_FOLDER .. "  " .. d, path = cwd..'/'..d }) 
            end

            pickers.new(get_ivy_opts({ title = "CD: " .. vim.fn.fnamemodify(cwd, ":~") }), {
                finder = finders.new_table({ 
                    results = entries, 
                    entry_maker = function(e) return { value=e.value, display=e.display, ordinal=e.value, path=e.path } end 
                }),
                sorter = conf.generic_sorter({}),
                previewer = dir_previewer,
                attach_mappings = function(prompt_bufnr, map)
                    local function enter_dir()
                        local sel = action_state.get_selected_entry()
                        if sel.value == ".." or vim.fn.isdirectory(sel.path) == 1 then
                            actions.close(prompt_bufnr)
                            open_dir_picker(sel.path)
                        else
                            actions.close(prompt_bufnr)
                            vim.cmd("cd " .. sel.path)
                        end
                    end
                    local function select_cd()
                        local sel = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        vim.cmd("cd " .. sel.path)
                    end

                    -- Ctrl+a: Crear Archivo
                    map('i', '<C-a>', function()
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Nombre del archivo: " }, function(name)
                            if name and name ~= "" then fs_create(cwd, name, false) end
                            open_dir_picker(cwd)
                        end)
                    end)

                    -- Ctrl+d: Crear Carpeta
                    map('i', '<C-d>', function()
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Nombre de la carpeta: " }, function(name)
                            if name and name ~= "" then fs_create(cwd, name, true) end
                            open_dir_picker(cwd)
                        end)
                    end)

                    -- Ctrl+x: Eliminar
                    map('i', '<C-x>', function()
                        local sel = action_state.get_selected_entry()
                        if not sel or sel.value == '..' then return end
                        local path = sel.path
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Delete? (y/n): " }, function(c)
                            if c and c:lower() == 'y' then fs_delete(path) end
                            open_dir_picker(cwd)
                        end)
                    end)

                    map('i', '<C-e>', function()
                        local sel = action_state.get_selected_entry()
                        if not sel or sel.value == '..' then return end
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Renombrar a: ", default = sel.value }, function(new_name)
                            if new_name and new_name ~= '' and new_name ~= sel.value then
                                fs_rename(sel.path, cwd .. '/' .. new_name)
                            end
                            open_dir_picker(cwd)
                        end)
                    end)

                    map('i', '<CR>', select_cd)
                    map('i', '<C-w>', enter_dir)
                    map('i', '<C-s>', enter_dir)
                    map('i', '<C-v>', function() show_dotfiles = not show_dotfiles; actions.close(prompt_bufnr); open_dir_picker(cwd) end)
                    return true
                end
            }):find()
        end

        -- ─────────────────────────── Terminal float ───────────────────────────
        local ts = { active = false }

        local function close_terminal()
            ts.active = false
            local win = ts.win
            local title_win = ts.title_win
            local prev_win = ts.prev_win
            ts.win = nil
            ts.title_win = nil
            ts.prev_win = nil

            if win and vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, false) end
            if title_win and vim.api.nvim_win_is_valid(title_win) then pcall(vim.api.nvim_win_close, title_win, false) end
            if prev_win and vim.api.nvim_win_is_valid(prev_win) then pcall(vim.api.nvim_win_close, prev_win, false) end
        end

        local function open_terminal()
            vim.fn.system('kitty --directory ' .. vim.fn.getcwd() .. ' &')
        end

        -- ─────────────────────────── Find Files con CRUD ───────────────────────────

        local function open_find_files()
            local opts = get_ivy_opts({ title = "Files" })
            require('telescope.builtin').find_files(vim.tbl_extend('force', opts, {
                attach_mappings = function(prompt_bufnr, map)
                    local base = vim.fn.getcwd()

                    map('i', '<C-v>', function()
                        show_dotfiles = not show_dotfiles
                        actions.close(prompt_bufnr)
                        open_find_files()
                    end)

                    -- Ctrl+a: Crear Archivo
                    map('i', '<C-a>', function()
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Nombre del archivo: " }, function(name)
                            if name and name ~= "" then
                                fs_create(base, name, false)
                                vim.schedule(function() vim.cmd('edit ' .. vim.fn.fnameescape(base .. '/' .. name)) end)
                            else
                                open_find_files()
                            end
                        end)
                    end)

                    -- Ctrl+d: Crear Carpeta
                    map('i', '<C-d>', function()
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Nombre de la carpeta: " }, function(name)
                            if name and name ~= "" then fs_create(base, name, true) end
                            open_find_files()
                        end)
                    end)

                    -- Ctrl+x: Eliminar
                    map('i', '<C-x>', function()
                        local sel = action_state.get_selected_entry()
                        if not sel then return end
                        local path = sel.path or sel.filename or sel.value
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Delete? (y/n): " }, function(c)
                            if c and c:lower() == 'y' then fs_delete(path) end
                            open_find_files()
                        end)
                    end)

                    map('i', '<C-e>', function()
                        local sel = action_state.get_selected_entry()
                        if not sel then return end
                        local path = sel.path or sel.filename or sel.value
                        local dir  = vim.fn.fnamemodify(path, ':h')
                        local old  = vim.fn.fnamemodify(path, ':t')
                        actions.close(prompt_bufnr)
                        vim.ui.input({ prompt = "Renombrar a: ", default = old }, function(new)
                            if new and new ~= '' and new ~= old then fs_rename(path, dir .. '/' .. new) end
                            open_find_files()
                        end)
                    end)

                    return true
                end
            }))
        end

        -- ─────────────────────────── Setup & Keymaps globales ───────────────────────────

        telescope.setup({
            defaults = {
                selection_caret = "  ", entry_prefix = "  ", initial_mode = "insert", border = true,
                tiebreak = function(current, existing, _)
                    local function depth(p) local _, c = p:gsub("/", "") return c end
                    local d1, d2 = depth(current.value), depth(existing.value)
                    if d1 ~= d2 then return d1 < d2 end
                    return current.value:lower() < existing.value:lower()
                end,
                mappings = { i = { ["<C-j>"] = actions.move_selection_next, ["<C-k>"] = actions.move_selection_previous, ["<esc>"] = actions.close } },
            },
        })

        vim.keymap.set('n', '<leader>f', open_find_files)
        vim.keymap.set({'n', 'i'},'<C-f>', open_find_files)
        vim.keymap.set('n', '<leader>c', function() open_dir_picker() end)
        vim.keymap.set({'n', 'i'}, '<C-c>', function() open_dir_picker() end)
        vim.keymap.set('n', '<leader>t',  open_terminal)
        vim.keymap.set({'n', 'i'}, '<C-t>',  open_terminal)
    end
}

