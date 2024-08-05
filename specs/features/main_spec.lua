assert = require "luassert"
local mock = require "luassert.mock"
local match = require "luassert.match"
local spy = require "luassert.spy"
local f = require "lsp-format"

local mock_client = {
    id = 1,
    name = "lsp-client-test",
    request = function(_, _, _, _) end,
    request_sync = function(_, _, _, _) end,
    supports_method = function(_) end,
    setup = function() end,
}

---@diagnostic disable-next-line
vim.lsp.get_clients = function(options)
    f.buffers[options.bufnr] = { mock_client.id }
    return { mock_client }
end

describe("lsp-format", function()
    local c
    local api

    before_each(function()
        c = mock(mock_client, true)
        api = mock(vim.api)
        c.supports_method = function(_, _)
            return true
        end
        f.setup {}
        f.on_attach(c)
    end)

    after_each(function()
        mock.revert(c)
        mock.revert(api)
    end)

    it("sends a valid format request", function()
        f.format { buf = 1 }
        assert.stub(c.request).was_called(1)
        assert.stub(c.request).was_called_with("textDocument/formatting", {
            options = {
                insertSpaces = false,
                tabSize = 8,
            },
            textDocument = {
                uri = "file://",
            },
        }, match.is_not_nil(), 1)
    end)

    it("FormatToggle prevent/allow formatting", function()
        f.toggle { args = "" }
        f.format { buf = 1 }
        assert.stub(c.request).was_called(0)

        f.toggle { args = "" }
        f.format { buf = 1 }
        assert.stub(c.request).was_called(1)
    end)

    it("FormatDisable/Enable prevent/allow formatting", function()
        f.disable { args = "" }
        f.format { buf = 1 }
        assert.stub(c.request).was_called(0)

        f.enable { args = "" }
        f.format { buf = 1 }
        assert.stub(c.request).was_called(1)
    end)

    it("sends default format options", function()
        f.setup {
            lua = {
                bool_test = true,
                int_test = 1,
                string_test = "string",
            },
        }
        vim.bo.filetype = "lua"
        f.format { buf = 1 }
        assert.stub(c.request).was_called(1)
        assert.stub(c.request).was_called_with("textDocument/formatting", {
            options = {
                insertSpaces = false,
                tabSize = 8,
                bool_test = true,
                int_test = 1,
                string_test = "string",
            },
            textDocument = {
                uri = "file://",
            },
        }, match.is_not_nil(), 1)
    end)

    it("sends format options", function()
        f.format {
            buf = 1,
            fargs = { "bool_test", "int_test=1", "string_test=string" },
        }
        assert.stub(c.request).was_called(1)
        assert.stub(c.request).was_called_with("textDocument/formatting", {
            options = {
                insertSpaces = false,
                tabSize = 8,
                bool_test = true,
                int_test = 1,
                string_test = "string",
            },
            textDocument = {
                uri = "file://",
            },
        }, match.is_not_nil(), 1)
    end)

    it("overwrites default format options", function()
        f.setup {
            lua = {
                bool_test = true,
                int_test = 1,
                string_test = "string",
            },
        }
        vim.bo.filetype = "lua"
        f.format {
            buf = 1,
            fargs = { "bool_test=false", "int_test=2", "string_test=another_string" },
        }
        assert.stub(c.request).was_called(1)
        assert.stub(c.request).was_called_with("textDocument/formatting", {
            options = {
                insertSpaces = false,
                tabSize = 8,
                bool_test = false,
                int_test = 2,
                string_test = "another_string",
            },
            textDocument = {
                uri = "file://",
            },
        }, match.is_not_nil(), 1)
    end)

    it("does not overwrite changes", function()
        local apply_text_edits = spy.on(vim.lsp.util, "apply_text_edits")
        c.request = function(_, params, handler, bufnr)
            api.nvim_buf_get_var = function(_, var)
                if var == "format_changedtick" then
                    return 9999
                end
                return 1
            end
            handler(nil, {}, { bufnr = bufnr, params = params })
        end
        f.format { buf = 1 }
        assert.spy(apply_text_edits).was.called(0)
    end)

    it("does overwrite changes with force", function()
        local apply_text_edits = spy.on(vim.lsp.util, "apply_text_edits")
        c.request = function(_, params, handler, bufnr)
            api.nvim_buf_get_var = function(_, var)
                if var == "format_changedtick" then
                    return 9999
                end
                return 1
            end
            handler(nil, {}, { bufnr = bufnr, params = params })
        end
        f.format { buf = 1, fargs = { "force=true" } }
        assert.spy(apply_text_edits).was.called(1)
    end)

    it("does not overwrite when in insert mode", function()
        local apply_text_edits = spy.on(vim.lsp.util, "apply_text_edits")
        c.request = function(_, params, handler, bufnr)
            api.nvim_get_mode = function()
                return "insert"
            end
            handler(nil, {}, { bufnr = bufnr, params = params })
        end
        f.format { buf = 1 }
        assert.spy(apply_text_edits).was.called(0)
    end)

    it("does overwrite when in insert mode with force", function()
        local apply_text_edits = spy.on(vim.lsp.util, "apply_text_edits")
        c.request = function(_, params, handler, bufnr)
            api.nvim_get_mode = function()
                return "insert"
            end
            handler(nil, {}, { bufnr = bufnr, params = params })
        end
        f.format { buf = 1, fargs = { "force=true" } }
        assert.spy(apply_text_edits).was.called(1)
    end)
end)
