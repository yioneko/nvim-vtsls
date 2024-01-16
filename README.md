# nvim-vtsls

Plugin to help utilize capabilities of [vtsls](https://github.com/yioneko/vtsls).

**NOTE**: This plugin is **not needed** to work with `vtsls`. It simply offers some extra helper commands and optional improvements. Any server related issue should go up to the upstream.

## Usage

### Setup server

Through [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig):

```lua
require("lspconfig.configs").vtsls = require("vtsls").lspconfig -- set default server config, optional but recommended

-- If the lsp setup is taken over by other plugin, it is the same to call the counterpart setup function
require("lspconfig").vtsls.setup({ --[[ your custom server config here ]] })
```

### Execute commands

```vim
:VtsExec {command}
```

### Rename file/folder and update import paths

```vim
:VtsRename {from} {to}
```

## Config

This is OPTIONAL. All the fields are also optional.

```lua
require('vtsls').config({
  -- customize handlers for commands
  handlers = {
    source_definition = function(err, locations) end,
    file_references = function(err, locations) end,
    code_action = function(err, actions) end,
  },
  -- automatically trigger renaming of extracted symbol
  refactor_auto_rename = true,
  refactor_move_to_file = {
    -- controls how path is displayed for selection of destination file
    -- "default" | "vscode" | function(path: string) -> string
    path_display = "default",
    -- If dressing.nvim is installed, telescope will be used for selection prompt. Use this to customize the opts for telescope picker.
    telescope_opts = function(items) end,
  }
})
```

## Commands

| name                     | description                                                              |
| ------------------------ | ------------------------------------------------------------------------ |
| `restart_tsserver`       | This not restart vtsls itself, but restart the underlying tsserver.      |
| `open_tsserver_log`      | It will open prompt if logging has not been enabled.                     |
| `reload_projects`        |                                                                          |
| `select_ts_version`      | Select version of ts either from workspace or global.                    |
| `goto_project_config`    | Open `tsconfig.json`.                                                    |
| `goto_source_definition` | Go to the source definition instead of typings.                          |
| `file_references`        | Show references of the current file.                                     |
| `rename_file`            | Rename the current file and update all the related paths in the project. |
| `organize_imports`       |                                                                          |
| `sort_imports`           |                                                                          |
| `remove_unused_imports`  |                                                                          |
| `fix_all`                |                                                                          |
| `remove_unused`          |                                                                          |
| `add_missing_imports`    |                                                                          |
| `source_actions`         | Pick applicable source actions (same as above)                           |

## API

```lua
require('vtsls').commands[any_command_name](bufnr, on_resolve, on_reject)
require('vtsls').commands.goto_source_definition(winnr, on_resolve, on_reject) -- goto_source_definition requires winnr
require('vtsls').rename(old_name, new_name, on_resolve, on_reject) -- rename file or folder

-- These callbacks are useful if you want to promisify the command functions to write async code.
function on_resolve() end -- after handler called
function on_reject(msg_or_err) end -- in case any error happens
```

## Other useful snippets

<details>
<summary>Common settings to enable inlay hints</summary>

```lua
{
  settings = {
    typescript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      }
    },
  }
}
```

</details>

<details>
<summary>Handler for codelens command</summary>

```lua
vim.lsp.commands["editor.action.showReferences"] = function(command, ctx)
  local locations = command.arguments[3]
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if locations and #locations > 0 then
    local items = vim.lsp.util.locations_to_items(locations, client.offset_encoding)
    vim.fn.setloclist(0, {}, " ", { title = "References", items = items, context = ctx })
    vim.api.nvim_command("lopen")
  end
end
```

Then executing `vim.lsp.codelens.run()` will open up a quickfix window for references shown by the lens.

</details>

<details>
<summary>Integration to <a href='https://github.com/nvim-tree/nvim-tree.lua'>nvim-tree.lua</a> for automatic renamed paths update</summary>

Excellent replacement for manually calling `:VtsExec rename_file` or `:VtsRename`.

The following snippet also works for any server supporting `workspace/didRenameFiles` notification.

```lua
local path_sep = package.config:sub(1, 1)

local function trim_sep(path)
  return path:gsub(path_sep .. "$", "")
end

local function uri_from_path(path)
  return vim.uri_from_fname(trim_sep(path))
end

local function is_sub_path(path, folder)
  path = trim_sep(path)
  folder = trim_sep(path)
  if path == folder then
    return true
  else
    return path:sub(1, #folder + 1) == folder .. path_sep
  end
end

local function check_folders_contains(folders, path)
  for _, folder in pairs(folders) do
    if is_sub_path(path, folder.name) then
      return true
    end
  end
  return false
end

local function match_file_operation_filter(filter, name, type)
  if filter.scheme and filter.scheme ~= "file" then
    -- we do not support uri scheme other than file
    return false
  end
  local pattern = filter.pattern
  local matches = pattern.matches

  if type ~= matches then
    return false
  end

  local regex_str = vim.fn.glob2regpat(pattern.glob)
  if vim.tbl_get(pattern, "options", "ignoreCase") then
    regex_str = "\\c" .. regex_str
  end
  return vim.regex(regex_str):match_str(name) ~= nil
end

local api = require("nvim-tree.api")
api.events.subscribe(api.events.Event.NodeRenamed, function(data)
  local stat = vim.loop.fs_stat(data.new_name)
  if not stat then
    return
  end
  local type = ({ file = "file", directory = "folder" })[stat.type]
  local clients = vim.lsp.get_active_clients({})
  for _, client in ipairs(clients) do
    if check_folders_contains(client.workspace_folders, data.old_name) then
      local filters = vim.tbl_get(client.server_capabilities, "workspace", "fileOperations", "didRename", "filters")
        or {}
      for _, filter in pairs(filters) do
        if
          match_file_operation_filter(filter, data.old_name, type)
          and match_file_operation_filter(filter, data.new_name, type)
        then
          client.notify(
            "workspace/didRenameFiles",
            { files = { { oldUri = uri_from_path(data.old_name), newUri = uri_from_path(data.new_name) } } }
          )
        end
      end
    end
  end
end)
```

</details>

## Credits

- [typescript.nvim](https://github.com/jose-elias-alvarez/typescript.nvim)
- [typescript-tools.nvim](https://github.com/pmizio/typescript-tools.nvim)
