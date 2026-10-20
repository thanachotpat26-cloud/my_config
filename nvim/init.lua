vim.loader.enable()

require 'core.options'
require 'core.keymaps'
require 'core.autocmds'

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup 'plugins'
vim.filetype.add { extension = { urdf = 'xml', xacro = 'xml', ino = 'cpp' } }
vim.cmd.colorscheme 'rose-pine'
