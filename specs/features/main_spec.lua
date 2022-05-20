local mock = require "luassert.mock"
local stub = require "luassert.stub"
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

local _test_file_path = "/tmp/lsp-format-test-file.txt"
local _text_edit_result = {
    {
        range = {
            start = { line = 0, character = 0 },
            ["end"] = { line = 0, character = 19 },
        },
        newText = "some formatted text",
    },
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

    describe("updating the buffer", function()
        local cmd_spy
        local get_mode = stub.new()

        before_each(function()
            vim.cmd(":write! " .. _test_file_path)
            cmd_spy = spy.on(vim, "cmd")
        end)

        after_each(function()
            cmd_spy.revert(cmd_spy)
            get_mode.revert(get_mode)
        end)

        it("updates the buffer", function()
            c.request = function(_, _, handler, bufnr)
                handler(nil, _text_edit_result, { bufnr = bufnr })
            end
            f.format {}
            assert.spy(cmd_spy).was.called(1)
            assert.spy(cmd_spy).was.called_with "update"
        end)

        it("doesn't update the buffer if entered insert mode", function()
            c.request = function(_, _, handler, bufnr)
                get_mode = stub.new(vim.api, "nvim_get_mode").returns { mode = "insert" }
                handler(nil, _text_edit_result, { bufnr = bufnr })
            end
            f.format {}
            assert.spy(cmd_spy).was.called(0)
            assert.spy(cmd_spy).was_not.called_with "update"
        end)

        it("formats from insert mode if forced to", function()
            f.setup({}, { prioritize_async_over_formatting = false })
            c.request = function(_, _, handler, bufnr)
                get_mode = stub.new(vim.api, "nvim_get_mode").returns { mode = "insert" }
                handler(nil, _text_edit_result, { bufnr = bufnr })
            end
            f.format {}
            assert.spy(cmd_spy).was.called(1)
            assert.spy(cmd_spy).was.called_with "update"
        end)
    end)
end)
