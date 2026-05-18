return {
   "sidebar-nvim/sidebar.nvim",
   config = function()
      local files = require("sidebar-nvim.builtin.files")
      _G.todo_line_map = {}
      _G.sidebar_folder_lines = {} 

      -- Configuración de colores base
      vim.api.nvim_set_hl(0, "SidebarBlue", { fg = "#42a5f5", default = true })
      vim.api.nvim_set_hl(0, "SidebarNvimFileText", { fg = "#8899bb", default = true })

      -- =======================================================================
      -- 1. UTILIDADES DE POSICIÓN Y CÁLCULO
      -- =======================================================================
      
      local function get_sections_range()
         local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
         local sep_idx = nil
         for i, l in ipairs(lines) do
            if l:match("──────") then sep_idx = i break end
         end
         return 1, (sep_idx or 1) - 1, (sep_idx or 0) + 2, #lines
      end

      local function get_first_char_col(line_idx)
         local line_str = vim.api.nvim_buf_get_lines(0, line_idx - 1, line_idx, false)[1] or ""
         local col = line_str:find("%S")
         return col and (col - 1) or 0
      end

      -- Función auxiliar para partir un texto largo en una tabla de trozos (chunks)
      local function chunk_text(text, limit)
         local chunks = {}
         local i = 1
         while i <= #text do
            table.insert(chunks, text:sub(i, i + limit - 1))
            i = i + limit
         end
         return chunks
      end

      -- =======================================================================
      -- 2. SECCIÓN TO-DO (CON DETECCIÓN DE TAREAS LARGAS Y MULTILÍNEA)
      -- =======================================================================
      
      local todo_section = {
         title = "",
         icon = "",
         group = "todos",
         name = "todo_custom",
         
         bindings = {
            ["<CR>"] = function(line)
               local item = _G.todo_line_map[line]
               
               if item then
                  item.done = true
                  pcall(require("sidebar-nvim").update) 
                  
                  vim.defer_fn(function()
                     if _G.todos then
                        for i, t in ipairs(_G.todos) do
                           if t.task == item.task and t.cat == item.cat then
                              table.remove(_G.todos, i)
                              break
                           end
                        end
                        if _G.save_todos then _G.save_todos(_G.todos) end
                     end
                     
                     vim.schedule(function()
                        pcall(require("sidebar-nvim").update)
                     end)
                  end, 250)
               end
            end,

            ["b"] = function(line)
               local item = _G.todo_line_map[line]
               
               if item then
                  if _G.todos then
                     for _, t in ipairs(_G.todos) do t.current = false end
                     item.current = true
                     
                     for i, t in ipairs(_G.todos) do
                        if t.task == item.task and t.cat == item.cat then
                           table.remove(_G.todos, i)
                           break
                        end
                     end
                     table.insert(_G.todos, 1, item)
                     
                     if _G.save_todos then _G.save_todos(_G.todos) end
                  end
                  
                  pcall(require("sidebar-nvim").update)
                  
                  vim.schedule(function()
                     local _, _, t_start, _ = get_sections_range()
                     pcall(vim.api.nvim_win_set_cursor, 0, { t_start + 1, 0 })
                  end)
               end
            end,
         },

         draw = function(ctx)
            local result = { lines = { "  ──────", "" }, hl = { { "Comment", 0, 0, -1 } } }
            _G.todo_line_map = {}
            pcall(function()
               local current_todos = _G.todos or {}
               if #current_todos > 0 then
                  local groups = {}
                  local ordered_cats = {} 
                  
                  for _, t in ipairs(current_todos) do
                     local cat = t.cat or "General"
                     if not groups[cat] then 
                        groups[cat] = {} 
                        table.insert(ordered_cats, cat)
                     end
                     table.insert(groups[cat], t)
                  end
                  
                  local target_width = 35 
                  local right_margin = 2
                  local usable_width = target_width - right_margin -- 33 caracteres reales libres
                  
                  for _, cat in ipairs(ordered_cats) do
                     local items = groups[cat]
                     table.insert(result.lines, "   " .. cat)
                     table.insert(result.hl, { "SidebarBlue", #result.lines - 1, 0, -1 })
                     
                     for _, item in ipairs(items) do
                        local icon = item.done and "󰄵" or "󰄱"
                        local prefix_text = string.format("      %s ", icon)
                        local date_str = (item.date and item.date ~= "") and item.date or ""
                        
                        -- Calculamos cuántos caracteres quedan estrictamente para el texto de la tarea en la primera línea
                        -- Espacio total (33) - Prefijo ("      󰄱 ") - Fecha (" 20-5-26" si existe)
                        local date_space = (date_str ~= "") and (#date_str + 1) or 0
                        local max_task_len_first_line = usable_width - #prefix_text - date_space
                        
                        if #item.task <= max_task_len_first_line then
                           -- CASO 1: Cabe perfectamente en una sola línea
                           local left_text = prefix_text .. item.task
                           local display_text = left_text
                           if date_str ~= "" then
                              local padding_len = usable_width - #left_text - #date_str
                              display_text = left_text .. string.rep(" ", padding_len) .. date_str
                           end
                           
                           table.insert(result.lines, display_text)
                           _G.todo_line_map[#result.lines] = item
                           table.insert(result.hl, { item.current and "SidebarBlue" or "Comment", #result.lines - 1, 0, -1 })
                        else
                           -- CASO 2: La tarea es demasiado larga. Priorizamos la fecha arriba y troceamos el texto.
                           local first_chunk = item.task:sub(1, max_task_len_first_line)
                           local remaining_text = item.task:sub(max_task_len_first_line + 1)
                           
                           -- Renderizamos primera línea (Prefijo + Trozo 1 + Espacios sobrantes + Fecha al final)
                           local left_text = prefix_text .. first_chunk
                           local padding_len = usable_width - #left_text - #date_str
                           local first_line_display = left_text .. string.rep(" ", padding_len) .. date_str
                           
                           table.insert(result.lines, first_line_display)
                           _G.todo_line_map[#result.lines] = item -- Mapeamos la primera línea para poder interactuar
                           table.insert(result.hl, { item.current and "SidebarBlue" or "Comment", #result.lines - 1, 0, -1 })
                           
                            -- Troceamos el resto del texto con el mismo ancho disponible que la primera línea
                            local sub_line_prefix = string.rep(" ", #prefix_text)
                            local max_sub_task_len = max_task_len_first_line
                           
                           local extra_chunks = chunk_text(remaining_text, max_sub_task_len)
                           for _, chunk in ipairs(extra_chunks) do
                              table.insert(result.lines, sub_line_prefix .. chunk)
                              _G.todo_line_map[#result.lines] = item -- Mapeamos también las subsecuentes por comodidad
                              table.insert(result.hl, { item.current and "SidebarBlue" or "Comment", #result.lines - 1, 0, -1 })
                           end
                        end
                     end
                  end
               end
            end)
            return result
         end,
      }

      -- =======================================================================
      -- 3. NAVEGACIÓN DIRECTA GLOBAL
      -- =======================================================================
      
      _G.focus_sidebar_section = function(type)
         local is_open = false
         for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "SidebarNvim" then
               vim.api.nvim_set_current_win(win)
               is_open = true
               break
            end
         end

         if not is_open then vim.cmd("SidebarNvimOpen") end

         vim.schedule(function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
               if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "SidebarNvim" then
                  vim.api.nvim_set_current_win(win)
                  break
               end
            end

            local f_start, _, t_start, _ = get_sections_range()
            
            if type == "tree" then
               vim.b.last_sidebar_line = f_start
               vim.api.nvim_win_set_cursor(0, { f_start, get_first_char_col(f_start) })
            else
               vim.b.last_sidebar_line = t_start
               vim.api.nvim_win_set_cursor(0, { t_start, get_first_char_col(t_start) })
            end
         end)
      end

       -- =======================================================================
       -- 4. COLOR DE ICONOS Y TREEVIEW
       -- =======================================================================

       local icon_hl_cache = {}
       local function get_icon_hl(ext)
          if not ext or ext == "" then return nil end
          ext = ext:lower()
          if icon_hl_cache[ext] then return icon_hl_cache[ext] end

          local colors = {
             lua  = "#51a0cf", json = "#cbdc39",
             js   = "#cbcb41", jsx  = "#2085dc",
             ts   = "#3178c6", tsx  = "#3178c6",
             c    = "#6b7b8d", h    = "#6b7b8d",
             cpp  = "#519aba", hpp  = "#519aba",
             py   = "#3572a5", rs   = "#deb887",
             go   = "#00add8", zig  = "#f0a030",
             java = "#b07219", cs   = "#178600",
             php  = "#4f5d95", rb   = "#cc342d",
             html = "#e34c26", css  = "#563d7c",
             scss = "#c6538c", sass = "#c6538c",
             less = "#1d6a9f",
             md   = "#51a0cf", rst  = "#51a0cf",
             sh   = "#4e9a06", bash = "#4e9a06",
             zsh  = "#4e9a06", fish = "#4e9a06",
             yaml = "#db5856", yml  = "#db5856",
             toml = "#9c4221",
             xml  = "#f9c440", svg  = "#ffb13b",
             pdf  = "#e74c3c", txt  = "#8899bb",
             cfg  = "#c0caf5", ini  = "#c0caf5",
             conf = "#c0caf5", env  = "#f0c040",
             lock = "#6b6b6b",
             sql  = "#e38c00",
             vue  = "#41b883", svelte = "#ff3e00",
             gradle = "#02303a",
          }

          local color = colors[ext]
          if not color then return nil end

          local hl_name = "SidebarNvimIcon_" .. ext
          vim.api.nvim_set_hl(0, hl_name, { fg = color, default = false })
          icon_hl_cache[ext] = hl_name
          return hl_name
       end

       files.title = ""
       files.icon = ""
       local original_draw = files.draw
       files.draw = function(ctx)
          local res = original_draw(ctx)
          _G.sidebar_folder_lines = {}
          if res and res.lines then
             table.remove(res.lines, 1)
             local new_hl = {}
             for _, hl in ipairs(res.hl or {}) do
                local new_idx = hl[2] - 1
                if new_idx >= 0 then
                   hl[2] = new_idx
                   if (hl[1] or ""):match("Directory") then
                      hl[1] = "SidebarNvimDirectory"
                      _G.sidebar_folder_lines[new_idx + 1] = true
                   elseif hl[1] == "SidebarNvimNormal" then
                      if hl[3] == 0 then
                         local ext = (res.lines[new_idx + 1] or ""):match("%.([%w_]+)%s*$")
                         hl[1] = get_icon_hl(ext) or "SidebarNvimFileText"
                      else
                         hl[1] = "SidebarNvimFileText"
                      end
                   end
                   table.insert(new_hl, hl)
                end
             end
             res.hl = new_hl
          end
          return res
       end

       -- =======================================================================
       -- 5. INPUT Y CREACIÓN CON RUTAS
       -- =======================================================================

        local function sidebar_input(prompt)
           local buf = vim.api.nvim_create_buf(false, true)
           local win_width = vim.api.nvim_win_get_width(0)
           local width = math.min(50, math.max(20, win_width - 8))
           local col = math.max(1, win_width - width - 4)

           local saved = {
              echo = vim.api.nvim_echo,
              err_writeln = vim.api.nvim_err_writeln,
              err_write = vim.api.nvim_err_write,
           }
           vim.api.nvim_echo = function() end
           vim.api.nvim_err_writeln = function() end
           vim.api.nvim_err_write = function() end

           local win, ok
           ok, win = pcall(vim.api.nvim_open_win, buf, true, {
              relative = "win", row = 0, col = col,
              width = width, height = 1,
              style = "minimal",
              border = "rounded",
              title = " " .. prompt .. " ",
              noautocmd = true,
           })
           if not ok then
              width = math.max(20, win_width - 4)
              ok, win = pcall(vim.api.nvim_open_win, buf, true, {
                 relative = "win", row = 0, col = 0,
                 width = width, height = 1,
                 style = "minimal",
                 border = "none",
                 noautocmd = true,
              })
           end

           vim.api.nvim_echo = saved.echo
           vim.api.nvim_err_writeln = saved.err_writeln
           vim.api.nvim_err_write = saved.err_write

           if not ok then return nil end

          local result = nil
          vim.keymap.set({ "i", "n" }, "<CR>", function()
             result = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
             pcall(vim.api.nvim_win_close, win, true)
          end, { buffer = buf, nowait = true })

          vim.keymap.set({ "i", "n" }, "<Esc>", function()
             result = nil
             pcall(vim.api.nvim_win_close, win, true)
          end, { buffer = buf, nowait = true })

          vim.keymap.set("i", "<Left>", "<Nop>", { buffer = buf, nowait = true })
          vim.keymap.set("i", "<Home>", "<Nop>", { buffer = buf, nowait = true })

          vim.cmd("startinsert!")
          vim.wait(30000, function() return not vim.api.nvim_win_is_valid(win) end)

          vim.cmd("stopinsert")
          return result
       end

       local function upval(func, name)
          local i = 1
          while true do
             local n, v = debug.getupvalue(func, i)
             if not n then return nil end
             if n == name then return v end
             i = i + 1
          end
       end

       local orig_c = files.bindings["c"]
        local orig_d = files.bindings["d"]
        local orig_r = files.bindings["r"]
        local loclist = upval(orig_c, "loclist")
        local open_dirs = upval(orig_c, "open_directories")
        local create_file_fn = upval(orig_c, "create_file")

       files.bindings["c"] = function(line)
          local location = loclist:get_location_at(line)
          if location == nil then return end

          local parent
          if location.type == "directory" then
             parent = location.path
          else
             parent = location.parent
          end

          local name = sidebar_input("create file")
          if not name or vim.trim(name) == "" then return end

          name = vim.trim(name)
          local dest, is_dir

            if name:sub(1, 1) == "~" then
               dest = (os.getenv("HOME") or vim.fn.expand("~")) .. name:sub(2)
          elseif name:sub(1, 1) == "/" then
             dest = name
          else
             dest = parent .. "/" .. name
          end

          if name:sub(-1) == "/" then
             is_dir = true
          end

          if is_dir then
             vim.fn.mkdir(dest, "p")
          else
             local dir = vim.fn.fnamemodify(dest, ":h")
             if vim.fn.isdirectory(dir) == 0 then
                vim.fn.mkdir(dir, "p")
             end
              vim.fn.writefile({}, dest)
              create_file_fn(dest)
          end

          open_dirs[parent] = true
          pcall(require("sidebar-nvim").update)
       end

        files.bindings["d"] = function(line)
           local location = loclist:get_location_at(line)
           if location == nil then return end

           require("input-remove").confirm_delete({
               name = location.node.name,
               label = "",
               on_confirm = function()
                 vim.fn.delete(location.node.path, "rf")
                 vim.schedule(function() pcall(require("sidebar-nvim").update) end)
              end,
           })
        end

        files.bindings["r"] = function(line)
           local location = loclist:get_location_at(line)
           if location == nil then return end

           require("input-rename").open_rename({
               direct = true,
               current_name = location.node.name,
               label = "",
               on_rename = function(new_name)
                 local dest = location.node.parent .. "/" .. new_name
                 os.rename(location.node.path, dest)
                 vim.schedule(function() pcall(require("sidebar-nvim").update) end)
              end,
           })
        end

        vim.keymap.set("n", "<C-a>", function()
           if _G.open_input_creator_global then
              _G.open_input_creator_global()
              pcall(vim.api.nvim_feedkeys, "", "n", false)
           end
        end, { buffer = true, nowait = true })

        -- =======================================================================
        -- 6. COMPORTAMIENTO Y BLOQUEOS
        -- =======================================================================

       local sb_group = vim.api.nvim_create_augroup("SidebarBehavior", { clear = true })

      vim.api.nvim_create_autocmd("CursorMoved", {
         group = sb_group,
         callback = function()
            if vim.bo.filetype ~= "SidebarNvim" then return end
            local cursor = vim.api.nvim_win_get_cursor(0)
            local line, col = cursor[1], cursor[2]
            local f_start, f_end, t_start, _ = get_sections_range()
            local last = vim.b.last_sidebar_line or line

            local new_line = line
            if last <= f_end and line > f_end then new_line = f_end
            elseif last >= t_start and line < t_start then new_line = t_start end

            local new_col = get_first_char_col(new_line)
             local last_line = vim.api.nvim_buf_line_count(0)
             new_line = math.max(1, math.min(new_line, last_line))
             new_col = math.min(new_col, #(vim.api.nvim_buf_get_lines(0, new_line - 1, new_line, false)[1] or ""))
             if line ~= new_line or col ~= new_col then
                vim.api.nvim_win_set_cursor(0, { new_line, new_col })
             end
             vim.b.last_sidebar_line = new_line
         end,
      })

        vim.api.nvim_create_autocmd("WinEnter", {
           group = sb_group,
           callback = function()
              if vim.bo.filetype ~= "SidebarNvim" then return end
              if vim.api.nvim_win_get_config(0).relative ~= "" then return end
              vim.cmd("silent! setlocal cursorline winhighlight=CursorLine:CursorLine")
           end,
        })

        vim.api.nvim_create_autocmd("WinLeave", {
           group = sb_group,
           callback = function()
              if vim.bo.filetype ~= "SidebarNvim" then return end
              vim.cmd("silent! setlocal nocursorline")
           end,
        })

       vim.api.nvim_create_autocmd("InsertEnter", {
          group = sb_group,
          callback = function()
             if vim.bo.filetype ~= "SidebarNvim" then return end
             pcall(vim.cmd, "stopinsert")
          end,
       })

       local bv = string.char(22)
       vim.api.nvim_create_autocmd("ModeChanged", {
          pattern = "n:v,n:V,n:" .. bv,
          group = sb_group,
          callback = function()
             if vim.bo.filetype ~= "SidebarNvim" then return end
             vim.schedule(function()
                pcall(vim.cmd, "normal! <Esc>")
             end)
          end,
       })

       require("sidebar-nvim").setup({
         sections = { files, todo_section },
         side = "right",
         initial_width = 35,
         section_separator = { "" },
         section_title_separator = { "" },
      })

       vim.api.nvim_create_autocmd("FileType", {
          pattern = "SidebarNvim",
          callback = function()
             vim.bo.modifiable = false
             local nop = { buffer = true, silent = true, nowait = true }
             for _, k in ipairs({ "i", "a", "o", "s", "I", "A", "O", "S", "D", "C", "J", "R", "." }) do
                vim.keymap.set("n", k, "<Nop>", nop)
             end
             vim.keymap.set("n", "<Tab>", "<C-w>w", { buffer = true, silent = true })
             vim.keymap.set("n", "<S-Tab>", ":bnext<CR>", { buffer = true, silent = true })
          end,
       })
    end,
}
