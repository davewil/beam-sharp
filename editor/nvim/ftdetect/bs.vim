" Neovim 0.12 ships `.bs` as `brighterscript`. `set filetype=` (not
" `setfiletype`) overrides that; in neovim, `plugin/beam_sharp.lua` also claims
" the extension through `vim.filetype.add`, which wins before this runs.
autocmd BufRead,BufNewFile *.bs set filetype=bs

" beam-sharp has no statement terminator and no block delimiters, so indentation
" carries the reading even though nothing in the grammar depends on it. Four
" spaces is what every file in `compiler/examples/` uses.
autocmd FileType bs setlocal expandtab shiftwidth=4 softtabstop=4 commentstring=//\ %s
