local M = {}

M.config = {
  -- sections to display, in order
  sections = { "header", "sections", "segments", "symbols", "dynamic" },
  -- max symbols to show (can be slow for large binaries)
  max_symbols = 200,
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

local function collect_header(path)
  local out, err = run({ "readelf", "-h", path })
  if not out then return { "  [error] " .. (err or "readelf -h failed") } end
  local result = {}
  for _, line in ipairs(lines(out)) do
    result[#result + 1] = "  " .. line
  end
  return result
end

local function collect_sections(path)
  local out, err = run({ "readelf", "-S", "--wide", path })
  if not out then return { "  [error] " .. (err or "readelf -S failed") } end
  local result = {}
  for _, line in ipairs(lines(out)) do
    result[#result + 1] = "  " .. line
  end
  return result
end

local function collect_segments(path)
  local out, err = run({ "readelf", "-l", "--wide", path })
  if not out then return { "  [error] " .. (err or "readelf -l failed") } end
  local result = {}
  for _, line in ipairs(lines(out)) do
    result[#result + 1] = "  " .. line
  end
  return result
end

local function collect_symbols(path, max)
  local out, err = run({ "readelf", "-s", "--wide", path })
  if not out then return { "  [error] " .. (err or "readelf -s failed") } end
  local result = {}
  local count = 0
  for _, line in ipairs(lines(out)) do
    if count >= max then
      result[#result + 1] = string.format("  ... (truncated, showing %d symbols)", max)
      break
    end
    result[#result + 1] = "  " .. line
    count = count + 1
  end
  return result
end

local function collect_dynamic(path)
  local out, err = run({ "readelf", "-d", path })
  if not out then
    -- not a dynamic binary, that's fine
    return { "  (no dynamic section)" }
  end
  if out:find("There is no dynamic section") then
    return { "  (no dynamic section — static binary)" }
  end
  local result = {}
  for _, line in ipairs(lines(out)) do
    result[#result + 1] = "  " .. line
  end
  return result
end

local dispatch = {
  header   = function(path, _cfg) return collect_header(path) end,
  sections = function(path, _cfg) return collect_sections(path) end,
  segments = function(path, _cfg) return collect_segments(path) end,
  symbols  = function(path, cfg)  return collect_symbols(path, cfg.max_symbols) end,
  dynamic  = function(path, _cfg) return collect_dynamic(path) end,
}

local titles = {
  header   = "ELF Header",
  sections = "Section Headers",
  segments = "Program Headers / Segments",
  symbols  = "Symbol Table",
  dynamic  = "Dynamic Section",
}

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

  for _, sec in ipairs(M.config.sections) do
    local fn = dispatch[sec]
    if fn then
      vim.list_extend(content, section_header(titles[sec] or sec))
      vim.list_extend(content, fn(path, M.config))
    end
  end

  -- create or reuse a buffer named after the file
  local bufname = "elf://" .. path
  local buf = vim.fn.bufnr(bufname, false)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, bufname)
  end

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

  -- open in current window
  vim.api.nvim_set_current_buf(buf)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- intercept ELF files on BufReadCmd so nvim never tries to load binary
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = vim.api.nvim_create_augroup("bin_nvim", { clear = true }),
    callback = function(ev)
      local path = ev.match
      if is_elf(path) then
        M.open(path)
      end
    end,
  })
end

return M
