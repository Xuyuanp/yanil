local Section = require("yanil/section")

local M = Section:new {
    name = "Header"
}

function M:draw()
    local header = "Yanil"
    local texts = {
        line_start = 0,
        line_end = 2,
        lines = {
            header,
            "",
        }
    }
    return {
        texts = texts
    }
end

function M:total_lines()
    return 2
end

return M
