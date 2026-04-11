local map = vim.keymap.set

map("n", "<leader>s", ":split<CR>", { noremap = true, silent = true })
map("n", "<leader>v", ":vsplit<CR>", { noremap = true, silent = true })
map("n", "<leader>t", ":terminal<CR>A", { noremap = true, silent = true })
map("n", ",d", ":bd<CR>", { noremap = true, silent = true })
map("n", "<leader>d", ":bd!<CR>", { noremap = true, silent = true })
map("n", ",q", ":quit<CR>", { noremap = true, silent = true })
map("n", "<leader>q", ":quit!<CR>", { noremap = true, silent = true })
map("n", "<leader>x", ":qall!<CR>", { noremap = true, silent = true })
map("n", ",s", ":source %<CR>")
map("n", "<Tab>", "<C-w>w<CR>", { noremap = true, silent = true })
map("n", "<S-Tab>", ":bn<CR>", { noremap = true, silent = true })
map("n", "zz", "<Esc>yyp", { noremap = true, silent = true })
map("n", "za", "<Esc>kyyp", { noremap = true, silent = true })
map("i", "<C-p>", "<Esc>pa", { noremap = true, silent = true})
map("n", "<S-p>", "o<Esc>", { noremap = true, silent = true })
map({"n", "i"}, "<C-v>", ":vsplit<CR>", { noremap = true, silent = true })
map({"n", "i"}, "<C-s>", ":split<CR>", { noremap = true, silent = true })
map({"n", "i"}, "<C-z>", ":undo<CR>", { noremap = true, silent = true })
map({"n", "i"}, "<C-q>", ":quit!<CR>", { noremap = true, silent = true })
map({"n", "i"}, "<C-d>", ":bd!<CR>", { noremap = true, silent = true })
map({"n", "i"}, "<C-x>", ":qall!<CR>", { noremap = true, silent = true })
map("n", "m", "5l", { noremap = true, silent = true })
map("n", "n", "5h", { noremap = true, silent = true })
map({"n", "i"}, "<C-S-Right>", "<C-w>>", { noremap = true, silent = true })
map({"n", "i"}, "<C-S-Left>", "<C-w><", { noremap = true, silent = true })

vim.api.nvim_create_user_command('SaveOrPrompt', function()
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == '' then
        local filename = vim.fn.input('Enter filename: ')
        if filename ~= '' then
            vim.cmd('w ' .. filename)
        end
    else
        vim.cmd('w')
    end
end, {})

map("n", ",w", ":SaveOrPrompt<CR>")
map({"n", "i", "v"}, "<C-w>", ":SaveOrPrompt<CR>")


