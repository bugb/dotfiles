local fn = vim.fn
local api = vim.api
local keymap = vim.keymap
local lsp = vim.lsp
local diagnostic = vim.diagnostic

local utils = require("utils")

-- nvim 0.11 takes float options directly on vim.lsp.buf.hover and deprecated
-- the lsp.with() handler wrapper we use on older versions.
local has_native_hover_opts = fn.has("nvim-0.11") == 1

local custom_attach = function(client, bufnr)
  -- Mappings.
  local map = function(mode, l, r, opts)
    opts = opts or {}
    opts.silent = true
    opts.buffer = bufnr
    keymap.set(mode, l, r, opts)
  end

  map("n", "gd", vim.lsp.buf.definition, { desc = "go to definition" })
  map("n", "<C-]>", vim.lsp.buf.definition)
  if has_native_hover_opts then
    map("n", "K", function() vim.lsp.buf.hover({ border = "rounded" }) end)
  else
    map("n", "K", vim.lsp.buf.hover)
  end
  map("n", "<C-k>", vim.lsp.buf.signature_help)
  map("n", "<space>rn", vim.lsp.buf.rename, { desc = "varialbe rename" })
  map("n", "gr", vim.lsp.buf.references, { desc = "show references" })
  -- diagnostic.goto_prev/goto_next were removed in nvim 0.12 in favour of jump()
  if diagnostic.jump then
    map("n", "[d", function() diagnostic.jump({ count = -1, float = true }) end, { desc = "previous diagnostic" })
    map("n", "]d", function() diagnostic.jump({ count = 1, float = true }) end, { desc = "next diagnostic" })
  else
    map("n", "[d", diagnostic.goto_prev, { desc = "previous diagnostic" })
    map("n", "]d", diagnostic.goto_next, { desc = "next diagnostic" })
  end
  map("n", "<space>q", diagnostic.setqflist, { desc = "put diagnostic to qf" })
  map("n", "<space>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
  map("n", "<space>wa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
  map("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, { desc = "remove workspace folder" })
  map("n", "<space>wl", function()
    inspect(vim.lsp.buf.list_workspace_folders())
  end, { desc = "list workspace folder" })

  -- Set some key bindings conditional on server capabilities
  if client.server_capabilities.documentFormattingProvider then
    map("n", "<space>f", vim.lsp.buf.format, { desc = "format code" })
  end

  api.nvim_create_autocmd("CursorHold", {
    buffer = bufnr,
    callback = function()
      local float_opts = {
        focusable = false,
        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
        border = "rounded",
        source = true, -- show source in diagnostic popup window ("always" was dropped in 0.10)
        prefix = " ",
      }

      if not vim.b.diagnostics_pos then
        vim.b.diagnostics_pos = { nil, nil }
      end

      local cursor_pos = api.nvim_win_get_cursor(0)
      if (cursor_pos[1] ~= vim.b.diagnostics_pos[1] or cursor_pos[2] ~= vim.b.diagnostics_pos[2])
          and #diagnostic.get() > 0
      then
        diagnostic.open_float(nil, float_opts)
      end

      vim.b.diagnostics_pos = cursor_pos
    end,
  })

  -- The blow command will highlight the current variable and its usages in the buffer.
  if client.server_capabilities.documentHighlightProvider then
    vim.cmd([[
      hi! link LspReferenceRead Visual
      hi! link LspReferenceText Visual
      hi! link LspReferenceWrite Visual
    ]])

    local gid = api.nvim_create_augroup("lsp_document_highlight", { clear = true })
    api.nvim_create_autocmd("CursorHold" , {
      group = gid,
      buffer = bufnr,
      callback = function ()
        lsp.buf.document_highlight()
      end
    })

    api.nvim_create_autocmd("CursorMoved" , {
      group = gid,
      buffer = bufnr,
      callback = function ()
        lsp.buf.clear_references()
      end
    })
  end

  if vim.g.logging_level == "debug" then
    local msg = string.format("Language server %s started!", client.name)
    vim.notify(msg, vim.log.levels.DEBUG, { title = "Nvim-config" })
  end
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- nvim 0.11 replaced the lspconfig "framework" (lspconfig.<server>.setup) with
-- vim.lsp.config/vim.lsp.enable, and nvim-lspconfig prints a deprecation
-- traceback whenever the old path is used. Prefer the builtin API where it
-- exists and keep the old one for older nvim.
local use_native_lsp = vim.lsp.config ~= nil and vim.lsp.enable ~= nil

--- The language servers we configure. `binary` must be on $PATH for the server
--- to be registered; `legacy_name` covers servers nvim-lspconfig has renamed.
local servers = {
  {
    name = "pylsp",
    binary = "pylsp",
    title = "Nvim LSP config for Python",
    config = {
      settings = {
        pylsp = {
          plugins = {
            pylint = { enabled = true, executable = "pylint" },
            pyflakes = { enabled = false },
            pycodestyle = { enabled = false },
            jedi_completion = { fuzzy = true },
            pyls_isort = { enabled = true },
            pylsp_mypy = { enabled = true },
          },
        },
      },
    },
  },
  {
    name = "ts_ls",
    legacy_name = "tsserver",
    binary = "typescript-language-server",
    title = "Nvim LSP config for Nodejs/Javascript",
    config = {},
  },
  {
    name = "gopls",
    binary = "gopls",
    title = "Nvim LSP config for Go",
    config = {
      cmd = { "gopls", "serve" },
      filetypes = { "go", "gomod" },
      root_markers = { "go.work", "go.mod", ".git" },
      settings = {
        gopls = {
          analyses = {
            unusedparams = true,
          },
          staticcheck = true,
        },
      },
    },
  },
}

if use_native_lsp then
  -- The builtin API has no on_attach, so run custom_attach for every client.
  api.nvim_create_autocmd("LspAttach", {
    group = api.nvim_create_augroup("lsp_custom_attach", { clear = true }),
    callback = function(args)
      local client = lsp.get_client_by_id(args.data.client_id)
      if client then
        custom_attach(client, args.buf)
      end
    end,
  })
end

--- Register a server through the pre-0.11 lspconfig framework.
local function legacy_setup(server, conf)
  local lspconfig = require("lspconfig")

  -- root_markers is the builtin spelling; lspconfig wants a root_dir function.
  if conf.root_markers then
    conf.root_dir = require("lspconfig.util").root_pattern(unpack(conf.root_markers))
    conf.root_markers = nil
  end
  conf.on_attach = custom_attach
  conf.flags = { debounce_text_changes = 200 }

  for _, name in ipairs({ server.name, server.legacy_name }) do
    if name then
      -- Unknown server names raise instead of returning nil on old versions.
      local ok, mod = pcall(function()
        return lspconfig[name]
      end)
      if ok and mod ~= nil then
        mod.setup(conf)
        return true
      end
    end
  end

  return false
end

for _, server in ipairs(servers) do
  if not utils.executable(server.binary) then
    vim.notify(server.binary .. " not found!", vim.log.levels.WARN, { title = server.title })
  else
    local conf = vim.tbl_deep_extend("force", { capabilities = capabilities }, server.config)

    if use_native_lsp then
      vim.lsp.config(server.name, conf)
      vim.lsp.enable(server.name)
    elseif not legacy_setup(server, conf) then
      vim.notify("No lspconfig entry for " .. server.name, vim.log.levels.WARN, { title = server.title })
    end
  end
end
-- if utils.executable('pyright') then
--   lspconfig.pyright.setup{
--     on_attach = custom_attach,
--     capabilities = capabilities
--   }
-- else
--   vim.notify("pyright not found!", vim.log.levels.WARN, {title = 'Nvim-config'})
-- end

-- Change diagnostic signs.
fn.sign_define("DiagnosticSignError", { text = "✗", texthl = "DiagnosticSignError" })
fn.sign_define("DiagnosticSignWarn", { text = "!", texthl = "DiagnosticSignWarn" })
fn.sign_define("DiagnosticSignInformation", { text = "", texthl = "DiagnosticSignInfo" })
fn.sign_define("DiagnosticSignHint", { text = "", texthl = "DiagnosticSignHint" })

-- global config for diagnostic
diagnostic.config {
  underline = false,
  virtual_text = false,
  signs = true,
  severity_sort = true,
}

-- lsp.handlers["textDocument/publishDiagnostics"] = lsp.with(lsp.diagnostic.on_publish_diagnostics, {
--   underline = false,
--   virtual_text = false,
--   signs = true,
--   update_in_insert = false,
-- })

-- Change border of documentation hover window, See https://github.com/neovim/neovim/pull/13998.
-- From nvim 0.11 the border is passed to vim.lsp.buf.hover (see custom_attach)
-- and lsp.with() is deprecated.
if not has_native_hover_opts then
  lsp.handlers["textDocument/hover"] = lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
  })
end
