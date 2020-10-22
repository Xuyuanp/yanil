local git      = require("yanil/git")
local devicons = require("yanil/devicons")

local config = {
    colors   = require("yanil/colors"),
    commands = require("yanil/commands"),
    keymaps  = require("yanil/keymaps"),
}

local M = {}

function M.setup(opts)
    opts = opts or {}
    config.colors.setup()
    config.commands.setup()
    git.setup(opts.git)
    devicons.setup(opts.devicons)
end

return M
