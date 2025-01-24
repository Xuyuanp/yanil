local vim = vim
local api = vim.api

local validate = vim.validate

local iswin = vim.uv.os_uname().sysname == 'Windows_NT'

local M = {
    path_sep = iswin and '\\' or '/',
    ns_id = api.nvim_create_namespace('Yanil'),
}

---@class yani.Stack
---@field private head? table
local Stack = {}
Stack.__index = Stack

---@return yani.Stack
function Stack.new()
    return setmetatable({}, Stack)
end

function Stack:is_empty()
    return self.head == nil
end

function Stack:push(item)
    self.head = { next = self.head, value = item }
end

function Stack:pop()
    if self:is_empty() then
        return
    end

    local item = self.head.value
    self.head = self.head.next
    return item
end

M.Stack = Stack

function M.is_binary(path)
    validate({ path = { path, 'string' } })

    local output = vim.fn.system('file -binLN ' .. path)
    if vim.v.shell_error > 0 then
        vim.notify(string.format('check file %s mime encoding failed: %s', path, output), vim.log.levels.ERROR)
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
        t1 = { t1, 'table' },
        t2 = { t2, 'table' },
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
