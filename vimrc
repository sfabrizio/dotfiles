set nocompatible
" Vundle
let iCanHazVundle=1
let vundle_readme=expand('~/.vim/bundle/vundle/README.md')
if !filereadable(vundle_readme)
    echo "Installing Vundle..."
    echo ""
    silent !mkdir -p ~/.vim/bundle
    silent !git clone https://github.com/gmarik/vundle ~/.vim/bundle/Vundle
    let iCanHazVundle=0
endif

" required for Vundle
filetype off

set rtp+=~/.vim/bundle/Vundle/
call vundle#rc()


" -----------------------------------------------------------------------------
" Plugins
" -----------------------------------------------------------------------------
" Required for vundle
Bundle 'gmarik/vundle'

" File browser
Bundle 'scrooloose/nerdtree'

" Code commenter
Bundle 'scrooloose/nerdcommenter'

" Code and files fuzzy finder
Bundle 'ctrlpvim/ctrlp.vim'

" Search inside files
Bundle 'dyng/ctrlsf.vim'

"Monokai theme
Bundle 'sickill/vim-monokai'

" Paint css colors with the real color
Bundle 'lilydjwg/colorizer'

" Airline
Bundle 'bling/vim-airline'

"devicons
Bundle 'ryanoasis/vim-devicons'

"choosewin
Bundle 't9md/vim-choosewin'
" git
Bundle 'tpope/vim-fugitive'
Bundle 'airblade/vim-gitgutter'

" Better autocompletion
"Bundle 'Shougo/neocomplcache.vim'

" Search results counter
"Bundle 'IndexedSearch'

" XML/HTML tags navigation
"Bundle 'matchit.zip'

" Syntax
" JSON support
Bundle 'elzr/vim-json'
" html5 support
Bundle 'othree/html5.vim'
Bundle 'jelera/vim-javascript-syntax'
"Python and other lenguages
Bundle 'scrooloose/syntastic'
Bundle 'genoma/vim-less'
Bundle 'othree/yajs.vim'
Bundle 'JulesWang/css.vim'
Bundle 'Konfekt/FastFold'
"Bundle 'SirVer/ultisnips' python 2.7 lib trouble on mac
Bundle 'pangloss/vim-javascript'
" nodejs
Bundle 'moll/vim-node'

"Code beautify
Bundle 'maksimr/vim-jsbeautify'


" Installing plugins the first time
if iCanHazVundle == 0
    echo "Installing Bundles, please ignore key map error messages"
    echo ""
    :BundleInstall
endif

" -----------------------------------------------------------------------------
"  Detect OS to make things nicer
" -----------------------------------------------------------------------------
if has("unix")
  " 'Darwin' or 'Linux'.
  let s:uname = system("echo -n \"$(uname -s)\"")
  let $PLATFORM = tolower(s:uname)
else
  let s:uname = ""
end

" Set the font, colour scheme, etc. appropriately.
if has("gui_running")
  colors desert
  if has("gui_gtk2")
    set guifont=Monospace\ 10
  elseif has("gui_win32")
    set guifont=Consolas:h10:cANSI
  elseif has("gui_macvim")
    set guifont=Menlo\ Regular:h11
  endif
endif

" On Mac OS X, "set lines" causes the terminal window to be resized; we don't want that.
if has("gui_running")
  " gui_running => not in a terminal => safe to resize.
  if &lines < 50
    set lines=50
  endif
  if &columns < 120
    set columns=120
  endif
endif

" In terminal mode, use a different coloured cursor for insert mode:
if s:uname != "Darwin" && &term =~ "xterm-256color" && !has("gui_running")
  " Use an orange cursor in insert mode.
  let &t_SI = "\<Esc>]12;orange\x7"
  " Use a white cursor otherwise, and set it initially.
  let &t_EI = "\<Esc>]12;white\x7"
  silent !echo -ne "\E]12;white\x7"
  " Reset it when exiting.
  autocmd VimLeave * silent !echo -ne "\E]12;white\x7"
end

" -----------------------------------------------------------------------------
"General Configuration
" -----------------------------------------------------------------------------

colorscheme monokai
set background=dark
syntax enable
"set encoding=utf8
set guifont=Droid\ Sans\ Mono\ for\ Powerline\ Plus\ Nerd\ File\ Types:h11
"auto remove all trailing whitespaces
autocmd BufWritePre * %s/\s\+$//e

set mouse=a
set clipboard=unnamed "clipboard issue with tmux and iterm
set nowrap " no use swp files
set autoindent
set incsearch  "make search act like search in modern browsers
set showmatch "show matching for ({[ "
set noswapfile   "noswap files
set tabstop=4   " size of a hard tabstop
set shiftwidth=4    " size of an "indent"
set softtabstop=4
set showtabline=2 " Always display the tabline, even if there is only one tab
set expandtab
set noshowmode " Hide the default mode text (e.g. -- INSERT -- below the statusline)
set laststatus=2  " Always display the status line
set autowrite     " Automatically :write before running commands
set autoread      " Reload files changted outside vim
set matchpairs+=<:>  "HTML Editing
set viminfo^=% "open buffers on close
set cursorline
set nu "number lines
set rnu "relatives number lines
set autochdir "Auto set dir


" -----------------------------------------------------------------------------
" Hooks
" -----------------------------------------------------------------------------

