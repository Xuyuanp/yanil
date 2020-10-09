local vim = vim

local utils = require("yanil/utils")
local path_sep = utils.path_sep

local get_devicon = vim.fn.WebDevIconsGetFileTypeSymbol

local M = {}

function M.default(node)
    local text = node.name
    local hl_group = "YanilTreeFile"
    if node:is_dir() then
        if not vim.endswith(text, path_sep) then
            text = text .. path_sep
        end
        if not node.parent then
            hl_group = "YanilTreeRoot"
        else
            hl_group = node:is_link() and "YanilTreeLink" or "YanilTreeDirectory"
        end
    else
        if node:is_link() then
            hl_group = node:is_broken() and "YanilTreeLinkBroken" or "YanilTreeLink"
        elseif node.is_exec then
            hl_group = "YanilTreeFileExecutable"
        end
    end

    return text, hl_group
end

function M.link_to(node)
    if not node:is_link() then return end

    local text = string.format(" -> %s", node.link_to)
    local hls = {
        {
            col_start = 1,
            col_end = 3,
            hl_group = "YanilTreeLinkArrow",
        },
        {
            col_start = 4,
            col_end = text:len(),
            hl_group = "YanilTreeLinkTo",
        },
    }
    return text, hls
end

function M.executable(node)
    if node:is_dir() or not node.is_exec then return end
    local text = "*"
    return text, "YanilTreeFileExecutable"
end

function M.readonly(node)
    if not node.is_readonly then return end
    return " "
end

function M.devicons(node)
    if not node.parent then return end
    if node:is_dir() then
        local text = string.format("%s ", node.is_open and "" or "")
        return text, node:is_link() and "YanilTreeLink" or "YanilTreeDirectory"
    end

    -- TODO: add highlight
    return get_devicon(node.name) .. " "
end

function M.plain_indent(node)
    return string.rep("  ", node.depth)
end

local function pretty_prefix(node)
    if not node.parent then return "" end
    if node == node.parent:get_last_entry() then
        return pretty_prefix(node.parent) .. "   "
    end
    return pretty_prefix(node.parent) .. "│  "
end

function M.pretty_indent(node)
    if not node.parent then return end

    local prefix = pretty_prefix(node.parent)
    local indent = node == node.parent:get_last_entry() and "└╴ " or (node:is_dir() and "├╴ " or "│  ")
    local text = prefix .. indent
    return text, "SpecialComment"
end

-- for debuging
function M.random(_)
    return string.format("%d ", math.random(9))
end

return M
