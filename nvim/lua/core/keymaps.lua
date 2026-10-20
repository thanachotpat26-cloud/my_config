local map = vim.keymap.set
map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('n', '<leader>q', function()
  vim.diagnostic.setloclist()
end, { desc = 'Open diagnostic [Q]uickfix list' })
map('i', 'jk', '<Esc>', { desc = 'Escape to normal mode' })
map('v', 'J', ":m '>+1<CR>gv=gv")
map('v', 'K', ":m '<-2<CR>gv=gv")
map('n', 'L', ':bnext<CR>', { desc = 'Next buffer' })
map('n', 'H', ':bprevious<CR>', { desc = 'Previous buffer' })
map('n', 'J', "mzJ'z")
map('n', '<C-n>', '<C-d>zz')
map('n', '<C-p>', '<C-u>zz')
map('n', 'n', 'nzzzv')
map('n', 'N', 'Nzzzv')
map('n', '<leader>fg', '<cmd>Telescope git_files<cr>', { desc = 'Find Git Files' })

map('n', '<leader>e', function()
  if vim.bo.filetype == 'oil' then
    require('oil').close() -- restores the buffer from before oil was opened
  else
    require('oil').open()
  end
end, { desc = 'Toggle file explorer' })
map('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent directory' })
