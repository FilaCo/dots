local path_sep = '/'
local path_delim = ':'

local function get_arch()
  local cmd_handle = io.popen('uname -m', 'r')
  if not cmd_handle then
    return 'x86_64'
  end

  local cmd_output = cmd_handle:read '*l'
  cmd_handle:close()

  return cmd_output
end

local arch = get_arch()
local user_home = vim.fs.normalize(vim.env.HOME)

local cangjie_home = os.getenv 'CANGJIE_HOME'
  or user_home .. path_sep .. '.cangjie'
local cjpm_bin_fname = table.concat({ user_home, '.cjpm', 'bin' }, path_sep)
local cangjie_env = {
  CANGJIE_HOME = cangjie_home,
  CANGJIE_STDX_PATH = table.concat({
    cangjie_home,
    'cangjie_stdx',
    'target',
    'linux_' .. arch .. '_cjnative',
    'static',
    'stdx',
  }, path_sep),
  CANGJIE_PATH = table.concat({
    cangjie_home .. path_sep .. 'bin',
    table.concat({ cangjie_home, 'tools', 'bin' }, path_sep),
    cjpm_bin_fname,
  }, path_delim),
  PATH = table.concat({
    cangjie_home .. path_sep .. 'bin',
    table.concat({ cangjie_home, 'tools', 'bin' }, path_sep),
    vim.env.PATH or '',
    cjpm_bin_fname,
  }, path_delim),
  LD_LIBRARY_PATH = table.concat({
    table.concat({
      cangjie_home,
      'runtime',
      'lib',
      'linux_' .. arch .. '_cjnative',
    }, path_sep),
    table.concat({ cangjie_home, 'tools', 'lib' }, path_sep),
    vim.env.LD_LIBRARY_PATH or '',
  }, path_delim),
}

local lsp_server_bin =
  table.concat({ cangjie_home, 'tools', 'bin', 'LSPServer' }, path_sep)

local cjfmt_bin =
  table.concat({ cangjie_home, 'tools', 'bin', 'cjfmt' }, path_sep)

local cjlint_bin =
  table.concat({ cangjie_home, 'tools', 'bin', 'cjlint' }, path_sep)

local function parse_toml(fname)
  local TOML = require 'toml'
  return TOML.parse(table.concat(vim.fn.readfile(fname), '\n'))
end

local function make_multi_module_option(cjpm_metadata, root_dir)
  local multi_module_option = {}

  local root_uri = vim.uri_from_fname(root_dir)
  multi_module_option[root_uri] = {
    name = cjpm_metadata.package.name,
    requires = cjpm_metadata.requires,
  }
  return multi_module_option
end

local function get_cjpm_metadata(root_dir)
  local result = {
    package = {
      name = 'default',
    },
  }

  -- parse cjpm.toml
  local cjpm_toml_fname = vim.fn.fnamemodify(root_dir, ':p')
    .. path_sep
    .. 'cjpm.toml'
  if vim.fn.filereadable(cjpm_toml_fname) == 1 then
    result = vim.tbl_deep_extend('force', result, parse_toml(cjpm_toml_fname))

    result.package['target-dir'] = result.package['target-dir'] ~= ''
        and result.package['target-dir']
      or 'target'

    result.package['src-dir'] = result.package['src-dir'] ~= ''
        and result.package['src-dir']
      or 'src'
  end

  -- parse cjpm.lock
  local cjpm_lock_fname = vim.fn.fnamemodify(root_dir, ':p')
    .. path_sep
    .. 'cjpm.lock'
  if vim.fn.filereadable(cjpm_lock_fname) == 1 then
    result = vim.tbl_deep_extend('force', result, parse_toml(cjpm_lock_fname))
  end

  -- fill [requires]

  return result
end

local severities = {
  ['error'] = vim.diagnostic.severity.ERROR,
  ['warning'] = vim.diagnostic.severity.WARN,
}

