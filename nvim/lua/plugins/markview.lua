return {
    "OXY2DEV/markview.nvim",
    lazy = false,
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons"
    },
    config = function()
        require("markview").setup({
            preview = {
                enable = true,
                modes = { "n", "i", "no", "c" },
                hybrid_mode = true,
                icon_provider = "",
                condition = function(buf)
                    if vim.bo[buf].filetype ~= "markdown" then
                        return false
                    end
                    local wins = vim.fn.win_findbuf(buf)
                    for _, win in ipairs(wins) do
                        if vim.api.nvim_win_get_config(win).relative ~= "" then
                            return false
                        end
                    end
                    return true
                end,
                callbacks = {
                    on_enable = function()
                        vim.wo.conceallevel = 2
                    end,
                },
            },
            markdown = {
                enable = true,
                headings = {
                    enable = true,
                    shift_width = 0,
                    heading_1 = { style = "simple", hl = "MarkviewHeading1" },
                    heading_2 = { style = "simple", hl = "MarkviewHeading2" },
                    heading_3 = { style = "simple", hl = "MarkviewHeading3" },
                    heading_4 = { style = "simple", hl = "MarkviewHeading4" },
                    heading_5 = { style = "simple", hl = "MarkviewHeading5" },
                    heading_6 = { style = "simple", hl = "MarkviewHeading6" },
                    setext_1 = { style = "simple", hl = "MarkviewHeading1" },
                    setext_2 = { style = "simple", hl = "MarkviewHeading2" },
                },
                code_blocks = {
                    enable = true,
                    style = "block",
                    border_hl = "MarkviewCode",
                    info_hl = "MarkviewCodeInfo",
                    label_direction = "right",
                    min_width = 40,
                    pad_amount = 2,
                    pad_char = " ",
                    sign = false,
                    default = {
                        block_hl = "MarkviewCode",
                        pad_hl = "MarkviewCode",
                    },
                },
                block_quotes = {
                    enable = true,
                    default = { border = "▋", hl = "MarkviewBlockQuoteDefault" },
                },
                list_items = {
                    enable = true,
                    marker_minus = { text = "•", hl = "MarkviewListItemMinus", add_padding = true },
                    marker_plus = { text = "◦", hl = "MarkviewListItemPlus", add_padding = true },
                    marker_star = { text = "▪", hl = "MarkviewListItemStar", add_padding = true },
                },
                horizontal_rules = { enable = true },
                tables = { enable = true },
                metadata_minus = { enable = true, hl = "MarkviewCode", border_hl = "MarkviewCodeFg" },
                metadata_plus = { enable = true, hl = "MarkviewCode", border_hl = "MarkviewCodeFg" },
            },
            markdown_inline = {
                enable = true,
                checkboxes = { enable = true },
                hyperlinks = { enable = true },
                inline_codes = { enable = true },
                highlights = { enable = true },
            },
            latex = { enable = false },
            html = { enable = false },
            typst = { enable = false },
            yaml = { enable = false },
        })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function()
                vim.wo.foldmethod = "expr"
                vim.wo.foldexpr = "v:lua.require'markview'.foldexpr()"
                vim.wo.foldtext = "v:lua.require'markview'.foldtext()"
            end,
        })
    end
}
