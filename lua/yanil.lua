local git        = require("yanil/git")
local decorators = require("yanil/decorators")
local devicons   = require("yanil/devicons")
local canvas     = require("yanil/canvas")

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

function M.apply_authors_config()
    local header = require("yanil/sections/header"):new()
    local tree = require("yanil/sections/tree"):new()

    tree:setup {
        draw_opts = {
            decorators = {
                decorators.pretty_indent_with_git,
                devicons.decorator(),
                decorators.space,
                decorators.default,
                decorators.executable,
                decorators.readonly,
                decorators.link_to,
            }
        },
    }

    canvas.register_hooks {
        on_enter = function() git.update(tree.cwd) end,
    }

    canvas.setup {
        sections = {
            header,
            tree,
        },
        autocmds = {
            {
                event = "User",
                pattern = "YanilGitStatusChanged",
                cmd = function() tree:refresh() end,
            },
        }
    }
end

return M
