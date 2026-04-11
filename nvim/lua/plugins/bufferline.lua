return {
  "akinsho/bufferline.nvim",
  dependencies = "nvim-tree/nvim-web-devicons",
  version = "*",
  opts = {
    options = {
      indicator = {
        style = "slope",
        icon = "",
      },
      close_icon = "",
      modified_icon = " +",
      left_trunc_marker = "󰜷",
      right_trunc_marker = "󰜵",
      max_name_length = 18,
      max_prefix_length = 13,
      tab_size = 10,
      show_buffer_close_icons = false,
      show_close_icon = false,
      persist_buffer_sort = true,
      numbers = "ordinal",
      diagnostics = "nvim_lsp",
      offsets = {
        {
          filetype = { "NvimTree", "neo-tree", "packer", "lazy" },
          text = "",
          highlight = "BufferLineOffset",
          text_align = "left",
        },
      },
      separator_style = "slope",
      name_formatter = function(buf)
        return buf.name
      end,
    },
  },
}
