local log = require "vim.lsp.log"

local M = {
    format_options = {},
    disabled = false,
    disabled_filetypes = {},
    saving_buffers = {},
    queue = {},
    buffers = {},
}

local method = "textDocument/formatting"

---@param bufnr number
local get_filetypes = function(bufnr)
    return vim.split(
        vim.api.nvim_get_option_value("filetype", { buf = bufnr }),
        ".",
        { plain = true, trimempty = true }
    )
end

---@param bufnr number
local filetype_format_options = function(bufnr)
    local format_options = {}
    for _, filetype in ipairs(get_filetypes(bufnr)) do
        if M.format_options[filetype] then
            format_options = vim.tbl_deep_extend("keep", format_options, M.format_options[filetype])
        end
    end
    return format_options
end

---@param format_options? table
M.setup = function(format_options)
    M.format_options = vim.tbl_deep_extend("force", M.format_options, format_options or {})

    vim.api.nvim_create_user_command("Format", function(args)
        args.buf = vim.api.nvim_get_current_buf()
        M.format(args)
    end, { nargs = "*", bar = true, force = true })
    vim.api.nvim_create_user_command(
        "FormatToggle",
        M.toggle,
        { nargs = "?", bar = true, complete = "filetype", force = true }
    )
    vim.api.nvim_create_user_command(
        "FormatDisable",
        M.disable,
        { nargs = "?", bar = true, complete = "filetype", force = true }
    )
    vim.api.nvim_create_user_command(
        "FormatEnable",
        M.enable,
        { nargs = "?", bar = true, complete = "filetype", force = true, bang = true }
    )
end

---@param key string
---@param value? string
---@return boolean|number|string|string[]
local parse_value = function(key, value)
    if not value then
        return true
    end
    if key == "order" or key == "exclude" then
        return vim.split(value, ",")
    end
    local int_value = tonumber(value)
    if int_value then
        return int_value
    end
    if value == "false" then
        return false
    end
    if value == "true" then
        return true
    end

    return value
end

---@param bufnr number
---@param options lsp.FormattingOptions
---@return lsp.DocumentFormattingParams
local function make_formatting_params(bufnr, options)
    local tabSize = vim.lsp.util.get_effective_tabstop(bufnr)
    local expandtab = vim.api.nvim_get_option_value("expandtab", { buf = bufnr })
    return {
        textDocument = { uri = vim.uri_from_bufnr(bufnr) },
        options = vim.tbl_extend("keep", options, { tabSize = tabSize, insertSpaces = expandtab }),
    }
end

---@param options table
M.format = function(options)
    local bufnr = options.buf
    if M.saving_buffers[bufnr] or M.disabled then
        return
    end

    for _, filetype in ipairs(get_filetypes(bufnr)) do
        if M.disabled_filetypes[filetype] then
            return
        end
    end
    local format_options = filetype_format_options(bufnr)

    for key, option in pairs(format_options) do
        if type(option) == "function" then
            format_options[key] = option()
        end
    end
    for _, option in ipairs(options.fargs or {}) do
        local key, value = unpack(vim.split(option, "="))
        format_options[key] = parse_value(key, value)
    end

    local get_clients = vim.lsp.get_clients
    if not get_clients then
        ---@diagnostic disable-next-line: deprecated
        get_clients = vim.lsp.get_active_clients
    end

    local clients = {}
    for _, client in ipairs(get_clients { bufnr = bufnr }) do
        if
            client
            and not vim.tbl_contains(format_options.exclude or {}, client.name)
            and vim.tbl_contains(M.buffers[bufnr] or {}, client.id)
        then
            table.insert(clients, client)
        end
    end

    for _, client_name in pairs(format_options.order or {}) do
        for i, client in pairs(clients) do
            if client.name == client_name then
                table.insert(clients, table.remove(clients, i))
                break
            end
        end
    end

    if #clients > 0 then
        table.insert(M.queue, { bufnr = bufnr, clients = clients, format_options = format_options })
        M._next()
    end
