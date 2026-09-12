" +----------------------------------------------------------------------------+
" |                            BASIC SETTINGS                                  |
" +----------------------------------------------------------------------------+

" ignorecase+smartcase: case sensitive only if uppercase letters given
set ignorecase
set smartcase

" <Leader> (for userdefined commands) is now ',' instead of '\'
let mapleader = ","

" show cursor-line & -column
set cursorcolumn
set cursorline

" show tabs, trailing spaces, wrapped lines
set listchars=tab:→\ ,trail:?
set list
set showbreak=↪\

" show row-numbers
set number

" don't preselect/insert the first completion
set completeopt=menu,menuone,noselect,noinsert

" FileType indentation
"  tabstop=n:     Display a tab character as n spaces.
"  shiftwidth=n:  Use n spaces for each indentation level (>>, <<, auto-indent).
"  softtabstop=n: Make <Tab> and <Backspace> behave in increments of n spaces while editing.
"  expandtab:     Insert spaces instead of actual tab characters.
autocmd FileType json,html,xml,yaml setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab

" +----------------------------------------------------------------------------+
" |                            PLUGINS                                         |
" +----------------------------------------------------------------------------+

" disable barbar auto-setup
let g:barbar_auto_setup = v:false

lua << END
require('barbar').setup {
  icons = { filetype = { enabled = false } }
};

require('nvim-treesitter').setup {
  highlight = { enable = true },
  indent = { enable = true }
}

-- Set up go-nvim
require('go').setup()
local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
   vim.cmd('GoFmt')
  end,
  group = format_sync_grp,
})

-- Set up nvim-cmp.
local cmp = require'cmp'

cmp.setup({
  snippet = {
    expand = function(args)
      vim.fn["vsnip#anonymous"](args.body)
    end,
  },
  window = {
    -- completion = cmp.config.window.bordered(),
    -- documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm { select = false },
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'vsnip' }, -- For vsnip users.
  }, {
    { name = 'buffer' },
  })
})

-- Use buffer source for `/` and `?`
-- XXX: won't work with `native_menu` being enabled
cmp.setup.cmdline({ '/', '?' }, {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':'
-- XXX: won't work with `native_menu` being enabled
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  }),
  matching = { disallow_symbol_nonprefix_matching = false }
})

-- Add additional capabilities supported by nvim-cmp
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local lspconfig = require('lspconfig')

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
end

local servers = { 'nil_ls', 'gopls', 'ccls', 'ts_ls' }
for _, lsp in ipairs(servers) do
  vim.lsp.config(lsp, {
    on_attach = on_attach,
    capabilities = capabilities,
  })
  vim.lsp.enable(lsp)
end

-- See `:help vim.diagnostic.*` for documentation on any of the below functions
local opts = { noremap=true, silent=true }
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)

local wk = require("which-key")
wk.setup {
  plugins = {
    marks = false, -- shows a list of your marks on ' and `
    registers = false -- shows your registers on " in NORMAL or <C-r> in INSERT mode
  },
}
wk.add({
  { "<leader>b",  "<cmd>Buffers<cr>", desc = "Show Buffers (FZF)" },
  { "<leader>dw", "<cmd>call DeleteTrailingWS()<cr>", desc = "Delete Trailing Space" },
  { "<leader>cp", "<cmd>call CopyPaste()<cr>", desc = "Toggle 'C&P-Mode'" },
  { "<leader>cc", "<cmd>call ToggleColorColumn()<cr>", desc = "Toggle ColorColumn" },
  { "<leader>ll", "<cmd>nohl<cr>", desc = "Clear Search" },
  { "<leader>q",  "<cmd>bd<cr>", desc = "Close Buffer (:bd)" },
})
END

" vim-signify: default updatetime (4000 ms) is too slow for async update
set updatetime=100

" +----------------------------------------------------------------------------+
" |                            OWN FUNCTIONS                                   |
" +----------------------------------------------------------------------------+

" make text copy- & pastable despite all plugin sidebars/columns
function! CopyPaste()
  if &paste ==# "nopaste"
    set nolist
    set nonumber
    set paste
    LspStop
  else
    set listchars=tab:→\ ,trail:?
    set list
    set number
    set nopaste
    LspStart
  endif
endfunction

" toggle the colorcolumn
function! ToggleColorColumn()
  if &colorcolumn ==# ""
    set colorcolumn=+1
  else
    set colorcolumn=
  endif
endfunction
highlight ColorColumn ctermbg=0 guibg=#333333

" set default textwidth if not set yet
autocmd BufEnter * execute 'setlocal textwidth=80'

" initially call enable the colorcolumn if possible
autocmd BufEnter * :call ToggleColorColumn()

" delete the trailing whitespaces
function! DeleteTrailingWS()
  exe "normal mz"
  %s/\s\+$//ge
  exe "normal `z"
endfunc

" +----------------------------------------------------------------------------+
" |                            MAPPINGS                                        |
" +----------------------------------------------------------------------------+

" move among buffers with CTRL
" OR use fzf's :Buffers
map <C-J> :bnext<CR>
map <C-K> :bprev<CR>

" insert a Markdown-style header with the current date and time
map <leader>D :put =strftime('# %a %Y-%m-%d %H:%M:%S%z')<CR>
