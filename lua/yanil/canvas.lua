local vim = vim
local api = vim.api

local decorators = require("yanil/decorators")
local devicons   = require("yanil/devicons")
local utils      = require("yanil/utils")

local M = {
    bufnr = nil,
    bufname = "Yanil"
}

local buffer_options = {
    bufhidden = "wipe",
    buftype = "nofile",
    modifiable = false,
    filetype = "Yanil",
}
local win_options = {
    'noswapfile',
    'norelativenumber',
    'nonumber',
    'nolist',
    'nobuflisted',
    'winfixwidth',
    'winfixheight',
    'nofoldenable',
    'nospell',
    'foldmethod=manual',
    'foldcolumn=0',
    'signcolumn=yes:1',
    'bufhidden=wipe',
}

function M.setup(opts)
    M.sections = opts.sections

    M.set_autocmds({
        {
            event = "BufEnter",
            cmd = M.on_enter,
        },
        {
            event = "BufLeave",
            cmd = M.on_leave
        },
    })
end

function M.on_enter()
    for _, section in ipairs(M.sections) do
        section:on_enter()
    end
end

function M.on_leave()
    print("canvas bufleave")
    for _, section in ipairs(M.sections) do
        section:on_leave()
    end
    M.cursor = api.nvim_win_get_cursor(M.winnr())
end

function M.set_autocmds(autocmds)
    api.nvim_command("augroup yanil_convas")
    api.nvim_command("autocmd!")

    for _, autocmd in ipairs(autocmds) do
        local pattern = autocmd.pattern or "Yanil"
        local cb_key = string.format("canvas_%s_%s", autocmd.event, pattern)
        utils.register_callback(cb_key, autocmd.cmd)
        local t = {"autocmd", autocmd.event, pattern}
        if autocmd.once then table.insert(t, "++once") end
        if autocmd.nested then table.insert(t, "++nested") end
        table.insert(t, string.format([[lua require("yanil/utils").callback("%s")]], cb_key))
        api.nvim_command(table.concat(t, " "))
    end

    api.nvim_command("augroup end")
end

function M.winnr()
    for _, winnr in ipairs(api.nvim_list_wins()) do
        local bufname = api.nvim_buf_get_name(api.nvim_win_get_buf(winnr))
        if bufname:match(".*/"..M.bufname.."$") then
            return winnr
        end
    end
end

local function create_buf(name)
    local bufnr = api.nvim_create_buf(false, true)
    if name then
        api.nvim_buf_set_name(bufnr, name)
    end
    for k, v in ipairs(buffer_options) do
        api.nvim_buf_set_option(bufnr, k, v)
    end
    return bufnr
end

local function create_win(bufnr)
    api.nvim_command("noautocmd topleft vertical 30 new")
    api.nvim_command("noautocmd setlocal bufhidden=wipe")

    api.nvim_win_set_buf(0, bufnr)

    for _, win_opt in ipairs(win_options) do
        api.nvim_command("noautocmd setlocal " .. win_opt)
    end
end

function M.open()
    if M.winnr() then return end

    M.bufnr = create_buf(M.bufname)
    create_win(M.bufnr)

    -- TODO: how to trigger bufenter?
    M.on_enter()

    M.draw()

    utils.buf_set_keymap(M.bufnr, "n", "<CR>", function()
        local cursor = api.nvim_win_get_cursor(0)
        local linenr = cursor[1] - 1
        local texts, highlights = M.section_on_key(linenr, "<CR>")
        if not texts and not highlights then return end
        M.in_edit_mode(function()
            M.apply_changes(linenr, texts, highlights)
        end)
    end)

    if M.cursor then
        api.nvim_win_set_cursor(M.winnr(), M.cursor)
    end
end

function M.draw()
    local linenr = 0

    M.in_edit_mode(function()
        for _, section in ipairs(M.sections) do
            local texts, highlights = section:draw()

            M.apply_changes(linenr, texts, highlights)

            linenr = linenr + section:lens_displayed()
        end
    end)
end

function M.apply_changes(linenr, texts, highlights)
    local bufnr = M.bufnr
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
end

function M.section_on_key(linenr, key)
    for _, section in ipairs(M.sections) do
        local line_end = section:lens_displayed()

        if linenr < line_end then
            return section:on_key(linenr, key)
        end

        linenr = linenr - line_end
    end
end

function M.in_edit_mode(fn)
    api.nvim_buf_set_option(M.bufnr, "modifiable", true)
    pcall(fn)
    api.nvim_buf_set_option(M.bufnr, "modifiable", false)
end

function M.mock_init()
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
    M.setup {
        sections = {
            require("yanil/sections/header"):new(),
            tree,
        }
    }
end

return M