local function cjlint_parse(diags, fname, item)
  -- 1 - buf fname
  -- 2 - line
  -- 3 - col
  -- 4 - severity
  -- 5 - Cangjie linter error code
  -- 6 - Cangjie linter error message
  local splitted = vim.split(item, ':')

  if #splitted == 0 or #splitted < 6 then
    return
  end

  -- Show only current file diags (should we?)
  if splitted[1] ~= fname then
    return
  end

  local str_lnum = splitted[2]:gsub('%D', '')
  local str_col = splitted[3]:gsub('%D', '')
  -- strip ANSI from cjlint stderr report https://stackoverflow.com/a/49209650/368691
  local raw_severity =
    splitted[4]:gsub('[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]', '')

  str_lnum = vim.trim(str_lnum)
  str_col = vim.trim(str_col)
  raw_severity = vim.trim(raw_severity)
  local code = vim.trim(splitted[5])
  local message = vim.trim(splitted[6])

  ---@type vim.Diagnostic
  local diag = {
    source = fname,
    lnum = tonumber(str_lnum) - 1 or 0,
    col = tonumber(str_col) - 1 or 0,
    severity = severities[raw_severity],
    code = code,
    message = message,
  }
  table.insert(diags, diag)
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        'cangjie',
      })
    end,
  },
  {
    'stevearc/conform.nvim',
    opts = {
      formatters_by_ft = {
        cangjie = { 'cjfmt' },
      },
      formatters = {
        ---@type conform.FileFormatterConfig
        cjfmt = {
          meta = {
            url = 'https://gitcode.com/Cangjie/cangjie_tools',
            description = 'An automated code formatting tool developed based on the Cangjie language programming specifications.',
          },
          command = cjfmt_bin,
          args = function(_, _)
            return { '-c', 'cjfmt.toml', '-f', '$FILENAME' }
          end,
          range_args = function(_, ctx)
            return { '-l' .. ctx.range.start[1] .. ':' .. ctx.range['end'][1] }
          end,
          cwd = require('conform.util').root_file {
            'cjfmt.toml',
          },
          stdin = false,
        },
      },
    },
  },
  {
    'mfussenegger/nvim-lint',
    opts = {
      linters_by_ft = {
        cangjie = { 'cjlint' },
      },
      linters = {
        cjlint = {
          cmd = cjlint_bin,
          stdin = false,
          append_fname = false,
          args = {
            '-f',
            function()
              return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:h')
            end,
          },
          stream = 'stderr',
          env = cangjie_env,
          parser = function(output, bufnr, _)
            local diags = {}
            local items = #output > 0 and vim.split(output, '\n') or {}
            local fname = vim.api.nvim_buf_get_name(bufnr)
            for _, i in ipairs(items) do
              cjlint_parse(diags, fname, i)
            end

            return diags
          end,
        },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        ---@type vim.lsp.Config
        cangjie = {
          cmd = {
            lsp_server_bin,
            '--unconfigured',
          },
          cmd_env = cangjie_env,
          filetypes = { 'cangjie' },
          -- TODO: support workspaces via root_dir
          root_markers = {
            'cjpm.toml',
            '.git',
          },
          settings = {
            cangjie = {},
          },
          single_file_support = true,
          before_init = function(init_params, config)
            local cjpm_metadata = get_cjpm_metadata(config.root_dir)

            init_params.initializationOptions = {
              targetLib = table.concat({
                config.root_dir,
                cjpm_metadata.package['target-dir'],
                'release',
              }, path_sep),
              multiModuleOption = make_multi_module_option(
                cjpm_metadata,
                config.root_dir
              ),
            }

            init_params.workspaceFolders = {
              {
                uri = vim.uri_from_fname(config.root_dir),
                name = vim.fn.fnamemodify(config.root_dir, ':t'),
              },
            }
          end,
          on_attach = function(client, bufnr)
            local root_dir = vim.fs.root(bufnr, 'cjpm.toml')
              or client.config.root_dir
              or cangjie_home

            local cjpm_metadata = get_cjpm_metadata(root_dir)

            client.config.cmd = {
              lsp_server_bin,
              cjpm_metadata.package['src-dir'],
              '-V',
              '--disableAutoImport',
            }
          end,
        },
      },
    },
  },
}
