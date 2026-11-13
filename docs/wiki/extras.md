# Language extras

Language tooling is chosen per machine, like LazyVim's extras. A work machine
enables C/C++ and BitBake; a laptop used for dotfiles may enable none.

`<leader>px` (or `:NVExtras`) opens the dashboard: enabled and available packs,
whether each pack's tools are installed, and the details of the pack under the
cursor. `x`, `<CR>` or `<Space>` toggles it. `:NVExtras <pack> [on|off]` does
the same from the command line.

## Always on

| | |
| --- | --- |
| Servers | `lua_ls`, `jsonls`, `yamlls`, `taplo`, `systemd_lsp` |
| Tools | `prettier` (markdown), `systemd-lsp` |
| Parsers | about 50, so anything reads with highlighting: assembly, linker scripts, make, CMake, Kconfig, device tree, SQL, proto, … |

## Packs

| Pack | Servers | Tools | Formatters / linters | Plugins |
| --- | --- | --- | --- | --- |
| C / C++ | clangd, neocmake | clang-format | clang-format | cppman.nvim |
| BitBake / Yocto | bitbake_ls | language-server-bitbake, oelint-adv | oelint-adv (lint) | |
| Rust | rust_analyzer (clippy) | | rustfmt through the server | crates.nvim |
| Python | basedpyright, ruff | | ruff (organize imports, format) | |
| JavaScript / TypeScript | vtsls, eslint | prettier | prettier | |
| Shell | bashls | shellcheck, shfmt | shfmt | |

Each pack also lists the parsers it relies on (most are in the base set).

## How it works

- **Machine-local choice:** stored in `stdpath('state')/extras.json`, so chezmoi
  does not sync it. A machine that has never chosen gets C/C++ and BitBake,
  which is what the config enabled before extras existed.
- **`config/extras.lua` is data:** the packs and the base. Every consumer reads
  it: the server list (`features/lsp`), Mason tools (`plugins/lsp/mason.lua`),
  treesitter parsers, conform, nvim-lint, and plugin specs through
  `extras.enabled(name)`.
- **Toggles apply at once:**
  - Turning a pack on: Mason installs its tools and servers, its parsers
    compile, its servers start on open buffers, and its formatters and linters
    take effect.
  - Turning a pack off: its servers stop.
  - A pack's plugins load on the next start.
  - Installed tools stay installed; remove them in Mason (`<leader>pm`).

`tests/extras.sh` covers the defaults, saving, merging, and live toggling,
with installs stubbed.
