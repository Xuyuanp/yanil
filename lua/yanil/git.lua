local vim = vim
local api = vim.api

local default_options = {
    icons = {
        Modified  = "",
        Staged    = "",
        Untracked = "",
        Renamed   = "",
        Unmerged  = "",
        Deleted   = "",
        Dirty     = "",
        Ignored   = "",
        Clean     = "",
        Unknown   = ""
    }
}

local M = {
    state = {},
    options = {}
}

function M.setup(opts)
    opts = opts or {}
    M.options.icons = vim.tbl_deep_extend("keep", opts.icons or {}, default_options.icons)
end

local delimiter = string.char(1)

local parsers = {
    ["1"] = function(line)
        return "Modified", line:sub(114, -1)
    end,
    ["2"] = function(line)
        return "Renamed", line:sub(114, -1)
    end,
    ["u"] = function(line)
        return "Unmerged", line:sub(162, -1)
    end,
    ["?"] = function(line)
        return "Untracked", line:sub(3, -1)
    end,
    ["!"] = function(line)
        return "Ignored", line:sub(3, -1)
    end,
}

function M.update()
    local cwd = require("yanil/ui").tree.cwd
    local result = vim.fn.system({
        "git",
        "-C", cwd,
        "status",
        "--porcelain=v2",
        "-z",
    })
    if vim.v.shell_error > 0 then
        api.nvim_err_writeln(string.format("execute git status failed: %s", result))
        return
    end
    local lines = vim.split(result, delimiter)

    local state = {}

    local is_rename = false
    for _, line in ipairs(lines) do
        if line == "" then break end

        local status, path
        if is_rename then
            status = "Dirty"
            path = line

            is_rename = false
        else
            local parser = parsers[line:sub(1, 1)]
            status, path = parser(line)

            is_rename = status == "Renamed"
        end

        local abs_path = vim.fn.fnamemodify(path, ":p")
        state[abs_path] = status
    end

    M.state = state
end

function M.decorator()
    return function(node)
        local status = M.state[node.abs_path]
        if not status then
            if node.parent then return "  " end
            return
        end

        local icon = M.options.icons[status]
        local text = string.format("%s ", icon)
        return text, "YanilGit" .. status
    end
end

return M
