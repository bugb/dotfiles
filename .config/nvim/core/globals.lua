local fn = vim.fn
local api = vim.api

local utils = require('utils')

-- Inspect something
function _G.inspect(item)
  -- vim.pretty_print is gone as of nvim 0.12; vim.print replaced it in 0.9
  local pp = vim.print or vim.pretty_print
  pp(item)
end

------------------------------------------------------------------------
--                          custom variables                          --
------------------------------------------------------------------------
vim.g.is_win = (utils.has("win32") or utils.has("win64")) and true or false
vim.g.is_linux = (utils.has("unix") and (not utils.has("macunix"))) and true or false
vim.g.is_mac  = utils.has("macunix") and true or false

vim.g.logging_level = "info"

------------------------------------------------------------------------
--                         builtin variables                          --
------------------------------------------------------------------------
vim.g.loaded_perl_provider = 0  -- Disable perl provider
vim.g.loaded_ruby_provider = 0  -- Disable ruby provider
vim.g.loaded_node_provider = 0  -- Disable node provider
vim.g.did_install_default_menus = 1  -- do not load menu

-- Pin the python3 provider to a dedicated venv when one exists. Otherwise the
-- provider follows whichever python3 is first on $PATH, so activating a conda
-- env or virtualenv without pynvim in it silently breaks python plugins such as
-- UltiSnips. Create it with:
--   python3 -m venv ~/.local/share/nvim/venv
--   ~/.local/share/nvim/venv/bin/python3 -m pip install pynvim
local venv_python = fn.stdpath("data") .. "/venv/bin/python3"
if vim.g.is_win then
  venv_python = fn.stdpath("data") .. "/venv/Scripts/python.exe"
end

if fn.executable(venv_python) == 1 then
  vim.g.python3_host_prog = venv_python
elseif utils.executable('python3') then
  if vim.g.is_win then
    vim.g.python3_host_prog = fn.substitute(fn.exepath("python3"), ".exe$", '', 'g')
  else
    vim.g.python3_host_prog = fn.exepath("python3")
  end
else
  api.nvim_err_writeln("Python3 executable not found! You must install Python3 and set its PATH correctly!")
  return
end

-- Custom mapping <leader> (see `:h mapleader` for more info)
vim.g.mapleader = ','

-- Enable highlighting for lua HERE doc inside vim script
vim.g.vimsyn_embed = 'l'

-- Use English as main language
vim.cmd [[language en_US.UTF-8]]

-- Disable loading certain plugins

-- Whether to load netrw by default, see https://github.com/bling/dotvim/issues/4
-- vim.g.loaded_netrw       = 1
-- vim.g.loaded_netrwPlugin = 1
-- vim.g.netrw_liststyle = 3
-- if vim.g.is_win then
--  vim.g.netrw_http_cmd = "curl --ssl-no-revoke -Lo"
-- end

-- Do not load tohtml.vim
vim.g.loaded_2html_plugin = 1

-- Do not load zipPlugin.vim, gzip.vim and tarPlugin.vim (all these plugins are
-- related to checking files inside compressed files)
vim.g.loaded_zipPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_tarPlugin = 1

-- Do not load the tutor plugin
vim.g.loaded_tutor_mode_plugin = 1

-- Do not use builtin matchit.vim and matchparen.vim since we use vim-matchup
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1

-- Disable sql omni completion, it is broken.
vim.g.loaded_sql_completion = 1
