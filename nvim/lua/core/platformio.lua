local function pio_exe()
  local exe = vim.fn.exepath 'pio'
  if exe ~= '' then
    return exe
  end
  local fallback = vim.fn.expand '~/.platformio/penv/bin/pio'
  return vim.fn.filereadable(fallback) == 1 and fallback or ''
end

local function pio_root(bufnr)
  local buf = (bufnr and vim.api.nvim_buf_is_valid(bufnr)) and bufnr or 0
  return vim.fs.root(buf, 'platformio.ini') or vim.fs.root(vim.fn.getcwd(), 'platformio.ini')
end

local function restart_clangd(bufnr)
  local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'clangd' }
  if #clients == 0 then
    return
  end
  for _, client in ipairs(clients) do
    client:stop()
  end
  vim.api.nvim_exec_autocmds('FileType', { buffer = bufnr, modeline = false })
end

local function generate_cdb(root, bufnr)
  local exe = pio_exe()
  if exe == '' then
    vim.notify('pio executable not found; install PlatformIO Core', vim.log.levels.ERROR)
    return
  end

  vim.notify('PlatformIO: generating compile_commands.json (runs a build once)...')
  vim.system({ exe, 'run', '-t', 'compiledb', '-d', root }, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify('PlatformIO: `pio run -t compiledb` failed:\n' .. (res.stderr or ''), vim.log.levels.ERROR)
        return
      end
      vim.notify('PlatformIO: compile_commands.json updated')
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        restart_clangd(bufnr)
      end
    end)
  end)
end

local attempted = {}

vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('platformio', { clear = true }),
  callback = function(event)
    local root = pio_root(event.buf)
    if not root or attempted[root] then
      return
    end
    if vim.fn.filereadable(root .. '/compile_commands.json') == 1 then
      return
    end
    attempted[root] = true
    generate_cdb(root, event.buf)
  end,
})

vim.api.nvim_create_user_command('PioCdb', function()
  local root = pio_root(0)
  if not root then
    vim.notify('No platformio.ini found for this buffer or the current directory', vim.log.levels.ERROR)
    return
  end
  generate_cdb(root, 0)
end, { desc = 'Regenerate compile_commands.json for the PlatformIO project' })
