return {
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'saghen/blink.cmp',
    },
    config = function()
      local attach_group = vim.api.nvim_create_augroup('lsp-attach', { clear = true })
      local highlight_group = vim.api.nvim_create_augroup('lsp-highlight', { clear = true })
      local detach_group = vim.api.nvim_create_augroup('lsp-detach', { clear = true })
      local jumps = {
        grd = { vim.lsp.buf.definition, '[G]oto [D]efinition' },
        grD = { vim.lsp.buf.declaration, '[G]oto [D]eclaration' },
        gri = { vim.lsp.buf.implementation, '[G]oto [I]mplementation' },
        grt = { vim.lsp.buf.type_definition, '[G]oto [T]ype Definition' },
        grr = { nil, '[G]oto [R]eferences', 'lsp_references' },
        gO = { nil, '[Document] Symbols', 'lsp_document_symbols' },
        gW = { nil, '[Workspace] Symbols', 'lsp_dynamic_workspace_symbols' },
      }

      vim.api.nvim_create_autocmd('LspAttach', {
        group = attach_group,
        callback = function(event)
          local function map(keys, func, desc, mode)
            vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          for keys, jump in pairs(jumps) do
            map(keys, jump[1] or function()
              require('telescope.builtin')[jump[3]]()
            end, jump[2])
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            -- A buffer can collect a second client later; clear first so the
            -- CursorHold handler is not registered twice.
            vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_group,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_group,
              callback = vim.lsp.buf.clear_references,
            })
          end

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            vim.lsp.inlay_hint.enable(false, { bufnr = event.buf })
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Registered once, globally: the handler reads event.buf itself, so there
      -- is no reason to create a fresh LspDetach autocmd on every attach.
      vim.api.nvim_create_autocmd('LspDetach', {
        group = detach_group,
        callback = function(event)
          -- vim.lsp.buf.clear_references() ignores arguments and clears the current
          -- buffer; detaching a background buffer would strand its highlights.
          vim.lsp.util.buf_clear_references(event.buf)
          vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = false,
        signs = false,
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local severity = diagnostic.severity
            if severity <= vim.diagnostic.severity.WARN then
              return diagnostic.message
            end
            return (severity == vim.diagnostic.severity.INFO and 'info: ' or 'hint: ') .. diagnostic.message
          end,
        },
      }

      -- PlatformIO query-driver configuration for clangd
      local packages_dir = vim.fn.expand '~/.platformio/packages'
      local pio_drivers = {}
      for _, driver in ipairs { '*-gcc', '*-g++' } do
        vim.list_extend(pio_drivers, vim.fn.glob(packages_dir .. '/toolchain-*/bin/' .. driver, 0, 1))
      end

      local clangd_cmd = {
        'clangd',
        '--header-insertion=never',
        -- ESP-IDF/Arduino headers are re-parsed on nearly every edit; keeping the
        -- PCH in RAM costs memory but skips the disk round-trip each time.
        '--pch-storage=memory',
        -- Background indexing otherwise runs at editor priority and stutters the
        -- UI while it works through a framework tree.
        '--background-index-priority=low',
      }
      if #pio_drivers > 0 then
        clangd_cmd[#clangd_cmd + 1] = '--query-driver=' .. table.concat(pio_drivers, ',')
      end

      -- blink's capabilities include Neovim's own defaults. The wildcard reaches
      -- every server mason-lspconfig's automatic_enable starts -- including the
      -- ones with no entry in `servers` (rust_analyzer, bashls, lemminx).
      vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })

      local servers = {
        clangd = {
          cmd = clangd_cmd,
          root_markers = { 'platformio.ini', '.clangd', 'compile_commands.json', '.git' },
        },
        pyright = {
          settings = {
            python = {
              analysis = {
                autoImportCompletions = false,
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                -- 'workspace' makes pyright parse every .py file under the root on
                -- attach (build/install trees included). Errors are only read in
                -- buffers that are open anyway.
                diagnosticMode = 'openFilesOnly',
              },
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = { callSnippet = 'Replace' },
              -- Stops lua_ls re-offering to import third-party libraries (and
              -- re-indexing them) every time a buffer opens in a new project.
              workspace = { checkThirdParty = false },
            },
          },
        },
      }

      -- Register only; enabling/starting is left to mason-lspconfig's
      -- automatic_enable, so a server is never started twice with two configs.
      -- The call form merges -- `vim.lsp.config[name] = server` replaces.
      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
      end

      require('mason-lspconfig').setup {}

      -- mason is the only installer in this config, so the formatters are listed
      -- here too. Two package names differ from their lspconfig name; everything
      -- else it skips silently, so there is no is_installed() bookkeeping.
      require('mason-tool-installer').setup {
        ensure_installed = { 'clangd', 'pyright', 'rust-analyzer', 'lua-language-server', 'stylua', 'clang-format' },
        run_on_start = true,
        start_delay = 1000,
        notify = false,
      }
    end,
  },
}
