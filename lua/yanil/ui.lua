local vim = vim
local api = vim.api
local loop = vim.loop

local nodelib = require("yanil/node")

local ns_id = api.nvim_create_namespace("Yanil")

require("yanil/colors").setup()

local decorators = {
    function(node)
        if node:is_dir() then
            local text = node.name .. "/"
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
    end,
}

local M = {}

M.tree = {
    bufname = "Yanil",
    bufnr = nil,
    win_width = 30,
    cwd = nil,
    root = nil,
    header_height = 2,
    winnr = function()
        for _, winnr in ipairs(api.nvim_list_wins()) do
            if api.nvim_buf_get_name(api.nvim_win_get_buf(winnr)):match(".*/"..M.tree.bufname.."$") then
                return winnr
            end
        end
    end,
    options = {
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
        'signcolumn=yes:1'
    },
}

function M.init(cwd)
    cwd = cwd or loop.cwd()
    M.tree.cwd = cwd
    local root = nodelib.Dir:new {
        name = cwd,
        abs_path = cwd,
    }
    root:open()

    M.tree.root = root
end

function M.set_mappings()
    api.nvim_buf_set_keymap(M.tree.bufnr, "n", "<CR>", '<cmd>lua require("yanil/ui").open_current_node()<CR>', {
        nowait = true,
        noremap = false,
        silent = false,
    })
    api.nvim_buf_set_keymap(M.tree.bufnr, "n", "c", '<cmd>lua require("yanil/ui").change_dir_to_current_node()<CR>', {
        nowait = true,
        noremap = false,
        silent = false,
    })
    api.nvim_buf_set_keymap(M.tree.bufnr, "n", "u", '<cmd>lua require("yanil/ui").change_dir_to_parent()<CR>', {
        nowait = true,
        noremap = false,
        silent = false,
    })
end

function M.open_current_node()
    local cursor = api.nvim_win_get_cursor(M.tree.winnr())
    local linenr = cursor[1] -- 1-based
    local node = M.get_node_by_linenr(linenr)
    if not node then return end

    if not node:is_dir() then
        api.nvim_command("wincmd p")
        api.nvim_command("e " .. node.abs_path)
        return
    end

    local bufnr = M.tree.bufnr
    api.nvim_buf_set_option(bufnr, "modifiable", true)

    if node.is_open then
        api.nvim_buf_set_lines(bufnr, linenr, linenr+node:total_lines(), false, {})
        node.is_open = false
    else
        node:open()
    end

    local opts = {holder = "  ", decorators = decorators}
    local lines, highlights = node:draw(opts)
    api.nvim_buf_set_lines(bufnr, linenr, linenr, false, lines)
    api.nvim_buf_set_lines(bufnr, linenr - 1, linenr, false, {})
    for _, hl in ipairs(highlights) do
        api.nvim_buf_add_highlight(bufnr, ns_id, hl.hl_group, linenr + hl.line - 1, hl.col_start, hl.col_end)
    end

    api.nvim_buf_set_option(bufnr, "modifiable", false)
end

function M.change_dir_to_current_node()
    local node = M.get_node_under_cursor()
    if not node then return end

    M.change_dir(node.abs_path)
end

function M.change_dir_to_parent()
    if M.tree.cwd == "/" then return end
    local parent = vim.fn.fnamemodify(M.tree.cwd, ":h")
    if not parent then return end

    M.change_dir(parent)
end

function M.get_node_under_cursor()
    local cursor = api.nvim_win_get_cursor(M.tree.winnr())
    return M.get_node_by_linenr(cursor[1])
end

function M.get_node_by_linenr(linenr)
    local index = M.tree.header_height
    return M.tree.root:get_nth_node(linenr - index - 1)
end

local function create_buf()
    local options = {
        bufhidden = "wipe",
        buftype = "nofile",
        modifiable = false,
    }
    local bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(bufnr, M.tree.bufname)
    for k, v in pairs(options) do
        api.nvim_buf_set_option(bufnr, k, v)
    end
    return bufnr
end

local function create_win()
    api.nvim_command("topleft vertical " .. M.tree.win_width .. " new")
    api.nvim_command("setlocal nobuflisted")
end

function M.open()
    if M.tree.winnr() then return end

    M.tree.bufnr = create_buf()
    create_win()
    api.nvim_win_set_buf(M.tree.winnr(), M.tree.bufnr)

    for _, opt in ipairs(M.tree.options) do
        api.nvim_command("setlocal " .. opt)
    end
end

function M.draw()
    local opts = {
        holder = "  ",
        decorators = decorators,
    }

    local lines, highlights = M.tree.root:draw(opts, {"", ""})

    api.nvim_buf_set_option(M.tree.bufnr, "modifiable", true)
    api.nvim_buf_set_lines(M.tree.bufnr, 0, -1, false, {})
    api.nvim_buf_set_lines(M.tree.bufnr, 0, -1, false, lines)
    for _, hl in ipairs(highlights) do
        api.nvim_buf_add_highlight(M.tree.bufnr, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
    end

    M.set_mappings()

    api.nvim_buf_set_option(M.tree.bufnr, "modifiable", false)
end

function M.refresh_ui()
    M.draw()
end

function M.change_dir(cwd)

    M.init(cwd)
    M.draw()

    api.nvim_win_set_cursor(M.tree.winnr(), {3, 0})
end

function M.startup(cwd)
    M.init(cwd)
    M.open()
    M.draw()
end

return M
