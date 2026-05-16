return {
   'norcalli/nvim-colorizer.lua',
   config = function()
    require("colorizer").setup({
      '*', -- Habilitar para todos los tipos de archivo
    })
  end
}
