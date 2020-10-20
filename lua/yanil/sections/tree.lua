local vim = vim
local api = vim.api
local loop = vim.loop

local Section = require("yanil/section")
local nodelib = require("yanil/node")

local M = Section:new {
    name = "Tree"
}

function M:setup(opts)
    opts = opts or {}

    self.decorators = opts.decorators

    self.cwd = opts.cwd or loop.cwd()
    self.root = nodelib.Dir:new {
        name = self.cwd,
        abs_path = self.cwd,
    }
    self.root:open()
end

function M:draw()
    local lines, highlights = self.root:draw({ decorators = self.decorators })
    if not lines then return end
    local text = {
        line_start = 0, line_end = #lines, lines = lines
    }
    return text, highlights
end

function M:lens_displayed()
    return self.root:total_lines()
end

function M:on_enter()
    if self.dir_state then self.root:load_state(self.dir_state) end
end

function M:on_leave()
    self.dir_state = self.root:dump_state()
end

function M:on_key(linenr, key)
    local node = self.root:get_nth_node(linenr)
    if not node then return end

    return self:node_on_key(node, key)
end

function M:node_on_key(node, key)
    if key ~= "<CR>" then return end

    local cmd = "e"
    if not node:is_dir() then
        if node:is_binary() then
            local input = vim.fn.input(string.format("Yanil Warning:\n\n%s is a binary file.\nStill open? (yes/No): ", node.abs_path), "No")
            if input:lower() ~= "yes" then
                return
            end
        end
        api.nvim_command("wincmd p")
        api.nvim_command(cmd .. " " .. node.abs_path)
        return
    end

    local total_lines = node:total_lines()

    node:toggle()

    local lines, highlights = node:draw(self)
    return {
        line_start = 0,
        line_end = total_lines,
        lines = lines,
    }, highlights
end

return M
