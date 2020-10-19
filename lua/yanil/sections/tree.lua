local vim = vim
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

return M
