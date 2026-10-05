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
      -- Augroups are created once here, not inside the callbacks: an augroup with
      -- clear=true made from within its own autocmd deletes and re-registers the
      -- autocmd that is currently running.
      local attach_group = vim.api.nvim_create_augroup('lsp-attach', { clear = true })
      local highlight_group = vim.api.nvim_create_augroup('lsp-highlight', { clear = true })
      local detach_group = vim.api.nvim_create_augroup('lsp-detach', { clear = true })

      -- A nil function means "go through telescope by this builtin name": those
      -- pickers earn their keep with a preview pane over :cnext. The rest are
      -- native vim.lsp.buf calls, which land in the quickfix list -- what you
      -- want when there is a single hit.
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
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = highlight_group, buffer = event.buf }
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = false,
        signs = false,
        -- Render the message itself inline at the end of the offending line.
        -- `signs` and `underline` stay off, so this text is the only indicator --
        -- which means format must return a string for EVERY severity. Returning
        -- nil drops the diagnostic from virtual text outright
        -- (diagnostic_shared.reformat_diagnostics), leaving it invisible.
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

      -- PlatformIO cross-compiles with a bundled xtensa/riscv GCC. By default
      -- clangd refuses to execute a driver it doesn't recognise, so it falls
      -- back to guessing a host triple and resolves newlib headers (machine/endian.h,
      -- sys/cdefs.h, ...) against the host's glibc -- which reports bogus
      -- "'file' not found" diagnostics. --query-driver whitelists the real
      -- toolchain so clangd asks it for the correct target triple and its own
      -- sys-include paths.
      --
      -- Only the compiler drivers are whitelisted, not every binary in the
      -- toolchain's bin/ (linker, objcopy, ...) -- clangd only ever invokes
      -- these to interrogate the build, but there is no reason to widen it.
      -- The glob is rebuilt at startup so a fresh package install is picked up
      -- without editing this file. Note that expand() must not see the wildcard
      -- (it would expand it itself and glob would then match nothing).
      local packages_dir = vim.fn.expand '~/.platformio/packages'
      local pio_drivers = {}
      for _, driver in ipairs { '*-gcc', '*-g++' } do
        vim.list_extend(pio_drivers, vim.fn.glob(packages_dir .. '/toolchain-*/bin/' .. driver, 0, 1))
      end

      local clangd_cmd = { 'clangd', '--header-insertion=never' }
      if #pio_drivers > 0 then
        clangd_cmd[#clangd_cmd + 1] = '--query-driver=' .. table.concat(pio_drivers, ',')
      end

      local capabilities = require('blink.cmp').get_lsp_capabilities()
      local servers = {
        -- clangd's stock root_markers are all build artefacts (.git,
        -- compile_commands.json, .clangd, ...), so on a freshly cloned PlatformIO
        -- project vim.fs.root() returned nil until the first build and clangd
        -- resolved headers against nvim's cwd. platformio.ini is committed.
        clangd = {
          cmd = clangd_cmd,
          root_markers = { 'platformio.ini', '.clangd', 'compile_commands.json', '.git' },
        },
        pyright = { settings = { pyright = { autoImportCompletions = false } } },
        -- `pkg` is the mason package name, which differs from the lspconfig name
        -- for these two. Setting it also lets lspconfig find them in mason's bin.
        rust_analyzer = { pkg = 'rust-analyzer' },
        lua_ls = { pkg = 'lua-language-server', settings = { Lua = { completion = { callSnippet = 'Replace' } } } },
      }

      -- Only ask mason-tool-installer to act on packages that are genuinely absent.
      -- Its startup check refreshes the registry, and pyright ships via npm,
      -- which fnm only puts on PATH from an interactive shell -- from a desktop
      -- launcher that install failed silently, leaving the server missing (and
      -- its LSP dead). Gating on `missing` skips the check once all are
      -- installed. See :help mason-tool-installer.
      local registry = require 'mason-registry'
      local is_installed = function(pkg_name)
        local ok, pkg = pcall(registry.get_package, pkg_name)
        return ok and pkg:is_installed()
      end

      require('mason-lspconfig').setup {
        -- mason-lspconfig owns installation and `:h vim.lsp.enable()`; per-server
        -- options are applied below through vim.lsp.config.
        --
        -- NB: this used to pass a `handlers` table. mason-lspconfig v2 dropped
        -- that option (only `ensure_installed` and `automatic_enable` are read
        -- now), so the handler was silently dead and none of the per-server
        -- config below was ever applied.
      }

      -- Register each customised server and collect the mason packages that are
      -- still absent, in one pass over `servers`. The config is only *registered*
      -- here -- enabling/starting is left to mason-lspconfig's
      -- automatic_enable, so a server is never started twice with two different
      -- configs.
      local missing = {}
      for name, server in pairs(servers) do
        server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
        vim.lsp.config[name] = server
        local pkg_name = server.pkg or name
        if not is_installed(pkg_name) then
          missing[#missing + 1] = pkg_name
        end
      end

      -- 'clang-format' and 'stylua' aren't language servers, but
      -- mason-tool-installer is the only place in this config that provisions
      -- binaries, so they're listed here.
      for _, tool in ipairs { 'stylua', 'clang-format' } do
        if not is_installed(tool) then
          missing[#missing + 1] = tool
        end
      end

      require('mason-tool-installer').setup {
        ensure_installed = missing,
        run_on_start = #missing > 0,
        start_delay = 1000,
        notify = false,
      }

      -- :LspRestart was deprecated in Neovim 0.10 and removed in 0.11, so on
      -- 0.13 it is simply not a command any more. :lsp restart is the
      -- replacement and takes the client name as an optional argument, which
      -- :LspRestart used to do too. Keep the old name as an alias so the
      -- muscle memory still works.
      vim.api.nvim_create_user_command('LspRestart', function(opts)
        -- vim.cmd's table form wants args as a *list* of strings, and an empty
        -- client name has to be omitted rather than passed as "".
        local args = { 'restart' }
        local name = vim.trim(opts.args)
        if name ~= '' then
          args[#args + 1] = name
        end
        vim.cmd({ cmd = 'lsp', args = args })
      end, {
        nargs = '?',
        desc = 'Restart LSP server(s) (alias for :lsp restart)',
        complete = function(lead)
          return vim.tbl_filter(function(name)
            return name:find(lead, 1, true) == 1
          end, vim.tbl_keys(vim.lsp.get_clients {}))
        end,
      })
    end,
  },
}
