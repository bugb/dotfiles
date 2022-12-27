local builtin = require('telescope.builtin')
local nmap = vim.api.nvim_set_keymap
local map = vim.keymap.set
local set = vim.opt
local defaults = { noremap = true, silent = true }

-- Keys notation table:
-- https://neovim.io/doc/user/intro.html#key-notation

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
set.termguicolors = true
--unmap Ctrl + q
map("n", "<C-q>", "", defaults)

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

-- Disable highlights results from your previous search
set.hlsearch = false

-- map for quick quit, save files using leader key
---- Normal mode
map('n', '<Leader>w', ':write<CR>')
map('n', '<Leader>a', ':wqa<CR>')
map('n', '<Leader>x', ':wq<CR>')

---- Insert mode
map('i', ';w', '<esc>:write<CR>')
map('i', ';x', '<esc>:wq<CR>')

-- map for quick open the file init.lua
map('n', '<leader>nv', ':vsplit ~/.config/nvim/init.lua<cr>', {})

-- auto add closing {, [, (, ', ", <
map('i', '{<cr>', '{<cr>}<ESC>kA<CR>', {})
closing_pairs = {'}', ')', ']', '"', "'", '>'}
opening_pairs = {'{', '(', '[', '"', "'", '<'}
for key, chr in pairs(opening_pairs)
do
  map('i', chr, chr..closing_pairs[key]..'<esc>i', {})
end

-- use U for redo :))
map('n', 'U', '<C-r>', {})

-- map c and d to black hole registers
map('n', 'd', '"_d', {})
map('n', 'c', '"_c', {})
-- map('n', 'r', 'd', {})

-- scrolling
map('n', ',', '<C-u>', defaults)
map('n', 'm', '<C-d>', defaults)
map('n', 'M', 'm', defaults)

-- Insert empty line without entering insert mode
map('n', '<leader>o', ':<C-u>call append(line("."), repeat([""], v:count1))<CR>', defaults)
map('n', '<leader>O', ':<C-u>call append(line(".")-1, repeat([""], v:count1))<CR>', defaults)

-- Fast searching text under cursor with Goole with Ctrl+q Ctrl+g
-- I am using ArchLinux so I use the xdg-open command
-- For other file system it can be opEn
local searching_google_in_normal = [[:lua vim.fn.system({'xdg-open', 'https://google.com/search?q=' .. vim.fn.expand("<cword>")})<CR>]]
map("n", "<C-q><C-g>", searching_google_in_normal, defaults)

-- Select all text in the current buffer
map('n', '<leader>C', ':keepjumps normal! ggyG<cr>', defaults)

-- Toggle see whitespace characters like: eol, space, ...
set.lcs = 'tab:>-,eol:$,nbsp:X,trail:#'
map('n', '<F6>', ':set list!<cr>')
-- Disable scroll to end of file
set.scrolloff = 3

-- Ctrl + l to remove highlights and redraw your screen
map('n', '<C-l>', ':nohlsearch<cr>', defaults)

-- Alt/Meta + c to capitalize the inner word
map('n', '<M-c>', 'guiw~w', defaults)

-- Alt/Meta + u to capitalize the inner word
map('n', '<M-u>', 'gUiww', defaults)

-- Alt/Meta + l to capitalize the inner word
map('n', '<M-l>', 'guiww', defaults)

-- Shift + Up/Down to move line up/down
map('n', '<S-Up>', 'yyddkP', defaults)
map('n', '<S-Down>', 'yyddp', defaults)

-- Keymaps for Nvim tree
map('n', '<leader>e', ':NvimTreeToggle<cr>', defaults)
map('n', '<C-Left>', '<C-w><Left>', defaults)
map('n', '<C-Right>', '<C-w><Right>', defaults)

---- Do some magic with autocmd
-- Remove trailing space
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})
--Thank to the commit: https://github.com/vijaymarupudi/nvim-fzf-commands/issues/7
--map('n', '<Leader>f', ':lua require("fzf-commands").files({command_flags="--hidden --exclude .git --exclude node_modules"})<CR>', defaults)

