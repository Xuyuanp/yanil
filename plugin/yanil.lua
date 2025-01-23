vim.api.nvim_create_user_command('Yanil', function(args)
    local dir = args.args or '.'
    local root = vim.fn.fnamemodify(dir, ':p')
    require('yanil.canvas').open(root)
end, {
    nargs = '?',
    complete = 'dir',
    desc = '[Yanil] open',
})

vim.api.nvim_create_user_command('YanilClose', function()
    require('yanil.canvas').close()
end, {
    desc = '[Yanil] close',
})

vim.api.nvim_create_user_command('YanilToggle', function()
    require('yanil.canvas').toggle()
end, {
    desc = '[Yanil] toggle',
})
