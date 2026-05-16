return {
  "brenton-leighton/multiple-cursors.nvim",
  version = "*", -- Usa la última versión estable
  opts = {},     -- Activa la configuración por defecto de forma automática
  keys = {
    {"<C-S-Down>", "<Cmd>MultipleCursorsAddDown<CR>", mode = {"n", "x"}, desc = "Añadir cursor abajo"},
    {"<C-S-Up>", "<Cmd>MultipleCursorsAddUp<CR>", mode = {"n", "x"}, desc = "Añadir cursor arriba"},
  },
}

