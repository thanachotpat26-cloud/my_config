return {
  'linux-cultist/venv-selector.nvim',
  dependencies = {
    { 'nvim-telescope/telescope.nvim', version = '*', dependencies = { 'nvim-lua/plenary.nvim' } }, -- optional: you can also use fzf-lua, snacks, mini-pick instead.
  },
  ft = 'python', -- Load when opening Python files
  keys = { { ',v', '<cmd>VenvSelect<cr>' } }, -- Open picker on keymap
  opts = {
    options = {
      -- Ubuntu's fd-find package installs the `fd` binary as `fdfind`.
      -- Without this, venv-selector errors on every Python file open and
      -- aborts the FileType autocmd chain (breaking treesitter startup).
      fd_binary_name = 'fdfind',
    }, -- plugin-wide options
    search = {}, -- custom search definitions
  },
}
