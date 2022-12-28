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
			nargs = 1,
			complete = function()
				return vim.tbl_keys(require("vtsls.commands"))
			end,
		})
	end,
	_on_detach = function(client_id, bufnr)
		local client = vim.lsp.get_client_by_id(client_id)
		if client.name == require("vtsls.config").get().name then
			pcall(vim.api.nvim_buf_del_user_command, bufnr, "VtsExec")
		end
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
