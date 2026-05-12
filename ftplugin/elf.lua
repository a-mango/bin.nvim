-- Basic highlighting for the elf:// info buffer
local buf = vim.api.nvim_get_current_buf()

vim.wo.wrap = false
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.signcolumn = "no"
vim.wo.cursorline = true

-- simple syntax via vim.fn.matchadd
local function hi(group, pattern)
  vim.fn.matchadd(group, pattern)
end

-- section borders
hi("Title", "^[┌└│].*")
hi("Comment", "^  bin\\.nvim.*")
hi("Special", "^  .*═.*")

-- readelf -h fields
hi("Identifier", "^  \\s*[A-Z][A-Za-z ]*:")
hi("Number", "0x[0-9a-fA-F]\\+")
hi("Number", "\\<\\d\\+\\>")

-- section flags / types
hi("Type",
  "\\<\\(PROGBITS\\|NOBITS\\|DYNAMIC\\|SYMTAB\\|STRTAB\\|RELA\\|REL\\|NOTE\\|GNU_HASH\\|GNU_RELRO\\|DYNSYM\\|NULL\\)\\>")
hi("Keyword", "\\<\\(LOAD\\|INTERP\\|PHDR\\|TLS\\|GNU_STACK\\|GNU_EH_FRAME\\|DYNAMIC\\|NOTE\\)\\>")
hi("String", "\\[.*\\]")

-- symbol binding / type
hi("Function", "\\<FUNC\\>")
hi("Type", "\\<OBJECT\\>")
hi("Constant", "\\<\\(GLOBAL\\|LOCAL\\|WEAK\\)\\>")

-- errors / warnings
hi("ErrorMsg", "\\[error\\].*")
hi("WarningMsg", "(truncated.*)")
