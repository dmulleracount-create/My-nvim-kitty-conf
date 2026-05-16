return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "folke/tokyonight.nvim",
  },
  event = "VimEnter",
  config = function()
    local colors = require("tokyonight.colors").setup()
    local tokyonight = {
      normal = {
        a = { bg = colors.blue,       fg = colors.bg_dark },
        b = { bg = colors.fg_gutter,  fg = colors.blue    },
        c = { bg = '#1a1b26', fg = colors.fg   },
      },
      insert = {
        a = { bg = colors.green, fg = colors.bg_dark },
        b = { bg = colors.fg_gutter, fg = colors.green },
        c = { bg = '#1a1b26', fg = colors.fg },
      },
      command = {
        a = { bg = '#7fb4ca', fg = colors.bg_dark },
        b = { bg = colors.fg_gutter, fg = '#7fb4ca' },
        c = { bg = '#1a1b26', fg = colors.fg },
      },
      visual = {
        a = { bg = colors.magenta, fg = colors.bg_dark },
        b = { bg = colors.fg_gutter, fg = colors.magenta },
        c = { bg = '#1a1b26', fg = colors.fg },
      },
      replace = {
        a = { bg = colors.orange, fg = colors.bg_dark },
        b = { bg = colors.fg_gutter, fg = colors.orange },
        c = { bg = '#1a1b26', fg = colors.fg },
      },
      inactive = {
        a = { bg = colors.bg_dark, fg = colors.fg_gutter },
        b = { bg = colors.bg_dark, fg = colors.fg_gutter },
        c = { bg = colors.bg_dark, fg = colors.fg_gutter },
      },
      terminal = {
        a = { bg = colors.green, fg = colors.bg_dark },
        b = { bg = colors.fg_gutter, fg = colors.green },
        c = { bg = '#1a1b26', fg = colors.fg },
      },
    }

    require('lualine').setup {
      options = {
        theme              = tokyonight,
        section_separators   = { left = '', right = '' },
        component_separators = { left = '', right = '' },
        globalstatus = true,
        -- Sin timer automatico: lualine solo se redibuja cuando nosotros lo pedimos
      },
      sections = {
        lualine_a = {
          {
            function()
              local m = vim.fn.mode()
              -- En modo terminal mostramos TERMINAL (mismo color que INSERT)
              if m == 't' then return 'TERMINAL' end
              return require('lualine.utils.mode').get_mode()
            end,
          }
        },
        lualine_b = {
          function()
            local cwd  = vim.fn.getcwd()
            local home = vim.fn.expand("~")
            if cwd:sub(1, #home) == home then
              local rel = cwd:sub(#home + 1):gsub("^/", "")
              return "~/" .. (rel ~= "" and rel or "")
            end
            return cwd
          end,
        },
        lualine_c = {
          {
            'filename', 
            color = { fg = colors.comment, gui = 'italic' },
            file_status = false,
            path        = 1,
          }
        },
        lualine_x = {
          { 'filetype', icon = '' },
          {
            function()
              local count = vim.tbl_keys(vim.diagnostic.get(0))
              return #count > 0 and 'o ' .. #count or ''
            end,
            color = { fg = colors.error },
          },
        },
        lualine_y = { 'progress' },
        lualine_z = {
          {
            function()
              return vim.fn.line('.') .. '/' .. vim.fn.line('$')
            end,
            color = { fg = colors.bg_dark },
          },
        }
      },
    }


  end,
}
