local M = {
    format_options = {},
    disabled = false,
    disabled_filetypes = {},
    queue = {},
    buffers = {},
}

M.setup = function(format_options)
    M.format_options = vim.tbl_deep_extend("force", M.format_options, format_options or {})

    vim.cmd [[command! -nargs=* -bar Format lua require'lsp-format'.format("<args>")]]
    vim.cmd [[command! -nargs=? -complete=filetype -bar FormatToggle lua require'lsp-format'.toggle(<q-args>)]]
    vim.cmd [[command! -nargs=? -complete=filetype -bar FormatDisable lua require'lsp-format'.disable(<q-args>)]]
    vim.cmd [[command! -nargs=? -complete=filetype -bar -bang FormatEnable lua require'lsp-format'.enable(<q-args>, "<bang>" == "!")]]
end

M.format = function(format_options_string)
    if vim.b.format_saving or M.disabled or M.disabled_filetypes[vim.bo.filetype] then
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local format_options = M.format_options[vim.bo.filetype] or {}
    for _, option in ipairs(vim.split(format_options_string or "", " ")) do
        local key, value = unpack(vim.split(option, "="))
        if key == "order" or key == "exclude" then
            value = vim.split(value, ",")
        end
        format_options[key] = value or true
    end

    local clients = vim.tbl_values(vim.lsp.buf_get_clients())
    for i, client in pairs(clients) do
        if
            vim.tbl_contains(format_options.exclude or {}, client.name)
            or not vim.tbl_contains(M.buffers[bufnr] or {}, client.id)
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

    table.insert(M.queue, { bufnr = bufnr, clients = clients, format_options = format_options })

    M._next()
end

M.disable = function(filetype)
    if filetype == "" then
        M.disabled = true
    else
        M.disabled_filetypes[filetype] = true
    end
end

M.enable = function(filetype, bang)
    if bang then
        M.disabled_filetypes = {}
        M.disabled = false
    elseif filetype == "" then
        M.disabled = false
    else
        M.disabled_filetypes[filetype] = false
    end
end

M.toggle = function(filetype)
    if filetype == "" then
        M.disabled = not M.disabled
    else
        M.disabled_filetypes[filetype] = not M.disabled_filetypes[filetype]
    end
end

M.on_attach = function(client)
    local bufnr = vim.api.nvim_get_current_buf()
    if M.buffers[bufnr] == nil then
        M.buffers[bufnr] = {}
    end
    table.insert(M.buffers[bufnr], client.id)
    vim.cmd [[
        augroup Format
        autocmd! * <buffer>
        autocmd BufWritePost <buffer> lua require'lsp-format'.format()
        augroup END
    ]]
end

M._handler = function(err, result, ctx)
    if err ~= nil then
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        local client_name = client and client.name or string.format("client_id=%d", ctx.client_id)
        vim.api.nvim_err_write(string.format("%s: %d: %s", client_name, err.code, err.message))
        return
    end
    if
        result == nil
        or vim.api.nvim_buf_get_var(ctx.bufnr, "format_changedtick") ~= vim.api.nvim_buf_get_var(
            ctx.bufnr,
            "changedtick"
        )
        or vim.startswith(vim.api.nvim_get_mode().mode, "i")
    then
        return
    end

    local view = vim.fn.winsaveview()
    vim.lsp.util.apply_text_edits(result, ctx.bufnr, "utf-16")
    vim.fn.winrestview(view)
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
    client.request("textDocument/formatting", params, M._handler, bufnr)
end

M._next = function()
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
