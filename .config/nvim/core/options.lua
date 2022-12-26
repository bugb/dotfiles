local builtin = require('telescope.builtin')
local nmap = vim.api.nvim_set_keymap
local map = vim.keymap.set
local set = vim.opt
local defaults = { noremap = true, silent = true }

-- map jj to esc 
nmap('i', 'jj', '<esc>l', defaults)

-- map leader to <Space>
map("n", " ", "<Nop>", { silent = true, remap = false })
vim.g.mapleader = " "

-- map for telescope
map('n', '<leader>ff', builtin.find_files, {})
map('n', '<leader>fg', builtin.live_grep, {})
map('n', '<leader>fb', builtin.buffers, {})
map('n', '<leader>fh', builtin.help_tags, {})

for i=1,9,1
do
  map('n', '<leader>'..i, i.."gt", {})
end
map('n', '<leader>0', ":tablast<cr>", {})

-- Discovered it when using vim-forgit
-- https://github.com/ray-x/forgit.nvim/issues/1
set.shellcmdflag = '-ic'

--Thank to the commit: https://github.com/vijaymarupudi/nvim-fzf-commands/issues/7
--map('n', '<Leader>f', ':lua require("fzf-commands").files({command_flags="--hidden --exclude .git --exclude node_modules"})<CR>', defaults)

