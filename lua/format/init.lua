local format = require("format.format").format
local utils = require("format.utils")
local embedded = require("format.embedded")
local M = {}

function M.setup(config)
    M.config = config
end

function M.format(bang, write, startline, endline)
    xpcall(
        function()
            if vim.g.format_writing then
                return
            end
            local force = bang == "!"
            local filetype = vim.fn.eval("&filetype")
            local file_config = M.config[filetype] or {}
            local global_config = M.config["*"] or {}
            local config = utils.merge_config({global_config, file_config})
            local undojoin = utils.undojoin()
            local bufnr = vim.api.nvim_get_current_buf()

            function step()
                if #config == 0 then
                    return
                end
                current = table.remove(config, 1)

                local options = {
                    bufnr = bufnr,
                    force = force,
                    write = write,
                    startline = startline,
                    endline = endline,
                    tempfile_postfix = current.tempfile_postfix,
                    tempfile_prefix = current.tempfile_prefix,
                    tempfile_dir = current.tempfile_dir,
                    undojoin = undojoin
                }

                if current.cmd == nil then
                    step()
                elseif current.start_pattern == nil or current.end_pattern == nil then
                    format(current.cmd, options, step)
                elseif current.target ~= "current" then
                    embedded.format_all_embedded(current, options, 1, step)
                else
                    embedded.format_embedded(current, options, step)
                end
            end

            step()
        end,
        function(error)
            if vim.g.format_debug then
                print(string.format("Format error: %s", error))
            end
        end
    )
end

return M
