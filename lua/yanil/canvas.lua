local vim = vim
local api = vim.api

local decorators = require("yanil/decorators")
local devicons   = require("yanil/devicons")
local utils      = require("yanil/utils")

local M = {
    bufnr = nil,
    bufname = "Yanil"
}

function M.setup(opts)
    M.sections = opts.sections
end

function M.winnr()
    for _, winnr in ipairs(api.nvim_list_wins()) do
        local bufname = api.nvim_buf_get_name(api.nvim_win_get_buf(winnr))
        if bufname == M.bufname then return winnr end
    end
end

function M.open()
end

function M.draw()
    local linenr = 0
    local bufnr = M.bufnr

    for _, section in ipairs(M.sections) do
        local texts, highlights = section:draw()

        texts = texts or {}
        if not vim.tbl_islist(texts) then texts = { texts } end
        for _, text in ipairs(texts) do
            api.nvim_buf_set_lines(bufnr, linenr + text.line_start, linenr + text.line_end, false, text.lines)
        end

        highlights = highlights or {}
        if not vim.tbl_islist(highlights) then highlights = { highlights } end
        for _, hl in ipairs(highlights) do
            api.nvim_buf_add_highlight(bufnr, hl.ns_id or utils.ns_id, hl.hl_group, linenr + hl.line, hl.col_start, hl.col_end)
        end

        linenr = linenr + section:lens_displayed()
    end
end

function M.section_on_key(linenr, key)
    for _, section in ipairs(M.sections) do
        local line_end = section:lens_displayed()

        if linenr < line_end then return section:on_key(linenr, key) end

        linenr = linenr - line_end
    end
end

local function test()
    local tree = require("yanil/sections/tree"):new()
    tree:setup {
        decorators = {
            decorators.pretty_indent_with_git,
            devicons.decorator(),
            decorators.space,
            decorators.default,
            decorators.executable,
            decorators.readonly,
            decorators.link_to,
        }
    }
    tree.root.entries[1]:open()
    M.setup {
        sections = {
            require("yanil/sections/header"):new(),
            tree,
        }
    }

    M.bufnr = 137

    M.draw()

    utils.buf_set_keymap(M.bufnr, "n", "<CR>", function()
        local cursor = api.nvim_win_get_cursor(0)
        M.section_on_key(cursor[1] - 1, "<CR>")
    end)
end

test()

return M
