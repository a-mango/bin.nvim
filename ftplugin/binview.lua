vim.wo.wrap           = false
vim.wo.number         = false
vim.wo.relativenumber = false
vim.wo.signcolumn     = "no"
vim.wo.cursorline     = true

-- folding: section chrome (┌│└, blank, header) stays visible at all levels;
-- content lines fold at level 1. Use zM to collapse all, zR to open all.
vim.wo.foldmethod   = "expr"
vim.wo.foldexpr     = "v:lua.require('bin').foldexpr(v:lnum)"
vim.wo.foldtext     = "v:lua.require('bin').foldtext()"
vim.wo.foldlevel    = 99
vim.wo.foldminlines = 1

-- section navigation
local o = { noremap = true, silent = true, buffer = true }
vim.keymap.set("n", "]]", function() vim.fn.search("^┌", "W")  end, o)
vim.keymap.set("n", "[[", function() vim.fn.search("^┌", "bW") end, o)

-- syntax highlighting lives in syntax/binview.vim (buffer-local, no accumulation)
