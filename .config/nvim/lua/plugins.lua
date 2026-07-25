local fn = vim.fn

-- Bootstrap lazy.nvim. Replaces packer.nvim, which has been unmaintained since
-- 2023. Unlike the old packer bootstrap this needs no separate sync step: lazy
-- installs anything missing on the first startup, so a fresh machine ends up
-- with a working setup by launching nvim once.
local lazypath = fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop

if not uv.fs_stat(lazypath) then
  vim.api.nvim_echo({ { "Installing lazy.nvim\n", "Type" } }, true, {})

  local out = fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })

  -- Report and carry on rather than aborting: a config that still starts is
  -- more useful than one that refuses to, and this must not block headless runs.
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Could not clone lazy.nvim, no plugin will be loaded:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    return
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    ------------------------------------------------------------------ syntax --
    { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
    { "andymass/vim-matchup", event = "VimEnter" },

    ---------------------------------------------------------------- snippets --
    { "SirVer/ultisnips" },

    -------------------------------------------------------------- completion --
    {
      "hrsh7th/nvim-cmp",
      event = "InsertEnter",
      dependencies = {
        "onsails/lspkind-nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-omni",
        "SirVer/ultisnips",
        "quangnguyen30192/cmp-nvim-ultisnips",
      },
      config = function()
        require("config.nvim-cmp")
      end,
    },

    --------------------------------------------------------------------- lsp --
    {
      "neovim/nvim-lspconfig",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = { "hrsh7th/cmp-nvim-lsp" },
      config = function()
        require("config.lsp")
      end,
    },
    { "mrcjkb/rustaceanvim", ft = "rust" },

    ------------------------------------------------------------------ finder --
    -- Pinned, as it was under packer. The keymaps in core/options.lua require
    -- telescope.builtin lazily, and lazy.nvim loads the plugin on that require.
    {
      "nvim-telescope/telescope.nvim",
      tag = "0.1.4",
      cmd = "Telescope",
      dependencies = { "nvim-lua/plenary.nvim" },
    },

    ----------------------------------------------------------------------- ui --
    -- Eager: its config registers a VimEnter autocmd that opens the tree when
    -- nvim is started on a directory, which has to be in place by then.
    {
      "nvim-tree/nvim-tree.lua",
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("config.nvim-tree")
      end,
    },
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("config.nvim-lualine")
      end,
    },
    { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
    { "kevinhwang91/nvim-ufo", dependencies = "kevinhwang91/promise-async" },

    ---------------------------------------------------------------- colours --
    -- core/colorschemes.lua has the final say on which one is active.
    {
      "rose-pine/neovim",
      name = "rose-pine",
      config = function()
        vim.cmd("colorscheme rose-pine")
      end,
    },
    { "catppuccin/nvim", name = "catppuccin" },

    -------------------------------------------------------------------- misc --
    {
      "iamcco/markdown-preview.nvim",
      ft = "markdown",
      build = function()
        vim.fn["mkdp#util#install"]()
      end,
    },
    { "dstein64/vim-startuptime", cmd = "StartupTime" },
  },

  -- The config directory is a symlink into a git repo, so the "config changed"
  -- popups are constant noise. Updates stay manual, via :Lazy.
  change_detection = { notify = false },
  checker = { enabled = false },
})
