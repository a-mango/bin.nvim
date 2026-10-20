-- luacheck configuration for bin.nvim
std = "luajit"
cache = true

-- Neovim's global; everything hangs off it
globals = { "vim" }

-- the test files use plenary's busted-style globals
files["tests/"] = {
  globals = { "describe", "it", "before_each", "after_each", "pending", "assert" },
}

-- generated / vendored
exclude_files = { ".tests/" }

-- the rendered output and long readelf command lines run wide on purpose
max_line_length = false
