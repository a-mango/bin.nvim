local bin = require("bin")

-- the default section list, captured before any test mutates config via setup()
local default_sections = vim.deepcopy(bin.config.sections)

-- a buffer has finished rendering once its title line is in place and the
-- "Loading..." placeholder is gone
local function rendered(buf)
  if buf == -1 or not vim.api.nvim_buf_is_valid(buf) then return false end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines < 2 or not lines[1]:match("bin%.nvim") then return false end
  for _, l in ipairs(lines) do
    if l:match("Loading") then return false end
  end
  return true
end

local function open_and_wait(path, timeout)
  bin.open(path)
  local buf = vim.fn.bufnr("elf://" .. path)
  local ok = vim.wait(timeout or 15000, function() return rendered(buf) end, 50)
  return buf, ok
end

describe("is_elf", function()
  it("recognises an ELF binary", function()
    assert.is_true(bin._test.is_elf(vim.v.progpath))
  end)

  it("rejects a text file", function()
    local tmp = vim.fn.tempname()
    vim.fn.writefile({ "not an elf" }, tmp)
    assert.is_false(bin._test.is_elf(tmp))
    os.remove(tmp)
  end)

  it("rejects a path that does not exist", function()
    assert.is_false(bin._test.is_elf("/no/such/file/xyz"))
  end)
end)

describe("parse_checksec", function()
  -- checksec --output=csv puts the filename last, so fields 1..10 are the props
  local full = "Full RELRO,Canary found,NX enabled,PIE enabled,No RPATH,No RUNPATH,No Symbols,Partial,11,19,/bin/ls"

  it("maps a full row onto the right labels", function()
    local out = bin._test.parse_checksec(full)
    assert.equals("  RELRO:           Full RELRO", out[1])
    assert.equals("  PIE:             PIE enabled", out[4])
    assert.equals("  Fortifiable:     19", out[10])
  end)

  it("keeps columns aligned when a field is empty", function()
    local blank = ",Canary found,NX enabled,PIE enabled,No RPATH,No RUNPATH,No Symbols,Partial,11,19,/bin/ls"
    local out = bin._test.parse_checksec(blank)
    assert.is_truthy(out[1]:match("^  RELRO:%s+$"))        -- empty value, no shift
    assert.equals("  Stack Canary:    Canary found", out[2])
    assert.equals("  PIE:             PIE enabled", out[4])
  end)
end)

describe("open", function()
  before_each(function()
    bin.setup({ sections = vim.deepcopy(default_sections) })
  end)

  it("renders an ELF into a binview buffer", function()
    local buf, ok = open_and_wait(vim.v.progpath)
    assert.is_true(ok, "buffer did not render in time")
    assert.equals("binview", vim.bo[buf].filetype)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_truthy(lines[1]:match("bin%.nvim"))
    local has_header = false
    for _, l in ipairs(lines) do
      if l:match("^┌") then has_header = true; break end
    end
    assert.is_true(has_header, "no section header rendered")
  end)

  it("warns and creates no buffer for a non-ELF file", function()
    local tmp = vim.fn.tempname()
    vim.fn.writefile({ "plain text" }, tmp)
    bin.open(tmp)
    assert.equals(-1, vim.fn.bufnr("elf://" .. tmp))
    os.remove(tmp)
  end)

  it("does not hang when sections is empty", function()
    bin.setup({ sections = {} })
    local buf, ok = open_and_wait(vim.v.progpath, 3000)
    assert.is_true(ok, "empty-sections open stayed on Loading")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_truthy(lines[1]:match("bin%.nvim"))
  end)

  it("renders two binaries without stranding the first", function()
    local p2 = vim.fn.exepath("readelf")
    if p2 == "" then
      pending("readelf not available")
      return
    end
    -- light sections so this isolates the generation counter, not DWARF speed.
    -- Under the old global counter, opening p2 superseded p1's generation and
    -- left p1 stuck on Loading forever; per-buffer counters let both finish.
    bin.setup({ sections = { "header", "file" } })
    local p1 = vim.v.progpath
    bin.open(p1)
    bin.open(p2)
    local b1 = vim.fn.bufnr("elf://" .. p1)
    local b2 = vim.fn.bufnr("elf://" .. p2)
    local ok = vim.wait(10000, function()
      return rendered(b1) and rendered(b2)
    end, 25)
    assert.is_true(ok, "one binary stayed on Loading (stranded)")
  end)
end)
