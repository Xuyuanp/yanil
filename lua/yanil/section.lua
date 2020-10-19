-- Section
--  setup(opts)
--  on_enter()
--  on_exit()
--  draw() -> texts, highlights
--    texts: { line_start = 0, line_end = 10, lines = { } }
--    highlights: { line = 10, col_start = 0, col_end = 3, hl_group = "Red" }
--  on_key(linenr, key)
--  ui_lens() -> number

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

function M:on_enter()
end

function M:on_exit()
end

function M:on_reveal()
end

function M:on_hide()
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

return M
