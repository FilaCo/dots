-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd('User', {
  pattern = 'TSUpdate',
  callback = function()
    require('nvim-treesitter.parsers').cangjie = {
      install_info = {
        url = 'https://github.com/FilaCo/tree-sitter-cangjie',
        revision = '6a4b60adef56a57b0c0aabbf1261131e749a7cf5',
        queries = 'queries',
      },
    }
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'cangjie',
  callback = function(ev)
    vim.bo[ev.buf].commentstring = '// %s'
  end,
})
