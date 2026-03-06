---@type LazySpec
return {
  {
    "nvzone/typr",
    dependencies = { "nvzone/volt" },
    cmd = { "Typr", "TyprStats" },
    opts = {},
    keys = {
      { "<leader>tp", "<cmd>Typr<cr>", desc = "Start Typr practice" },
      { "<leader>tS", "<cmd>TyprStats<cr>", desc = "Show Typr stats" },
    },
  },
}
