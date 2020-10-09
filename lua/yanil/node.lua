local vim = vim
local api = vim.api
local validate = vim.validate
local loop = vim.loop

local utils = require("yanil/utils")
local path_sep = utils.path_sep

local startswith = vim.startswith
local endswith = vim.endswith

local filetypes = {
    "directory", "file", "link", "block", "char", "socket", "unknown"
}

local Node = {
    name = "",
    abs_path = "",
    depth = 0,
}

function Node:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    return o
end

function Node:init()
    if not self.ntype then
        error("cannot initialize abstract node")
    end
end

do
    for _, ft in ipairs(filetypes) do
        Node["is_" .. ft] = function(n)
            return n.ntype == ft
        end
    end
end

function Node:is_dir()
    return self:is_directory()
end

function Node:is_hidden()
    return startswith(self.name, ".")
end

local DirNode = Node:new {
    ntype = "directory",
    is_open = false,
    is_loaded = false,
    last_modified = 0,
}

local FileNode = Node:new {
    ntype = "file",
    is_exec = false,
    extension = "",
}

local LinkNode = FileNode:new {
    ntype = "link",
    link_to = nil,
}

local LinkDirNode = DirNode:new {
    ntype = "link",
    link_to = nil
}

local classes = {
    directory = DirNode,
    file = FileNode,
    link = LinkNode,
}

function DirNode:init()
    local stat = loop.fs_stat(self.abs_path)
    self.last_modified = stat.mtime.sec
    self.entries = {}
end

function FileNode:init()
    self.is_exec = loop.fs_access(self.abs_path, "X")
    self.is_readonly = not loop.fs_access(self.abs_path, "W")
    self.extension = vim.fn.fnamemodify(self.abs_path, ":e") or ""
end

function LinkNode:init()
    FileNode.init(self)

    if self.link_to then
        local stat = loop.fs_stat(self.link_to)
        self.link_to_type = stat.type
    end
end

function LinkNode:is_broken()
    return not self.link_to
end

function LinkDirNode:init()
    DirNode.init(self)
    self.link_to_type = "directory"
end

function LinkDirNode:is_directory()
    return true
end

function DirNode:load()
    local handle, err = loop.fs_scandir(self.abs_path)
    if not handle then
        api.nvim_err_writeln(string.format("scandir %s failed: %s", self.abs_path, err))
        return
    end

    while true do
        local name, ft = loop.fs_scandir_next(handle)
        if not name then break end

        local class = classes[ft] or FileNode

        local abs_path = self.abs_path
        if not endswith(abs_path, path_sep) then
            abs_path = abs_path .. path_sep
        end
        abs_path = abs_path .. name

        local realpath = nil
        if ft == "link" then
            realpath = loop.fs_realpath(abs_path)
            if realpath then
                local stat = loop.fs_stat(realpath)
                if stat.type == "directory" then class = LinkDirNode end
            end
        end

        local node = class:new {
            name = name,
            abs_path = abs_path,
            depth = self.depth + 1,
            link_to = realpath,
            parent = self,
        }
        table.insert(self.entries, node)
    end

    self:sort_entries()

    self.is_loaded = true
end

function DirNode:open()
    if self.is_open then return end
    if not self.is_loaded then self:load() end
    self.is_open = true

    if #self.entries ~= 1 then return end

    local child = self.entries[1]
    if not child:is_dir() or child.is_loaded then return end
    child:open()
end

function DirNode:close()
    self.is_open = false
end

function DirNode:toggle()
    if self.is_open then
        self:close()
    else
        self:open()
    end
end

function DirNode:iter()
    local stack = utils.Stack:new { self }
    return function()
        local current_node = stack:pop()
        if not current_node then return end
        if current_node:is_dir() and current_node.is_open then
            for index = #current_node.entries, 1, -1 do
                stack:push(current_node.entries[index])
            end
        end
        return current_node
    end
end

function DirNode:get_nth_node(n)
    local index = 0
    for node in self:iter() do
        if index == n then return node end
        index = index + 1
    end
end

-- TODO: more sort options
function DirNode:sort_entries(_opts)
    table.sort(self.entries, function(lhs, rhs)
        if lhs:is_dir() and not rhs:is_dir() then return true end
        if rhs:is_dir() and not lhs:is_dir() then return false end

        return lhs.name < rhs.name
    end)
end

function Node:draw(opts, lines, highlights)
    validate {
        opts = {opts, "t", false},
        lines = {lines, "t", true},
        highlights = {highlights, "t", true},
    }
    lines = lines or {}
    highlights = highlights or {}

    local symbols = { }
    local line = #lines
    local hl_offset = 0
    for _, decorator in ipairs(opts.decorators or {}) do
        local text, hls = decorator(self)
        if text then
            table.insert(symbols, text)
            hls = hls or {}
            if not vim.tbl_islist(hls) then hls = {hls} end
            for _, hl in ipairs(hls) do
                table.insert(highlights, {
                    line      = line,
                    col_start = hl_offset + hl.col_start,
                    col_end   = hl_offset + hl.col_end,
                    hl_group  = hl.hl_group,
                })
            end
            hl_offset = hl_offset + text:len()
        end
    end
    local display_str = vim.fn.join(symbols, "")
    table.insert(lines, display_str)

    return lines, highlights
end

function DirNode:draw(opts, lines, highlights)
    lines, highlights = Node.draw(self, opts, lines, highlights)
    if self.is_open then
        for _, child in ipairs(self.entries) do
            child:draw(opts, lines, highlights)
        end
    end
    return lines, highlights
end

function Node:total_lines()
    return 1
end

function DirNode:total_lines()
    local count = 1
    if self.is_open then
        for _, child in ipairs(self.entries) do
            count = count + child:total_lines()
        end
    end
    return count
end

function DirNode:get_last_entry()
    if #self.entries > 0 then return self.entries[#self.entries] end
end

return {
    Dir = DirNode,
    File = FileNode,
    Link = LinkNode,
}
