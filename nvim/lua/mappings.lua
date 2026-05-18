local map = vim.keymap.set

-- Mapeos generales
map("n", "<leader>s", ":split<CR>", { noremap = true, silent = true })
map("n", "<leader>v", ":vsplit<CR>", { noremap = true, silent = true })
map("n", "<leader>lt", ":terminal<CR>A", { noremap = true, silent = true })
map("n", "<leader>q", ":quit!<CR>", { noremap = true, silent = true })
map("n", "-", ":source %<CR>", { noremap = true, silent = true })
map("n", "w", ":SaveOrPrompt<CR>")
map("n", "<Tab>", "<C-w>w<CR>", { noremap = true, silent = true })
map("n", "<S-Tab>", ":bn<CR>", { noremap = true, silent = true })
map("n", "zz", "<Esc>yyp", { noremap = true, silent = true })
map("n", "za", "<Esc>kyyp", { noremap = true, silent = true })
map("i", "<C-p>", "<Esc>pa", { noremap = true, silent = true})
map("n", "<S-p>", "o<Esc>", { noremap = true, silent = true })
map({"n", "i"}, "<C-v>", "<Esc>:vsplit<CR>", { noremap = true, silent = true })
map({"n", "i"}, "<C-z>", "<Esc>:undo<CR>", { noremap = true, silent = true })
map({"n", "i"}, "<C-q>", "<Esc>:quit!<CR>", { noremap = true, silent = true })
map("n", "<C-d>", "<Esc>yy<Esc>p", { noremap = true, silent = true })
map({"n", "i"}, "<C-x>", "<Esc>:qall!<CR>", { noremap = true, silent = true })
map("n", "<C-a>", "<Esc>ggVG", { noremap = true, silent = true })
map("n", "m", "5l", { noremap = true, silent = true })
map("n", "n", "5h", { noremap = true, silent = true })
map({"n", "i"}, "<C-S-Right>", "<C-w>>", { noremap = true, silent = true })
map({"n", "i"}, "<C-S-Left>", "<C-w><", { noremap = true, silent = true })
map("n", "m", "<Esc>o<Esc>k", { noremap = true, silent = true })
map("v", "p", "di", { noremap = true, silent = true})
map({"n", "i"}, "<C-Up>", "<Esc>5k", { noremap = true, silent = true})
map({"n", "i"}, "<C-Down>", "<Esc>5j", { noremap = true, silent = true})
map("n", "b", "5h", { noremap = true, silent = true})
map("n", "n", "5l", { noremap = true, silent = true})
map({"i", "n"}, "<C-i>", "<Esc>ji", { noremap = true, silent = true})
map({"i", "n"}, "<C-o>", "<Esc>o", { noremap = true, silent = true})
map({"i", "n"}, "<C-,>", "<Esc>$a,<CR>", { noremap = true, silent = true})
map({"i", "n"}, "<C-;>", "<Esc>$a;<CR>", { noremap = true, silent = true})
map("n", "<S-q>", ":bp<CR>", { noremap = true, silent = true})
map("t", "<Esc>", "<C-\\><C-n>", { noremap = true, silent = true})
map("n", "<C-n>", ":noh<CR>", { noremap = true, silent = true})
map("i", "<C-$>", "<Esc>$a", {})




vim.cmd([[
  let g:sym_pattern = '[(){}\[\]"' . "'" . ']'
  nnoremap <C-l> :call search(g:sym_pattern, '')<CR>
  inoremap <C-l> <Esc>:call search(g:sym_pattern, '')<CR>a
]])





---
-- Esto abrirá (o cerrará) toda la barra lateral con ambos widgets
map({"n", "i"}, "<C-s>", "<Esc>:SidebarNvimToggle<CR>", { noremap = true, silent = true })

---

