local vim = vim

local utils = require("yanil/utils")
local path_sep = utils.path_sep

local get_devicon = vim.fn.WebDevIconsGetFileTypeSymbol

local M = {}

function M.default(node)
    if node:is_dir() then
        local text = node.name .. path_sep
        return text, {
            col_start = 0,
            col_end = text:len(),
            hl_group = node.parent and "YanilTreeDirectory" or "YanilTreeRoot",
        }
    end

    local text = node.name
    local hls = {
        col_start = 0,
        col_end = text:len(),
        hl_group = node.is_exec and "YanilTreeFileExecutable" or "YanilTreeFile",
    }
    return text, hls
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

function M.devicons(node)
    if not node.parent then return end
    if node:is_dir() then
        local text = node.is_open and " " or " "
        return text, {
            col_start = 0,
            col_end = text:len() - 1,
            hl_group = "YanilTreeDirectory",
        }
    end

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
    local indent = node == node.parent:get_last_entry() and "└╴ " or "├╴ "
    local text = prefix .. indent
    return text, {
        col_start = 0,
        col_end = text:len(),
        hl_group = "SpecialComment"
    }
end

-- for debuging
function M.random(_)
    return string.format("%d ", math.random(9))
end

return M