" automatically reload vimrc when it's saved
au BufWritePost .vimrc so ~/.vimrc

"autocmd BufWritePre * :call Trim()



" -----------------------------------------------------------------------------
" Plugins Configuration
" -----------------------------------------------------------------------------

"Nerd tree
let NERDTreeIgnore = ['\.pyc$', '\.pyo$']
let NERDTreeShowHidden=1 "show hidden files by default
map <C-n> :NERDTreeToggle<CR>
" NERDTress File highlighting
function! NERDTreeHighlightFile(extension, fg, bg, guifg, guibg)
exec 'autocmd FileType nerdtree highlight ' . a:extension .' ctermbg='. a:bg .' ctermfg='. a:fg .' guibg='. a:guibg .' guifg='. a:guifg
exec 'autocmd FileType nerdtree syn match ' . a:extension .' #^\s\+.*'. a:extension .'$#'
endfunction

call NERDTreeHighlightFile('jade', 'green', 'none', 'green', '#151515')
call NERDTreeHighlightFile('ini', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('md', 'blue', 'none', '#3366FF', '#151515')
call NERDTreeHighlightFile('yml', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('config', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('conf', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('json', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('html', 'green', 'none', 'green', '#151515')
call NERDTreeHighlightFile('styl', 'cyan', 'none', 'cyan', '#151515')
call NERDTreeHighlightFile('css', 'cyan', 'none', 'cyan', '#151515')
call NERDTreeHighlightFile('coffee', 'Red', 'none', 'red', '#151515')
call NERDTreeHighlightFile('js', 'Red', 'none', '#ffa500', '#151515')
call NERDTreeHighlightFile('php', 'Magenta', 'none', '#ff00ff', '#151515')
call NERDTreeHighlightFile('ds_store', 'Gray', 'none', '#686868', '#151515')
call NERDTreeHighlightFile('gitconfig', 'Gray', 'none', '#686868', '#151515')
call NERDTreeHighlightFile('gitignore', 'Gray', 'none', '#686868', '#151515')
call NERDTreeHighlightFile('bashrc', 'Gray', 'none', '#686868', '#151515')
call NERDTreeHighlightFile('bashprofile', 'Gray', 'none', '#686868', '#151515')

"Airlines
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = '>'
let g:airline#extensions#tabline#left_alt_sep = '<'
let g:airline_powerline_fonts = 1

"ctrlP
" don't change working directory
let g:ctrlp_working_path_mode = 0
" ignore these files and folders on file finder
let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/](\.git|\.hg|\.svn)$',
  \ 'file': '\.pyc$\|\.pyo$',
  \ }

"Syntastic
" check also when just opened the file
let g:syntastic_check_on_open = 1
" don't put icons on the sign column (it hides the vcs status icons of signify)
let g:syntastic_enable_signs = 0
" custom icons (enable them if you use a patched font, and enable the previous
" setting)
let g:syntastic_error_symbol = '✗'
let g:syntastic_warning_symbol = '⚠'
let g:syntastic_style_error_symbol = '✗'
let g:syntastic_style_warning_symbol = '⚠'
"eslint checker
let g:syntastic_javascript_checkers = ['eslint']
let g:syntastic_javascript_eslint_exec = 'eslint_d'

"colors
hi SpellBad ctermfg=233 ctermbg=160
hi SpellCap ctermfg=226 ctermbg=233

"choose-win
nmap - <Plug>(choosewin)
" if you want to use overlay feature
let g:choosewin_overlay_enable = 1

"ctrlSF
nmap     <C-F>f <Plug>CtrlSFPrompt
vmap     <C-F>f <Plug>CtrlSFVwordPath
vmap     <C-F>F <Plug>CtrlSFVwordExec
nmap     <C-F>n <Plug>CtrlSFCwordPath
nmap     <C-F>p <Plug>CtrlSFPwordPath
nnoremap <C-F>o :CtrlSFOpen<CR>
nnoremap <C-F>t :CtrlSFToggle<CR>
inoremap <C-F>t <Esc>:CtrlSFToggle<CR>let g:ctrlsf_ackprg = 'ack'
let g:ctrlsf_ignore_dir = ['bower_components', 'npm_modules']
let g:ctrlsf_default_root = 'project'
let g:ctrlsf_auto_close = 0

"==================
"GUNDO
"==================
nnoremap <F5> :GundoToggle<CR>

let g:EditorConfig_exclude_patterns = ['fugitive://.*']
"==================
" GIT
"==================
map <Leader>gc :GCommit -m ""<LEFT>
map <Leader>gs :GStatus
"always activate GitGutter plug
autocmd VimEnter * GitGutterSignsEnable

"Code beautify
map <c-l> :call JsBeautify()<cr>
" or
autocmd FileType javascript noremap <buffer>  <c-l> :call JsBeautify()<cr>
" for json
autocmd FileType json noremap <buffer> <c-l> :call JsonBeautify()<cr>
" for jsx
autocmd FileType jsx noremap <buffer> <c-l> :call JsxBeautify()<cr>
" for html
autocmd FileType html noremap <buffer> <c-l> :call HtmlBeautify()<cr>
" for css or scss
autocmd FileType css noremap <buffer> <c-l> :call CSSBeautify()<cr>

