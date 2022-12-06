# LSP-format.nvim

LSP-format.nvim is a wrapper around Neovims native LSP formatting.

It does

1. Asynchronous or synchronous formatting on save
2. Sequential formatting with all attached LSP server
3. Add commands for disabling formatting (globally or per filetype)
4. Make it easier to send format options to the LSP
5. Allow you to exclude specific LSP servers from formatting.

It does not

1. _Provide any formatting by itself._ You still need to use an LSP server

## Requirements

LSP-format requires Neovim 0.7 or newer.

## Install

Use your favourite plugin manager to install.

#### Example with Packer

[wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- init.lua
require("packer").startup(function()
    use "lukas-reineke/lsp-format.nvim"
end)
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
require("lspconfig").gopls.setup { on_attach = require("lsp-format").on_attach }
```

or

```lua
require("lsp-format").setup {}

local on_attach = function(client)
    require("lsp-format").on_attach(client)

    -- ... custom code ...
end
require("lspconfig").gopls.setup { on_attach = on_attach }
```

That's it, saving a buffer will format it now.

## Special format options

There are a couple special format options that LSP-format uses.

#### `exclude` format option

`exclude` is a table of LSP servers that should not format the buffer.

Alternatively, you can also just not call `on_attach` for the clients you don't want to use for
formatting.

#### `order` format option

`order` is a table that determines the order formatting is requested from the LSP server.

#### `sync` format option

`sync` turns on synchronous formatting. The editor will block until the formatting is done.

#### `force` format option

`force` will write the format result to the buffer, even if the buffer changed after the format request started.

#### `on_save` format option

`on_save` turns on formatting on save. Defaults to `true`. If set `false`, you can invoke `:Format` to format.

## Notes

#### Make sure you remove any old format on save code

You don't want to run formatting twice. If you had setup formatting on save before, remove it.  
You can check if something is listening on buffer write events with `:autocmd BufWritePre` and `:autocmd BufWritePost`

#### `:wq` will not format when not using `sync`

Because default formatting is async, you can't save and quit in the same command. The formatting results will not get back
in time and Neovim will close without applying the changes.  
In this case you need to use the `sync` format option.

Add this abbreviation into your dotfiles to do the right thing when doing `:wq`

```lua
vim.cmd [[cabbrev wq execute "Format sync" <bar> wq]]
```

## FAQ

### How is it different to `autocmd BufWritePre <buffer> lua vim.lsp.buf.format()`?

The main difference is that LSP-format.nvim is async by default. It will format on save, _without blocking the editor_.  
When the formatting is done, LSP-format.nvim will only change the buffer if it
didn't change since the time formatting was called.  
And it adds some convenience with disable commands and format options.  
But the end result is the same.

### How do I use format options?

You can pass the format options into the `setup` function, or as arguments to the `:Format` command.  
How the format options look like depends on the LSP server you are using.

The format options can either be string, number, boolean, or a function that
resolves to those.

As an example, [mattn/efm-langserver](https://github.com/mattn/efm-langserver) uses `${}` template syntax with which you can
define your own options `${--flag:lua_variable_name}`.

```lua
require("lsp-format").setup {
    typescript = {
        tab_width = function()
            return vim.opt.shiftwidth:get()
        end,
    },
    yaml = { tab_width = 2 },
}
local prettier = {
    formatCommand = [[prettier --stdin-filepath ${INPUT} ${--tab-width:tab_width}]],
    formatStdin = true,
}
require("lspconfig").efm.setup {
    on_attach = require("lsp-format").on_attach,
    init_options = { documentFormatting = true },
    settings = {
        languages = {
            typescript = { prettier },
            yaml = { prettier },
        },
    },
}
```

Now Typescript gets formatted with what `shiftwidth` is set to, and YAML with 2 spaces by default.  
And you can run `:Format tab_width=8` to overwrite the setting and format with 8 spaces.
