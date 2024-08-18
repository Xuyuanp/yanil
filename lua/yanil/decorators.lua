local vim = vim

local M = {}

function M.default(node)
    local text = node.name
    local hl_group = 'YanilTreeFile'
    if node:is_dir() then
        if not node.parent then
            text = vim.fn.pathshorten(vim.fn.fnamemodify(node.name, ':~:h'))
            hl_group = 'YanilTreeRoot'
        else
            hl_group = node:is_link() and 'YanilTreeLink' or 'YanilTreeDirectory'
        end
    else
        if node:is_link() then
            hl_group = node:is_broken() and 'YanilTreeLinkBroken' or 'YanilTreeLink'
        elseif node.is_exec then
            hl_group = 'YanilTreeFileExecutable'
        end
    end

    return text, hl_group
end

function M.link_to(node)
    if not node:is_link() then
        return
    end

    local text = string.format(' -> %s', node.link_to)
    local hls = {
        {
            col_start = 1,
            col_end = 3,
            hl_group = 'YanilTreeLinkArrow',
        },
        {
            col_start = 4,
            col_end = text:len(),
            hl_group = 'YanilTreeLinkTo',
        },
    }
    return text, hls
end

function M.executable(node)
    if node:is_dir() or not node.is_exec then
        return
    end
    local text = '*'
    return text, 'YanilTreeFileExecutable'
end

function M.readonly(node)
    if not node.is_readonly then
        return
    end
    return ' '
end

---@diagnostic disable-next-line: unused-local
function M.space(_node)
    return ' '
end

function M.plain_indent(node)
    return string.rep('  ', node.depth)
end

local function pretty_prefix(node)
    if not node.parent then
        return ''
    end
    if node == node.parent:get_last_entry() then
        return pretty_prefix(node.parent) .. '   '
    end
    return pretty_prefix(node.parent) .. '│  '
end

function M.pretty_indent(node)
    if not node.parent then
        return
    end

    local prefix = pretty_prefix(node.parent)
    local indent = node == node.parent:get_last_entry() and '└╴ ' or (node:is_dir() and '├╴ ' or '│  ')
    local text = prefix .. indent
    return text, 'SpecialComment'
end

function M.pretty_indent_with_git(node)
    local text, hl = M.pretty_indent(node)
    if not text then
        return
    end

    local hls = { {
        col_start = 0,
        col_end = text:len(),
        hl_group = hl,
    } }

    local git = require('yanil/git')
    local git_icon, git_hl = git.get_icon_and_hl(node.abs_path)
    if git_icon then
        local suffix_len = vim.endswith(text, '╴ ') and 4 or 2
        text = text:sub(0, -(suffix_len + 1)) .. git_icon .. ' '
        hls = {
            {
                col_start = 0,
                col_end = text:len() - git_icon:len() - 1,
                hl_group = hl,
            },
            {
                col_start = text:len() - git_icon:len() - 1,
                col_end = text:len() - 1,
                hl_group = git_hl,
            },
        }
    end
    return text, hls
end

-- for debugging
function M.random(_)
    return string.format('%d ', math.random(9))
end

return M
