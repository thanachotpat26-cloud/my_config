return {
  {
    'rose-pine/neovim',
    name = 'rose-pine',
    lazy = true,
    config = function()
      require('rose-pine').setup {
        variant = 'auto',
        dark_variant = 'main',
        styles = {
          -- Disable global bold and italic styling
          bold = false,
          italic = false,
          transparency = true,
        },
      }
    end,
  },
}
