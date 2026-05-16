local function open_deleter()
    local width, height = 40, 1
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    local prefix = " - "
    local prefix_len = #prefix
    local bufnr = vim.api.nvim_create_buf(false, true)
    
    vim.api.nvim_set_hl(0, "MiniCreatorBorder", { fg = "#414868" })

    local win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor", width = width, height = height,
        row = row, col = col, style = "minimal", border = "single"
    })

    -- Mismo highlight que el creador
    vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = win })
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix })

    local function close_safe()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
            vim.cmd("stopinsert")
        end
    end

    -- BLOQUEO DE CURSOR
    vim.api.nvim_create_autocmd("CursorMovedI", {
        buffer = bufnr,
        callback = function()
            local cursor = vim.api.nvim_win_get_cursor(win)
            if cursor[2] < prefix_len then
                vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
            end
        end
    })

    local function confirm()
        local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        local input = line:sub(prefix_len + 1):gsub("^%s*(.-)%s*$", "%1")
        if input ~= "" then
            local targets = vim.split(input, " ", { trimempty = true })
            for _, target in ipairs(targets) do
                local path = vim.fn.expand(target)
                if vim.fn.empty(vim.fn.glob(path)) == 0 then
                    vim.fn.delete(path, "rf")
                end
            end
            vim.schedule(function() vim.cmd("checktime") end)
        end
        close_safe()
    end

    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("i", "<CR>", confirm, opts)
    vim.keymap.set("i", "<Esc>", close_safe, opts)
    vim.keymap.set("i", "<BS>", function()
        return vim.api.nvim_win_get_cursor(win)[2] > prefix_len and "<BS>" or ""
    end, { buffer = bufnr, expr = true })

    vim.cmd("startinsert!")
    vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
end

vim.keymap.set("n", "<leader>y", open_deleter, { desc = "Mini Deleter" })



