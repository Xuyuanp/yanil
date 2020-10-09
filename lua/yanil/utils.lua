local vim = vim
local api = vim.api
local loop = vim.loop

local Stack = {}

function Stack:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Stack:is_empty()
    return vim.tbl_isempty(self)
end

function Stack:push(item)
    table.insert(self, item)
end

function Stack:pop()
    if self:is_empty() then return end
    local size = #self
    local item = self[size]
    table.remove(self, size)
    return item
end

local M = {
    path_sep = loop.os_uname().sysname == "Windows" and "\\" or "/",
    ns_id = api.nvim_create_namespace("Yanil"),
    Stack = Stack,
}

return M
