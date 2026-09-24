-- beam-sharp for neovim: filetype, and the Tree-sitter parser when it is installed.
--
-- `editor/nvim/` is a plugin directory, so one lazy.nvim line loads this file,
-- `ftdetect/` and `syntax/` together. Until `:TSInstall beam_sharp` has run, the
-- regex grammar in `syntax/bs.vim` colours the buffer; afterwards Tree-sitter
-- replaces it for every `.bs` buffer opened.

-- Neovim 0.12 ships `bs = "brighterscript"` in its own extension table. A
-- user-added extension overrides the built-in one, so this line decides the
-- filetype however the plugins load.
vim.filetype.add({ extension = { bs = 'bs' } })
vim.treesitter.language.register('beam_sharp', 'bs')

-- This file is editor/nvim/plugin/beam_sharp.lua; the grammar is editor/tree-sitter-beam-sharp.
local here = debug.getinfo(1, 'S').source:sub(2)
local grammar = vim.fs.joinpath(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(here))), 'tree-sitter-beam-sharp')

-- nvim-treesitter's `main` branch reads custom parsers from its parsers table,
-- which it rebuilds and announces with `User TSUpdate`. `path` builds from the
-- checkout as it stands, and `queries` symlinks the directory, so an edit to
-- highlights.scm is live on the next buffer and needs no reinstall.
local function register()
  require('nvim-treesitter.parsers').beam_sharp = {
    install_info = { path = grammar, queries = 'queries' },
  }
end

vim.api.nvim_create_autocmd('User', { pattern = 'TSUpdate', callback = register })
if package.loaded['nvim-treesitter.parsers'] then
  register()
end

-- `main` does not start highlighting on its own, and LazyVim starts it only for
-- parsers in a list it caches at startup. pcall because a missing parser is the
-- normal state before `:TSInstall`, and the regex grammar is then what shows.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'bs',
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf, 'beam_sharp')
  end,
})
