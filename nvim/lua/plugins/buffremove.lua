return {
    'echasnovski/mini.bufremove',
    version = false,
    config = function()
        require('mini.bufremove').setup()
        vim.keymap.set('n', '<Leader>d', '<Cmd>lua MiniBufremove.delete(0, false)<CR>', { desc = 'Cerrar búfer' })
    end
}

