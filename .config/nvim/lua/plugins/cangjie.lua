local description = [[
Cangjie is a general-purpose programming language designed for application development across all scenarios.
It balances development efficiency and runtime performance, and provides a good programming experience.
]]

local CANGJIE_HOME = os.getenv 'CANGJIE_HOME'
local enable_log = true

local isWindows = vim.fn.has 'win32' == 1 or vim.fn.has 'win64' == 1
local pathSeparator = isWindows and '\\' or '/'
local pathDelimeter = isWindows and ';' or ':'
-- Windows下使用USERPROFILE替代HOME
local home_dir = isWindows and vim.fn.getenv 'USERPROFILE'
  or vim.fn.getenv 'HOME'
local cjpm_bin_path = isWindows and 'cjpm\\bin' or '.cjpm/bin'

-- Windows平台URI格式处理(https://gitcode.com/ystyle/cangjie-nvim)
local function format_windows_uri(uri)
  local prefix = 'file:///'
  if uri:sub(1, #prefix) == prefix then
    local path_part = uri:sub(#prefix + 1)
    -- 检查是否是Windows驱动器路径
    if path_part:match '^[A-Za-z]:' then
      -- 转换为小写驱动器字母并转义冒号
      local drive_letter = path_part:sub(1, 1):lower()
      local rest_path = path_part:sub(3)
      return prefix .. drive_letter .. '%3A' .. rest_path
    end
  end
  return uri
end

-- 使用 TOML 解析库解析文件(https://gitcode.com/ystyle/cangjie-nvim)
local function parse_toml_with_library(file_path)
  local TOML
  local ok = pcall(function()
    TOML = require 'toml2lua'
  end)

  if not ok or not TOML then
    return nil
  end

  local success, parsed = pcall(function()
    return TOML.parse(vim.fn.readfile(file_path))
  end)

  return success and parsed or nil
end

-- 回退解析逻辑：解析 cjpm.toml(https://gitcode.com/ystyle/cangjie-nvim)
local function parse_cjpm_toml_fallback(file_path, root_dir)
  local package_name = 'default'
  local package_src = 'src'
  local package_target = 'target'
  local dependencies = {}

  local toml_content = vim.fn.readfile(file_path)
  local in_package = false
  local in_dependencies = false

  for _, line in ipairs(toml_content) do
    if line:match '^%s*%[package%]%s*$' then
      in_package = true
      in_dependencies = false
    elseif line:match '^%s*%[dependencies%]%s*$' then
      in_dependencies = true
      in_package = false
    elseif line:match '^%s*%[' then
      in_package = false
      in_dependencies = false
    end

    if in_package then
      local name_match = line:match '^%s*name%s*=%s*[\'"]([^\'"]+)[\'"]'
      if name_match then
        package_name = name_match
      end

      local src_match = line:match '^%s*src-dir%s*=%s*[\'"]([^\'"]+)[\'"]'
      if src_match and src_match ~= '' then
        package_src = src_match
      end

      local target_match = line:match '^%s*target-dir%s*=%s*[\'"]([^\'"]+)[\'"]'
      if target_match and target_match ~= '' then
        package_target = target_match
      end
    end

    if in_dependencies then
      local dep_name, path_val =
        line:match '^%s*([%w_]+)%s*=%s*{.-path%s*=%s*[\'"]([^\'"]+)[\'"]'
      if dep_name and path_val then
        local abs_path = path_val:sub(1, 1) == '/' and path_val
          or vim.fn.fnamemodify(root_dir, ':p') .. path_val
        dependencies[dep_name] = {
          type = 'path',
          path = vim.uri_from_fname(abs_path),
        }
      end

      local git_dep_name, git_url, git_branch =
        line:match '^%s*([%w_]+)%s*=%s*{.-git%s*=%s*[\'"]([^\'"]+)[\'"].-branch%s*=%s*[\'"]([^\'"]+)[\'"]'
      if git_dep_name and git_url then
        dependencies[git_dep_name] = {
          type = 'git',
          git = git_url,
          branch = git_branch or 'master',
        }
      end
    end
  end

  return {
    name = package_name,
    src = package_src,
    target = package_target,
    dependencies = dependencies,
  }
end

-- 回退解析逻辑：解析 cjpm.lock(https://gitcode.com/ystyle/cangjie-nvim)
local function parse_cjpm_lock_fallback(file_path, dependencies)
  local lock_content = vim.fn.readfile(file_path)
  for _, line in ipairs(lock_content) do
    for dep_name, dep_info in pairs(dependencies) do
      if dep_info.type == 'git' then
        local pattern = dep_name
          .. '%s*=%s*{.-commitId%s*=%s*[\'"]([a-f0-9]+)[\'"]'
        local commit_match = line:match(pattern)
        if commit_match then
          dep_info.commitId = commit_match
        end
      end
    end
  end
end

-- 使用 TOML 库解析 cjpm.toml(https://gitcode.com/ystyle/cangjie-nvim)
local function parse_cjpm_toml_with_library(file_path, root_dir)
  local parsed = parse_toml_with_library(file_path)
  if not parsed then
    return nil
  end

  local package_name = parsed.package and parsed.package.name or 'default'
  local dependencies = {}

  if parsed.dependencies then
    for dep_name, dep_config in pairs(parsed.dependencies) do
      if type(dep_config) == 'table' then
        if dep_config.path then
          local abs_path = dep_config.path:sub(1, 1) == '/' and dep_config.path
            or vim.fn.fnamemodify(root_dir, ':p') .. dep_config.path
          dependencies[dep_name] = {
            type = 'path',
            path = vim.uri_from_fname(abs_path),
          }
        elseif dep_config.git then
          dependencies[dep_name] = {
            type = 'git',
            git = dep_config.git,
            branch = dep_config.branch or 'master',
          }
        end
      end
    end
  end

  return {
    name = package_name,
    src = parsed['src-dir'],
    target = parsed['target-dir'],
    dependencies = dependencies,
  }
end

-- 使用 TOML 库解析 cjpm.lock(https://gitcode.com/ystyle/cangjie-nvim)
local function parse_cjpm_lock_with_library(file_path, dependencies)
  local parsed = parse_toml_with_library(file_path)
  if not parsed then
    return
  end

  for dep_name, dep_info in pairs(dependencies) do
    if dep_info.type == 'git' and parsed[dep_name] then
      dep_info.commitId = parsed[dep_name].commitId
    end
  end
end

-- 获取项目信息
local function get_project_info(root_dir)
  local package_name = 'default'
  local package_src = 'src'
  local package_target = 'target'
  local dependencies = {}
  local requires = {}

  -- 解析 cjpm.toml
  local cjpm_toml_path = vim.fn.fnamemodify(root_dir, ':p') .. 'cjpm.toml'
  if vim.fn.filereadable(cjpm_toml_path) == 1 then
    local result = parse_cjpm_toml_with_library(cjpm_toml_path, root_dir)
      or parse_cjpm_toml_fallback(cjpm_toml_path, root_dir)
    if result then
      package_name = result.name
      package_src = result.src
      package_target = result.target
      dependencies = result.dependencies
    end
  end

  -- 解析 cjpm.lock
  local cjpm_lock_path = vim.fn.fnamemodify(root_dir, ':p') .. 'cjpm.lock'
  if vim.fn.filereadable(cjpm_lock_path) == 1 then
    local has_library =
      parse_cjpm_lock_with_library(cjpm_lock_path, dependencies)
    if not has_library then
      parse_cjpm_lock_fallback(cjpm_lock_path, dependencies)
    end
  end

  -- 构建 requires
  for dep_name, dep_info in pairs(dependencies) do
    if dep_info.type == 'git' and dep_info.commitId then
      local git_path = home_dir
        .. '/.cjpm/git/'
        .. dep_name
        .. '/'
        .. dep_info.commitId
      requires[dep_name] = {
        git = dep_info.git,
        branch = dep_info.branch,
        path = vim.uri_from_fname(git_path),
      }
    elseif dep_info.type == 'path' then
      requires[dep_name] = {
        path = dep_info.path,
      }
    end
  end
  retrun {
    name = package_name,
    src = package_src,
    target = package_target,
    requires = requires,
  }
end

-- (https://gitcode.com/ystyle/cangjie-nvim)
local function create_multi_module_option(requires, root_dir)
  -- 构建 multiModuleOption
  local multi_module_config = {}
  for dep_name, dep_info in pairs(requires) do
    if dep_info.git and dep_info.path then
      local uri = dep_info.path
      if isWindows then
        uri = format_windows_uri(uri)
      end
      multi_module_config[uri] = {
        name = dep_name,
        requires = {},
      }
    end
  end

  local root_uri = vim.uri_from_fname(root_dir)
  if isWindows then
    root_uri = format_windows_uri(root_uri)
  end
  multi_module_config[root_uri] = {
    name = package_name,
    requires = requires,
  }
  return multi_module_config
end

local lspserver = table.concat({
  CANGJIE_HOME,
  'tools',
  'bin',
  'LSPServer',
}, pathSeparator) .. (isWindows and '.exe' or '')

local default_config = {
  cmd = { lspserver, 'src', '--disableAutoImport', '-V' },
  cmd_env = {
    PATH = table.concat({
      vim.env.PATH or '',
      CANGJIE_HOME .. pathSeparator .. 'bin',
      CANGJIE_HOME .. pathSeparator .. 'tools' .. pathSeparator .. 'bin',
      home_dir .. pathSeparator .. cjpm_bin_path,
    }, pathDelimeter),
    LD_LIBRARY_PATH = table.concat({
      table.concat(
        { CANGJIE_HOME, 'runtime', 'lib', 'linux_x86_64_llvm' },
        pathSeparator
      ),
      table.concat({ CANGJIE_HOME, 'tools', 'lib' }, pathSeparator),
      CANGJIE_HOME .. pathSeparator .. 'lib',
      table.concat({ CANGJIE_HOME, 'lib', 'linux_x86_64_llvm' }, pathSeparator),
      vim.env.LD_LIBRARY_PATH or '',
    }, pathDelimeter),
    CANGJIE_PATH = table.concat({
      CANGJIE_HOME .. pathSeparator .. 'bin',
      CANGJIE_HOME .. pathSeparator .. 'tools' .. pathSeparator .. 'bin',
      home_dir .. pathSeparator .. cjpm_bin_path,
    }, pathDelimeter),
    CANGJIE_LD_LIBRARY_PATH = table.concat({
      table.concat(
        { CANGJIE_HOME, 'runtime', 'lib', 'linux_x86_64_llvm' },
        pathSeparator
      ),
      CANGJIE_HOME .. pathSeparator .. 'tools' .. pathSeparator .. 'lib',
    }, pathDelimeter),
  },
  filetypes = { 'cangjie' },
  pattern = { '.cj' },
  autostart = true,
  version = '',
  name = '',
  single_file_support = true,
  capabilities = {
    textDocument = {
      completion = {
        editsNearCursor = true,
      },
    },
    offsetEncoding = { 'utf-8', 'utf-16' },
  },
  init_options = {
    modulesHomeOption = CANGJIE_HOME,
    stdLibPathOption = CANGJIE_HOME
      .. pathSeparator
      .. 'lib'
      .. pathSeparator
      .. 'linux_x86_64_llvm',
    conditionCompileOption = {},
    singleConditionCompileOption = {},
    conditionCompilePaths = {},
    telemetryOption = true,
  },
}

local client_capabilities =
  vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
        relativePatternSupport = true,
      },
      configuration = true,
    },
    textDocument = {
      semanticTokens = nil,
      completion = {
        dynamicRegistration = true,
        completionItem = {
          snippetSupport = true,
          resolveSupport = {
            properties = { 'documentation', 'detail', 'additionalTextEdits' },
          },
        },
        completionItemKind = {
          valueSet = {
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
            16,
            17,
            18,
            19,
            20,
            21,
            22,
            23,
            24,
            25,
          },
        },
      },
      codeAction = {
        dynamicRegistration = true,
        resolveSupport = {
          properties = { 'edit' },
        },
        codeActionLiteralSupport = {
          codeActionKind = {
            valueSet = {
              '',
              'quickfix',
              'refactor',
              'refactor.extract',
              'refactor.inline',
              'refactor.rewrite',
              'source',
              'source.organizeImports',
            },
          },
        },
      },
      hover = {
        dynamicRegistration = true,
        contentFormat = { 'markdown', 'plaintext' },
      },
      definition = {
        dynamicRegistration = true,
        linkSupport = true,
      },
      references = {
        dynamicRegistration = true,
      },
      documentHighlight = {
        dynamicRegistration = true,
      },
      documentSymbol = {
        dynamicRegistration = true,
        hierarchicalDocumentSymbolSupport = true,
      },
      rename = {
        dynamicRegistration = true,
        prepareSupport = true,
      },
      signatureHelp = {
        dynamicRegistration = true,
        signatureInformation = {
          documentationFormat = { 'markdown', 'plaintext' },
          parameterInformation = { labelOffsetSupport = true },
          activeParameterSupport = true,
        },
      },
    },
  })

return {
  'neovim/nvim-lspconfig',
  dependencies = {
    'nexo-tech/toml2lua',
  },
  config = function()
    local lspconfig = require 'lspconfig'
    local util = require 'lspconfig.util'
    local configs = require 'lspconfig.configs'

    if not configs.cangjie then
      configs.cangjie = {
        default_config = default_config,
        docs = {
          description = description,
        },
      }
    end

    lspconfig.cangjie.setup {
      flags = {
        debounce_text_changes = 150,
      },
      capabilities = client_capabilities,

      root_dir = util.root_pattern 'cjpm.toml',

      on_new_config = function(config, root_dir)
        local package = get_project_info(root_dir)
        local log_dir = vim.g.log_dir or root_dir

        config.cmd = { lspserver, package.src, '--disableAutoImport', '-V' }
        if enable_log then
          table.insert(config.cmd, '--enable-log=true')
          table.insert(config.cmd, '--log-path=' .. log_dir)
        end

        config.init_options = config.init_options or {}
        config.init_options.targetLib = root_dir
          .. pathSeparator
          .. package.target
          .. pathSeparator
          .. 'release'
        config.init_options.multiModuleOption =
          create_multi_module_config(package.requires, root_dir)

        -- workspace folders
        local workspace_name = vim.fn.fnamemodify(root_dir, ':t')
        local workspace_uri = vim.uri_from_fname(root_dir)
        if isWindows then
          workspace_uri = format_windows_uri(workspace_uri)
        end
        config.workspace_folders = {
          {
            uri = workspace_uri,
            name = workspace_name,
          },
        }

        return true
      end,
    }
  end,
}
