local vim = vim
local api = vim.api

local utils = require("yanil/utils")

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
    },
    highlights = {},
}

do
    for status, _ in pairs(default_options.icons) do
        default_options.highlights[status] = "YanilGit" .. status
    end
end

local M = {
    state = {},
    options = {}
}

function M.setup(opts)
    opts = opts or {}
    M.options.icons = vim.tbl_deep_extend("keep", opts.icons or {}, default_options.icons)
    M.options.highlights = vim.tbl_deep_extend("keep", opts.highlights or {}, default_options.highlights)
end

local delimiter = string.char(0)

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
    if not vim.endswith(cwd, utils.path_sep) then cwd = cwd .. utils.path_sep end

    local git_root

    local function status_callback(code, _signal, stdout, stderr)
        if code > 0 then
            print("git status failed:", stderr)
            return
        end

        local state = {}

        local lines = vim.split(stdout, delimiter)
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

            local abs_path = git_root .. path
            state[abs_path] = status
        end

        M.state = state

        vim.schedule(function()
            require("yanil/ui").refresh_ui()
        end)
    end

    local function root_callback(code, _signal, stdout, _stderr)
        if code > 0 then
            return
        end

        git_root = vim.trim(stdout) .. "/"

        utils.spawn("git", {
            args = {
                "status",
                "--porcelain=v2",
                "-z",
            },
            cwd = git_root,
        }, status_callback)
    end

    utils.spawn("git", {
        args = {
            "rev-parse",
            "--show-toplevel",
        },
        cwd = cwd,
    }, root_callback)
end

function M.get_icon_and_hl(path)
    local status = M.state[path]
    if not status then return end

    return M.options.icons[status], M.options.highlights[status]
end

function M.decorator()
    return function(node)
        local icon, hl = M.get_icon_and_hl(node.abs_path)
        if not icon then
            if node.parent then return "  " end
            return
        end

        local text = string.format("%s ", icon)
        return text, hl
    end
end

function M.debug()
    print(vim.inspect(M.state))
end

return M
