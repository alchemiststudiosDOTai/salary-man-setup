# My AstroNvim Configuration

This is my personal Neovim configuration based on [AstroNvim](https://github.com/AstroNvim/AstroNvim) v5+.

## Directory Structure

```
.
├── lua/
│   ├── plugins/        # Plugin configurations
│   │   ├── astroui.lua # UI customizations
│   │   └── user.lua    # Main plugin definitions
│   └── user/          # User-specific configurations
├── lazy-lock.json     # Plugin version lock file
└── README.md          # This file
```

## Installed Plugins

### Core Plugins

- **[folke/noice.nvim](https://github.com/folke/noice.nvim)** - Command palette for cmdline with popup interface
- **[maxmx03/solarized.nvim](https://github.com/maxmx03/solarized.nvim)** - Solarized Dark theme (winter variant)
- **[ray-x/lsp_signature.nvim](https://github.com/ray-x/lsp_signature.nvim)** - LSP signature help during typing
- **[coder/claudecode.nvim](https://github.com/coder/claudecode.nvim)** - Claude AI integration for code assistance

### Modified Default Plugins

- **[folke/snacks.nvim](https://github.com/folke/snacks.nvim)** - Custom AstroNvim dashboard header
- **[L3MON4D3/LuaSnip](https://github.com/L3MON4D3/LuaSnip)** - Extended for JavaScript/React snippets
- **[windwp/nvim-autopairs](https://github.com/windwp/nvim-autopairs)** - Custom rules for LaTeX

### Disabled Plugins

- **better-escape.nvim** - Disabled by default

## Key Features

- **Theme**: Solarized Dark with winter variant
- **Command Interface**: Noice.nvim popup command palette
- **AI Integration**: Claude Code for AI-assisted development
- **LSP Enhancements**: Signature help on typing
- **Custom Dashboard**: AstroNvim ASCII art header

## Installation

1. Backup your existing Neovim configuration:

```shell
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

2. Clone this configuration:

```shell
git clone https://github.com/larock22/astro-nvim-config.git ~/.config/nvim
```

3. Start Neovim:

```shell
nvim
```

Plugins will automatically install on first launch.

## Cheat Sheet

### Search Commands

- `<leader>ff` - Find files in current directory
- `<leader>fw` - Live grep (search text in all files)
- `<leader>fc` - Search for word under cursor
- `<leader>fo` - Search recently opened files
- `<leader>fg` - Find files in git repository
- `/` - Search within Neo-tree file explorer
- `:vimgrep /pattern/ **/*.lua` - Search pattern in all lua files
- `:grep pattern **/*` - Use external grep
