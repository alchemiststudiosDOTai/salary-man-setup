-- WARN: USER PLUGINS FILE IS NOW ACTIVE

-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {

  -- == Examples of Adding Plugins ==

  -- Command palette for cmdline
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    opts = {
      lsp = {
        hover = {
          enabled = false,
        },
        signature = {
          enabled = false,
        },
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
          ["vim.lsp.util.stylize_markdown"] = false,
          ["cmp.entry.get_documentation"] = false,
        },
      },
      presets = {
        bottom_search = false,
        command_palette = true,
        long_message_to_split = false,
        inc_rename = false,
        lsp_doc_border = false,
      },
      cmdline = {
        enabled = true,
        view = "cmdline_popup",
      },
      messages = { enabled = false },
      popupmenu = { enabled = false },
      notify = { enabled = false },
    },
  },

  -- Dracula theme
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.termguicolors = true
      require("dracula").setup({
        transparent_bg = false,
        italic_comment = true,
        lualine_bg_color = "#44475a",
      })
      vim.cmd.colorscheme 'dracula'
    end,
  },

  -- Enhanced markdown preview (load after colorscheme)
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
    ft = "markdown",
  },

  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- == Examples of Overriding Plugins ==

  -- customize dashboard options
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            " █████  ███████ ████████ ██████   ██████ ",
            "██   ██ ██         ██    ██   ██ ██    ██",
            "███████ ███████    ██    ██████  ██    ██",
            "██   ██      ██    ██    ██   ██ ██    ██",
            "██   ██ ███████    ██    ██   ██  ██████ ",
            "",
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },

  -- Neo-tree configuration to show hidden files
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true, -- This will show hidden files
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false, -- only works on Windows for hidden files/directories
          hide_by_name = {
            -- you can add specific files to hide if needed
            -- ".DS_Store",
            -- "thumbs.db",
          },
          hide_by_pattern = {
            -- you can add patterns to hide if needed
            -- "*.meta",
          },
          always_show = { -- remains visible even if hidden by other settings
            ".env",
            ".gitignore",
            ".github",
          },
        },
      },
    },
  },

  
  -- Custom search keybinding
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        file_ignore_patterns = { "node_modules", ".git/" },
      },
    },
    keys = {
      { "ss", function() require("telescope.builtin").live_grep({ cwd = vim.fn.getcwd(), additional_args = { "--fixed-strings" } }) end, desc = "Search entire directory (literal)" },
    },
  },

  -- Timerly plugin for pomodoro timer
  {
    "nvzone/timerly",
    dependencies = { "nvzone/volt" },
    cmd = "TimerlyToggle",
    keys = {
      { "<leader>pt", "<cmd>TimerlyToggle<cr>", desc = "Toggle Pomodoro Timer" },
    },
  },

  -- Toggle terminal
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "tt", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal", mode = { "n", "t" } },
      { "<Esc>", [[<C-\><C-n>]], mode = "t", desc = "Exit terminal mode" },
    },
    opts = {
      size = 20,
      direction = "float",
      start_in_insert = true,
      persist_mode = true,
      float_opts = {
        border = "curved",
      },
      on_open = function()
        vim.cmd("startinsert!")
      end,
    },
  },

  -- New file creation shortcut
  {
    "folke/which-key.nvim",
    keys = {
      { "<leader>nf", "<cmd>enew<cr>", desc = "New file" },
      { "qq", ":", desc = "Open command line", mode = "n" },
    },
  },
}
