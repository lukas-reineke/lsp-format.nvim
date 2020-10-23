
if exists('g:loaded_format') || !has('nvim-0.5.0')
    finish
endif
let g:loaded_format = 1

command! -bang -range=% Format lua require("format").format("<bang>", false, <line1>, <line2>)
command! -bang -range=% FormatWrite lua require("format").format("<bang>", true, <line1>, <line2>)

