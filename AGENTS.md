# Neovim Config Repository

This is `jadonwb/nvim`, a git submodule at
`~/.local/share/chezmoi/.repos/nvim`; `~/.config/nvim` is a symlink to this
directory.

The OpenCode artifact UI lives in
`lua/editor/features/opencode-artifacts.lua`.

## Procedure

Commit and push this repo first, then update the chezmoi superproject
(`~/.local/share/chezmoi`) and run `chezmoi apply`.