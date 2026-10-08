vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local opt = vim.opt
vim.opt.clipboard = 'unnamedplus'
opt.number = true
opt.mouse = 'a'
opt.showmode = true
opt.undofile = true
opt.signcolumn = 'no'
opt.cursorline = false
opt.scrolloff = 8
opt.confirm = false
opt.guicursor = ''
opt.incsearch = true
-- opt.fillchars = { eob = ' ' }
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
opt.wrap = false
vim.opt.updatetime = 50
vim.opt.hlsearch = false
vim.opt.smartindent = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.termguicolors = true
