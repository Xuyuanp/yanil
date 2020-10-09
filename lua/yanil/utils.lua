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

local M = {
    path_sep = loop.os_uname().sysname == "Windows" and "\\" or "/",
    ns_id = api.nvim_create_namespace("Yanil"),
    new_stack = new_stack,
}

return M
