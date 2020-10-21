local M = {}

function M:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    return o
end

function M:init()
    if not self.name then error("cannot initialize abstrace section") end
end

function M:setup(_opts)
end

local hooks = {
    "on_enter",
    "on_leave",
    "on_exit",
}

do
    for _, hook in ipairs(hooks) do
        M[hook] = function(_self)
        end
    end
end

function M:draw()
    error("not implemented")
end

function M:lens_displayed()
    error("not implemented")
end

function M:on_key(linenr, key)
    print("section", self.name, "handled key", key, "pressed event on line", linenr)
end

function M:set_post_changes_fn(fn)
    self.post_changes = fn
end

return M
