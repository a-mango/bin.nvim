local M = {}

M.config = {
  sections = {
    "file", "header", "checksec", "size",
    "sections", "segments", "dynamic",
    "notes", "versions", "symbols", "strings",
  },
  max_symbols = 200,
  max_strings = 300,
  min_string_len = 10,
}

local function run(cmd)
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    return nil, result.stderr
  end
  return result.stdout, nil
end

local function is_elf(path)
  local f = io.open(path, "rb")
  if not f then return false end
  local magic = f:read(4)
  f:close()
  return magic == "\x7fELF"
end

local function lines(str)
  local t = {}
  for line in (str or ""):gmatch("[^\n]+") do
    t[#t + 1] = line
  end
  return t
end

local function section_header(title)
  local bar = string.rep("─", 60)
  return { "", "┌" .. bar, "│  " .. title, "└" .. bar, "" }
end

local function indent(out)
  local result = {}
  for _, line in ipairs(lines(out)) do
    result[#result + 1] = "  " .. line
  end
  return result
end

-- ── collectors ────────────────────────────────────────────────────────────────

local function collect_file(path)
  local out, err = run({ "file", path })
  if not out then return { "  [error] " .. (err or "file failed") } end
  -- strip leading "path: "
  local info = out:gsub("^[^:]+:%s*", ""):gsub("\n$", "")
  return { "  " .. info }
end

local function collect_header(path)
  local out, err = run({ "readelf", "-h", path })
  if not out then return { "  [error] " .. (err or "") } end
  return indent(out)
end

local function collect_checksec(path)
  if vim.fn.executable("checksec") == 0 then
    return { "  (checksec not found — install checksec)" }
  end
  local out, err = run({ "checksec", "--file=" .. path, "--output=csv" })
  if not out then return { "  [error] " .. (err or "") } end

  local fields = {}
  for field in (out:gsub("\n$", "")):gmatch("[^,]+") do
    fields[#fields + 1] = field
  end

  -- CSV: RELRO, STACK CANARY, NX, PIE, RPATH, RUNPATH, Symbols, FORTIFY, Fortified, Fortifiable, FILE
  local labels = { "RELRO", "Stack Canary", "NX", "PIE", "RPATH", "RUNPATH", "Symbols", "FORTIFY", "Fortified", "Fortifiable" }
  local result = {}
  for i, label in ipairs(labels) do
    local val = fields[i] or "?"
    result[#result + 1] = string.format("  %-16s %s", label .. ":", val)
  end
  return result
end

local function collect_size(path)
  local out, err = run({ "size", path })
  if not out then return { "  [error] " .. (err or "") } end
  return indent(out)
end

local function collect_sections(path)
  local out, err = run({ "readelf", "-S", "--wide", path })
  if not out then return { "  [error] " .. (err or "") } end
  return indent(out)
end

local function collect_segments(path)
  local out, err = run({ "readelf", "-l", "--wide", path })
  if not out then return { "  [error] " .. (err or "") } end
  return indent(out)
end

local function collect_dynamic(path)
  local out, _ = run({ "readelf", "-d", path })
  if not out or out:find("There is no dynamic section") then
    return { "  (no dynamic section — static binary)" }
  end
  return indent(out)
end

local function collect_notes(path)
  local out, err = run({ "readelf", "-n", path })
  if not out then return { "  [error] " .. (err or "") } end
  return indent(out)
end

local function collect_versions(path)
  local out, err = run({ "readelf", "-V", path })
  if not out then return { "  [error] " .. (err or "") } end
  return indent(out)
end

local function collect_symbols(path, max)
  local out, err = run({ "readelf", "-s", "--wide", path })
  if not out then return { "  [error] " .. (err or "") } end
  local result = {}
  local count = 0
  for _, line in ipairs(lines(out)) do
    if count >= max then
      result[#result + 1] = string.format("  ... (truncated, showing %d/%d lines)", max, count)
      break
    end
    result[#result + 1] = "  " .. line
    count = count + 1
  end
  return result
end

local function collect_strings(path, min_len, max)
  local out, err = run({ "strings", "-n", tostring(min_len), path })
  if not out then return { "  [error] " .. (err or "") } end
  local result = {}
  local count = 0
  local total = 0
  for _, line in ipairs(lines(out)) do
    total = total + 1
    if count < max then
      result[#result + 1] = "  " .. line
      count = count + 1
    end
  end
  if total > max then
    result[#result + 1] = string.format("  ... (truncated, showing %d/%d strings)", max, total)
  end
  return result
end

-- ── dispatch ──────────────────────────────────────────────────────────────────

local dispatch = {
  file     = function(path, _)   return collect_file(path) end,
  header   = function(path, _)   return collect_header(path) end,
  checksec = function(path, _)   return collect_checksec(path) end,
  size     = function(path, _)   return collect_size(path) end,
  sections = function(path, _)   return collect_sections(path) end,
  segments = function(path, _)   return collect_segments(path) end,
  dynamic  = function(path, _)   return collect_dynamic(path) end,
  notes    = function(path, _)   return collect_notes(path) end,
  versions = function(path, _)   return collect_versions(path) end,
  symbols  = function(path, cfg) return collect_symbols(path, cfg.max_symbols) end,
  strings  = function(path, cfg) return collect_strings(path, cfg.min_string_len, cfg.max_strings) end,
}

local titles = {
  file     = "File",
  header   = "ELF Header",
  checksec = "Security Properties",
  size     = "Section Sizes",
  sections = "Section Headers",
  segments = "Program Headers / Segments",
  dynamic  = "Dynamic Section",
  notes    = "Notes",
  versions = "Version Information",
  symbols  = "Symbol Table",
  strings  = "Strings (≥" .. M.config.min_string_len .. " chars)",
}

-- ── public API ────────────────────────────────────────────────────────────────

function M.open(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if not is_elf(path) then
    vim.notify("bin.nvim: not an ELF file: " .. path, vim.log.levels.WARN)
    return
  end

  local content = {
    "  bin.nvim — " .. path,
    "  " .. string.rep("═", 58),
  }

  -- update strings title in case min_string_len was customised
  titles.strings = "Strings (≥" .. M.config.min_string_len .. " chars)"

  for _, sec in ipairs(M.config.sections) do
    local fn = dispatch[sec]
    if fn then
      vim.list_extend(content, section_header(titles[sec] or sec))
      vim.list_extend(content, fn(path, M.config))
    end
  end

  local bufname = "elf://" .. path
  local buf = vim.fn.bufnr(bufname, false)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, bufname)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].filetype   = "elf"
  vim.bo[buf].swapfile   = false

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>bd<cr>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "r", "", {
    noremap = true, silent = true,
    callback = function()
      vim.bo[buf].modifiable = true
      M.open(path)
    end,
  })

  vim.api.nvim_set_current_buf(buf)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("bin_nvim", { clear = true }),
    callback = function(ev)
      local path = ev.match
      if vim.fn.filereadable(path) == 1 and is_elf(path) then
        M.open(path)
      end
    end,
  })
end

return M
