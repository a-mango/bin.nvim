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

-- syntax highlighting via matchadd
local function hi(group, pattern)
  vim.fn.matchadd(group, pattern)
end

-- section chrome
hi("Title",      "^[┌└│].*")
hi("Comment",    "^  bin\\.nvim.*")
hi("Special",    "^  .*═.*")

-- checksec labels
hi("Identifier", "^  \\s*[A-Z][A-Za-z ]*:")

-- addresses and numbers
hi("Number", "0x[0-9a-fA-F]\\+")
hi("Number", "\\<\\d\\+\\>")

-- section types
hi("Type",
  "\\<\\(PROGBITS\\|NOBITS\\|DYNAMIC\\|SYMTAB\\|STRTAB\\|RELA\\|REL\\|NOTE\\|GNU_HASH\\|GNU_RELRO\\|DYNSYM\\|NULL\\)\\>")

-- segment types
hi("Keyword",
  "\\<\\(LOAD\\|INTERP\\|PHDR\\|TLS\\|GNU_STACK\\|GNU_EH_FRAME\\|DYNAMIC\\|NOTE\\)\\>")

-- brackets (section names in output)
hi("String", "\\[.*\\]")

-- symbol attributes
hi("Function", "\\<FUNC\\>")
hi("Type",     "\\<OBJECT\\>")
hi("Constant", "\\<\\(GLOBAL\\|LOCAL\\|WEAK\\)\\>")

-- security property values
hi("DiagnosticOk",    "\\<\\(Full RELRO\\|Canary found\\|NX enabled\\|PIE enabled\\)\\>")
hi("DiagnosticWarn",  "\\<\\(Partial RELRO\\|No canary\\|NX disabled\\|No PIE\\|Partial\\)\\>")
hi("DiagnosticError", "\\<\\(No RELRO\\|NX disabled\\)\\>")

-- status / info lines
hi("WarningMsg", "(\\.\\.\\. (first.*)")
hi("ErrorMsg",   "\\[error\\].*")
hi("Comment",    "  (.*not installed.*)")
hi("Comment",    "  (no .*)")
hi("Comment",    "  (static binary.*)")
