local M = {}

M.config = {
  sections = {
    "file", "header", "checksec", "size",
    "sections", "segments", "dynamic",
    "notes", "versions", "relocations",
    "symbols", "strings", "ldd", "dwarf",
  },
  max_symbols    = 200,
  max_strings    = 300,
  min_string_len = 10,
  max_dwarf      = 300,
  demangle       = true,
}

-- per-buffer generation, bumped on every M.open() for that buffer; async
-- callbacks check against it to discard results from a superseded reload.
-- Keyed by buffer so opening a second binary can't strand the first.
local gens = {}

-- ── helpers ───────────────────────────────────────────────────────────────────

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

local function indent(str)
  local result = {}
  for _, line in ipairs(lines(str)) do
    result[#result + 1] = "  " .. line
  end
  return result
end

local function missing(tool)
  return { "  (" .. tool .. " not installed — skipping)" }
end

-- splits `str` into lines but stops once `max` is reached, so a huge dump (the
-- multi-million-line DWARF of a debug build, say) never materialises in full
-- just to show a few hundred lines. The config cap thus bounds the work, not
-- only the display. Adds a trailing note when the output was cut.
local function cap_lines(str, max, label)
  local t = {}
  local n = 0
  for line in (str or ""):gmatch("[^\n]+") do
    n = n + 1
    if n > max then
      t[#t + 1] = string.format("... (first %d %s shown — raise the limit in config to see more)", max, label)
      break
    end
    t[n] = line
  end
  return t
end

local section_titles = {
  file        = "File",
  header      = "ELF Header",
  checksec    = "Security Properties",
  size        = "Section Sizes",
  sections    = "Section Headers",
  segments    = "Program Headers / Segments",
  dynamic     = "Dynamic Section",
  notes       = "Notes",
  versions    = "Version Information",
  relocations = "Relocations",
  symbols     = "Symbol Table",
  strings     = "Strings",
  ldd         = "Shared Library Dependencies",
  dwarf       = "DWARF Debug Info",
}

local function make_section_header(sec, cfg)
  local title = section_titles[sec] or sec
  if sec == "strings" then
    title = string.format("Strings (≥%d chars)", cfg.min_string_len)
  end
  local bar = string.rep("─", 60)
  return { "", "┌" .. bar, "│  " .. title, "└" .. bar, "" }
end

-- ── async utilities ───────────────────────────────────────────────────────────

-- pipe `input` (string) through `cmd`; call cb(result_or_input_on_failure)
local function pipe(cmd, input, cb)
  vim.system(cmd, { text = true, stdin = input }, function(r)
    cb((r.code == 0 and r.stdout) or input)
  end)
end

-- run `out` through c++filt then rustfilt if available and cfg.demangle is set
local function demangle(out, exe, cfg, cb)
  if not cfg.demangle then cb(out); return end
  if exe.cppfilt then
    pipe({ "c++filt" }, out, function(d)
      if exe.rustfilt then pipe({ "rustfilt" }, d, cb) else cb(d) end
    end)
  elseif exe.rustfilt then
    pipe({ "rustfilt" }, out, cb)
  else
    cb(out)
  end
end

-- ── async section runners ─────────────────────────────────────────────────────
-- signature: function(path, cfg, exe, cb)  where cb receives a lines table

local runners = {}

runners.file = function(path, _, exe, cb)
  if not exe.file then cb(missing("file")); return end
  vim.system({ "file", path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    local info = r.stdout:gsub("^[^:]+:%s*", ""):gsub("\n$", "")
    cb({ "  " .. info })
  end)
end

runners.header = function(path, _, _, cb)
  vim.system({ "readelf", "-h", path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    cb(indent(r.stdout))
  end)
end

-- format checksec's CSV row into aligned label/value lines. Splits on commas
-- while keeping empty fields, so a blank value can't shift the remaining
-- columns onto the wrong labels.
local function parse_checksec(raw)
  local fields = vim.split((raw:gsub("\n$", "")), ",", { plain = true })
  local labels = {
    "RELRO", "Stack Canary", "NX", "PIE",
    "RPATH", "RUNPATH", "Symbols", "FORTIFY",
    "Fortified", "Fortifiable",
  }
  local result = {}
  for i, label in ipairs(labels) do
    result[#result + 1] = string.format("  %-16s %s", label .. ":", fields[i] or "?")
  end
  return result
end

runners.checksec = function(path, _, exe, cb)
  if not exe.checksec then cb(missing("checksec")); return end
  vim.system({ "checksec", "--file=" .. path, "--output=csv" }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    cb(parse_checksec(r.stdout))
  end)
end

runners.size = function(path, _, exe, cb)
  if not exe.size then cb(missing("size")); return end
  vim.system({ "size", path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    cb(indent(r.stdout))
  end)
end

runners.sections = function(path, _, _, cb)
  vim.system({ "readelf", "-S", "--wide", path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    cb(indent(r.stdout))
  end)
end

runners.segments = function(path, _, _, cb)
  vim.system({ "readelf", "-l", "--wide", path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    cb(indent(r.stdout))
  end)
end

runners.dynamic = function(path, _, _, cb)
  vim.system({ "readelf", "-d", path }, { text = true }, function(r)
    local out = r.stdout or ""
    if r.code ~= 0 or out:find("There is no dynamic section") then
      cb({ "  (no dynamic section — static binary)" }); return
    end
    cb(indent(out))
  end)
end

runners.notes = function(path, _, _, cb)
  vim.system({ "readelf", "-n", path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    cb(indent(r.stdout))
  end)
end

runners.versions = function(path, _, _, cb)
  -- readelf -V exits non-zero on binaries with no version info
  vim.system({ "readelf", "-V", path }, { text = true }, function(r)
    local out = r.stdout or ""
    if out == "" or out:find("no symbol") or out:find("no version") then
      cb({ "  (no version information)" }); return
    end
    cb(indent(out))
  end)
end

runners.relocations = function(path, _, _, cb)
  vim.system({ "readelf", "-r", "--wide", path }, { text = true }, function(r)
    local out = r.stdout or ""
    if out == "" or out:find("There are no relocations") then
      cb({ "  (no relocations)" }); return
    end
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    cb(indent(out))
  end)
end

runners.symbols = function(path, cfg, exe, cb)
  vim.system({ "readelf", "-s", "--wide", path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    demangle(r.stdout, exe, cfg, function(out)
      local capped = cap_lines(out, cfg.max_symbols, "lines")
      local result = {}
      for _, line in ipairs(capped) do
        result[#result + 1] = "  " .. line
      end
      cb(result)
    end)
  end)
end

runners.strings = function(path, cfg, exe, cb)
  if not exe.strings then cb(missing("strings")); return end
  vim.system({ "strings", "-n", tostring(cfg.min_string_len), path }, { text = true }, function(r)
    if r.code ~= 0 then cb({ "  [error] " .. r.stderr }); return end
    local capped = cap_lines(r.stdout, cfg.max_strings, "strings")
    local result = {}
    for _, line in ipairs(capped) do
      result[#result + 1] = "  " .. line
    end
    cb(result)
  end)
end

runners.ldd = function(path, _, exe, cb)
  if not exe.ldd then cb(missing("ldd")); return end
  vim.system({ "ldd", path }, { text = true }, function(r)
    local out = r.stdout or ""
    local err = r.stderr or ""
    if out:find("not a dynamic executable") or err:find("not a dynamic executable") then
      cb({ "  (static binary — no shared dependencies)" }); return
    end
    if r.code ~= 0 then cb({ "  [error] " .. err }); return end
    cb(indent(out))
  end)
end

runners.dwarf = function(path, cfg, _, cb)
  vim.system({ "readelf", "--debug-dump=info", path }, { text = true }, function(r)
    local out = r.stdout or ""
    if out == "" then
      cb({ "  (no debug symbols — compile with -g)" }); return
    end
    local capped = cap_lines(out, cfg.max_dwarf, "lines")
    local result = {}
    for _, line in ipairs(capped) do
      result[#result + 1] = "  " .. line
    end
    cb(result)
  end)
end

-- ── rendering ─────────────────────────────────────────────────────────────────

local function render(buf, path, section_order, section_data, cfg)
  local content = {
    "  bin.nvim — " .. path,
    "  " .. string.rep("═", 58),
  }
  for _, sec in ipairs(section_order) do
    if section_data[sec] then
      vim.list_extend(content, make_section_header(sec, cfg))
      vim.list_extend(content, section_data[sec])
    end
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].filetype   = "binview"
  vim.bo[buf].swapfile   = false
end

local function show_loading(buf, path)
  local content = {
    "  bin.nvim — " .. path,
    "  " .. string.rep("═", 58),
    "",
    "  Loading...",
  }
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].filetype   = "binview"
  vim.bo[buf].swapfile   = false
end

-- ── keymaps ───────────────────────────────────────────────────────────────────

local function set_keymaps(buf, path)
  local o = { noremap = true, silent = true }
  local function map(key, rhs)
    pcall(vim.api.nvim_buf_del_keymap, buf, "n", key)
    vim.api.nvim_buf_set_keymap(buf, "n", key, rhs, o)
  end
  local function mapcb(key, fn)
    pcall(vim.api.nvim_buf_del_keymap, buf, "n", key)
    vim.api.nvim_buf_set_keymap(buf, "n", key, "", vim.tbl_extend("force", o, { callback = fn }))
  end
  map("q", "<cmd>bd<cr>")
  mapcb("r", function() M.open(path) end)
end

-- ── fold support (called from ftplugin via foldexpr / foldtext options) ───────

function M.foldexpr(lnum)
  local line = vim.fn.getline(lnum)
  -- section chrome and blank lines stay visible at all fold levels
  if line == ""
    or line:match("^[┌│└]")
    or line:match("^  bin%.nvim")
    or line:match("^  [═]+")
  then
    return "0"
  end
  return "1"  -- content lines are foldable
end

function M.foldtext()
  return "  ··· " .. (vim.v.foldend - vim.v.foldstart + 1) .. " lines"
end

-- ── public API ────────────────────────────────────────────────────────────────

function M.open(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if not is_elf(path) then
    vim.notify("bin.nvim: not an ELF file: " .. path, vim.log.levels.WARN)
    return
  end

  -- whatever buffer we were called from; if the file was read into a normal
  -- buffer (BufReadPost, or :edit), we wipe it once the preview is up so it
  -- doesn't linger behind us and resurface when the preview is closed
  local origin = vim.api.nvim_get_current_buf()

  local bufname = "elf://" .. path
  local buf = vim.fn.bufnr(bufname, false)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, bufname)
  end

  gens[buf] = (gens[buf] or 0) + 1
  local gen = gens[buf]

  show_loading(buf, path)
  set_keymaps(buf, path)
  vim.api.nvim_set_current_buf(buf)

  vim.schedule(function()
    if origin ~= buf
      and vim.api.nvim_buf_is_valid(origin)
      and vim.bo[origin].buftype == ""
      and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(origin), ":p")
          == vim.fn.fnamemodify(path, ":p")
    then
      vim.api.nvim_buf_delete(origin, { force = true })
    end
  end)

  -- snapshot config and check executables on the main thread before going async
  local cfg = M.config
  local exe = {
    file     = vim.fn.executable("file")     == 1,
    size     = vim.fn.executable("size")     == 1,
    strings  = vim.fn.executable("strings")  == 1,
    checksec = vim.fn.executable("checksec") == 1,
    ldd      = vim.fn.executable("ldd")      == 1,
    cppfilt  = vim.fn.executable("c++filt")  == 1,
    rustfilt = vim.fn.executable("rustfilt") == 1,
  }

  local sections     = cfg.sections
  local section_data = {}
  local remaining    = #sections

  -- nothing configured: render the title bar now, rather than waiting forever
  -- on a countdown that starts already at zero
  if remaining == 0 then
    render(buf, path, sections, section_data, cfg)
    return
  end

  local function on_done(sec, data)
    if gen ~= gens[buf] then return end  -- superseded by a newer reload
    section_data[sec] = data
    remaining = remaining - 1
    if remaining == 0 then
      vim.schedule(function()
        if gen ~= gens[buf] then return end
        render(buf, path, sections, section_data, cfg)
      end)
    end
  end

  for _, sec in ipairs(sections) do
    local runner = runners[sec]
    if runner then
      -- vim.system throws synchronously when the tool is absent; catch it so a
      -- missing dependency degrades to an error section instead of aborting the
      -- whole open (and leaving the buffer stuck on "Loading...")
      local ok, err = pcall(runner, path, cfg, exe, function(data) on_done(sec, data) end)
      if not ok then
        on_done(sec, { "  [error] " .. tostring(err) })
      end
    else
      on_done(sec, { "  (unknown section: " .. sec .. ")" })
    end
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("Bin", function(o)
    M.open(o.args ~= "" and o.args or nil)
  end, { nargs = "?", complete = "file", desc = "Inspect an ELF binary" })

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

-- internals exposed for the test suite; not part of the public API
M._test = {
  is_elf         = is_elf,
  parse_checksec = parse_checksec,
}

return M
