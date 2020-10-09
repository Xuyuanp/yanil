local vim = vim
local api = vim.api

local default_highlight = {
    Tree = {
        Root           = "Tag",
        Directory      = "Green",
        File           = "Normal",
        FileExecutable = "Keyword",
        FileReadonly   = "Special",
        Link           = "SpecialComment",
        LinkBroken     = "IncSearch",
        LinkArrow      = "Blue",
        LinkTo         = "Normal",
    },
}

local M = {}

function M.setup()
    for section, links in pairs(default_highlight) do
        for k, v in pairs(links) do
            api.nvim_command(string.format("hi default link Yanil%s%s %s", section, k, v))
        end
    end
end

return M
