local vim = vim
local api = vim.api

local M = {}

local default_mappings = {
    q = "close()",
    ["<CR>"] = "open_current_node()",
    c = "change_dir_to_current_node()",
    u = "change_dir_to_parent()",
    r = "refresh_current_node()",
    i = "open_current_node('split')",
    s = "open_current_node('vsplit')",
    gd = "git_diff()",
}

local action_template = "<cmd>lua require('yanil/ui').%s<CR>"

function M.setup(bufnr)
    for key, action in pairs(default_mappings) do
        api.nvim_buf_set_keymap(bufnr, "n", key, action_template:format(action), {
            nowait = true,
            noremap = false,
            silent = false,
        })
    end
end

return M
