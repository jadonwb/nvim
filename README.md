# Neovim configuration

Personal Neovim config using lazy.nvim, with an IDE layout for workspaces and
smaller launch profiles for diff, pager, and embedded editing. Chezmoi deploys
this repository to `~/.config/nvim`; Omarchy supplies the active theme on
machines that use it. Elsewhere the theme falls back to `habamax`.

## Setup

1. Install Neovim 0.12 or 0.13. See [version support](docs/wiki/nvim-0.13.md).
2. Install `git`, `make`, `unzip`, a C compiler, `ripgrep`, `fd`, and a recent
   `tree-sitter` CLI. A Nerd Font is recommended for icons. Use `wl-clipboard`
   on Wayland or `xclip`/`xsel` on X11 for system clipboard access.
3. Deploy with `chezmoi apply ~/.config/nvim`, or place this repository at
   `~/.config/nvim` on a standalone machine.
4. Start Neovim and run `:Lazy sync` to install plugins, then restart.
   Startup does not automatically install missing plugins. lazy.nvim owns
   `lazy-lock.json` locally; Git and chezmoi leave it alone.
5. Open `:NVExtras` to choose language packs. New state defaults to C/C++ and
   BitBake. C++ manual pages require the separate `cppman` executable; for
   example, `uv tool install cppman` installs it for your user.

See the [wiki](docs/wiki/README.md) for startup, keymaps, and feature guides.
