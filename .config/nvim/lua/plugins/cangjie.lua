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

local function get_cjpm_metadata(root_dir)
  local result = {
    package = {
      name = 'default',
      src = 'src',
      target = 'target',
    },
  }

  -- parse cjpm.toml
  local cjpm_toml_fname = vim.fn.fnamemodify(root_dir, ':p')
    .. path_sep
    .. 'cjpm.toml'
  if vim.fn.filereadable(cjpm_toml_fname) then
    result = vim.tbl_deep_extend('force', result, parse_toml(cjpm_toml_fname))
  end

  return result
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
          args = function(self, ctx)
            return { '-c', 'cjfmt.toml', '-f', '$FILENAME' }
          end,
          range_args = function(self, ctx)
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
          args = function()
            local bufname = vim.api.nvim_buf_get_name(0)
            local cjpm_package_root = vim.fs.root(bufname, { 'cjpm.toml' })
            return { '-f', cjpm_package_root }
          end, -- list of arguments. Can contain functions with zero arguments that will be evaluated once the linter is used.
          stream = 'stderr', -- ('stdout' | 'stderr' | 'both') configure the stream to which the linter outputs the linting result.
          ignore_exitcode = true, -- set this to true if the linter exits with a code != 0 and that's considered normal.
          -- parser =
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
          cmd = { lsp_server_bin, 'src', '-V' },
          cmd_env = {
            CANGJIE_HOME = cangjie_home,
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
          },
          filetypes = { 'cangjie' },
          -- TODO: support workspaces via root_dir
          root_markers = {
            'cjpm.toml',
          },
          init_options = {
            modulesHomeOption = cangjie_home,
            stdLibPathOption = cangjie_home,
            telemetryOption = true,
          },
          before_init = function(init_params, config)
            local cjpm_meta = get_cjpm_metadata(config.root_dir)
            config.cmd = {
              lsp_server_bin,
              cjpm_meta.package.src,
              '-V',
            }
            config.init_options.targetLib = table.concat(
              { config.root_dir, cjpm_meta.package.target, 'release' },
              path_sep
            )
          end,
        },
      },
    },
  },
}
