-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

if not vim.filetype.match { filename = 'cangjie' } then
  vim.filetype.add {
    extension = {
      cj = 'cangjie',
    },
  }
end

vim.treesitter.language.register('cangjie', { 'cj' })
