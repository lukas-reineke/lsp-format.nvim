# LSP-format.nvim

LSP-format.nvim is a wrapper around Neovims native LSP formatting.

It does

1. Asynchronously formats on save
2. Adds commands to disable formatting (globally or per filetype)
3. Makes it easier to send format options to the LSP

It does not

1. _Provide any formatting by itself._ You still need to use an LSP server

## Install

Use your favourite plugin manager to install.

#### Example with Packer

[wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- init.lua
require("packer").startup(
    function()
        use "lukas-reineke/lsp-format.nvim"
    end
)
```

#### Example with Plug

[junegunn/vim-plug](https://github.com/junegunn/vim-plug)

```vim
" init.vim
call plug#begin('~/.vim/plugged')
Plug 'lukas-reineke/lsp-format.nvim'
call plug#end()
```

## Setup

To use LSP-format, you have to run the setup function, and pass the `on_attach` function to each LSP that should use it.

```lua
require("lsp-format").setup {}
require "lspconfig".gopls.setup { on_attach = require "lsp-format".on_attach }
```

or

```lua
require("lsp-format").setup {}

local on_attach = function(client)
    require "lsp-format".on_attach(client)

    -- ... custom code ...
end
require "lspconfig".gopls.setup { on_attach = on_attach }
```

## FAQ

### How is it different to `autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()`?

The main difference is that LSP-format.nvim is async. It will format on save, _without blocking the editor_.  
And it adds some convenience with disable commands and format options.  
But the end result is the same.

### How do I use format options?

You can pass the format options into the `setup` function, or as arguments to the `:Format` command.  
How the format options look like depends on the LSP server you are using.

As an example, [mattn/efm-langserver](https://github.com/mattn/efm-langserver) uses `${}` template syntax with which you can
define your own options `${--flag:lua_variable_name}`.

```lua
require "lsp-format".setup {
    typescript = { tab_width = 4 },
    yaml = { tab_width = 2 },
}
local prettier = {
    formatCommand = [[prettier --stdin-filepath ${INPUT} ${--tab-width:tab_width}]],
    formatStdin = true,
}
require "lspconfig".efm.setup {
    on_attach = require "lsp-format".on_attach,
    init_options = { documentFormatting = true },
    settings = {
        languages = {
            typescript = { prettier },
            yaml = { prettier },
        },
    },
}
```

Now Typescript gets formatted with 4 and YAML with 2 spaces by default.  
And you can run `:Format tab_width=8` to overwrite the setting and format with 8 spaces.

