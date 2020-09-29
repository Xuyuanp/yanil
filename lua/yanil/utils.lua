local vim = vim
local loop = vim.loop

local M = {
    path_sep = loop.os_uname().sysname == "Windows" and "\\" or "/"
}

return M
