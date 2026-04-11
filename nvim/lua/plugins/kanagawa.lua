return {
  "rebelot/kanagawa.nvim",
  lazy = false,    -- Asegura que el tema cargue pronto
  priority = 1000, -- Prioridad alta para evitar parpadeos
  config = function()
    require("kanagawa").setup({
      background = { dark = "dragon", light = "lotus" },
             overrides = function(colors)
        local bg_bar = "#0f1014" -- Tu color de fondo de la barra
        local bg_active = "#181616" -- Tu color de buffer seleccionado

        return {
            -- 1. El fondo total de la barra (donde no hay buffers)
            BufferLineFill = { bg = bg_bar },
            
            -- 2. Los buffers que NO están seleccionados (inactivos)
            BufferLineBackground = { bg = bg_bar, fg = "#616367" },

            -- 3. El buffer seleccionado
            BufferLineBufferSelected = { bg = bg_active, bold = true },

            BufferLineNumbers = { bg = bg_bar }, 
            BufferLineNumbersVisible = { bg = bg_bar },


            -- 4. LOS SEPARADORES (Aquí suele estar el problema del "blanco")
            BufferLineSeparator = { fg = bg_bar, bg = bg_bar },
            BufferLineSeparatorVisible = { fg = bg_bar, bg = bg_bar },
            BufferLineSeparatorSelected = { fg = bg_bar, bg = bg_active },

            -- 5. El "Offset" (si usas nvim-tree o neo-tree a un lado)
            BufferLineOffsetSeparator = { fg = bg_bar, bg = bg_bar },
        }
      end,
   })

    vim.cmd("colorscheme kanagawa")
  end,
}

