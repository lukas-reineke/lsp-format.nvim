local format = require("format.format").format
local M = {}

function M.format_all_embedded(current, options, line, step)
    local view = vim.fn.winsaveview()
    vim.fn.cursor(line, 1)
    local startline = vim.fn.search(current.start_pattern, "Wc")
    if startline == 0 then
        vim.fn.winrestview(view)
        step()
        return
    end
    local endline = vim.fn.search(current.end_pattern, "W")
    if endline == 0 then
        vim.fn.winrestview(view)
        step()
        return
    end

    options.startline = startline + 1
    options.endline = endline - 1

    local callback = function()
        M.format_all_embedded(current, options, options.endline, step)
    end

    format(current.cmd, options, callback)

    vim.fn.winrestview(view)
end

function M.format_embedded(current, options, step)
    local startline = vim.fn.search(current.start_pattern, "bnWc")
    local next_endline_up = vim.fn.search(current.end_pattern, "bnWc")
    local endline = vim.fn.search(current.end_pattern, "nW")

    if startline == 0 or endline == 0 or next_endline_up > startline then
        step()
        return
    end

    options.startline = startline + 1
    options.endline = endline - 1

    format(current.cmd, options, step)
end

return M
