local lazy_mod = {
	commands = function()
		return require("vtsls.commands")
	end,
	config = function()
		return require("vtsls.config").override
	end,
	lspconfig = function()
		return require("vtsls.lspconfig")
	end,
	rename = function()
		return require("vtsls.rename")
	end,
}

return setmetatable({
	_on_attach = function(client_id, bufnr)
		local client = vim.lsp.get_client_by_id(client_id)
		if client.name ~= require("vtsls.config").get().name then
			return
		end
		vim.api.nvim_buf_create_user_command(bufnr, "VtsExec", function(cargs)
			local command_name = cargs.fargs[1]
			if command_name then
				-- apply only on current win or buf
				require("vtsls.commands")[command_name](0)
			end
		end, {
			desc = "Execute vtsls commands",
			nargs = 1,
			complete = function(arglead)
				local opts = vim.tbl_keys(require("vtsls.commands"))
				if not arglead or arglead == "" then
					return opts
				end
				return vim.tbl_filter(function(opt)
					return vim.startswith(opt, arglead)
				end, opts)
			end,
		})

		if not vim.api.nvim_get_commands({})["VtsRename"] then
			vim.api.nvim_create_user_command("VtsRename", function(cargs)
				local from = cargs.fargs[1]
				local to = cargs.fargs[2]
				if from and to then
					require("vtsls.rename")(from, to)
				else
					print("Missing args for rename")
				end
			end, {
				desc = "Rename file or directory and update import paths",
				nargs = "*",
				complete = "file",
			})
		end

		if not client.commands["editor.action.rename"] and require("vtsls.config").get().refactor_auto_rename then
			client.commands["editor.action.rename"] = function(command)
				for _, renaming in ipairs(command.arguments) do
					local uri = renaming[1]
					local pos = renaming[2]
					local applied_bufnr = vim.uri_to_bufnr(uri)
					vim.api.nvim_set_current_buf(applied_bufnr)
					local line = pos.line + 1
					-- TODO: consider copying this util function
					local col = vim.lsp.util._get_line_byte_from_position(applied_bufnr, pos, client.offset_encoding)
					vim.api.nvim_win_set_cursor(0, { line, col })
					vim.lsp.buf.rename()
					-- only rename once
					break
				end
			end
		end
		require("vtsls.format-notifier").attach(client, bufnr)
	end,
	_on_detach = function(client_id, bufnr)
		local client = vim.lsp.get_client_by_id(client_id)
		local vtsls_name = require("vtsls.config").get().name
		if client.name == vtsls_name then
			pcall(vim.api.nvim_buf_del_user_command, bufnr, "VtsExec")
			if #vim.lsp.get_active_clients({ name = vtsls_name }) == 0 then
				pcall(vim.api.nvim_del_user_command, "VtsRename")
			end
		end
		require("vtsls.format-notifier").detach(client, bufnr)
	end,
}, {
	__index = function(tbl, key)
		local value = rawget(tbl, key)
		if value == nil and lazy_mod[key] then
			value = lazy_mod[key]()
			rawset(tbl, key, value)
		end
		return value
	end,
})
