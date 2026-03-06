return {
  {
    "okuuva/auto-save.nvim",
    event = "InsertLeave", -- load when leaving insert mode instead of startup
    opts = {
      enabled = true,
      trigger_events = {
        immediate_save = { "BufLeave", "FocusLost" },
        defer_save = { "InsertLeave", "TextChanged" },
      },
    },
  },
}
