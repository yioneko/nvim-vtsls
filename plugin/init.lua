local group = vim.api.nvim_create_augroup("nvim-vtsls", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
	group = group,
	callback = function(args)
		if args.data and args.data.client_id then
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client.name ~= require("vtsls.config").get().name then
				return
			end
		end
		vim.api.nvim_buf_create_user_command(args.buf, "VtsExec", function(cargs)
			local command_name = cargs.fargs[1]
			if command_name then
				-- apply only on current win or buf
				require("vtsls").commands[command_name](0)
			end
		end, {
			nargs = 1,
			complete = function()
				return vim.tbl_keys(require("vtsls").commands)
			end,
		})
	end,
})

vim.api.nvim_create_autocmd("LspDetach", {
	group = group,
	callback = function(args)
		if args.data and args.data.client_id then
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client.name == require("vtsls.config").get().name then
				pcall(vim.api.nvim_buf_del_user_command, args.buf, "VtsExec")
			end
		end
	end,
})
