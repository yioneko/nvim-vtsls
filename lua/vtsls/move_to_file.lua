local async = require("vtsls.async")
local o = require("vtsls.config")

local function exec_command(bufnr, client, command, args)
	return async.request(client, "workspace/executeCommand", {
		command = command,
		arguments = args,
	}, bufnr)
end

local function to_file_range_request_args(file, range)
	return {
		file = file,
		startLine = range.start.line + 1,
		startOffset = range.start.character + 1,
		endLine = range["end"].line + 1,
		endOffset = range["end"].character + 1,
	}
end

return function(client)
	local function get_target_file(uri, range)
		local bufnr = vim.uri_to_bufnr(uri)
		local fname = vim.uri_to_fname(uri)
		local err, response = exec_command(
			bufnr,
			client,
			"typescript.tsserverRequest",
			{ "getMoveToRefactoringFileSuggestions", to_file_range_request_args(fname, range) }
		)
		if err or response.type ~= "response" or not response.body then
			error("get candidate target files failed: " .. vim.inspect(response))
		end

		local files = response.body.files
		local target = async.call(vim.ui.select, files, {
			prompt = "Select target file",
			format_item = function(path)
				return vim.fn.fnamemodify(path, ":.")
			end,
		})
		return target
	end

	local function move_to_file_handler(command)
		async.exec(function()
			local args = command.arguments
			local action = args[1]
			local uri = args[2]
			local range = args[3]

			local bufnr = vim.uri_to_bufnr(uri)
			local target_file = get_target_file(uri, range)
			exec_command(bufnr, client, command.command, { action, uri, range, target_file })
		end, o.get().default_resolve, o.get().default_reject)
	end

	return move_to_file_handler
end
