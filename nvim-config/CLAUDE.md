# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim configuration based on AstroNvim v5+ framework. It uses Lazy.nvim as the plugin manager and follows AstroNvim's modular configuration structure.

## Architecture

### Configuration Loading Order

1. `init.lua` - Bootstraps Lazy.nvim installation
2. `lua/lazy_setup.lua` - Sets up Lazy.nvim with AstroNvim core and imports
3. Plugin loading order:
   - AstroNvim core plugins (`astronvim.plugins`)
   - Community plugins (`lua/community.lua` - currently disabled)
   - User plugins (`lua/plugins/*.lua`)
4. `lua/polish.lua` - Final configuration adjustments

### Plugin Configuration Structure

- **Enabled plugins**: Files in `lua/plugins/` without the disable line
- **Disabled plugins**: Files starting with `if true then return {} end`
- **Main user plugins**: `lua/plugins/user.lua` contains most custom plugin definitions

### Key Mappings

- Leader key: `<Space>`
- Local leader: `,`
- ClaudeCode shortcuts: `<leader>a*` prefix (e.g., `<leader>cc` to focus Claude)

## Common Development Tasks

### Adding a New Plugin

Add plugin configuration to `lua/plugins/user.lua` or create a new file in `lua/plugins/`:

```lua
{
  "plugin/name",
  dependencies = { "dependency/plugin" },
  config = function()
    require("plugin").setup({})
  end,
  keys = {
    { "<leader>xx", "<cmd>PluginCommand<cr>", desc = "Description" },
  },
}
```

### Modifying Keymaps

1. For plugin-specific keymaps: Add to the plugin's `keys` table in `lua/plugins/user.lua`
2. For general keymaps: Enable and modify `lua/plugins/astrocore.lua` (currently disabled)

### Enabling Disabled Files

Remove the first line `if true then return {} end` from files like:
- `lua/plugins/astrocore.lua` - Core mappings and options
- `lua/community.lua` - AstroCommunity plugin packs

## Important Files

- `lua/plugins/user.lua` - Main user plugin configurations
- `lazy-lock.json` - Pinned plugin versions (auto-managed by Lazy.nvim)
- Plugin configs: `lua/plugins/*.lua`

## Notes

- This config uses Solarized Dark theme (winter variant)
- ClaudeCode integration is configured with comprehensive keybindings
- Community plugins are disabled by default but can be enabled by removing the disable line in `lua/community.lua`
- No build/test/lint commands are configured for this Neovim setup itself