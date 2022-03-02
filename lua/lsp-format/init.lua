local M = {
    format_options = {},
    disabled = false,
    disabled_filetypes = {},
}

M.setup = function(format_options)
    M.format_options = vim.tbl_deep_extend("force", M.format_options, format_options or {})

    vim.cmd [[command! -nargs=* -bar Format lua require'lsp-format'.format("<args>")]]
    vim.cmd [[command! -nargs=? -complete=filetype -bar FormatToggle lua require'lsp-format'.toggle(<q-args>)]]
    vim.cmd [[command! -nargs=? -complete=filetype -bar FormatDisable lua require'lsp-format'.disable(<q-args>)]]
    vim.cmd [[command! -nargs=? -complete=filetype -bar -bang FormatEnable lua require'lsp-format'.enable(<q-args>, "<bang>" == "!")]]

    vim.lsp.handlers["textDocument/formatting"] = function(err, result, ctx)
        if err ~= nil then
            vim.api.nvim_err_write(err)
            return
        end
        if result == nil then
            return
        end
        if
            vim.api.nvim_buf_get_var(ctx.bufnr, "format_changedtick")
            == vim.api.nvim_buf_get_var(ctx.bufnr, "changedtick")
        then
            local view = vim.fn.winsaveview()
            vim.lsp.util.apply_text_edits(result, ctx.bufnr, "utf-16")
            vim.fn.winrestview(view)
            if ctx.bufnr == vim.api.nvim_get_current_buf() then
                vim.b.format_saving = true
                vim.cmd [[update]]
                vim.b.format_saving = false
            end
        end
    end
end

M.format = function(format_options_string)
    local format_options = {}
    for _, option in ipairs(vim.split(format_options_string or "", " ")) do
        local key, value = unpack(vim.split(option, "="))
        format_options[key] = value or true
    end
    if not vim.b.format_saving and not M.disabled and not M.disabled_filetypes[vim.bo.filetype] then
        vim.b.format_changedtick = vim.b.changedtick
        vim.lsp.buf.formatting((format_options_string and format_options) or M.format_options[vim.bo.filetype] or {})
    end
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
    if client.resolved_capabilities.document_formatting then
        vim.cmd [[
            augroup Format
            autocmd! * <buffer>
            autocmd BufWritePost <buffer> lua require'lsp-format'.format()
            augroup END
        ]]
    end
end

return M
