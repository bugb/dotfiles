local builtin = require('telescope.builtin')
local map = vim.api.nvim_set_keymap
local set = vim.opt
local defaults = { noremap = true, silent = true }

-- map jj to esc 
map('i', 'jj', '<esc>l', defaults)

-- map leader to <Space>
vim.keymap.set("n", " ", "<Nop>", { silent = true, remap = false })
vim.g.mapleader = " "

-- map for telescope
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

for i=1,9,1
do
  vim.keymap.set('n', '<leader>'..i, i.."gt", {})
end
vim.keymap.set('n', '<leader>0', ":tablast<cr>", {})

set.shellcmdflag = '-ic'
--Thank to the commit: https://github.com/vijaymarupudi/nvim-fzf-commands/issues/7
--map('n', '<Leader>f', ':lua require("fzf-commands").files({command_flags="--hidden --exclude .git --exclude node_modules"})<CR>', defaults)

