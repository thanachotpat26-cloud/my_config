return {
  'nvim-treesitter/nvim-treesitter',
  -- This plugin does not support lazy-loading
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').setup {
      install_dir = vim.fn.stdpath('data') .. '/site',
    }

    -- Modern replacement for the removed `highlight = { enable = true }`:
    -- auto-start treesitter highlighting on every buffer that has a parser.
    vim.api.nvim_create_autocmd('FileType', {
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })

    -- Install missing parsers on first run (no-op afterwards).
    -- Deferred to VeryLazy so a missing parser can never block startup.
    local want = {
      'bash',
      'c',
      'diff',
      'html',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'query',
      'vim',
      'vimdoc',
      'python',
      'ruby',
    }
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      once = true,
      callback = function()
        local ts = require('nvim-treesitter')
        local have = ts.get_installed()
        local need = vim.tbl_filter(function(p)
          return not vim.tbl_contains(have, p)
        end, want)
        if #need > 0 then
          ts.install(need):wait(300000)
        end
      end,
    })
  end,
}