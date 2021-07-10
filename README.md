# Format.nvim

format.nvim applies formatting to the current buffer.

Main goals

1. fast
2. async
3. no magic

## Details

format.nvim is a lua plugin and only works in Neovim.

It writes the buffer content into a temporary file, runs user defined commands
on that file, then writes the content back into the buffer.

Everything happens asynchronously.

There is no hidden configuration to resolve executables. The commands are run as
is. If you need a specific executable, define the path in the command.

By default unsaved changes will not be overwritten, so `Format` and `FormatWrite`
are safe to call anytime.

## Embedded syntax blocks.

format.nvim supports formatting embedded blocks of code with different
command than the current filetype. For example `lua << EOF` blocks in
vimscript, or code blocks in markdown.
Just specify a start and end-pattern.

## Format on save

There is no format on save functionality build in, the plugin only provides the
`Format` and `FormatWrite` commands.
To format on save, you can put this in your `vimrc`

```vimscript
augroup Format
    autocmd!
    autocmd BufWritePost * FormatWrite
augroup END
```

## Example configuration

Please see `:help format.txt` for more information on configuration.

````lua
require "format".setup {
    ["*"] = {
        {cmd = {"sed -i 's/[ \t]*$//'"}} -- remove trailing whitespace
    },
    vim = {
        {
            cmd = {"luafmt -w replace"},
            start_pattern = "^lua << EOF$",
            end_pattern = "^EOF$"
        }
    },
    vimwiki = {
        {
            cmd = {"prettier -w --parser babel"},
            start_pattern = "^{{{javascript$",
            end_pattern = "^}}}$"
        }
    },
    lua = {
        {
            cmd = {
                function(file)
                    return string.format("luafmt -l %s -w replace %s", vim.bo.textwidth, file)
                end
            }
        }
    },
    go = {
        {
            cmd = {"gofmt -w", "goimports -w"},
            tempfile_postfix = ".tmp"
        }
    },
    javascript = {
        {cmd = {"prettier -w", "./node_modules/.bin/eslint --fix"}}
    },
    markdown = {
        {cmd = {"prettier -w"}},
        {
            cmd = {"black"},
            start_pattern = "^```python$",
            end_pattern = "^```$",
            target = "current"
        }
    }
}
````

## Mentions

At first this was supposed to be a PR to [mhartington/formatter.nvim](https://github.com/mhartington/formatter.nvim)
but I ended up rewriting everything.
