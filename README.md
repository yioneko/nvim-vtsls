# nvim-vtsls

Plugin to help utilize capabilities of [vtsls](https://github.com/yioneko/vtsls).

## Setup

Not needed. The command will be automatically created on `LspAttach` event.

## Usage

```vim
:VtsExec {command}
```

## Config

```lua
require('vtsls').config({
    -- lsp server name
    name = "vtsls",
    -- customize handlers for commands
    handlers = {
        source_definition = function(err, locations) end,
        file_references = function(err, locations) end,
        code_action = function(err, actions) end,
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
| `goto_project_config`    | Open `tsconfig.json` or `jsconfig.json`.                                 |
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

-- These callbacks are useful if you want to promisify the command functions to write async code.
function on_resolve() end -- after handler called
function on_reject(msg_or_err) end -- in case any error happens
```

## Credits

- [typescript.nvim](https://github.com/jose-elias-alvarez/typescript.nvim)
