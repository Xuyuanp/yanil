local vim = vim
local api = vim.api
local loop = vim.loop

local Section = require("yanil/section")
local nodelib = require("yanil/node")

local utils = require("yanil/utils")

local M = Section:new {
    name = "Tree",
    keymaps = {
        ["<CR>"] = function(tree, node) return tree:open_node(node) end,
        s = function(tree, node) return tree:open_file_node(node, "vsplit") end,
        i = function(tree, node) return tree:open_file_node(node, "split") end,
        C = function(tree, node) tree:cd_to_node(node) end,
        U = function(tree, node, key, linenr) tree:cd_to_parent(node, key, linenr) end,
        K = function(tree, node) return tree:go_to_first_child(node) end,
        J = function(tree, node) return tree:go_to_last_child(node) end,
        ["<C-K>"] = function(tree, node) return tree:go_to_prev_sibling(node) end,
        ["<C-J>"] = function(tree, node) return tree:go_to_next_sibling(node) end,
    }
}

function M:setup(opts)
    opts = opts or {}

    self.draw_opts = opts.draw_opts
    self.filters = opts.filters

    self.keymaps = vim.tbl_deep_extend("keep", opts.keymaps or {}, self.keymaps)

    -- TODO: is here the right place?
    require("yanil/canvas").register_hooks {
        on_exit = function() self:on_exit() end,
        on_open = function(cwd) self:on_open(cwd) end,
    }
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

function M:refresh(reload)
    -- TODO: deal with reload
    if reload then return end

    self:post_changes(self:draw())
end

function M:draw()
    if not self.root then return end
    local lines, highlights = self.root:draw(self.draw_opts)
    if not lines then return end
    local texts = {{
        line_start = 0,
        line_end = #lines,
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

function M:cd_to_parent(_node, _key, linenr)
    if self.cwd == "/" then return end -- TODO: check root path for windows
    local old_cwd = self.cwd
    local parent = vim.fn.fnamemodify(self.cwd, ":h:h")
    self:cd_to_path(parent)

    local index = 0
    for node in self.root:iter() do
        if node.abs_path == old_cwd then
            break
        end
        index = index + 1
    end
    self:post_changes {
        cursor = {
            line = index - linenr
        }
    }
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

function M:go_to_last_child(node)
    if not node.parent then return end

    local parent = node.parent
    local last_child = parent:get_last_entry()
    if node == last_child then return end

    local index = 1
    for child in parent:iter() do
        if child == node then
            break
        end
        index = index + 1
    end
    return {
        cursor = {
            line = parent:total_lines() - index
        }
    }
end

function M:go_to_first_child(node)
    if not node.parent then return end

    local parent = node.parent
    local first_child = parent.entries[1]
    if node == first_child then return end

    local index = 1
    for child in parent:iter() do
        if child == node then
            break
        end
        index = index + 1
    end
    return {
        cursor = {
            line = -index + 2
        }
    }
end

function M:go_to_prev_sibling(node)
    if not node.parent then return end

    local parent = node.parent
    local first_child = parent.entries[1]
    if node == first_child then return end

    for i = 1, #parent.entries - 1 do
        if parent.entries[i+1] == node then
            local prev_node = parent.entries[i]
            return {
                cursor = {
                    line = - prev_node:total_lines()
                }
            }
        end
    end
end

function M:go_to_next_sibling(node)
    if not node.parent then return end

    local parent = node.parent
    local last_child = parent:get_last_entry()
    if node == last_child then return end

    return {
        cursor = {
            line = node:total_lines()
        }
    }
end

return M
