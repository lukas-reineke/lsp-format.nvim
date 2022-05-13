local mock = require "luassert.mock"
local match = require "luassert.match"
local f = require "lsp-format"

local mock_client = {
    id = 1,
    name = "lsp-client-test",
    request = function(_, _, _, _) end,
    request_sync = function(_, _, _, _) end,
    supports_method = function(_) end,
    setup = function() end,
}

vim.lsp.buf_get_clients = function()
    local clients = {}
    clients[mock_client.name] = mock_client
    return clients
end

describe("lsp-format", function()
    local c

    before_each(function()
        c = mock(mock_client, true)
        c.supports_method = function(_)
            return true
        end
        f.setup {}
        f.on_attach(c)
    end)

    after_each(function()
        mock.revert(c)
    end)

    it("sends a valid format request", function()
        f.format {}
        assert.stub(c.request).was_called(1)
        assert.stub(c.request).was_called_with("textDocument/formatting", {
            options = {
                insertSpaces = false,
                tabSize = 8,
            },
            textDocument = {
                uri = "file://",
            },
        }, match.is_ref(f._handler), 1)
    end)

    it("FormatToggle prevent/allow formatting", function()
        f.toggle { args = "" }
        f.format {}
        assert.stub(c.request).was_called(0)

        f.toggle { args = "" }
        f.format {}
        assert.stub(c.request).was_called(1)
    end)

    it("FormatDisable/Enable prevent/allow formatting", function()
        f.disable { args = "" }
        f.format {}
        assert.stub(c.request).was_called(0)

        f.enable { args = "" }
        f.format {}
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
        f.format {}
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
        }, match.is_ref(f._handler), 1)
    end)

    it("sends format options", function()
        f.format {
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
        }, match.is_ref(f._handler), 1)
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
        }, match.is_ref(f._handler), 1)
    end)
end)
