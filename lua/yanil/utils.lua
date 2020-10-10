local vim = vim
local api = vim.api
local loop = vim.loop

local function new_stack()
    local head = { next = nil }

    local stack = {}

    function stack:is_empty()
        return head.next == nil
    end

    function stack:push(item)
        local o = { next = head.next, value = item }
        head.next =  o
    end

    function stack:pop()
        if stack:is_empty() then return end

        local item = head.next.value
        head.next = head.next.next
        return item
    end

    return stack
end

local function spawn(path, options, callback)
    local stdout = loop.new_pipe(false)
    local stderr = loop.new_pipe(false)

    local stdout_chunk, stderr_chunk

    local handle
    handle = loop.spawn(path, vim.tbl_deep_extend("keep", options, {
        stdio = {nil, stdout, stderr},
    }), function(code, signal)
        callback(code, signal, stdout_chunk, stderr_chunk)
        handle:close()
    end)

    stdout:read_start(function(err, data)
        assert(not err, err)
        if not data then return end
        stdout_chunk = (stdout_chunk or "") .. data
    end)
    stderr:read_start(function(err, data)
        assert(not err, err)
        if not data then return end
        stderr_chunk = (stderr_chunk or "") .. data
    end)
end

local M = {
    path_sep = loop.os_uname().sysname == "Windows" and "\\" or "/",
    ns_id = api.nvim_create_namespace("Yanil"),
    new_stack = new_stack,
    spawn = spawn,
}

return M
