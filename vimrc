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

"Monokai theme
Bundle 'sickill/vim-monokai'

"easy motion 
Bundle 'easymotion/vim-easymotion'

" Paint css colors with the real color
"Bundle 'lilydjwg/colorizer'

" Airline
"Bundle 'bling/vim-airline'

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
" Plugins Configuration
" -----------------------------------------------------------------------------
:set number "show lines numbers 
colorscheme monokai
set background=dark
syntax enable

"Nerd tree
let NERDTreeIgnore = ['\.pyc$', '\.pyo$']
map <C-n> :NERDTreeToggle<CR>i


