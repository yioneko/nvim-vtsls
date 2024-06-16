local M = {}

M.lsp_get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

local global_registered_commands = {}

function M.register_client_command(client, command, handler)
	if global_registered_commands[command] then
		return
	end
	if client.config.commands == client.commands then
		-- There is a bug in nvim-lspconfig: https://github.com/neovim/nvim-lspconfig/issues/3009
		-- Until the deprecated `commands` get removed in nvim-lspconfig, try to avoid error like #5
		if vim.lsp.commands[command] then
			vim.notify(
				"[vtsls]: Skip registering " .. command .. " which is already registered by user config or other plugin",
				vim.log.levels.WARN
			)
			return
		end
		vim.lsp.commands[command] = handler
		global_registered_commands[command] = true
	elseif not client.commands[command] then
		-- Safe to add to client.commands
		client.commands[command] = handler
	end
end

return M
