return {
  {
    'echasnovski/mini.ai',
    event = 'VeryLazy',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
    end,
  },
  {
    'echasnovski/mini.surround',
    event = 'VeryLazy',
    config = function()
      require('mini.surround').setup()
    end,
  },
  {
    'echasnovski/mini.pairs',
    event = 'InsertEnter',
    config = function()
      require('mini.pairs').setup()
    end,
  },
}
