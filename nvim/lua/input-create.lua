local function open_creator()
  local width, height = 35, 1
  -- CAMBIOS AQUÍ:
  local row = 1  -- Una línea de margen superior
  -- Restamos el ancho, los bordes (2) y una columna de margen derecho
  local col = vim.api.nvim_win_get_width(0) - width - 3

  local prefix = " + "
  local prefix_len = #prefix
  local bufnr = vim.api.nvim_create_buf(false, true)
  
  vim.api.nvim_set_hl(0, "MiniCreatorBorder", { fg = "#414868" })
  
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "win", -- CAMBIO: Relativo a la ventana activa
    win = 0,          -- 0 significa la ventana actual
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single"
  })

  vim.api.nvim_set_option_value("winhl", "Normal:MiniCreatorNormal,FloatBorder:MiniCreatorBorder", { win = win })
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { prefix })
  
  local function close_safe()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      vim.cmd("stopinsert")
    end
  end

  -- BLOQUEO DE CURSOR: Evita que retroceda más allá del prefijo
  vim.api.nvim_create_autocmd("CursorMovedI", {
    buffer = bufnr,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[2] < prefix_len then
        vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
      end
    end
  })

  local function confirm()
    local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
    local input = line:sub(prefix_len + 1):gsub("^%s*(.-)%s*$", "%1")
    if input ~= "" then
      if input:sub(-1) == "/" then
        vim.fn.mkdir(input, "p")
      else
        local dir = vim.fn.fnamemodify(input, ":h")
        if dir ~= "." and vim.fn.isdirectory(dir) == 0 then
          vim.fn.mkdir(dir, "p")
        end
        close_safe()
        vim.schedule(function()
          vim.cmd("edit " .. vim.fn.fnameescape(input))
        end)
        return
      end
    end
    close_safe()
  end

  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("i", "<CR>", confirm, opts)
  vim.keymap.set("i", "<Esc>", close_safe, opts)

  -- Evitar borrado accidental del prefijo
  vim.keymap.set("i", "<BS>", function()
    return vim.api.nvim_win_get_cursor(win)[2] > prefix_len and "<BS>" or ""
  end, { buffer = bufnr, expr = true })

  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, prefix_len })
end

vim.keymap.set("n", "<leader>a", open_creator)

