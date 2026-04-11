return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  cmd = "Telescope",
  keys = {
    {
      "<leader>f",
      function()
        require("telescope.builtin").find_files({
          cwd = vim.fn.getcwd(),
          -- Sobrescribimos para este comando específico si es necesario
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              anchor = "E",      -- Pegado a la derecha
              anchor_padding = 10, -- Margen derecho
              width = 0.35,      -- Ancho del 35% de la pantalla
              height = 0.85,     -- Alto del 85% para dejar margen arriba/abajo
              prompt_position = "bottom",
            },
          },
          border = true,
          title = false,
        })
      end,
      desc = "Find files (Right side)",
    },
  },
  opts = {
    defaults = {
      prompt_prefix = " ",
      selection_caret = " ",
      entry_prefix = " ",
      initial_mode = "insert",
      selection_strategy = "reset",
      sorting_strategy = "ascending",
      
      -- Configuración global para que todos los Telescope salgan a la derecha
      layout_strategy = "horizontal",
      layout_config = {
        horizontal = {
          anchor = "E",
          anchor_padding = 3,
          width = 0.35,
          height = 0.85,
          prompt_position = "bottom",
        },
      },
      
      border = true,
      borderchars = { ' ', ' ', ' ', ' ', '┌', '┐', '┘', '└' },
      preview = false,
      title = false,
    },
  },
}
