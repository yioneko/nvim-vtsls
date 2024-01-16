local function gen_config()
	local util = require("lspconfig.util")

	local cmd = { "vtsls", "--stdio" }

	if vim.fn.has("win32") == 1 then
		cmd = { "cmd.exe", "/C", unpack(cmd) }
	end

	return {
		default_config = {
			cmd = cmd,
			filetypes = {
				"javascript",
				"javascriptreact",
				"javascript.jsx",
				"typescript",
				"typescriptreact",
				"typescript.tsx",
			},
			root_dir = function(fname)
				return util.root_pattern("tsconfig.json", "jsconfig.json")(fname)
					or util.root_pattern("package.json", ".git")(fname)
			end,
			single_file_support = true,
			settings = {
				typescript = {
					updateImportsOnFileMove = "always",
				},
				javascript = {
					updateImportsOnFileMove = "always",
				},
				vtsls = {
					enableMoveToFileCodeAction = true,
				},
			},
		},
	}
end

return gen_config()
