local vim = vim
local api = vim.api
local loop = vim.loop

local Section = require("yanil/section")
local nodelib = require("yanil/node")

local utils = require("yanil/utils")

local M = Section:new {
    name = "Tree",
}

function M:setup(opts)
    opts = opts or {}

    self.draw_opts = opts.draw_opts
    self.filters = opts.filters

    local default_keymaps = {
        ["<CR>"] = self.open_node,
        s = self:gen_open_file_node("vsplit"),
        i = self:gen_open_file_node("split"),
        C = self.cd_to_node,
        U = self.cd_to_parent,
        K = self.go_to_first_child,
        J = self.go_to_last_child,
        ["<C-K>"] = self:gen_go_to_sibling(-1),
        ["<C-J>"] = self:gen_go_to_sibling(1),
        r = function(tree, node) return tree:refresh(node) end,
        R = function(tree) return tree:refresh() end,
    }

    self.keymaps = vim.tbl_deep_extend("keep", opts.keymaps or {}, default_keymaps)
end

function M:set_cwd(cwd)
    cwd = cwd or loop.cwd()
    if not vim.endswith(cwd, utils.path_sep) then cwd = cwd .. utils.path_sep end
    if self.cwd == cwd then return end
    self.cwd = cwd

    self.root = nodelib.Dir:new {
        name = cwd,
        abs_path = cwd,
        filters = self.filters,
    }

    if self.dir_state then
        self.root:load_state(self.dir_state)
    end
    self.root:open()
end

function M:refresh(node, opts)
    node = node or self.root
    local index = self.root:find_node(node)
    local changes = self:draw(node, opts)
    self:post_changes(changes, index)
end

function M:iter(loaded)
    if not self.root then return function() end end
    return self.root:iter(loaded)
end

function M:draw(node, opts)
    opts = opts or {}
    node = node or self.root
    if not node then return end

    local total_lines = node:total_lines()
    local lines, highlights = node:draw(vim.tbl_deep_extend("force", self.draw_opts, opts))
    if not lines then return end
    local texts = {{
        line_start = 0,
        line_end = opts.non_recursive and #lines or total_lines,
        lines = lines
    }}
    return {
        texts = texts,
        highlights = highlights
    }
end

function M:total_lines()
    return self.root:total_lines()
end

function M:on_open(cwd)
    if not self.cwd or cwd then self:set_cwd(cwd) end
end

function M:on_exit()
    self.dir_state = self.root:dump_state()
end

function M:watching_keys()
    return vim.tbl_keys(self.keymaps)
end

function M:on_key(linenr, key)
    local node = self.root:get_nth_node(linenr)
    if not node then return end

    local action = self.keymaps[key]
    if not action then return end

    return action(self, node, key, linenr)
end

-- key handlers
function M:open_file_node(node, cmd)
    cmd = cmd or "e"
    if node:is_dir() then return end

    if node:is_binary() then
        local input = vim.fn.input(string.format("Yanil Warning:\n\n%s is a binary file.\nStill open? (yes/No): ", node.abs_path), "No")
        if input:lower() ~= "yes" then
            return
        end
    end
    api.nvim_command("wincmd p")
    api.nvim_command(cmd .. " " .. node.abs_path)
end

function M:gen_open_file_node(cmd)
    return function(_, node)
        return self:open_file_node(node, cmd)
    end
end

function M:open_node(node)
    if not node:is_dir() then
        return self:open_file_node(node)
    end

    local total_lines = node:total_lines()

    node:toggle()

    local lines, highlights = node:draw(self.draw_opts)
    return {
        texts = {
            line_start = 0,
            line_end = total_lines,
            lines = lines,
        },
        highlights = highlights
    }
end

function M:cd_to_node(node)
    if not node:is_dir() then return end

    self:cd_to_path(node.abs_path)
end

function M:cd_to_parent()
    if self.cwd == utils.path_sep then return end -- TODO: check root path for windows
    local old_cwd = self.cwd
    local parent = vim.fn.fnamemodify(self.cwd, ":h:h")
    self:cd_to_path(parent)

    for node, index in self:iter() do
        if node.abs_path == old_cwd then
            self:post_changes {
                cursor = {
                    line = index
                }
            }
            return
        end
    end
end

function M:cd_to_path(path)
    local total_lines = self:total_lines()
    self:set_cwd(path)
    local lines, highlights = self.root:draw(self.draw_opts)
    local texts = {{
        line_start = 0,
        line_end = total_lines,
        lines = lines,
    }}
    self:post_changes {
        texts = texts,
        highlights = highlights,
    }
end

function M:go_to_node(node)
    local index = self.root:find_node(node)
    if not index then return end
    self:post_changes {
        cursor = {
            line = index
        }
    }
end

function M:go_to_last_child(node)
    if not node.parent then return end

    local parent = node.parent
    local last_child = parent:get_last_entry()
    if node == last_child then return end

    return self:go_to_node(last_child)
end

function M:go_to_first_child(node)
    if not node.parent then return end

    local parent = node.parent
    local first_child = parent.entries[1]
    if node == first_child then return end

    return self:go_to_node(first_child)
end

---Generate go_to_sibling function
---@param n number
function M:gen_go_to_sibling(n)
    return function(_, node)
        return self:go_to_sibling(node, n)
    end
end

function M:go_to_sibling(node, n)
    local sibling = node:find_sibling(n)
    if not sibling then return end

    return self:go_to_node(sibling)
end

return M
