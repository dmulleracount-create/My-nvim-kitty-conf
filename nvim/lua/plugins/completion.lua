return {
   {
      "hrsh7th/nvim-cmp",
      dependencies = {
         "hrsh7th/cmp-buffer",
         "hrsh7th/cmp-path",
         "hrsh7th/cmp-nvim-lsp",
         "L3MON4D3/LuaSnip",
         "saadparwaiz1/cmp_luasnip",
         "neovim/nvim-lspconfig",
         "williamboman/mason.nvim",
         "williamboman/mason-lspconfig.nvim",
      },
      event = "InsertEnter",
      config = function()
         local cmp = require("cmp")
         local luasnip = require("luasnip")

         local servers = { "ts_ls", "clangd", "rust_analyzer", "gopls", "pyright", "lua_ls", "vimls" }

         local on_attach = function(client, bufnr)
            local bufopts = { buffer = bufnr, silent = true, nowait = true }
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
            vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
            vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
            vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, bufopts)
            vim.keymap.set("n", "]d", vim.diagnostic.goto_next, bufopts)
         end

         local capabilities = require("cmp_nvim_lsp").default_capabilities()

         for _, server in ipairs(servers) do
            vim.lsp.config(server, {
               capabilities = capabilities,
               on_attach = on_attach,
               flags = { debounce_text_changes = 1000 },
            })
         end

         vim.lsp.config('lua_ls', {
            on_init = function(client)
               if client.workspace_folders then
                  local path = client.workspace_folders[1].name
                  if path ~= vim.fn.stdpath('config')
                     and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
                  then
                     return
                  end
               end
               client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
                  runtime = { version = 'LuaJIT' },
                  workspace = {
                     checkThirdParty = false,
                     library = { vim.env.VIMRUNTIME },
                  },
               })
            end,
            settings = { Lua = {} },
         })

         vim.lsp.config('cmake', {
            capabilities = capabilities,
            on_attach = on_attach,
            flags = { debounce_text_changes = 1000 },
         })

         require("mason").setup()
         require("mason-lspconfig").setup({
            ensure_installed = servers,
         })

         vim.lsp.enable('cmake')

         cmp.setup({
            window = {
               completion = cmp.config.window.bordered({
                  winhighlight = 'Normal:Pmenu',
                  border = 'none',
               }),
               documentation = cmp.config.window.bordered({
                  winhighlight = 'Normal:Pmenu',
                  border = 'none',
               }),
            },
            enabled = function()
               local win_config = vim.api.nvim_win_get_config(0)
               return win_config.relative == ""
            end,
            snippet = {
               expand = function(args)
                  luasnip.lsp_expand(args.body)
               end,
            },
            mapping = cmp.mapping.preset.insert({
               ["<C-k>"] = cmp.mapping.select_prev_item(),
               ["<C-j>"] = cmp.mapping.select_next_item(),
               ["<C-b>"] = cmp.mapping.scroll_docs(-4),
               ["<C-f>"] = cmp.mapping.scroll_docs(4),
               ["<C-Space>"] = cmp.mapping.complete(),
               ["<C-e>"] = cmp.mapping.abort(),
               ["<CR>"] = cmp.mapping.confirm({ select = true }),
            }),
            sources = cmp.config.sources({
               { name = "nvim_lsp" },
               { name = "luasnip" },
            }, {
               { name = "buffer" },
               { name = "path" },
            }),
         })
      end,
   },
}
