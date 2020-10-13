local vim = vim
local api = vim.api

local M = {}

function M.setup()
    api.nvim_command([[command -nargs=? -complete=dir Yanil call luaeval('require("yanil/ui").startup(_A)', expand(<q-args>))]])
    api.nvim_command([[command YanilClose call luaeval('require("yanil/ui").close()')]])
    api.nvim_command([[command YanilToggle call luaeval('require("yanil/ui").toggle()')]])
end

return M
