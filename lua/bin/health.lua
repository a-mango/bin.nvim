local M = {}

function M.check()
  vim.health.start("bin.nvim")

  if vim.fn.executable("readelf") == 1 then
    vim.health.ok("readelf found: " .. vim.fn.exepath("readelf"))
  else
    vim.health.error("readelf not found — install binutils")
  end

  if vim.fn.executable("file") == 1 then
    vim.health.ok("file found: " .. vim.fn.exepath("file"))
  else
    vim.health.warn("file(1) not found — optional")
  end
end

return M
