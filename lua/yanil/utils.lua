local vim = vim
local api = vim.api
local loop = vim.loop

local validate = vim.validate

local M = {
    path_sep = loop.os_uname().sysname == "Windows" and "\\" or "/",
    ns_id = api.nvim_create_namespace("Yanil"),

    callbacks = {}
}

function M.new_stack()
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

function M.spawn(path, options, callback)
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

function M.is_binary(path)
    validate { path = {path, "string"} }

    local output = vim.fn.system("file --mime-encoding " .. path)
    if vim.v.shell_error > 0 then
        api.nvim_err_writeln(string.format("check file %s mime encoding failed: %s", path, output))
        return
    end

    return output:find("binary") ~= nil
end

function M.callback(key, ...)
    if not M.callbacks[key] then return end
    M.callbacks[key](...)
end

function M.register_callback(key, callback)
    validate {
        key = {key, "s"},
        callback = {callback, "f"}
    }
    M.callbacks[key] = callback
end

function M.buf_set_keymap(bufnr, mode, key, callback, opts)
    opts = vim.tbl_extend("force", {
        silent = false,
        noremap = false,
        nowait = true,
    }, opts or {})
    local callback_id = string.format("%d-%s-%s", bufnr, mode, key:gsub("<", ""):gsub(">", ""))
    M.register_callback(callback_id, callback)
    api.nvim_buf_set_keymap(bufnr, mode, key, string.format([[<cmd>lua require("yanil/utils").callback("%s")<CR>]], callback_id), opts)
end

return M
