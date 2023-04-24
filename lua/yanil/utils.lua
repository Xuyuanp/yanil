local vim = vim
local api = vim.api
local loop = vim.loop

local validate = vim.validate

local iswin = vim.loop.os_uname().sysname == 'Windows_NT'

local M = {
    path_sep = iswin and '\\' or '/',
    ns_id = api.nvim_create_namespace('Yanil'),
}

function M.new_stack()
    local head = { next = nil }

    local stack = {}

    function stack:is_empty()
        return head.next == nil
    end

    function stack:push(item)
        local o = { next = head.next, value = item }
        head.next = o
    end

    function stack:pop()
        if stack:is_empty() then
            return
        end

        local item = head.next.value
        head.next = head.next.next
        return item
    end

    return stack
end

function M.spawn(path, options, callback)
    local stdout = loop.new_pipe(false)
    local stderr = loop.new_pipe(false)

    local stdout_chunk, stderr_chunk

    local handle
    handle = loop.spawn(
        path,
        vim.tbl_deep_extend('keep', options, {
            stdio = { nil, stdout, stderr },
        }),
        function(code, signal)
            pcall(callback, code, signal, stdout_chunk, stderr_chunk)
            handle:close()
            stdout:close()
            stderr:close()
        end
    )

    stdout:read_start(function(err, data)
        assert(not err, err)
        if not data then
            return
        end
        stdout_chunk = (stdout_chunk or '') .. data
    end)
    stderr:read_start(function(err, data)
        assert(not err, err)
        if not data then
            return
        end
        stderr_chunk = (stderr_chunk or '') .. data
    end)
end

function M.is_binary(path)
    validate({ path = { path, 'string' } })

    local output = vim.fn.system('file -binLN ' .. path)
    if vim.v.shell_error > 0 then
        api.nvim_err_writeln(string.format('check file %s mime encoding failed: %s', path, output))
        return
    end

    return output:find('x-empty') == nil and output:find('binary') ~= nil
end

function M.set_autocmds(group_name, autocmds)
    local group = api.nvim_create_augroup(group_name, { clear = true })

    for _, autocmd in ipairs(autocmds or {}) do
        api.nvim_create_autocmd(autocmd.event, {
            pattern = autocmd.pattern or 'Yanil',
            callback = autocmd.cmd,
            group = group,
        })
    end
end

function M.table_equal(t1, t2)
    validate({
        t1 = { t1, 't' },
        t2 = { t2, 't' },
    })
    if vim.tbl_count(t1) ~= vim.tbl_count(t2) then
        return false
    end

    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        local type1, type2 = type(v1), type(v2)
        if type1 ~= type2 then
            return false
        end

        if type1 == 'table' then
            if not M.table_equal(v1, t2) then
                return false
            end
        end

        if v1 ~= v2 then
            return false
        end
    end

    return true
end

return M
