local vim = vim
local api = vim.api

local M = {}

function M.setup()
    api.nvim_command([[command -nargs=? -complete=dir Yanil call luaeval('require("yanil/ui").startup(_A)', expand(<q-args>))]])
end

return M
