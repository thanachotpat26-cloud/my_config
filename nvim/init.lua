vim.loader.enable()

-- Neovim re-probes PATH for a python3 host on every python filetype, which costs
-- ~40ms per file. Resolve it once here and cache it.
local py3 = vim.fn.exepath 'python3'
if py3 ~= '' then
  vim.g.python3_host_prog = py3
end

require 'core.options'
require 'core.keymaps'
require 'core.autocmds'
require 'core.platformio'

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  { import = 'plugins' },
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})
vim.filetype.add { extension = { urdf = 'xml', xacro = 'xml', ino = 'cpp' } }
vim.cmd.colorscheme 'rose-pine-moon'
