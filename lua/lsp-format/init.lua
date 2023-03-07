local log = require "vim.lsp.log"

local M = {
    format_options = {},
    disabled = false,
    disabled_filetypes = {},
    queue = {},
    buffers = {},
}

M.setup = function(format_options)
    M.format_options = vim.tbl_deep_extend("force", M.format_options, format_options or {})

    vim.api.nvim_create_user_command("Format", M.format, { nargs = "*", bar = true, force = true })
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

M._parse_value = function(key, value)
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

M.format = function(options)
    if vim.b.format_saving or M.disabled or M.disabled_filetypes[vim.bo.filetype] then
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local format_options = vim.deepcopy(M.format_options[vim.bo.filetype] or {})
    for key, option in pairs(format_options) do
        if type(option) == "function" then
            format_options[key] = option()
        end
    end
    for _, option in ipairs(options.fargs or {}) do
        local key, value = unpack(vim.split(option, "="))
        format_options[key] = M._parse_value(key, value)
    end

    local clients = vim.tbl_values(vim.lsp.buf_get_clients())
    for i = #clients, 1, -1 do
        if
            vim.tbl_contains(format_options.exclude or {}, clients[i].name)
            or not vim.tbl_contains(M.buffers[bufnr] or {}, clients[i].id)
        then
            table.remove(clients, i)
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

M.disable = function(options)
    if options.args == "" then
        M.disabled = true
    else
        M.disabled_filetypes[options.args] = true
    end
end

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

M.toggle = function(options)
    if options.args == "" then
        M.disabled = not M.disabled
    else
        M.disabled_filetypes[options.args] = not M.disabled_filetypes[options.args]
    end
end

M.on_attach = function(client)
    if not client.supports_method "textDocument/formatting" then
        log.warn(
            string.format('"textDocument/formatting" is not supported for %s, not attaching lsp-format', client.name)
        )
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    if M.buffers[bufnr] == nil then
        M.buffers[bufnr] = {}
    end
    table.insert(M.buffers[bufnr], client.id)
    local format_options = M.format_options[vim.bo.filetype] or {}

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
        desc = "format on save",
        pattern = "<buffer>",
        callback = M.format,
    })
end

M._handler = function(err, result, ctx)
    -- load buffer if not active
    if not vim.api.nvim_buf_is_loaded(ctx.bufnr) then
        vim.fn.bufload(ctx.bufnr)
        vim.api.nvim_buf_set_var(ctx.bufnr, "format_changedtick", vim.api.nvim_buf_get_var(ctx.bufnr, "changedtick"))
    end

    -- check if buffer was modified
    local buffer_modified = (
        vim.api.nvim_buf_get_var(ctx.bufnr, "format_changedtick")
        ~= vim.api.nvim_buf_get_var(ctx.bufnr, "changedtick")
    )
    vim.api.nvim_buf_del_var(ctx.bufnr, "format_changedtick")

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
    if not ctx.params.options.force and (buffer_modified or vim.startswith(vim.api.nvim_get_mode().mode, "i")) then
        M._next()
        return
    end

    vim.lsp.util.apply_text_edits(result, ctx.bufnr, "utf-16")
    if ctx.bufnr == vim.api.nvim_get_current_buf() then
        vim.b.format_saving = true
        vim.cmd [[update]]
        vim.b.format_saving = false
    end
    M._next()
end

M._format = function(bufnr, client, format_options)
    vim.b.format_changedtick = vim.b.changedtick
    local params = vim.lsp.util.make_formatting_params(format_options)
    local method = "textDocument/formatting"
    local timeout_ms = 2000
    if format_options.sync then
        local result = client.request_sync(method, params, timeout_ms, bufnr) or {}
        M._handler(result.err, result.result, { client_id = client.id, bufnr = bufnr, params = params })
    else
        client.request(method, params, M._handler, bufnr)
    end
end

M._next = function()
    -- if there are format process running, wait for it to finish
    if vim.b.format_changedtick then
        return
    end

    local next = M.queue[1]
    if not next or #next.clients == 0 then
        return
    end
    local next_client = table.remove(next.clients, 1)
    M._format(next.bufnr, next_client, next.format_options)
    if #next.clients == 0 then
        table.remove(M.queue, 1)
    end
end

return M
