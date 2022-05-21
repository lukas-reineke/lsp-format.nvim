set rtp-=~/.config/nvim
set rtp-=~/.local/share/nvim/site
set rtp+=.
set noswapfile

let $lsp_format = getcwd()
let $specs = getcwd() .. "/specs"
let $vendor = getcwd() .. "/vendor"

set rtp+=$lsp_format,$specs
set packpath=$vendor

packloadall
