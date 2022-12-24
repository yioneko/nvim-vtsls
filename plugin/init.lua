local group = vim.api.nvim_create_augroup("nvim-vtsls", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
	group = group,
	callback = function(args)
		if args.data and args.data.client_id then
			require("vtsls")._on_attach(args.data.client_id, args.buf)
		end
	end,
})

vim.api.nvim_create_autocmd("LspDetach", {
	group = group,
	callback = function(args)
		if args.data and args.data.client_id then
			require("vtsls")._on_detach(args.data.client_id, args.buf)
		end
	end,
})
