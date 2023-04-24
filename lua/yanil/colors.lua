local vim = vim
local api = vim.api

local default_highlight = {
    Tree = {
        Root = 'Tag',
        Directory = 'Green',
        File = 'Normal',
        FileExecutable = 'Keyword',
        FileReadonly = 'Special',
        Link = 'SpecialComment',
        LinkBroken = 'IncSearch',
        LinkArrow = 'Blue',
        LinkTo = 'Normal',
    },
    Git = {
        Unmerged = 'Function',
        Modified = 'Special',
        Staged = 'Function',
        Renamed = 'Title',
        Untracked = 'Comment',
        Dirty = 'Tag',
        Deleted = 'Operator',
        Ignored = 'SpecialKey',
        Clean = 'Method',
        Unknown = 'Error',
    },
}

local M = {}

function M.setup()
    for section, links in pairs(default_highlight) do
        for k, v in pairs(links) do
            api.nvim_set_hl(0, string.format('Yanil%s%s', section, k), {
                link = v,
                default = true,
            })
        end
    end
end

return M