end

---@param options table
M.disable = function(options)
    if options.args == "" then
        M.disabled = true
    else
        M.disabled_filetypes[options.args] = true
    end
end

---@param options table
M.enable = function(options)
    if options.bang then
        M.disabled_filetypes = {}
        M.disabled = false
    elseif options.args == "" then
        M.disabled = false
    else
        M.disabled_filetypes[options.args] = false
    end
end

---@param options table
M.toggle = function(options)
    if options.args == "" then
        M.disabled = not M.disabled
    else
        M.disabled_filetypes[options.args] = not M.disabled_filetypes[options.args]
    end
end

---@param client vim.lsp.Client
---@param bufnr? number
M.on_attach = function(client, bufnr)
    if not bufnr then
        bufnr = vim.api.nvim_get_current_buf()
    end
    if M.buffers[bufnr] == nil then
        M.buffers[bufnr] = {}
    end
    table.insert(M.buffers[bufnr], client.id)
    local format_options = filetype_format_options(bufnr)

    local event = "BufWritePost"
    if format_options.sync then
        event = "BufWritePre"
    end

    local group = vim.api.nvim_create_augroup("Format", { clear = false })

    vim.api.nvim_clear_autocmds {
        buffer = bufnr,
        group = group,
    }
    vim.api.nvim_create_autocmd(event, {
        group = group,
        desc = "Format on save",
        buffer = bufnr,
        callback = M.format,
    })
end

local handler = function(err, result, ctx)
    if err ~= nil then
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        local client_name = client and client.name or string.format("client_id=%d", ctx.client_id)
        log.error(string.format("%s: %d: %s", client_name, err.code, err.message))
        M._next()
        return
    end
    if result == nil then
        M._next()
        return
    end
    if vim.fn.bufexists(ctx.bufnr) == 0 then
        M._next()
        return
    end
    if not vim.api.nvim_buf_is_loaded(ctx.bufnr) then
        vim.fn.bufload(ctx.bufnr)
        vim.api.nvim_buf_set_var(ctx.bufnr, "format_changedtick", vim.api.nvim_buf_get_var(ctx.bufnr, "changedtick"))
    end
    if
        not ctx.params.options.force
        and (
            vim.api.nvim_buf_get_var(ctx.bufnr, "format_changedtick")
                ~= vim.api.nvim_buf_get_var(ctx.bufnr, "changedtick")
            or vim.startswith(vim.api.nvim_get_mode().mode, "i")
        )
    then
        M._next()
        return
    end

    vim.lsp.util.apply_text_edits(result, ctx.bufnr, "utf-16")
    if ctx.bufnr == vim.api.nvim_get_current_buf() then
        M.saving_buffers[ctx.bufnr] = true
        vim.cmd [[update]]
        M.saving_buffers[ctx.bufnr] = nil
    end
    M._next()
end

---@param bufnr number
---@param client vim.lsp.Client
---@param format_options table
local format = function(bufnr, client, format_options)
    if not client:supports_method(method, { bufnr = bufnr }) then
        log.warn(string.format('"%s" is not supported for %s, not formatting', method, client.name))
        return
    end
    vim.api.nvim_buf_set_var(bufnr, "format_changedtick", vim.api.nvim_buf_get_var(bufnr, "changedtick"))
    local params = make_formatting_params(bufnr, format_options)
    local timeout_ms = 2000
    if format_options.sync then
        ---@diagnostic disable-next-line
        local result = client:request_sync(method, params, timeout_ms, bufnr) or {}
        handler(result.err, result.result, { client_id = client.id, bufnr = bufnr, params = params })
    else
        client:request(method, params, handler, bufnr)
    end
end

M._next = function()
    local next = M.queue[1]
    if not next or #next.clients == 0 then
        return
    end
    local next_client = table.remove(next.clients, 1)
    format(next.bufnr, next_client, next.format_options)
    if #next.clients == 0 then
        table.remove(M.queue, 1)
    end
end

return M
