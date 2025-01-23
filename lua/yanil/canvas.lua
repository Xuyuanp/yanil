local vim = vim
local api = vim.api

local utils = require('yanil/utils')

local validate = vim.validate

-- hooks
-- on_open(cwd)
-- on_exit()
-- on_enter()
-- on_leave()

local M = {
    bufnr = nil,
    bufname = 'Yanil',
    hooks = {},
    keys = {},
}

local buffer_options = {
    bufhidden = 'wipe',
    buftype = 'nofile',
    modifiable = false,
    filetype = 'Yanil',
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
    'filetype=Yanil',
}

function M.setup(opts)
    M.sections = opts.sections

    for _, section in ipairs(M.sections) do
        section:set_post_changes_fn(M.on_section_changed)
        for _, key in ipairs(section:watching_keys() or {}) do
            local section_names = M.keys[key] or {}
            table.insert(section_names, section.name)
            M.keys[key] = section_names
        end
    end

    utils.set_autocmds('yanil_canvas', {
        {
            event = 'BufEnter',
            cmd = M.on_enter,
        },
        {
            event = 'BufLeave',
            cmd = M.on_leave,
        },
        {
            event = 'BufWipeout',
            cmd = M.on_exit,
        },
    })

    if opts.autocmds then
        utils.set_autocmds('yanil_canvas_custom', opts.autocmds)
    end
end

function M.on_enter()
    M.trigger_hook('on_enter')
end

function M.on_leave()
    M.trigger_hook('on_leave')
end

function M.on_open(cwd)
    M.trigger_hook('on_open', cwd)
end

function M.on_exit()
    M.trigger_hook('on_exit')

    M.cursor = api.nvim_win_get_cursor(M.winnr())
end

function M.winnr()
    for _, winnr in ipairs(api.nvim_list_wins()) do
        local bufname = api.nvim_buf_get_name(api.nvim_win_get_buf(winnr))
        if bufname:match('.*/' .. M.bufname .. '$') then
            return winnr
        end
    end
end

local function create_buf(name)
    local bufnr = api.nvim_create_buf(false, true)
    if name then
        api.nvim_buf_set_name(bufnr, name)
    end
    for k, v in pairs(buffer_options) do
        api.nvim_set_option_value(k, v, { buf = bufnr })
    end
    return bufnr
end

local function create_win(bufnr)
    vim.cmd('topleft vertical 30 new')
    vim.cmd('setlocal bufhidden=wipe')

    api.nvim_win_set_buf(0, bufnr)

    for _, win_opt in ipairs(win_options) do
        vim.cmd('setlocal ' .. win_opt)
    end
end

function M.get_current_linenr()
    local winnr = M.winnr()
    if not winnr then
        return
    end
    return api.nvim_win_get_cursor(winnr)[1] - 1
end

function M.set_keymaps()
    for key, section_names in pairs(M.keys) do
        vim.keymap.set('n', key, function()
            local linenr = M.get_current_linenr()
            if not linenr then
                return
            end

            local section, relative_linenr = M.get_section_on_linenr(linenr)
            if not section or not vim.tbl_contains(section_names, section.name) then
                return
            end

            local changes = section:on_key(relative_linenr, key)
            M.in_edit_mode(function()
                M.apply_changes(linenr, changes)
            end)
        end, { buffer = M.bufnr })
    end
end

function M.open(cwd)
    if M.winnr() then
        return
    end

    M.bufnr = create_buf(M.bufname)
    create_win(M.bufnr)

    M.on_open(cwd)

    M.draw()

    M.set_keymaps()

    if M.cursor then
        api.nvim_win_set_cursor(M.winnr(), M.cursor)
    end

    -- TODO: how to trigger bufenter?
    M.on_enter()
end

function M.close()
    local winnr = M.winnr()
    if not winnr then
        return
    end

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
            local changes = section:draw()

            M.apply_changes(linenr, changes)

            linenr = linenr + section:total_lines()
        end
    end)
end

---apply changes to canvas
---@param linenr number: Base line number
---@param changes table: Map of change descriptions. K-Vs are in these form:
---  texts: (optional)
---    table or list of table:
---      line_start: first relative line index (inclusive)
---      line_end: last relative line index (exclusive)
---      lines: array of lines to use as replacement
---  highlights: (optional)
---    table or list of table:
---      ns_id: highlight namespace id (optional)
---      hl_group: highlight group name
---      col_start: start of column number (inclusive)
---      col_end: end of column number (exclusive)
---  cursor: (optional)
---    line: relative lines to move cursor (optional)
---    col: relative columns to move cursor (optional)
function M.apply_changes(linenr, changes)
    if not changes then
        return
    end
    local bufnr = M.bufnr or 0
    local texts = changes.texts or {}
    if not vim.islist(texts) then
        texts = { texts }
    end
    for _, text in ipairs(texts) do
        api.nvim_buf_set_lines(bufnr, linenr + text.line_start, linenr + text.line_end, false, text.lines)
    end

    local highlights = changes.highlights or {}
    if not vim.islist(highlights) then
        highlights = { highlights }
    end
    for _, hl in ipairs(highlights) do
        api.nvim_buf_add_highlight(bufnr, hl.ns_id or utils.ns_id, hl.hl_group, linenr + hl.line, hl.col_start, hl.col_end)
    end

    -- TODO: set line relative to section start linenr
    local cursor = changes.cursor
    if cursor then
        local winnr = M.winnr()
        local current_cursor = api.nvim_win_get_cursor(winnr)
        pcall(api.nvim_win_set_cursor, M.winnr(), {
            linenr + (cursor.line or 0) + 1,
            current_cursor[2] + (cursor.col or 0),
        })
    end
end

function M.get_section_on_linenr(linenr)
    for _, section in ipairs(M.sections) do
        local line_end = section:total_lines()

        if linenr < line_end then
            return section, linenr
        end

        linenr = linenr - line_end
    end
end

function M.get_section_start_linenr(section)
    local linenr = 0
    for _, sec in ipairs(M.sections) do
        if sec == section then
            return linenr
        end
        linenr = linenr + sec:total_lines()
    end
end

function M.on_section_changed(section, changes, linenr_offset)
    local linenr = M.get_section_start_linenr(section)
    if not linenr then
        error('no such section: ' .. section.name)
    end
    linenr = linenr + (linenr_offset or 0)

    M.in_edit_mode(function()
        M.apply_changes(linenr, changes)
    end)
end

function M.in_edit_mode(fn)
    if not vim.api.nvim_buf_is_loaded(M.bufnr) then
        return
    end
    api.nvim_set_option_value('modifiable', true, { buf = M.bufnr })
    local ok, err = pcall(fn)
    if not ok then
        api.nvim_err_writeln(err)
    end
    api.nvim_set_option_value('modifiable', false, { buf = M.bufnr })
end

function M.register_hook(name, fn)
    validate({
        name = { name, 's' },
        fn = { fn, 'f' },
    })
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
    for _, section in ipairs(M.sections) do
        if section[name] then
            section[name](section, ...)
        end
    end
end

return M
