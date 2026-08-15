" `.bs` is not claimed by any filetype shipped with vim or neovim, so this is an
" unqualified association rather than a guess that might override something.
autocmd BufRead,BufNewFile *.bs set filetype=bs

" beam-sharp has no statement terminator and no block delimiters, so indentation
" carries the reading even though nothing in the grammar depends on it. Four
" spaces is what every file in `compiler/examples/` uses.
autocmd FileType bs setlocal expandtab shiftwidth=4 softtabstop=4 commentstring=//\ %s
