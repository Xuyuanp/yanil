local git = require('yanil.git')
local devicons = require('yanil.devicons')

local config = {
    colors = require('yanil.colors'),
}

local M = {}

function M.setup(opts)
    opts = opts or {}
    config.colors.setup()
    git.setup(opts.git)
    devicons.setup(opts.devicons)
end

return M
