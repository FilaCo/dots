vim.api.nvim_create_autocmd('User', {
  pattern = 'TSUpdate',
  callback = function()
    require('nvim-treesitter.parsers').cangjie = {
      install_info = {
        url = '~/.local/lib/tree-sitter-cangjie',
      },
    }
  end,
})
