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
    -- notify the server of the formatting options actively to be free of passing that through
    -- configuration, this is mainly related to the text edit of refactor code action
    active_format_opts_notify = false,
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

## Credits

- [typescript.nvim](https://github.com/jose-elias-alvarez/typescript.nvim)
- [typescript-tools.nvim](https://github.com/pmizio/typescript-tools.nvim)
