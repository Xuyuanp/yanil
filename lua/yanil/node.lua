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
    extension = nil,
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

    if not endswith(self.name, path_sep) then self.name = self.name .. path_sep end
    if not endswith(self.abs_path, path_sep) then self.abs_path = self.abs_path .. path_sep end
end

function FileNode:init()
    self.is_exec = loop.fs_access(self.abs_path, "X")
    self.is_readonly = not loop.fs_access(self.abs_path, "W")
    self.extension = vim.fn.fnamemodify(self.abs_path, ":e") or ""
end

function FileNode:is_binary()
    if self._is_binary ~= nil then return self._is_binary end
    self._is_binary = utils.is_binary(self.abs_path)
    return self._is_binary
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

function DirNode:load(force)
    if self.is_loaded and not force then return end

    local handle, err = loop.fs_scandir(self.abs_path)
    if not handle then
        api.nvim_err_writeln(string.format("scandir %s failed: %s", self.abs_path, err))
        return
    end

    self.entries = {}

    for name, ft in function() return loop.fs_scandir_next(handle) end do
        if self:check_ignore(name) then goto cont end

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
            filters = self.filters,
        }
        table.insert(self.entries, node)

        ::cont::
    end

    self:sort_entries()

    self.is_loaded = true
    return true
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

function DirNode:iter(loaded)
    validate {
        loaded = { loaded, "boolean", true },
    }
    local stack = utils.new_stack()
    stack:push(self)
    local index = -1
    return function()
        local current_node = stack:pop()
        if not current_node then return end
        index = index + 1
        if current_node:is_dir() and (current_node.is_open or (current_node.is_loaded and loaded)) then
            for i = #current_node.entries, 1, -1 do
                stack:push(current_node.entries[i])
            end
        end
        return current_node, index
    end
end

function DirNode:find_node(node)
    for entry, index in self:iter() do
        if entry == node then return index end
    end
end

function DirNode:find_node_by_path(path)
    if not vim.startswith(path, self.abs_path) then return end
    if self.abs_path == path then return self end
    for _, entry in ipairs(self.entries) do
        if entry.abs_path == path then return entry end
        if entry:is_dir() and vim.startswith(path, entry.abs_path) then
            entry:load()
            return entry:find_node_by_path(path)
        end
    end
end

function Node:find_sibling(n)
    validate {
        n = { n, "number" }
    }
    local parent = self.parent
    if not parent then return end

    for i, entry in ipairs(parent.entries) do
        if entry == self then
            local index = i + n
            if index >= 1 and index <= #parent.entries then
                return parent.entries[index]
            end
            return
        end
    end
end

function DirNode:get_nth_node(n, loaded)
    for node, index in self:iter(loaded) do
        if index == n then return node end
    end
end

function DirNode:sort_entries(opts)
    opts = opts or {}
    table.sort(self.entries, opts.comp or function(lhs, rhs)
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
                if type(hl) == "string" then hl = {hl_group = hl} end
                table.insert(highlights, {
                    line      = line,
                    col_start = hl_offset + (hl.col_start or 0),
                    col_end   = hl_offset + (hl.col_end or text:len()),
                    hl_group  = hl.hl_group,
                })
            end
            hl_offset = hl_offset + text:len()
        end
    end
    local display_str = table.concat(symbols, opts.sep or "")
    table.insert(lines, display_str)

    return lines, highlights
end

function DirNode:draw(opts, lines, highlights)
    lines, highlights = Node.draw(self, opts, lines, highlights)
    if self.is_open and not opts.non_recursive then
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

function DirNode:dump_state()
    local opened_dirs = {}
    local loaded_dirs = {}
    for node in self:iter(true) do
        if node:is_dir() then
            if node.is_loaded then
                loaded_dirs[node.abs_path] = true
                if node.is_open then opened_dirs[node.abs_path] = true end
            end
        end
    end
    return {
        opened_dirs = opened_dirs,
        loaded_dirs = loaded_dirs,
    }
end

function DirNode:load_state(state)
    state = state or {}
    local loaded_dirs = state.loaded_dirs or {}
    local opened_dirs = state.opened_dirs or {}

    local function open_dirs(dir)
        if not dir:is_dir() then return end
        if not dir.is_loaded and loaded_dirs[dir.abs_path] then
            dir:load()
        end
        if dir.is_open then
            if not opened_dirs[dir.abs_path] then dir:close() end
        else
            if opened_dirs[dir.abs_path] then dir:open() end
        end
        for _, child in ipairs(dir.entries) do
            if child:is_dir() then open_dirs(child) end
        end
    end

    open_dirs(self)
end

function DirNode:check_ignore(name)
    if not self.filters or #self.filters == 0 then return end
    for _, filter in ipairs(self.filters) do
        if filter(name) then return true end
    end
end

return {
    Dir = DirNode,
    File = FileNode,
    Link = LinkNode,
    LinkDir = LinkDirNode,
}
