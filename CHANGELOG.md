# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-08

First public release.

### Added

- Open any ELF binary as a structured, collapsible inspection buffer built from
  `readelf` and a handful of optional tools (`file`, `size`, `strings`, `ldd`,
  `checksec`, `c++filt`, `rustfilt`).
- Sections load in parallel; a missing optional tool leaves a short notice in
  place rather than failing the whole view.
- `:Bin` and `:Bin /path/to/binary`, alongside `require("bin").open()`.
- Folding (`zM` / `zR` / `za`) and `]]` / `[[` section navigation.
- Buffer-local syntax highlighting under a private `binview` filetype.
- `:checkhealth bin`, reporting the Neovim version floor and which tools are
  present.

[1.0.0]: https://github.com/a-mango/bin.nvim/releases/tag/v1.0.0
