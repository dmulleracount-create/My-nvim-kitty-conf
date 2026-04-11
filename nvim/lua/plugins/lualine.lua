return {
  "nvim-lualine/lualine.nvim",
  dependencies = { 
    "nvim-tree/nvim-web-devicons",
    "rebelot/kanagawa.nvim",
  },
  event = "VimEnter",
  config = function()
    require('kanagawa').load()
    local colors = require('kanagawa.colors').setup().theme
    local kanagawa = {
      normal = {
        a = { bg = colors.syn.fun, fg = colors.ui.bg_m3 },
        b = { bg = colors.diff.change, fg = colors.syn.fun },
        c = { bg = colors.ui.bg_p1, fg = colors.ui.fg },
      },
      insert = {
        a = { bg = colors.diag.ok, fg = colors.ui.bg },
        b = { bg = colors.ui.bg, fg = colors.diag.ok },
      },
      command = {
        a = { bg = colors.syn.operator, fg = colors.ui.bg },
        b = { bg = colors.ui.bg, fg = colors.syn.operator },
      },
      visual = {
        a = { bg = colors.syn.keyword, fg = colors.ui.bg },
        b = { bg = colors.ui.bg, fg = colors.syn.keyword },
      },
      replace = {
        a = { bg = colors.syn.constant, fg = colors.ui.bg },
        b = { bg = colors.ui.bg, fg = colors.syn.constant },
      },
      inactive = {
        a = { bg = colors.ui.bg_m3, fg = colors.ui.fg_dim },
        b = { bg = colors.ui.bg_m3, fg = colors.ui.fg_dim },
        c = { bg = colors.ui.bg_m3, fg = colors.ui.fg_dim },
      },
    }
    require('lualine').setup {
      options = {
        theme = kanagawa,
        section_separators = { left = '', right = '' },
        component_separators = { left = '', right = '' },
        globalstatus = true,
      },
      sections = {
        lualine_a = {'mode'},
        lualine_b = {
        function()
          return vim.fn.getcwd() -- Retorna la ruta del directorio actual
        end,
       },
       lualine_c = {
          {
            'filename',
            file_status = false,
            path = 1,
            color = { fg = '#6c7086', gui = 'italic' },
          }
        },
        lualine_x = {
          {'filetype', icon = ''},
          {
            function()
              local count = vim.tbl_keys(vim.diagnostic.get(0))
              return #count > 0 and '● ' .. #count or ''
            end,
            color = { fg = '#f38ba8' },
          },
        },
        lualine_y = {'progress'},
        lualine_z = {
          {
            function()
              return vim.fn.line('.') .. '/' .. vim.fn.line('$')
            end,
            color = { fg = '#1e1e2e' },
          },
        }
      },
    }
  end,
}
