local M = {}

function expand_cmd(cmd, tempfile_name)
    local error, result = pcall(cmd, tempfile_name)
    if error then
        return result
    end
    return string.format("%s %s", cmd, tempfile_name)
end

function M.format(cmd, options, callback)
    options.startline = options.startline - 1
    cmd = {unpack(cmd)}

    local bufname = vim.fn.bufname(options.bufnr)
    local lines = vim.api.nvim_buf_get_lines(options.bufnr, options.startline, options.endline, true)
    local split_bufname = vim.split(bufname, "/")
    local tempfile_prefix = options.tempfile_prefix or "~formatting"
    local tempfile_postfix = options.tempfile_postfix or ""
    local filename =
        string.format(
        "%s_%d-%d_%d_%s%s",
        tempfile_prefix,
        options.startline,
        options.endline,
        math.random(1, 1000000),
        split_bufname[#split_bufname],
        tempfile_postfix
    )
    split_bufname[#split_bufname] = nil
    local tempfile_dir = table.concat(split_bufname, "/")
    if tempfile_dir == "" then
        tempfile_dir = "."
    end
    local tempfile_name = (options.tempfile_dir or tempfile_dir) .. "/" .. filename

    local tempfile = io.open(tempfile_name, "w+")
    for _, line in pairs(lines) do
        tempfile:write(line)
        tempfile:write("\n")
    end
    tempfile:flush()
    tempfile:close()

    local F = {}

    function F.done()
        local tempfile = io.open(tempfile_name, "r")
        if tempfile == nil then
            if vim.g.format_debug then
                print("Format error: could not open tempfile")
            end
            return
        end
        local lines = {}
        for line in tempfile:lines() do
            table.insert(lines, line)
        end
        tempfile:close()
        os.remove(tempfile_name)
        if (not vim.bo.modified or options.force) and options.bufnr == vim.api.nvim_get_current_buf() then
            local view = vim.fn.winsaveview()
            options.undojoin()
            vim.api.nvim_buf_set_lines(options.bufnr, options.startline, options.endline, true, lines)
            if options.write then
                vim.g.format_writing = true
                vim.api.nvim_command(string.format("update %s", bufname))
                vim.g.format_writing = false
            end
            vim.fn.winrestview(view)
            callback()
        end
    end

    function F.on_event(job_id, data, event)
        if vim.g.format_debug then
            print(string.format("Format event %s: %s %s", job_id, event, vim.inspect(data)))
        end
        if event == "exit" then
            if #cmd > 0 then
                F.run_job(table.remove(cmd, 1))
            else
                F.done()
            end
        end
    end

    function F.run_job(cmd)
        local job = expand_cmd(cmd, tempfile_name)
        local job_id =
            vim.fn.jobstart(
            job,
            {
                on_stderr = F.on_event,
                on_stdout = F.on_event,
                on_exit = F.on_event,
                stdout_buffered = true,
                stderr_buffered = true
            }
        )
        if vim.g.format_debug then
            print(string.format('Format started job %s: "%s"', job_id, job))
        end
    end

    return F.run_job(table.remove(cmd, 1))
end

return M