map({"n", "i", "v"}, "<S-Right>", function()
    local mode = vim.api.nvim_get_mode().mode

    if mode == "i" then
        -- Si es modo Insertar: Escapa, entra en Visual y mueve
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>v<Right>", true, false, true), "n", false)
    elseif mode == "v" or mode == "V" or mode == "\22" then
        -- Si ya es modo Visual: Solo mueve para extender la selección
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Right>", true, false, true), "n", false)
    else
        -- Si es modo Normal: Entra en Visual y mueve
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("v<Right>", true, false, true), "n", false)
    end
end, { noremap = true, silent = true })

map({"n", "i", "v"}, "<S-Left>", function()
    local mode = vim.api.nvim_get_mode().mode

    if mode == "i" then
        -- Si es modo Insertar: Escapa, entra en Visual y mueve
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>v<Left>", true, false, true), "n", false)
    elseif mode == "v" or mode == "V" or mode == "\22" then
        -- Si ya es modo Visual: Solo mueve para extender la selección
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Left>", true, false, true), "n", false)
    else
        -- Si es modo Normal: Entra en Visual y mueve
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("v<Left>", true, false, true), "n", false)
    end
end, { noremap = true, silent = true })


-- No copiar al eliminar caracteres individuales (x)
vim.keymap.set('n', 'x', '"_x')
vim.keymap.set('n', 'X', '"_X')

-- No copiar al eliminar con d (ej: dd, dw, diw)
vim.keymap.set('n', 'd', '"_d')
vim.keymap.set('v', 'd', '"_d')

-- No copiar al cambiar texto (c) (ej: cw, ciw)
vim.keymap.set('n', 'c', '"_c')
vim.keymap.set('v', 'c', '"_c')

if vim.g.neovide then
  -- Función para pegar usando la API de Neovim y el registro "+" (sistema)
  local function paste()
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
    vim.cmd("SaveOrPrompt")
  end

  -- Mapeo para todos los modos: n, i, v, c, t
  vim.keymap.set({'n', 'v', 's', 'x', 'o', 'i', 'l', 'c', 't'}, '<C-S-v>', paste, { silent = true })
end

vim.api.nvim_create_user_command('SaveOrPrompt', function()
    if vim.bo.buftype ~= '' then return end
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == '' then
        if _G.open_input_creator_global then
            _G.open_input_creator_global()
            vim.api.nvim_feedkeys("", "n", false)
        end
    else
        vim.cmd('w')
    end
end, {})

local keymaps = vim.api.nvim_get_keymap('n')
for _, map in ipairs(keymaps) do
    if map.lhs:sub(1, 5):lower() == "<c-w>" then
        vim.keymap.del('n', map.lhs)
    end
end

map("n", ",w", ":SaveOrPrompt<CR>")
-- Tu mapa original para iniciar seleccionando la palabra
vim.keymap.set({"n", "i"}, "<C-w>", "<Esc>viw", { silent = true })

-- Mapa visual inteligente para expandir a delimitadores cercanos
vim.keymap.set("x", "<C-w>", function()
    -- Obtener el texto de la línea actual y la posición del cursor
    local line = vim.fn.getline(".")
    local col = vim.fn.col(".")

    -- Buscar si hay paréntesis o comillas alrededor de la posición actual
    local antes = string.sub(line, 1, col)
    local despues = string.sub(line, col)

    -- Detectar si estamos dentro de comillas dobles
    if string.find(antes, '"[^"]*$') and string.find(despues, '^[^"]*"') then
        vim.cmd("normal! i\"") -- Selecciona dentro de las comillas
    -- Detectar si estamos dentro de paréntesis
    elseif string.find(antes, '%([^%)]*$') and string.find(despues, '^[^%(]*%)') then
        vim.cmd("normal! i(")  -- Selecciona dentro de los paréntesis
    else
        -- Si no encuentra delimitadores, expande al párrafo como respaldo
        vim.cmd("normal! ap")
    end
end, { silent = true })

-- Crear un grupo de autocomandos para evitar duplicados
local autosave_group = vim.api.nvim_create_augroup("AutoSaveGroup", { clear = true })

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
    group = autosave_group,
    pattern = "*",
    command = "silent! update",
})

