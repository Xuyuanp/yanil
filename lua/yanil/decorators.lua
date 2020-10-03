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
            hl_group = "YanilTreeDirectory",
        }
    elseif node:is_link() then
        local text = string.format("%s -> %s", node.name, node.link_to)
        local name_len = node.name:len()
        local hls = {
            {
                col_start = 0,
                col_end = name_len,
                hl_group = "YanilTreeLink",
            },
            {
                col_start = name_len + 1,
                col_end = name_len + 3,
                hl_group = "YanilTreeLinkArrow",
            },
            {
                col_start = name_len + 3,
                col_end = text:len(),
                hl_group = "YanilTreeLinkTo",
            },
        }
        return text, hls
    else
        local text = node.name
        local hls = {
            col_start = 0,
            col_end = text:len(),
            hl_group = node.is_exec and "YanilTreeFileExecutable" or "YanilTreeFile",
        }
        return text, hls
    end
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

function M.indent(node)
    return string.rep("  ", node.depth)
end

return M
