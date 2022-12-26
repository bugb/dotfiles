scriptencoding utf-8

" this will install vim-plug if not installed
if empty(glob('~/.config/nvim/autoload/plug.vim'))
   silent !curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
   autocmd VimEnter * PlugInstall
endif
    
call plug#begin()
" Neovim plugins: 
    
call plug#end()

" Editor config
set encoding=UTF-8
set number
syntax on
filetype plugin indent on
set tabstop=2 softtabstop=2 shiftwidth=2 expandtab
set number relativenumber
set noswapfile
" Ignore case in search but case-sensitive when uppercase is present
set ignorecase smartcase

set linebreak
set showbreak=↪

set noshowmode
set fileformats=unix,dos

set visualbell noerrorbells  " Do not use visual and errorbells
set history=300  " The number of command and search history to keep
set title
set titlestring=
set titlestring=%{utils#Get_titlestr()}

set termguicolors

if !empty(provider#clipboard#Executable())
  set clipboard+=unnamedplus
endif

function! SearchHlClear()
    let @/ = ''
endfunction
augroup searchhighlight
    autocmd!
    autocmd CursorHold,CursorHoldI * call SearchHlClear()
augroup end

" " Copy to clipboard
"vnoremap  <leader>y  "+y
"nnoremap  <leader>Y  "+yg_
"nnoremap  <leader>y  "+y
"nnoremap  <leader>yy  "+yy

" " Paste from clipboard
"nnoremap <leader>p "+p
"nnoremap <leader>P "+P
"vnoremap <leader>p "+p
"vnoremap <leader>P "+P
