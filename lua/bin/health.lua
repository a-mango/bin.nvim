local M = {}

function M.check()
  vim.health.start("bin.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Neovim >= 0.10 required (vim.system API)")
  end

  local function check(name, pkg, required)
    if vim.fn.executable(name) == 0 then
      local msg = name .. " not found — install " .. pkg
      if required then
        vim.health.error(msg)
      else
        vim.health.warn(msg .. " (section will be skipped)")
      end
      return
    end
    local path = vim.fn.exepath(name)
    local r = vim.system({ name, "--version" }, { text = true }):wait()
    local ver = ((r.code == 0 and r.stdout) or r.stderr or ""):match("([^\n]+)")
    local detail = ver and ("  [" .. ver .. "]") or ""
    vim.health.ok(name .. ": " .. path .. detail)
  end

  -- required
  check("readelf",  "binutils", true)

  -- optional tools (sections skipped gracefully when missing)
  check("file",     "file",     false)
  check("size",     "binutils", false)
  check("strings",  "binutils", false)
  check("ldd",      "glibc",    false)
  check("checksec", "checksec", false)
  check("c++filt",  "binutils", false)
  check("rustfilt", "rustfilt", false)
end

return M
