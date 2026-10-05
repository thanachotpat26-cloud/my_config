-- Using lazy.nvim (with telescope)
return {
  'nosduco/remote-sshfs.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim', 'nvim-lua/plenary.nvim' },
  keys = {
    { '<leader>kn', '<cmd>RemoteSSHFSConnect<cr>', desc = 'SSHFS Connect' },
  },
  opts = {},
}