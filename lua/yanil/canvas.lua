local vim = vim
local api = vim.api

local utils = require("yanil/utils")

local validate = vim.validate

-- hooks
-- on_open(cwd)
-- on_exit()
-- on_enter()
-- on_leave()

local M = {
    bufnr = nil,
    bufname = "Yanil",
    hooks = {}
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

    for _, section in ipairs(M.sections) do
        section:set_post_changes_fn(M.on_section_changed)
    end

    utils.set_autocmds("yanil_canvas", {
        {
            event = "BufEnter",
            cmd = M.on_enter,
        },
        {
            event = "BufLeave",
            cmd = M.on_leave
        },
        {
            event = "BufWipeout",
            cmd = M.on_exit
        }
    })

    if opts.autocmds then
        utils.set_autocmds("yanil_canvas_custom", opts.autocmds)
    end
end

function M.on_enter()
    M.trigger_hook("on_enter")
end

function M.on_leave()
    M.trigger_hook("on_leave")
end

function M.on_open(cwd)
    M.trigger_hook("on_open", cwd)
end

function M.on_exit()
    M.trigger_hook("on_exit")

    M.cursor = api.nvim_win_get_cursor(M.winnr())
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

function M.open(cwd)
    if M.winnr() then return end

    M.bufnr = create_buf(M.bufname)
    create_win(M.bufnr)

    M.on_open(cwd)

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

    -- TODO: how to trigger bufenter?
    M.on_enter()
end

function M.close()
    local winnr = M.winnr()
    if not winnr then return end

    api.nvim_win_close(winnr, true)
end

function M.toggle()
    local winnr = M.winnr()
    if not winnr then
        M.open()
    else
        M.close()
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

function M.apply_changes(linenr, texts, highlights, cursor)
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

    if cursor then api.nvim_win_set_cursor(M.winnr(), cursor) end
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

function M.get_section_start_linenr(section)
    local linenr = 0
    for _, sec in ipairs(M.sections) do
        if sec == section then return linenr end
        linenr = linenr + sec:lens_displayed()
    end
end

function M.on_section_changed(section, texts, highlights)
    local linenr = M.get_section_start_linenr(section)
    if not linenr then error("no such section: " .. section.name) end

    if not (texts or highlights) then return end

    M.in_edit_mode(function()
        M.apply_changes(linenr, texts, highlights)
    end)
end

function M.in_edit_mode(fn)
    api.nvim_buf_set_option(M.bufnr, "modifiable", true)
    local ok, err = pcall(fn)
    if not ok then api.nvim_err_writeln(err) end
    api.nvim_buf_set_option(M.bufnr, "modifiable", false)
end

function M.register_hook(name, fn)
    validate {
        name = { name, "s" },
        fn = { fn, "f" }
    }
    local fns = M.hooks[name] or {}
    table.insert(fns, fn)
    M.hooks[name] = fns
end

function M.register_hooks(hooks)
    for name, fn in pairs(hooks) do
        M.register_hook(name, fn)
    end
end

function M.trigger_hook(name, ...)
    for _, fn in ipairs(M.hooks[name] or {}) do
        fn(...)
    end
end

return M
