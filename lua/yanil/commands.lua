local vim = vim
local api = vim.api

local M = {}

function M.setup()
    api.nvim_command([[command -nargs=? -complete=dir Yanil call luaeval('require("yanil.canvas").open(_A)', fnamemodify('<args>', ':p'))]])
    api.nvim_command([[command YanilClose call luaeval('require("yanil.canvas").close()')]])
    api.nvim_command([[command YanilToggle call luaeval('require("yanil.canvas").toggle()')]])
end

return M
