local vim = vim
local api = vim.api
local loop = vim.loop

local utils = require("yanil/utils")
local path_sep = utils.path_sep

local get_devicon = vim.fn.WebDevIconsGetFileTypeSymbol

local startswith = vim.startswith

local Node = {
    name = "",
    abs_path = "",
    depth = 0,
}

function Node:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    self.__lt = Node.__lt
    o:init()
    return o
end

function Node:init()
    if not self.ntype then
        error("cannot initialize abstract node")
    end
end

function Node:is_dir()
    return self.ntype == "directory"
end

function Node:is_hidden()
    return startswith(self.name, ".")
end

function Node:__lt(rhs)
    if self:is_dir() and not rhs:is_dir() then return true end
    if not self:is_dir() and rhs:is_dir() then return false end

    if self:is_hidden() and not rhs:is_hidden() then return true end
    if not self:is_hidden() and rhs:is_hidden() then return false end

    return self.name < rhs.name
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

local LinkNode = Node:new {
    ntype = "link",
    link_to = nil,
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
    self.extension = vim.fn.fnamemodify(self.abs_path, ":e") or ""
end

function LinkNode:init()
    self.link_to = loop.fs_realpath(self.abs_path)
end

function DirNode:load()
    local handle = loop.fs_scandir(self.abs_path)
    if type(handle) == "string" then
        api.nvim_err_writeln("scandir", self.abs_path, " failed:", handle)
        return
    end

    while true do
        local name, ft = loop.fs_scandir_next(handle)
        if not name then break end

        local node = classes[ft]:new {
            name = name,
            abs_path = self.abs_path .. path_sep .. name,
            depth = self.depth + 1,
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
end

function DirNode:toggle()
    if self.is_open then
        self.is_open = false
    else
        self:open()
    end
end

function DirNode:get_nth_node(n)
    if n == 0 then return self end

    local index = 1
    local function iter(entries)
        for _, child in ipairs(entries) do
            if index == n then return child end

            index = index + 1
            if child.ntype == "directory" and child.is_open then
                child = iter(child.entries)
                if child then return child end
            end
        end
    end
    return iter(self.entries)
end

-- TODO: more sort options
function DirNode:sort_entries(_opts)
    table.sort(self.entries)
end

function DirNode:draw(opts, lines, highlights)
    lines = lines or {}
    highlights = highlights or {}

    local prefix = string.rep(opts.holder or " ", self.depth)
    local display_str = string.format("%s%s %s/", prefix, self.is_open and "" or "", self.name)
    table.insert(lines, display_str)
    table.insert(highlights, {
        line = #lines - 1,
        col_start = prefix:len(),
        col_end = display_str:len(),
        hl_group = "YanilDirectory"
    })
    if self.is_open then
        for _, child in ipairs(self.entries) do
            child:draw(opts, lines, highlights)
        end
    end

    return lines, highlights
end

function DirNode:total_lines()
    local count = 0
    for _, child in ipairs(self.entries) do
        count = count + 1
        if child.ntype == "directory" and child.is_open then
            count = count + child:total_lines()
        end
    end
    return count
end

function FileNode:draw(opts, lines, highlights)
    lines = lines or {}
    highlights = highlights or {}

    local prefix = string.rep(opts.holder or " ", self.depth)
    local display_str = string.format("%s%s %s%s", prefix, get_devicon(self.name), self.name, self.is_exec and "*" or "")
    table.insert(lines, display_str)
    table.insert(highlights, {
        line = #lines - 1,
        col_start = prefix:len(),
        col_end = display_str:len(),
        hl_group = self.is_exec and "YanilFileExecutable" or "YanilFile"
    })

    return lines, highlights
end

function LinkNode:draw(opts, lines, highlights)
    lines = lines or {}
    highlights = highlights or {}
    local prefix = string.rep(opts.holder or " ", self.depth)
    local display_str = string.format("%s%s %s -> %s", prefix, get_devicon(self.name), self.name, self.link_to)
    table.insert(lines, display_str)

    local linenr = #lines - 1
    table.insert(highlights, {
        line = linenr,
        col_start = prefix:len(),
        col_end = prefix:len() + self.name:len(),
        hl_group = "YanilFile",
    })
    table.insert(highlights, {
        line = linenr,
        col_start = prefix:len() + self.name:len() + 1,
        col_end = prefix:len() + self.name:len() + 3,
        hl_group = "YanilLinkArrow",
    })
    table.insert(highlights, {
        line = linenr,
        col_start = prefix:len() + self.name:len() + 3,
        col_end = display_str:len(),
        hl_group = "YanilLinkTo",
    })

    return lines, highlights
end

return {
    Dir = DirNode,
    File = FileNode,
    Link = LinkNode,
}
