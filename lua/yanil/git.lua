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

    api.nvim_command("augroup yanil_git")
    api.nvim_command("autocmd!")
    api.nvim_command("autocmd BufWritePost * lua require('yanil/git').update()")
    api.nvim_command("augroup end")
end

local delimiter = string.char(0)

-- man git-status
-- X          Y     Meaning
-- -------------------------------------------------
--           [MD]   not updated
-- M        [ MD]   updated in index
-- A        [ MD]   added to index
-- D         [ M]   deleted from index
-- R        [ MD]   renamed in index
-- C        [ MD]   copied in index
-- [MARC]           index and work tree matches
-- [ MARC]     M    work tree changed since index
-- [ MARC]     D    deleted in work tree
local function get_status(x, y)
    if y == "M" then
        return "Modified"
    elseif x == "D" or y == "D" then
        return "Deleted"
    elseif x == "M" or x == "A" then
        return "Staged"
    else
        error(string.format("unexpected status %s%s", x, y))
    end
end

local parsers = {
    ["1"] = function(line)
        return get_status(line:sub(3, 3), line:sub(4, 4)), line:sub(114, -1)
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
    if not cwd then return end
    if not vim.endswith(cwd, utils.path_sep) then cwd = cwd .. utils.path_sep end

    local git_root

    local status_callback = vim.schedule_wrap(function(code, _signal, stdout, stderr)
        if code > 0 then
            api.nvim_err_writeln(string.format("git status failed: %s", stderr))
            return
        end

        local state = {}

        stdout = stdout or ""
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

            while vim.startswith(abs_path, git_root) do
                abs_path = vim.fn.fnamemodify(abs_path, ":h")
                local dir = abs_path .. utils.path_sep
                if state[dir] then break end
                state[dir] = "Dirty"
            end
        end

        M.state = state

        require("yanil/ui").refresh_ui()
    end)

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
