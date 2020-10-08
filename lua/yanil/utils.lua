local vim = vim
local api = vim.api
local loop = vim.loop

local M = {
    path_sep = loop.os_uname().sysname == "Windows" and "\\" or "/",
    ns_id = api.nvim_create_namespace("Yanil"),
}

return M
