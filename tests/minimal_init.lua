-- Minimal init for running the suite under `nvim --headless`.
-- plenary.nvim is located via $PLENARY_DIR, falling back to a local checkout
-- under .tests/ (see CONTRIBUTING / the CI workflow).

local plugin_root = vim.fn.getcwd()
local plenary_dir = vim.env.PLENARY_DIR or (plugin_root .. "/.tests/plenary.nvim")

vim.opt.runtimepath:prepend(plugin_root)
vim.opt.runtimepath:prepend(plenary_dir)

vim.cmd("runtime plugin/plenary.vim")

-- `nvim -u <init>` does not load ftplugins or syntax; the binview filetype
-- needs both for its ftplugin and syntax files to attach.
vim.cmd("filetype plugin on")
vim.cmd("syntax on")
