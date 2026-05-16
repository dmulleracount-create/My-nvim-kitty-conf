return {
  "salkhalil/summon.nvim",
  config = function()
    require("summon").setup({
      commands = {
        ekphos = {
          -- SOLUCIÓN: vim.fn.expand transforma '~/' en '/home/dani/' de forma nativa en Linux
          command = vim.fn.expand("~/.cargo/bin/ekphos"), 
          
          float = {
            border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
            title = " [ EKPHOS ] ",
            title_pos = "center",
            width = 0.85,
            height = 0.85,
          },
          terminal_keys = true, 
        },
      },
    })

    -- Integración estética minimalista Tokyonight
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "*",
      callback = function()
        vim.api.nvim_set_hl(0, "FloatBorder", { link = "TokyoNightBorder" or "FloatBorder" })
        vim.api.nvim_set_hl(0, "FloatTitle", { link = "TokyoNightTitle" or "Identifier" })
      end,
    })
  end,
  keys = {
    { "<leader>ek", "<cmd>Summon ekphos<cr>", desc = "Abrir Ekphos" },
  },
}

