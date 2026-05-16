return {
    "OXY2DEV/markview.nvim",
    lazy = false,      -- Recomendado cargarlo al inicio para evitar parpadeos
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons"
    },
    config = function()
        require("markview").setup({
            -- Esta es la parte crucial para tu ventana de notas
            preview = {
                enable = true,
                -- Modos donde se verá el renderizado (normal e insert)
                modes = { "n", "i", "no", "c" }, 
                hybrid_mode = true, -- Renderiza mientras escribes
                callbacks = {
                    on_enable = function()
                        -- Opcional: ocultar caracteres de markdown (como los asteriscos)
                        vim.wo.conceallevel = 2
                    end
                }
            },
            -- IMPORTANTE: Añade 'notanv' para que reconozca tu buffer de notas
            filetypes = { "markdown", "quarto", "rmd", "notanv" },
        })
    end
}
